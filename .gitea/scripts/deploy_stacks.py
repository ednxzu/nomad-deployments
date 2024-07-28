import os
import subprocess
import argparse
from typing import Tuple, List, Set, Dict
from prettytable import PrettyTable
import logging

SUCCESS_EMOJI = "✅"
ERROR_EMOJI = "❌"
INFO_EMOJI = "ℹ️"
WARN_EMOJI = "❗"
DEBUG_EMOJI = "🔍"
SKIPPED_EMOJI = "⏭️"
SEPARATOR = "-" * 80 + "\n"
IGNORED_DIRS: Set[str] = {"_dependencies", "_templates", ".github"}

TOFU_PATH = "tofu"

SUCCESS_LEVEL_NUM = 25
SKIPPED_LEVEL_NUM = 23

logging.addLevelName(SUCCESS_LEVEL_NUM, "SUCCESS")
logging.addLevelName(SKIPPED_LEVEL_NUM, "SKIPPED")


def success(self, message, *args, **kwargs):
    if self.isEnabledFor(SUCCESS_LEVEL_NUM):
        self._log(SUCCESS_LEVEL_NUM, message, args, **kwargs)


def skipped(self, message, *args, **kwargs):
    if self.isEnabledFor(SKIPPED_LEVEL_NUM):
        self._log(SKIPPED_LEVEL_NUM, message, args, **kwargs)


logging.Logger.success = success
logging.Logger.skipped = skipped


class EmojiFormatter(logging.Formatter):
    LEVEL_EMOJIS = {
        logging.DEBUG: f"{DEBUG_EMOJI} ",
        logging.INFO: f"{INFO_EMOJI} ",
        logging.WARNING: f"{WARN_EMOJI} ",
        logging.ERROR: f"{ERROR_EMOJI} ",
        logging.CRITICAL: f"{ERROR_EMOJI} ",
        SUCCESS_LEVEL_NUM: f"{SUCCESS_EMOJI} ",
        SKIPPED_LEVEL_NUM: f"{SKIPPED_EMOJI} ",
    }

    def format(self, record: logging.LogRecord) -> str:
        levelname = self.LEVEL_EMOJIS.get(record.levelno, record.levelname)
        record.levelname = levelname
        return super().format(record)


