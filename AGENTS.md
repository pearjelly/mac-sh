# PROJECT KNOWLEDGE BASE

**Generated:** 2026-04-27
**Commit:** aae63b5
**Branch:** main

## 使用中文

## OVERVIEW
Apple Silicon MacBook 一键开发环境安装脚本（pure bash，无外部依赖）。安装 brew/uv/nvm/iTerm2/Chrome/oh-my-zsh/powerlevel10k/Codex CLI/Claude Code，幂等可重复执行。

## STRUCTURE
```
mac-sh/
├── setup-mac.sh          # 主脚本，全部安装逻辑（638 行）
├── scripts/              # 独立验证工具（see scripts/AGENTS.md）
│   ├── self-check.sh     # 安装验收，13 项
│   └── test-idempotency.sh
├── templates/
│   └── p10k.zsh          # powerlevel10k 预置配置，禁用向导
└── .github/workflows/
    └── verify-setup.yml  # CI：bash-n + shellcheck + dry-run + 幂等性
```

## WHERE TO LOOK
| 任务 | 位置 | 说明 |
|------|------|------|
| 新增安装阶段 | `setup-mac.sh` → `main()` | 按固定顺序追加 phase 函数 |
| 修改 shell 配置写入 | `append_if_missing()` 调用处 | brew_phase/p10k_fonts_phase/uv_phase |
| 调整 DRY_RUN 行为 | 各 phase 函数内 `if [[ "$DRY_RUN" == true ]]` | append_if_missing 内置守卫无需改 |
| 修改 powerlevel10k 配置 | `templates/p10k.zsh` | 由 p10k_fonts_phase 复制到 ~/.p10k.zsh |
| CI 流程 | `.github/workflows/verify-setup.yml` | 5 步骤固定顺序 |
| 安装验收逻辑 | `scripts/self-check.sh` | --ci 模式跳过 6 项 |

## CODE MAP
| 函数 | 位置 | 说明 |
|------|------|------|
| `main()` | 末尾 | 阶段调用顺序 |
| `precheck_phase` | setup-mac.sh | xcode-select + sudo keepalive |
| `brew_phase` | setup-mac.sh | Homebrew 安装 + shellenv → ~/.zprofile |
| `gui_phase` | setup-mac.sh | iTerm2 + Chrome cask |
| `oh_my_zsh_phase` | setup-mac.sh | --unattended，不调用 chsh |
| `p10k_fonts_phase` | setup-mac.sh | 字体 cask + ZSH_THEME/source → ~/.zshrc |
| `nvm_node_phase` | setup-mac.sh | nvm install + LTS |
| `codex_claude_phase` | setup-mac.sh | npm i -g @openai/codex + claude |
| `uv_phase` | setup-mac.sh | uv installer + PATH → ~/.zprofile |
| `self_check_phase` | setup-mac.sh | 调用 scripts/self-check.sh |
| `manual_steps_phase` | setup-mac.sh | 打印人工步骤列表 |
| `append_if_missing` | setup-mac.sh | DRY_RUN 感知，幂等追加行到文件 |
| `run_step` | setup-mac.sh | DRY_RUN 感知的 eval 包装 |
| `retry` | setup-mac.sh | retry(max, delay, cmd) |
| `log_info/success/warn/error` | setup-mac.sh | ANSI 彩色，统一输出格式 |

## CONVENTIONS
- `set -euo pipefail` + `IFS=$'\n\t'`
- 所有 shell 配置写入必须通过 `append_if_missing(line, file)`，禁止直接 `echo >> file`
- DRY_RUN 模式：`append_if_missing` 内置；其余操作在 phase 函数内 `if [[ "$DRY_RUN" == true ]]` 分支打印跳过
- 阶段执行顺序不可打乱（nvm 依赖 brew，codex_claude 依赖 nvm）
- `# shellcheck disable=SC2064`（第 157 行）：trap 使用变量时展开时机问题，已知且合理

## ANTI-PATTERNS
- **禁止** 直接写 `echo "..." >> ~/.zshrc`（必须用 `append_if_missing`）
- **禁止** `brew upgrade`（只能 `brew install`）
- **禁止** 调用 `chsh`（oh-my-zsh 用 `--unattended`）
- **禁止** 在源码中硬编码 API Key（Codex/Claude Key 由用户手动配置）
- **禁止** 安装白名单之外的软件
- **禁止** 将 `run_step` / `retry` 以外的命令改为全局 eval

## COMMANDS
```bash
# 正式安装
bash setup-mac.sh

# 演练（不执行任何写操作）
bash setup-mac.sh --dry-run

# 安装验收
bash scripts/self-check.sh
bash scripts/self-check.sh --ci    # CI 模式，跳过需交互环境的 6 项

# 幂等性验证
bash scripts/test-idempotency.sh
```

## NOTES
- macOS 使用 `md5 -q <file>`，非 `md5sum`（test-idempotency.sh 已适配）
- xcode-select --install 是 brew 前置依赖，为授权范围内操作
- BUG-1（`sudo -n true` 非交互失败）对目标用户（交互式终端）无影响，未修复
- CI 在 `macos-latest` runner 执行，self-check --ci 结果 7P/0F/6S
