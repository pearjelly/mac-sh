#!/usr/bin/env bash
set -euo pipefail

# 安装后自检脚本：验证所有工具是否正常安装
# 用法：bash scripts/self-check.sh [--ci]
# --ci 模式：跳过需要网络或实际安装的检查（适合 CI 环境）

CI_MODE=false
[[ "${1:-}" == "--ci" ]] && CI_MODE=true

PASS=0
FAIL=0
SKIP=0

check() {
  local name="$1"
  local cmd="$2"
  local skip_in_ci="${3:-false}"

  if [[ "$CI_MODE" == true && "$skip_in_ci" == true ]]; then
    echo "[SKIP] ${name} (CI skip)"
    ((SKIP++)) || true
    return
  fi

  if eval "$cmd" &>/dev/null; then
    echo "[PASS] ${name}"
    ((PASS++)) || true
  else
    echo "[FAIL] ${name}"
    echo "       cmd: ${cmd}"
    ((FAIL++)) || true
  fi
}

echo "========================================"
echo "  MacBook 安装自检报告"
echo "========================================"
echo ""

check "Homebrew 版本" 'brew --version | grep -E "^Homebrew [0-9]"' true
check "uv 版本" 'uv --version | grep -E "^uv [0-9]"'
check "nvm 存在" 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ]'
check "Node.js 版本" 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && node --version | grep -E "^v[0-9]"'
check "npm 版本" 'export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && npm --version | grep -E "^[0-9]"'
check "iTerm2 已安装" 'test -d /Applications/iTerm.app' true
check "Google Chrome 已安装" 'test -d "/Applications/Google Chrome.app"' true
check "oh-my-zsh 已安装" 'test -d "$HOME/.oh-my-zsh"'
check "powerlevel10k 主题已安装" 'test -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"'
check "MesloLGS NF 字体已安装" 'test -f "$HOME/Library/Fonts/MesloLGS NF Regular.ttf"'
check "Codex CLI 可用" 'command -v codex' true
check "Claude Code 可用" 'command -v claude' true

echo ""
echo "========================================"
echo "  结果：${PASS} PASS / ${FAIL} FAIL / ${SKIP} SKIP"
echo "========================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo "❌ 自检未通过，请检查上方 [FAIL] 项"
  exit 1
else
  echo "✅ 自检通过"
  exit 0
fi
