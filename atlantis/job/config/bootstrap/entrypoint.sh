#!/bin/sh
set -eoux pipefail

# OpenTofu
TOFU_SHARED_PATH=${NOMAD_ALLOC_DIR}/data
TOFU_BINARY="${TOFU_SHARED_PATH}/tofu"
wget https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.zip
unzip tofu_${TOFU_VERSION}_linux_amd64.zip
mv tofu ${TOFU_SHARED_PATH}
chmod 755 "${TOFU_BINARY}"
${TOFU_BINARY} -v
