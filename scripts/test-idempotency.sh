#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="$SCRIPT_DIR/../setup-mac.sh"

zshrc_before=$(md5 -q "$HOME/.zshrc" 2>/dev/null || echo "notexist")
zprofile_before=$(md5 -q "$HOME/.zprofile" 2>/dev/null || echo "notexist")

echo "第一次运行（dry-run）..."
bash "$MAIN_SCRIPT" --dry-run
echo ""

echo "第二次运行（dry-run）..."
bash "$MAIN_SCRIPT" --dry-run
echo ""

zshrc_after=$(md5 -q "$HOME/.zshrc" 2>/dev/null || echo "notexist")
zprofile_after=$(md5 -q "$HOME/.zprofile" 2>/dev/null || echo "notexist")

if [[ "$zshrc_before" == "$zshrc_after" && "$zprofile_before" == "$zprofile_after" ]]; then
  echo "✅ dry-run 未修改 ~/.zshrc 或 ~/.zprofile"
else
  echo "❌ dry-run 修改了配置文件！幂等性验证失败"
  echo "   ~/.zshrc  : before=$zshrc_before  after=$zshrc_after"
  echo "   ~/.zprofile: before=$zprofile_before  after=$zprofile_after"
  exit 1
fi

echo "✅ 幂等性验证完成：连续两次 dry-run 均无报错且未修改配置文件"
