#!/bin/sh
set -eoux pipefail

# variables
TOFU_INSTALL_PATH=/root
TOFU_SHARED_PATH=${NOMAD_ALLOC_DIR}/data
TOFU_BINARY="${TOFU_SHARED_PATH}/tofu"

# main
apk add curl cosign gnupg
curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh
chmod +x install-opentofu.sh
./install-opentofu.sh --install-method standalone \
  --opentofu-version ${TOFU_VERSION} \
  --install-path ${TOFU_INSTALL_PATH} \
  --symlink-path "-"

mv ${TOFU_INSTALL_PATH}/tofu ${TOFU_BINARY}
${TOFU_BINARY} --version