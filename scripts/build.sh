#!/usr/bin/env bash
# 命令行构建 HAP（需本机安装 DevEco Studio）。用法：scripts/build.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."
DEVECO="${DEVECO_HOME:-/c/Program Files/Huawei/DevEco Studio}"
export DEVECO_SDK_HOME="${DEVECO_SDK_HOME:-$DEVECO/sdk}"
export PATH="$DEVECO/tools/node:$DEVECO/tools/ohpm/bin:$DEVECO/jbr/bin:$PATH"
node "$DEVECO/tools/hvigor/bin/hvigorw.js" assembleHap --mode module -p product=default -p buildMode="${1:-debug}" --no-daemon
