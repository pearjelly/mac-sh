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

  log_info "检测网络连通性..."
  if ! curl -s --head --max-time 5 https://brew.sh > /dev/null 2>&1; then
    log_error "网络不可用，无法访问 https://brew.sh，请检查网络连接后重试"
  fi
  log_info "网络连通性正常"

  log_info "检测处理器架构..."
  local arch
  arch=$(uname -m)
  if [[ "$arch" != "arm64" ]]; then
    log_warn "当前处理器架构为 $arch，非 Apple Silicon（arm64），后续部分操作可能不兼容"
  else
    log_info "Apple Silicon (arm64) 检测通过"
  fi

  log_info "检测 macOS 版本..."
  local os_version
  os_version=$(sw_vers -productVersion)
  local major_version
  major_version=$(echo "$os_version" | cut -d. -f1)
  if [[ "$major_version" -lt 12 ]]; then
    log_warn "当前 macOS 版本为 $os_version，低于 12.0（Monterey），部分功能可能不可用"
  else
    log_info "macOS 版本 $os_version 检测通过"
  fi

  log_info "检测当前 Shell..."
  if [[ "$SHELL" != *"zsh"* ]]; then
    log_warn "当前 Shell 为 $SHELL，建议使用 zsh 以获得最佳体验"
  else
    log_info "Shell 检测通过：$SHELL"
  fi

  log_info "检测 sudo 权限..."
  if ! sudo -n true 2>/dev/null; then
    if [[ "$DRY_RUN" == true ]]; then
      log_warn "sudo 凭证未缓存（演练模式，跳过交互式验证）"
    elif [[ -t 0 ]]; then
      log_info "需要 sudo 权限，请输入密码："
      if ! sudo true; then
        log_error "无法获取 sudo 权限，请确保当前用户有 sudo 权限后重试"
      fi
    else
      log_error "无法获取 sudo 权限，且当前没有交互式终端。请先运行 sudo -v 缓存凭证后重试"
    fi
  fi
  log_info "sudo 权限检测通过"

  if [[ "$DRY_RUN" != true ]]; then
    log_info "启动 sudo keepalive 后台进程..."
    while true; do sudo -n true; sleep 50; done &
    SUDO_KEEPALIVE_PID=$!
    # shellcheck disable=SC2064
    trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null" EXIT INT TERM
    log_info "sudo keepalive 已启动（PID: $SUDO_KEEPALIVE_PID）"
  fi

  log_info "检测 Xcode Command Line Tools..."
  if ! xcode-select -p > /dev/null 2>&1; then
    log_warn "Xcode Command Line Tools 未安装"
    if [[ "$DRY_RUN" != true ]]; then
      log_info "正在触发 Xcode Command Line Tools 安装（将弹出 GUI 安装窗口）..."
      xcode-select --install 2>/dev/null || true
      read -r -p "请在弹出的窗口中完成 Xcode Command Line Tools 安装，完成后按 Enter 继续... "
    else
      log_info "[演练模式] 将执行: xcode-select --install"
    fi
  else
    log_info "Xcode Command Line Tools 已安装：$(xcode-select -p)"
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_success "预检通过（演练模式）"
  else
    log_success "预检通过"
  fi
}

brew_phase() {
  phase_header "Homebrew 安装阶段"

  local brew_bin="/opt/homebrew/bin/brew"

  if [[ -x "$brew_bin" ]]; then
    log_info "Homebrew 已安装，跳过安装"
  else
    log_info "正在安装 Homebrew（低交互模式）..."
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[演练模式] 将执行: NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    else
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
  fi

  if [[ -x "$brew_bin" ]]; then
    log_info "加载 Homebrew shellenv 到当前进程..."
    eval "$("$brew_bin" shellenv)"
  elif [[ "$DRY_RUN" != true ]]; then
    log_error "Homebrew 安装后仍未找到 $brew_bin，安装失败"
  fi

  local zprofile="$HOME/.zprofile"
  local shellenv_line='eval "$(/opt/homebrew/bin/brew shellenv)"'
  log_info "确保 Homebrew shellenv 写入 ~/.zprofile..."
  append_if_missing "$shellenv_line" "$zprofile"

  if [[ "$DRY_RUN" != true ]]; then
    if command_exists brew; then
      log_success "Homebrew 安装完成：$(brew --version | head -1)"
    else
      log_error "brew 命令仍不可用，请检查 /opt/homebrew/bin 是否在 PATH 中"
    fi
  else
    log_success "Homebrew 阶段演练完成"
  fi
}

gui_phase() {
  phase_header "GUI 应用安装阶段"
  # TODO: 实现 GUI 应用安装逻辑
}

oh_my_zsh_phase() {
  phase_header "Oh My Zsh 安装阶段"

  local timestamp
  timestamp=$(date +%Y%m%d%H%M%S)

  if [[ -f "$HOME/.zshrc" ]]; then
    log_info "备份 ~/.zshrc -> ~/.zshrc.backup.$timestamp"
    [[ "$DRY_RUN" != true ]] && cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$timestamp"
  fi
  if [[ -f "$HOME/.zprofile" ]]; then
    log_info "备份 ~/.zprofile -> ~/.zprofile.backup.$timestamp"
    [[ "$DRY_RUN" != true ]] && cp "$HOME/.zprofile" "$HOME/.zprofile.backup.$timestamp"
  fi

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log_info "oh-my-zsh 已安装，跳过"
  else
    log_info "正在安装 oh-my-zsh（无人值守模式）..."
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[演练模式] 将执行 oh-my-zsh --unattended 安装"
    else
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
  fi

  if [[ "$DRY_RUN" != true ]]; then
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
      log_success "oh-my-zsh 安装完成"
    else
      log_error "oh-my-zsh 安装后目录 $HOME/.oh-my-zsh 不存在，安装失败"
    fi
    # 确认脚本中未调用 chsh
    if grep -q "chsh" "$HOME/.oh-my-zsh/tools/install.sh" 2>/dev/null; then
      log_warn "注意：oh-my-zsh 安装脚本中检测到 chsh，但我们使用了 --unattended 跳过"
    fi
  else
    log_success "oh-my-zsh 阶段演练完成"
  fi
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