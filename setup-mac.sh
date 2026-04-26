#!/usr/bin/env bash

set -euo pipefail

# 全局变量
DRY_RUN=false
VERBOSE=false

# 参数解析
while [[ $# -gt 0 ]]; do
  case $1 in
    --help)
      echo "使用说明："
      echo "  --help      显示此帮助信息"
      echo "  --dry-run   演练模式，输出阶段概要不执行"
      echo "  --verbose   详细输出"
      exit 0
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

# 日志函数
log_info() {
  echo -e "\033[34m[信息]\033[0m $1"
}

log_success() {
  echo -e "\033[32m[成功]\033[0m $1"
}

log_warn() {
  echo -e "\033[33m[警告]\033[0m $1"
}

log_error() {
  echo -e "\033[31m[错误]\033[0m $1"
  exit 1
}

# 阶段标题函数
phase_header() {
  echo "========================================"
  echo "$1"
  echo "========================================"
}

# 工具函数
command_exists() {
  command -v "$1" &>/dev/null
}

append_if_missing() {
  local line="$1"
  local file="$2"
  grep -qF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

run_step() {
  local phase="$1"
  local cmd="$2"
  if [[ "$DRY_RUN" == true ]]; then
    log_info "[$phase] 将执行: $cmd"
  else
    if [[ "$VERBOSE" == true ]]; then
      log_info "[$phase] 执行: $cmd"
    fi
    eval "$cmd"
  fi
}

retry() {
  local max_attempts="$1"
  local delay="$2"
  local cmd="$3"
  local attempt=1
  while [[ $attempt -le $max_attempts ]]; do
    if eval "$cmd"; then
      return 0
    else
      log_warn "命令失败，重试 $attempt/$max_attempts"
      sleep "$delay"
      ((attempt++))
    fi
  done
  log_error "命令失败，已重试 $max_attempts 次"
}

# 阶段函数占位
precheck_phase() {
  phase_header "预检阶段"
  # TODO: 实现预检逻辑
}

brew_phase() {
  phase_header "Homebrew 安装阶段"
  # TODO: 实现 brew 安装逻辑
}

gui_phase() {
  phase_header "GUI 应用安装阶段"
  # TODO: 实现 GUI 应用安装逻辑
}

oh_my_zsh_phase() {
  phase_header "Oh My Zsh 安装阶段"
  # TODO: 实现 oh-my-zsh 安装逻辑
}

p10k_fonts_phase() {
  phase_header "Powerlevel10k 和字体安装阶段"
  # TODO: 实现 p10k 和字体安装逻辑
}

nvm_node_phase() {
  phase_header "NVM 和 Node.js 安装阶段"
  # TODO: 实现 nvm 和 node 安装逻辑
}

codex_claude_phase() {
  phase_header "Codex 和 Claude Code 安装阶段"
  # TODO: 实现 codex 和 claude 安装逻辑
}

uv_phase() {
  phase_header "UV 安装阶段"
  # TODO: 实现 uv 安装逻辑
}

self_check_phase() {
  phase_header "自检阶段"
  # TODO: 实现自检逻辑
}

manual_steps_phase() {
  phase_header "人工步骤摘要"
  # TODO: 实现人工步骤摘要逻辑
}

# 主函数
main() {
  if [[ "$DRY_RUN" == true ]]; then
    log_info "演练模式：将输出各阶段概要，不执行实际操作"
  fi
  precheck_phase
  brew_phase
  gui_phase
  oh_my_zsh_phase
  p10k_fonts_phase
  nvm_node_phase
  codex_claude_phase
  uv_phase
  self_check_phase
  manual_steps_phase
}

main "$@"