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
  [[ "${DRY_RUN:-false}" == true ]] && { log_info "[演练模式] 将追加到 ${file}：${line}"; return; }
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
    trap "kill ${SUDO_KEEPALIVE_PID} 2>/dev/null" EXIT INT TERM
    log_info "sudo keepalive 已启动（PID: ${SUDO_KEEPALIVE_PID}）"
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
  phase_header "GUI 应用安装阶段（iTerm2 / Chrome）"

  # iTerm2
  if [[ -d "/Applications/iTerm.app" ]]; then
    log_info "iTerm2 已安装，跳过"
  else
    log_info "正在安装 iTerm2..."
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[演练模式] 将执行: brew install --cask iterm2"
    else
      brew install --cask iterm2
      if [[ -d "/Applications/iTerm.app" ]]; then
        log_success "iTerm2 安装完成"
      else
        log_error "iTerm2 安装后未找到 /Applications/iTerm.app，安装可能失败"
      fi
    fi
  fi

  # Google Chrome
  if [[ -d "/Applications/Google Chrome.app" ]]; then
    log_info "Google Chrome 已安装，跳过"
  else
    log_info "正在安装 Google Chrome..."
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[演练模式] 将执行: brew install --cask google-chrome"
    else
      brew install --cask google-chrome
      if [[ -d "/Applications/Google Chrome.app" ]]; then
        log_success "Google Chrome 安装完成"
      else
        log_error "Google Chrome 安装后未找到 /Applications/Google Chrome.app，安装可能失败"
      fi
    fi
  fi

  # Gatekeeper 说明
  log_info "------------------------------------------------------"
  log_info "【人工步骤提示】首次打开 iTerm2 或 Chrome 时，"
  log_info "macOS 可能弹出安全确认窗口（Gatekeeper），"
  log_info "请点击「打开」或在「系统偏好设置 → 隐私与安全」中允许。"
  log_info "------------------------------------------------------"

  if [[ "$DRY_RUN" == true ]]; then
    log_success "GUI 应用阶段演练完成"
  fi
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

  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  local p10k_dir="$zsh_custom/themes/powerlevel10k"
  local fonts_dir="$HOME/Library/Fonts"

  # 安装 powerlevel10k 主题
  if [[ -d "$p10k_dir" ]]; then
    log_info "powerlevel10k 已安装，跳过"
  else
    log_info "正在安装 powerlevel10k..."
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[演练模式] 将执行: git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $p10k_dir"
    else
      git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
      log_success "powerlevel10k 安装完成"
    fi
  fi

  # 下载 MesloLGS NF 字体
  local font_base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
  local -a fonts=(
    "MesloLGS NF Regular.ttf"
    "MesloLGS NF Bold.ttf"
    "MesloLGS NF Italic.ttf"
    "MesloLGS NF Bold Italic.ttf"
  )
  if [[ "$DRY_RUN" != true ]]; then
    mkdir -p "$fonts_dir"
  fi
  for font in "${fonts[@]}"; do
    local font_path="$fonts_dir/$font"
    if [[ -f "$font_path" ]]; then
      log_info "字体已存在，跳过：$font"
    else
      log_info "下载字体：$font"
      if [[ "$DRY_RUN" == true ]]; then
        log_info "[演练模式] 将执行: curl 下载 $font 到 $fonts_dir"
      else
        curl -fsSL "$font_base_url/${font// /%20}" -o "$font_path"
        log_success "字体下载完成：$font"
      fi
    fi
  done

  # 复制预置 p10k 配置（避免首次向导阻塞）
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local p10k_template="$script_dir/templates/p10k.zsh"
  if [[ -f "$HOME/.p10k.zsh" ]]; then
    log_info "~/.p10k.zsh 已存在，跳过复制"
  elif [[ -f "$p10k_template" ]]; then
    log_info "复制预置 p10k 配置到 ~/.p10k.zsh..."
    [[ "$DRY_RUN" != true ]] && cp "$p10k_template" "$HOME/.p10k.zsh"
  else
    log_warn "未找到预置模板 $p10k_template，跳过 p10k 配置复制"
  fi

  # 写入 .zshrc
  local zshrc="$HOME/.zshrc"

  # 设置主题为 powerlevel10k
  if grep -q 'ZSH_THEME=' "$zshrc" 2>/dev/null; then
    log_info "更新 ZSH_THEME 为 powerlevel10k/powerlevel10k..."
    [[ "$DRY_RUN" != true ]] && sed -i '' 's|ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$zshrc"
  else
    append_if_missing 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$zshrc"
  fi

  # 禁用 powerlevel10k 配置向导
  append_if_missing 'POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true' "$zshrc"

  # source p10k.zsh（如存在）
  append_if_missing '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' "$zshrc"

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[演练模式] 将更新 ~/.zshrc 中的 ZSH_THEME、禁用向导、source p10k.zsh"
    log_success "powerlevel10k 阶段演练完成"
  else
    log_info "------------------------------------------------------"
    log_info "【人工步骤提示】安装完成后请在 iTerm2 中："
    log_info "1. 前往「Preferences → Profiles → Text」"
    log_info "2. 将字体改为「MesloLGS NF」"
    log_info "如需个性化主题，运行 p10k configure"
    log_info "------------------------------------------------------"
  fi
}

