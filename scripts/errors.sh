#!/usr/bin/env bash
# 构建并只打印 ArkTS 编译错误
cd "$(dirname "$0")/.."
LOG="${TMPDIR:-/tmp}/cstf-harmony-build.log"
scripts/build.sh "$@" > "$LOG" 2>&1
sed "s/\x1b\[[0-9;]*m//g" "$LOG" | grep -E "ERROR: [0-9]+|Error Message|BUILD (SUCCESSFUL|FAILED)|COMPILE RESULT" | head -120
