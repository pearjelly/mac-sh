#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/../setup-mac.sh"

echo "第一次运行（dry-run）..."
bash "$MAIN_SCRIPT" --dry-run
echo ""
echo "第二次运行（dry-run）..."
bash "$MAIN_SCRIPT" --dry-run
echo ""
echo "✅ 幂等性验证完成：连续两次 dry-run 均无报错"