nvm_node_phase() {
  phase_header "NVM 和 Node.js 安装阶段"

  local nvm_dir="${NVM_DIR:-$HOME/.nvm}"

  if [[ -s "$nvm_dir/nvm.sh" ]]; then
    log_info "nvm 已安装，跳过安装"
  else
    log_info "正在安装 nvm..."
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[演练模式] 将执行: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash"
    else
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
    fi
  fi

  # 在当前进程中 source nvm（关键：nvm 是 shell 函数，不是可执行文件）
  export NVM_DIR="$nvm_dir"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    log_info "加载 nvm 到当前进程..."
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
  elif [[ "$DRY_RUN" != true ]]; then
    log_error "nvm 安装后仍未找到 $NVM_DIR/nvm.sh，安装失败"
  fi

  if [[ "$DRY_RUN" != true ]]; then
    local lts_installed
    lts_installed=$(nvm version 'lts/*' 2>/dev/null || echo "N/A")
    if [[ "$lts_installed" == "N/A" || "$lts_installed" == "none" ]]; then
      log_info "安装 LTS Node..."
      nvm install --lts
    else
      log_info "LTS Node 已安装 ($lts_installed)，跳过"
    fi
    nvm alias default lts/* 2>/dev/null || true
    log_success "Node 安装完成：$(node --version)，npm：$(npm --version)"
  else
    log_info "[演练模式] 将执行: nvm install --lts && nvm alias default lts/*"
  fi

  local zshrc="$HOME/.zshrc"
  local nvm_init_marker="# nvm 初始化"
  local nvm_init_line1='export NVM_DIR="$HOME/.nvm"'
  local nvm_init_line2='[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
  local nvm_init_line3='[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

  if grep -qF "$nvm_init_marker" "$zshrc" 2>/dev/null; then
    log_info "nvm 初始化已存在于 ~/.zshrc，跳过"
  elif [[ "$DRY_RUN" == true ]]; then
    log_info "[演练模式] 将写入 nvm 初始化到 ~/.zshrc"
  else
    log_info "写入 nvm 初始化到 ~/.zshrc..."
    {
      echo ""
      echo "$nvm_init_marker"
      echo "$nvm_init_line1"
      echo "$nvm_init_line2"
      echo "$nvm_init_line3"
    } >> "$zshrc"
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_success "nvm 阶段演练完成"
  fi
}

codex_claude_phase() {
  phase_header "OpenAI Codex CLI 与 Claude Code 安装阶段"

  # 确保 nvm 在当前进程可用（nvm 是 shell 函数，非可执行文件）
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
  else
    log_warn "nvm 未找到，npm 全局安装可能失败"
  fi

  if command -v codex &>/dev/null; then
    log_info "Codex CLI 已安装（$(codex --version 2>/dev/null || echo '版本未知')），跳过"
  else
    log_info "正在安装 OpenAI Codex CLI（@openai/codex）..."
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[演练模式] 将执行: npm install -g @openai/codex"
    else
      npm install -g @openai/codex
      if command -v codex &>/dev/null; then
        log_success "Codex CLI 安装完成：$(codex --version)"
      else
        log_error "Codex CLI 安装后未找到 codex 命令，请检查 npm 全局 PATH"
      fi
    fi
  fi

  if command -v claude &>/dev/null; then
    log_info "Claude Code 已安装（$(claude --version 2>/dev/null || echo '版本未知')），跳过"
  else
    log_info "正在安装 Claude Code（@anthropic-ai/claude-code）..."
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[演练模式] 将执行: npm install -g @anthropic-ai/claude-code"
    else
      npm install -g @anthropic-ai/claude-code
      if command -v claude &>/dev/null; then
        log_success "Claude Code 安装完成：$(claude --version)"
      else
        log_error "Claude Code 安装后未找到 claude 命令，请检查 npm 全局 PATH"
      fi
    fi
  fi

  log_info "======================================================"
  log_info "【人工步骤摘要】以下步骤需要在脚本完成后手动完成："
  log_info ""
  log_info "1. 配置 Codex CLI："
  log_info "   export OPENAI_API_KEY=\"<your-openai-key>\""
  log_info "   codex                （启动 Codex CLI）"
  log_info ""
  log_info "2. 配置 Claude Code："
  log_info "   claude                （首次运行，按提示完成 OAuth 授权）"
  log_info "   或设置 ANTHROPIC_API_KEY："
  log_info "   export ANTHROPIC_API_KEY=\"<your-anthropic-key>\""
  log_info ""
  log_info "3. 将 API Key 持久化（可选）："
  log_info "   请参考各工具官方文档，将 API Key 写入系统环境变量"
  log_info "   建议使用系统 Keychain 或 .zshrc/.zprofile 自行管理"
  log_info "======================================================"

  if [[ "$DRY_RUN" == true ]]; then
    log_success "CLI 安装阶段演练完成"
  fi
}

uv_phase() {
  phase_header "uv Python 包管理工具安装阶段"

  local uv_bin="$HOME/.local/bin/uv"

  # 安装 uv
  if [[ -f "$uv_bin" ]]; then
    log_info "uv 已安装（${uv_bin}），跳过"
  else
    log_info "正在安装 uv..."
    if [[ "$DRY_RUN" == true ]]; then
      log_info "[演练模式] 将执行: curl -LsSf https://astral.sh/uv/install.sh | sh"
    else
      curl -LsSf https://astral.sh/uv/install.sh | sh
    fi
  fi

  # 在当前进程中使 uv 可用
  if [[ -f "$uv_bin" ]]; then
    export PATH="$HOME/.local/bin:$PATH"
    log_info "uv 已加载到当前进程 PATH"
  fi

  # 幂等写入 ~/.zprofile
  local zprofile="$HOME/.zprofile"
  append_if_missing 'export PATH="$HOME/.local/bin:$PATH"' "$zprofile"
  log_info "PATH($HOME/.local/bin) 已确保写入 ~/.zprofile"

  # 验证
  if [[ "$DRY_RUN" != true ]]; then
    if command -v uv &>/dev/null; then
      log_success "uv 安装完成：$(uv --version)"
    else
      log_error "uv 安装后仍无法找到 uv 命令，请检查 PATH 配置"
    fi
  else
    log_success "uv 阶段演练完成"
  fi
}

self_check_phase() {
  phase_header "安装自检阶段"

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local check_script="$script_dir/scripts/self-check.sh"

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[演练模式] 安装完成后运行 bash scripts/self-check.sh 进行自检"
    return
  fi

  if [[ -f "$check_script" ]]; then
    log_info "运行安装自检..."
    bash "$check_script" || log_warn "自检发现部分问题，请查看上方 [FAIL] 项"
  else
    log_warn "未找到自检脚本 $check_script，跳过自检"
  fi
}

manual_steps_phase() {
  phase_header "安装完成 — 人工步骤汇总"

  log_info "=================================================="
  log_info "🎉 自动安装阶段完成！"
  log_info ""
  log_info "以下步骤需要手动完成："
  log_info ""
  log_info "【1】打开 iTerm2，设置终端字体："
  log_info "    Preferences → Profiles → Text → 字体改为「MesloLGS NF」"
  log_info ""
  log_info "【2】配置 OpenAI Codex CLI："
  log_info "    export OPENAI_API_KEY=\"<your-key>\""
  log_info "    codex"
  log_info ""
  log_info "【3】登录 Claude Code："
  log_info "    claude   （按提示完成浏览器 OAuth 授权）"
  log_info ""
  log_info "【4】运行自检确认全部安装成功："
  log_info "    bash scripts/self-check.sh"
  log_info "=================================================="
}

# 主函数
main() {
  log_info "=================================================="
  log_info "  MacBook 开发环境自动安装脚本"
  log_info "  开始时间：$(date '+%Y-%m-%d %H:%M:%S')"
  log_info "=================================================="
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