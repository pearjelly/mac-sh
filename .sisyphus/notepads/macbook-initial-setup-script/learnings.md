# Learnings - macbook-initial-setup-script

## 关键技术约定
- Homebrew Apple Silicon 安装路径：`/opt/homebrew`（非 Intel 的 `/usr/local`）
- Homebrew 低交互安装：`NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL ...)"`
- 安装后必须在当前进程 `eval "$(/opt/homebrew/bin/brew shellenv)"` 才能立即使用 brew
- oh-my-zsh 安装命令：`sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended`
- oh-my-zsh 安装会覆盖 `~/.zshrc`，因此必须先安装 omz，再追加自定义配置
- nvm 安装后必须在当前进程 `source "$NVM_DIR/nvm.sh"` 才能执行 `nvm install --lts`
- powerlevel10k 必须预置 `~/.p10k.zsh` 并设置 `POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true`
- MesloLGS NF 字体：从 `https://github.com/romkatv/powerlevel10k-media/raw/master/` 下载 4 个 ttf 文件到 `~/Library/Fonts/`
- Claude Code 登录：`claude auth login`（浏览器 OAuth）
- OpenAI Codex CLI 登录：`codex login` 或 `OPENAI_API_KEY` 环境变量
- uv 默认安装到 `$HOME/.local/bin`

## 幂等性写入函数约定
```bash
append_if_missing() {
  local file="$1" line="$2"
  grep -qF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}
```

## shell 配置文件策略
- PATH/环境变量写入 `~/.zprofile`（login shell，每次终端窗口打开时加载）
- zsh 插件/主题/工具配置写入 `~/.zshrc`（interactive shell）
- 修改前备份：`cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d%H%M%S)` (if exists)

## 2026-04-26 F2 脚本质量复核
- `setup-mac.sh` 的 `append_if_missing` 在 `DRY_RUN=true` 时会先记录日志并直接返回，未发生写入。
- 字体目录创建 `mkdir -p "$fonts_dir"` 仅在非 dry-run 分支执行。
- `nvm install --lts` 前先用 `nvm version 'lts/*'` 判断是否已安装 LTS。
- 自动化验证结果：3 个脚本 `bash -n` 通过，`self-check.sh --ci` 为 7 PASS / 0 FAIL / 6 SKIP，dry-run 完整执行通过，幂等性脚本确认两次 dry-run 后配置文件 md5 未变化。