logging.basicConfig(
    level=logging.DEBUG, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger()
formatter = EmojiFormatter("%(asctime)s - %(levelname)s - %(message)s")
handler = logging.StreamHandler()
handler.setFormatter(formatter)
logger.handlers = [handler]


def run_opentofu_command(stack_dir: str, command: List[str]) -> Tuple[int, str]:
    """Run an OpenTofu command and handle errors.

    Args:
        stack_dir (str): The directory of the stack.
        command (List[str]): The OpenTofu command to run.

    Returns:
        Tuple[int, str]: A tuple containing the exit code and the log string.
    """
    result = subprocess.run(command, cwd=stack_dir, capture_output=True, text=True)
    return result.returncode, result.stdout + result.stderr


def opentofu_init(stack_dir: str) -> None:
    """Initialize OpenTofu in the specified directory.

    Args:
        stack_dir (str): The directory of the stack.
    """
    logger.info(f"Initializing OpenTofu in {stack_dir}...")
    run_opentofu_command(stack_dir, [TOFU_PATH, "init"])


def plan_stack(
    stack_dir: str, show_logs: bool = True, return_exit_code: bool = False
) -> Tuple[bool, str, int]:
    """Plan OpenTofu stack.

    Args:
        stack_dir (str): The directory of the stack.
        show_logs (bool): Whether to show the logs or not.
        return_exit_code (bool): Whether to return the exit code.

    Returns:
        Tuple[bool, str, int]: A tuple containing a boolean indicating success, a log string, and the exit code.
    """
    opentofu_init(stack_dir)
    logger.info(f"Planning OpenTofu in directory: {stack_dir} ...")
    exit_code, log = run_opentofu_command(
        stack_dir,
        [
            TOFU_PATH,
            "plan",
            "-detailed-exitcode",
            "-compact-warnings",
            "-out",
            "plan.out",
        ],
    )

    if exit_code == 0:
        logger.skipped(f"No changes detected for {stack_dir}.")
        return True, log if show_logs else "", exit_code
    elif exit_code == 2:
        logger.success(f"Plan successful for {stack_dir}")
        logger.info(f"Plan for {stack_dir}:\n{log}")
        return True, log if show_logs else "", exit_code
    else:
        logger.error(f"Plan failed for {stack_dir}")
        logger.error(f"Plan for {stack_dir}:\n{log}")
        return False, log, exit_code


def apply_stack(stack_dir: str) -> Tuple[bool, str, str]:
    """Apply OpenTofu stack.

    Args:
        stack_dir (str): The directory of the stack.

    Returns:
        Tuple[bool, str, str]: A tuple containing a boolean indicating success, a log string, and a status string.
    """
    success, log, plan_exit_code = plan_stack(stack_dir, return_exit_code=True)
    if plan_exit_code == 0:
        logger.skipped(f"No changes detected for {stack_dir}, skipping deployment.")
        return True, log, SKIPPED_EMOJI
    elif plan_exit_code != 2:
        logger.error(f"Plan failed for {stack_dir}, skipping deployment.")
        return False, "", ERROR_EMOJI

    logger.info(f"Deploying {stack_dir} ...")
    exit_code, log = run_opentofu_command(
        stack_dir,
        [TOFU_PATH, "apply", "-compact-warnings", "-auto-approve", "plan.out"],
    )
    if exit_code == 0:
        logger.success(f"Deployment successful for {stack_dir}")
        return True, log, SUCCESS_EMOJI
    else:
        logger.error(f"Deployment failed for {stack_dir}")
        logger.error(f"Deployment log for {stack_dir}:\n{log}")
        return False, log, ERROR_EMOJI


def detect_changed_stacks() -> Set[str]:
    """Detect changes in the root-level directories.

    Returns:
        Set[str]: A set of changed stack directories.
    """
    merge_base_result = subprocess.run(
        ["git", "merge-base", "HEAD", "origin/main"], capture_output=True, text=True
    )
    merge_base = merge_base_result.stdout.strip()

    result = subprocess.run(
        ["git", "diff", "--name-only", merge_base, "HEAD"],
        capture_output=True,
        text=True,
    )
    changed_files: List[str] = result.stdout.splitlines()

    changed_stacks: Set[str] = set()
    for file in changed_files:
        stack = file.split("/")[0]
        if stack not in IGNORED_DIRS and stack != "" and os.path.isdir(stack):
            changed_stacks.add(stack)

    if changed_stacks:
        table = PrettyTable()
        table.field_names = ["Changed Stacks"]
        for stack in changed_stacks:
            table.add_row([stack])
        logger.info("The following stacks have changed:")
        logger.info(f"\n{table}\n")

    return changed_stacks


def main():
    parser = argparse.ArgumentParser(
        description="Detect and apply or plan OpenTofu changes."
    )
    parser.add_argument(
        "--plan-only", action="store_true", help="Only plan the OpenTofu changes."
    )
    args = parser.parse_args()

    changed_stacks: Set[str] = detect_changed_stacks()

    if not changed_stacks:
        logger.info("No changes detected in root-level directories.")
    else:
        results: List[Tuple[str, str]] = []
        logs: Dict[str, str] = {}
        failure_occurred = False

        for stack in changed_stacks:
            if failure_occurred:
                results.append((stack, SKIPPED_EMOJI))
                logger.warning(f"Skipping {stack} due to previous failure.")
                continue

            if args.plan_only:
                logger.info(f"{SEPARATOR}")
                logger.info(f"Planning deployment for {stack}...\n")
                logger.info(f"{SEPARATOR}")
                success, log, exit_code = plan_stack(stack)
                logs[stack] = log
                if exit_code == 0:
                    status = SKIPPED_EMOJI
                    logger.info(f"{stack} was skipped due to no changes.")
                else:
                    status = SUCCESS_EMOJI if success else ERROR_EMOJI
            else:
                logger.info(f"{SEPARATOR}")
                logger.info(f"Deploying {stack}...\n")
                logger.info(f"{SEPARATOR}")
                success, log, status = apply_stack(stack)
                if not success:
                    failure_occurred = True
                if status == SKIPPED_EMOJI:
                    logger.info(f"{stack} was skipped due to no changes.")
            results.append((stack, status))
            if not success and not args.plan_only:
                logs[stack] = log
            print("\n", flush=True)

        table = PrettyTable()
        table.field_names = ["Stack", "Status"]
        for result in results:
            table.add_row(result)

        logger.info(f"{SEPARATOR}")
        logger.info("Deployment Summary:")
        logger.info(f"\n{table}\n")

        if logs and not args.plan_only:
            logger.error("Logs for failed deployments:")
            for stack, log in logs.items():
                if log:
                    logger.error(f"{SEPARATOR}")
                    logger.error(f"{stack}:\n{log}")


if __name__ == "__main__":
    main()
