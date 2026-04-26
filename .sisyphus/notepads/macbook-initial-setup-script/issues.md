# Issues - macbook-initial-setup-script

## 已知陷阱

### nvm source 陷阱
nvm 是 shell 函数而非可执行文件，安装后必须在当前 Bash 进程 `source "$NVM_DIR/nvm.sh"` 才能用。
不能依赖新开子进程来获得 nvm 命令。

### oh-my-zsh 覆盖 .zshrc
oh-my-zsh 安装脚本会覆盖 `~/.zshrc`，因此安装 omz 之前写入的自定义配置会丢失。
**解决方案**：先安装 omz，再追加自定义配置；安装前先备份。

### Gatekeeper 首次启动
GUI 应用（iTerm2、Chrome）首次启动时 macOS 会弹出安全确认，无法通过脚本绕过。
**策略**：在脚本最终摘要中明确写出操作说明，不算作脚本失败。

### powerlevel10k 首次配置向导
新 zsh 会话如果没有 `.p10k.zsh` 且 `POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD` 未设置，会阻塞在交互向导。
**解决方案**：预置 `~/.p10k.zsh` + 在 `.zshrc` 中 export DISABLE 变量。

### CLI 认证与安装分离
codex 和 claude 的"安装"可以自动化，但"登录"需要浏览器授权或 API Key。
`codex --version` 和 `claude --version` 不需要登录即可成功。

### shellcheck 未安装
在开发环境中 shellcheck 未安装，导致无法进行静态代码检查。
**影响**：无法验证脚本符合 shellcheck 规则。
**解决方案**：记录此问题，待后续安装 shellcheck 后手动检查。

## 2026-04-26 F2 脚本质量复核
- 未发现阻断发布的问题。
- 代码搜索未发现 TODO/FIXME、硬编码真实 API Key、`brew upgrade` 或实际 `chsh` 调用；`chsh` 仅出现在注释和对 oh-my-zsh 安装脚本的检测逻辑中。
