# MacBook 初始安装脚本工作计划

## TL;DR

> **快速摘要**：为全新 Apple Silicon MacBook 设计一套“低干预、非技术用户可执行”的安装实现方案，交付一个主入口脚本 `setup-mac.sh`，自动安装并初始化 brew、uv、nvm、iTerm2、Chrome、oh-my-zsh、powerlevel10k、OpenAI Codex CLI、Claude Code。
>
> **交付物**：
> - `setup-mac.sh`：用户唯一需要执行的主入口脚本
> - `templates/p10k.zsh`：预置 Powerlevel10k 配置，避免首次向导阻塞
> - `scripts/self-check.sh`：安装后自动校验脚本
> - `scripts/test-idempotency.sh`：重复执行/幂等性验证脚本
> - `.github/workflows/verify-setup.yml`：macOS 自动验证流程
>
> **预计工作量**：中等
> **并行执行**：YES - 2 个主要波次 + 1 个整合波次
> **关键路径**：T1 → T2 → T3 → T7 → T9 → T10 → F1-F4

---

## Context

### 原始请求
用户希望为新的苹果芯片 MacBook 编写一份适合非技术背景用户使用的安装脚本，尽可能减少人工干预或确认，覆盖：brew、uv、nvm、iTerm2、Chrome、oh-my-zsh、powerlevel10k、Codex、Claude Code。

### 访谈结论
**关键决策**：
- 接受“少量最后一步手动授权”，尤其是浏览器登录授权类步骤
- 允许脚本自动修改 `~/.zshrc` 与 `~/.zprofile`
- 采用 **方案 A**：一个主入口脚本完成安装与初始化
- `codex` 按 **OpenAI Codex CLI** 理解
- 验证标准为 **高标准验证**：要求自检、重复执行验证、失败场景验证、非交互场景验证

**默认策略**：
- 默认 **不在脚本源码里存储 API Key**
- 默认 **不自动写入 OpenAI / Anthropic API Key**，而是在脚本末尾提供清晰的人工授权指引
- 默认 **不扩展安装范围**，严格限制在用户明确列出的工具清单内

### 研究结论
- Homebrew 在 Apple Silicon 上安装到 `/opt/homebrew`，可通过 `NONINTERACTIVE=1` 低交互安装，但可能触发 `sudo` 与 Xcode Command Line Tools 安装
- uv 默认可低交互安装，通常落在 `$HOME/.local/bin`
- nvm 安装后必须在当前进程中显式 `source`，再安装 LTS Node 与 npm 全局包
- iTerm2 与 Chrome 最适合通过 Homebrew Cask 安装；首次启动仍可能遇到 Gatekeeper 安全确认
- oh-my-zsh 支持 `--unattended`；powerlevel10k 需要预置 `.p10k.zsh` 并禁用首次配置向导
- Claude Code 与 OpenAI Codex CLI 的“安装”可自动化，但“登录/认证”通常需要人工浏览器授权或用户自行配置环境变量

### Metis 审查结果（已纳入）
- 在脚本起始阶段加入 **预检**：网络、管理员权限、macOS 版本、当前 shell、Xcode CLT 状态
- 所有 shell 配置修改前必须先备份 `~/.zshrc` / `~/.zprofile`
- oh-my-zsh 安装会覆盖 `~/.zshrc`，因此 **必须先安装 oh-my-zsh，再追加自定义配置**
- nvm 安装后必须在同一进程 `source` 后再执行 `nvm install --lts`
- 最终验收必须包含：shellcheck、幂等性、子 shell 中 PATH 生效、自检脚本 PASS

---

## Work Objectives

### 核心目标
产出一套可执行的实现计划，使执行代理能够创建一个主入口脚本 `setup-mac.sh`，让非技术用户在全新 Apple Silicon MacBook 上尽可能“一次运行完成大部分安装与配置”，只保留系统级密码和第三方服务授权等不可避免的人工步骤。

### 具体交付物
- `setup-mac.sh`
- `templates/p10k.zsh`
- `scripts/self-check.sh`
- `scripts/test-idempotency.sh`
- `.github/workflows/verify-setup.yml`
- `README.md`（简短使用说明，仅保留运行方式与人工步骤说明）

### 完成定义
- [ ] 用户运行 `./setup-mac.sh` 后，可完成目标工具安装与 shell 初始化
- [ ] 安装结束后，`scripts/self-check.sh` 能输出全部 PASS 或明确列出失败项
- [ ] `shellcheck` 对脚本与验证脚本无错误
- [ ] 重复执行脚本不会重复写入配置，不会因已安装状态而失败
- [ ] `zsh -i -c 'brew --version && node --version && uv --version'` 能成功执行

### 必须具备
- 中文输出与中文提示
- 失败即报错，带明确下一步建议
- 幂等设计：重复执行可安全跳过已完成步骤
- 脚本末尾明确列出人工步骤（如 Gatekeeper、Codex 登录、Claude 登录、iTerm2 字体切换）

### 必须避免（Guardrails）
- 不额外安装用户未要求的软件包（如 git、jq、pnpm、yarn、VS Code）
- 不在源码中硬编码或保存 API Key
- 不执行 `brew upgrade`
- 不调用 `chsh` 或修改 `/etc/shells`
- 不依赖“用户自己手动补 PATH”作为成功条件

---

## Verification Strategy

> **零人工验收**：实现过程中的验收必须由代理执行命令自动完成；人工仅保留服务授权/系统点击类步骤，不作为“任务完成”的验收依据。

### 测试决策
- **现有测试基础设施**：NO（仓库为空）
- **自动化测试策略**：Tests-after + 脚本自检 + 幂等性验证 + GitHub Actions macOS 校验
- **静态校验**：`shellcheck`
- **运行校验**：`scripts/self-check.sh`
- **重复执行验证**：`scripts/test-idempotency.sh`

### QA 政策
- Shell 脚本使用 Bash 执行，必要时以 `zsh -i -c` 验证新 shell 环境
- GUI 应用不要求自动化点击安装完成；以 `/Applications/*.app` 存在性验证安装成功
- 所有验证证据写入 `.sisyphus/evidence/`

### 12 项安装后验收命令清单
1. `brew --version | grep -E "^Homebrew [0-9]"`
2. `uv --version | grep -E "^uv [0-9]"`
3. `export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && node --version | grep -E "^v[0-9]"`
4. `export NVM_DIR="$HOME/.nvm" && [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && npm --version | grep -E "^[0-9]"`
5. `test -d /Applications/iTerm.app`
6. `test -d "/Applications/Google Chrome.app"`
7. `test -d "$HOME/.oh-my-zsh"`
8. `test -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"`
9. `test -f "$HOME/Library/Fonts/MesloLGS NF Regular.ttf"`
10. `codex --version`
11. `claude --version`
12. `zsh -i -c 'echo $PATH' | grep -E "/opt/homebrew/bin|$HOME/.local/bin"`

---

## Execution Strategy

### 并行执行波次

```text
Wave 1（基础设施与独立模块）
├── T1：主入口脚本骨架、日志、错误处理、重试机制
├── T2：预检、sudo keepalive、Xcode CLT 检测
├── T3：Homebrew 安装与 shellenv 生效
├── T4：GUI 应用安装（Chrome / iTerm2）
└── T5：oh-my-zsh 安装与 shell 配置备份策略

Wave 2（基于 Wave 1 的环境配置与工具安装）
├── T6：powerlevel10k、字体与 zsh 主题配置
├── T7：nvm、LTS Node、npm 全局环境初始化
├── T8：uv 安装与 PATH 收尾
├── T9：OpenAI Codex CLI、Claude Code、人工授权摘要
└── T10：自检脚本、幂等性验证脚本、GitHub Actions 校验

Wave 3（整合与交付）
├── T11：README 使用说明与最终用户中文提示整理
├── T12：主脚本串联各阶段、统一收口、确保重复执行体验
└── T13：最终本地验证与证据归档

Wave FINAL（全部完成后，4 个并行复核）
├── F1：计划符合性审计（oracle）
├── F2：脚本质量与静态检查复核
├── F3：真实执行 QA（macOS 环境）
└── F4：范围漂移检查
```

### 依赖矩阵
- **T1**：依赖无；阻塞 T12、T13
- **T2**：依赖 T1；阻塞 T3、T5、T7、T8、T9、T12
- **T3**：依赖 T1、T2；阻塞 T4、T8、T12、T13
- **T4**：依赖 T3；阻塞 T13
- **T5**：依赖 T1、T2；阻塞 T6、T12、T13
- **T6**：依赖 T5、T3；阻塞 T12、T13
- **T7**：依赖 T2；阻塞 T9、T12、T13
- **T8**：依赖 T2、T3；阻塞 T12、T13
- **T9**：依赖 T7；阻塞 T11、T12、T13
- **T10**：依赖 T3、T6、T7、T8、T9；阻塞 T13
- **T11**：依赖 T9；阻塞 T13
- **T12**：依赖 T1、T2、T3、T5、T6、T7、T8、T9；阻塞 T13
- **T13**：依赖 T3、T4、T5、T6、T7、T8、T9、T10、T11、T12；阻塞 F1-F4

### 代理分发摘要
- **Wave 1**：5 个任务，可并行 3-4 个；以 `quick` / `unspecified-high` 为主
- **Wave 2**：5 个任务，可并行 4 个；含 shell 与 Node 工具链任务
- **Wave 3**：3 个任务，偏整合与文档收尾
- **FINAL**：4 个复核任务，全部并行

---

## TODOs

- [x] 1. 搭建主入口脚本骨架与统一执行框架

  **What to do**:
  - 创建 `setup-mac.sh`，包含 shebang、`set -euo pipefail`、统一日志函数、错误退出函数、阶段标题输出
  - 设计统一的 `run_step` / `retry` / `command_exists` / `append_if_missing` 等基础函数
  - 支持 `--help`、`--dry-run`、`--verbose` 之类的最低必要参数

  **Must NOT do**:
  - 不直接在脚本最外层堆叠无结构命令
  - 不把所有逻辑写成单一超长函数

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 单文件骨架搭建，逻辑清晰、边界明确
  - **Skills**: `[]`
  - **Skills Evaluated but Omitted**:
    - `superpowers:test-driven-development`: 当前仓库为空，Shell 实施更适合后置验证而非先写单元测试

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1（与 T2/T3/T5 可并行）
  - **Blocks**: T12、T13
  - **Blocked By**: None

  **References**:
  - `.sisyphus/drafts/macbook-initial-setup-script.md` - 用户已确认的边界、自动化目标、授权策略
  - `.sisyphus/plans/macbook-initial-setup-script.md` - 总体顺序与后续任务依赖

  **Acceptance Criteria**:
  - [ ] `bash setup-mac.sh --help` 返回 0，并输出中文帮助
  - [ ] `bash setup-mac.sh --dry-run` 返回 0，并输出各阶段将执行的概要
  - [ ] `shellcheck setup-mac.sh` 不出现语法级错误（允许后续任务再消除全部风格问题）

  **QA Scenarios**:
  ```
  Scenario: 主脚本帮助信息可用
    Tool: Bash
    Preconditions: setup-mac.sh 已创建且可读
    Steps:
      1. 运行 `bash setup-mac.sh --help`
      2. 断言退出码为 0
      3. 断言输出包含“使用说明”或“帮助”字样
    Expected Result: 帮助信息正常输出，无报错
    Failure Indicators: 命令退出非 0；输出为空；出现 shell 语法错误
    Evidence: .sisyphus/evidence/task-1-help.txt

  Scenario: 非法参数被友好处理
    Tool: Bash
    Preconditions: setup-mac.sh 已创建
    Steps:
      1. 运行 `bash setup-mac.sh --not-a-real-flag`
      2. 断言输出包含“未知参数”或帮助提示
    Expected Result: 脚本明确提示参数错误，不进入安装流程
    Failure Indicators: 直接开始安装；无明确错误信息
    Evidence: .sisyphus/evidence/task-1-bad-arg.txt

  Scenario: dry-run 模式可稳定执行
    Tool: Bash
    Preconditions: setup-mac.sh 已创建
    Steps:
      1. 运行 `bash setup-mac.sh --dry-run`
      2. 断言退出码为 0
      3. 断言输出包含“dry-run”或“仅演练”以及阶段概要
    Expected Result: 脚本演练模式可用，且不会真正进入安装变更
    Failure Indicators: 退出非 0；直接执行真实安装；没有阶段概要
    Evidence: .sisyphus/evidence/task-1-dry-run.txt
  ```

  **Commit**: YES
  - Message: `feat(setup): 搭建主入口脚本骨架`

- [x] 2. 实现预检、管理员权限校验与 Xcode CLT 检测

  **What to do**:
  - 在 `setup-mac.sh` 中加入网络连通性检测、Apple Silicon/macOS 版本检测、当前 shell 检测
  - 加入 `sudo -v` 与 keepalive 机制，避免 CLT 长时间安装时 sudo 过期
  - 检测 Xcode Command Line Tools 是否已安装；若未安装，进入受控安装分支

  **Must NOT do**:
  - 不默认假设系统满足前提条件
  - 不把 `sudo` 检测放到脚本执行末尾

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 牵涉系统前置条件与失败路径，需更谨慎
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: T3、T5、T7、T8、T9、T12
  - **Blocked By**: T1

  **References**:
  - Metis 审查结论 - 预检必须覆盖网络、sudo、macOS 版本、当前 shell、Xcode CLT 状态
  - `/opt/homebrew` 与 Apple Silicon 前提 - 后续 Homebrew 与 PATH 依赖它

  **Acceptance Criteria**:
  - [ ] 无网络时脚本能快速失败并给出中文提示
  - [ ] 非管理员用户或 sudo 失败时脚本能快速失败并给出中文提示
  - [ ] `xcode-select -p` 已安装与未安装两条路径均有明确处理逻辑

  **QA Scenarios**:
  ```
  Scenario: 正常机器通过预检
    Tool: Bash
    Preconditions: Apple Silicon macOS，网络正常，用户可 sudo
    Steps:
      1. 运行 `bash setup-mac.sh --dry-run`
      2. 断言输出包含“预检通过”
      3. 断言未直接报错退出
    Expected Result: 预检阶段完成并进入下一阶段说明
    Failure Indicators: 在预检阶段异常退出
    Evidence: .sisyphus/evidence/task-2-preflight-pass.txt

  Scenario: 无 sudo 权限时优雅失败
    Tool: Bash
    Preconditions: 模拟 sudo 失败或在受限账户执行
    Steps:
      1. 运行 `bash setup-mac.sh --dry-run`
      2. 观察 `sudo -v` 分支
      3. 断言输出包含明确中文错误与停止提示
    Expected Result: 脚本在安装前停止，不进入后续步骤
    Evidence: .sisyphus/evidence/task-2-preflight-no-sudo.txt
  ```

  **Commit**: YES
  - Message: `feat(setup): 添加预检与 sudo keepalive`

- [x] 3. 实现 Homebrew 安装与当前进程 shellenv 生效

  **What to do**:
  - 检测 `/opt/homebrew/bin/brew` 是否已存在；不存在时用低交互方式安装 Homebrew
  - 安装后立即在当前脚本进程中执行 `eval "$([ -x /opt/homebrew/bin/brew ] && /opt/homebrew/bin/brew shellenv)"`
  - 将 Homebrew shellenv 写入 `~/.zprofile`
  - 加入安装后自检：`brew --version`、`brew doctor`（必要时以非阻塞方式记录）

  **Must NOT do**:
  - 不执行 `brew upgrade`
  - 不把 Homebrew PATH 依赖推给用户手工处理

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 这是所有后续安装的核心依赖
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: T4、T6、T8、T12、T13
  - **Blocked By**: T1、T2

  **References**:
  - Homebrew Apple Silicon 安装路径 `/opt/homebrew`
  - `.zprofile` 中 `brew shellenv` 是后续 shell 生效的关键

  **Acceptance Criteria**:
  - [ ] 安装或跳过后，当前进程可直接执行 `brew --version`
  - [ ] `~/.zprofile` 中恰好存在一段 Homebrew shellenv 初始化
  - [ ] 重复执行不会重复追加 shellenv

  **QA Scenarios**:
  ```
  Scenario: Homebrew 安装后当前会话立即可用
    Tool: Bash
    Preconditions: 机器上尚未安装 Homebrew，或在干净环境模拟
    Steps:
      1. 运行 `bash setup-mac.sh --dry-run` 或对应阶段执行
      2. 安装结束后立即运行 `brew --version`
      3. 断言输出以 `Homebrew ` 开头
    Expected Result: 无需新开终端即可调用 brew
    Failure Indicators: `command not found: brew`
    Evidence: .sisyphus/evidence/task-3-brew-current-shell.txt

  Scenario: 第二次执行不重复写入 zprofile
    Tool: Bash
    Preconditions: 已完成一次 Homebrew 配置
    Steps:
      1. 记录 `~/.zprofile` 中 shellenv 片段出现次数
      2. 再运行一次脚本
      3. 再次统计出现次数
    Expected Result: 次数保持 1，不重复追加
    Evidence: .sisyphus/evidence/task-3-brew-idempotent.txt
  ```

  **Commit**: YES
  - Message: `feat(setup): 添加 Homebrew 安装与 shellenv 配置`

- [x] 4. 安装 iTerm2 与 Chrome，并提供 Gatekeeper 说明

  **What to do**:
  - 使用 `brew install --cask iterm2 google-chrome` 安装 GUI 应用
  - 对已安装状态做显式检测，避免重复安装
  - 在脚本末尾人工步骤摘要中纳入首次启动的 Gatekeeper 提示

  **Must NOT do**:
  - 不尝试自动点击系统安全弹窗
  - 不把 GUI 安装失败静默吞掉

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 安装逻辑简单，但需要清晰的失败提示
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: T13
  - **Blocked By**: T3

  **References**:
  - `/Applications/iTerm.app`
  - `/Applications/Google Chrome.app`
  - Gatekeeper 首次打开确认属于允许的人工作业范围

  **Acceptance Criteria**:
  - [ ] `/Applications/iTerm.app` 存在
  - [ ] `/Applications/Google Chrome.app` 存在
  - [ ] 脚本输出中包含首次打开安全确认提示

  **QA Scenarios**:
  ```
  Scenario: GUI 应用安装成功
    Tool: Bash
    Preconditions: Homebrew 可用
    Steps:
      1. 执行 GUI 安装阶段
      2. 运行 `test -d /Applications/iTerm.app`
      3. 运行 `test -d "/Applications/Google Chrome.app"`
    Expected Result: 两个目录都存在
    Failure Indicators: 任一目录不存在
    Evidence: .sisyphus/evidence/task-4-gui-installed.txt

  Scenario: 首次打开提示被写入最终说明
    Tool: Bash
    Preconditions: 脚本执行完成
    Steps:
      1. 检查最终输出文本或 README
      2. 断言包含“首次打开时请点击打开”或等效中文提示
    Expected Result: 用户能看到明确的 Gatekeeper 指引
    Evidence: .sisyphus/evidence/task-4-gatekeeper-note.txt
  ```

  **Commit**: YES
  - Message: `feat(setup): 添加 iTerm2 与 Chrome 安装`

- [x] 5. 安装 oh-my-zsh 并安全处理现有 shell 配置

  **What to do**:
  - 在修改前备份 `~/.zshrc` 与 `~/.zprofile`（带时间戳）
  - 用 `--unattended` 安装 oh-my-zsh，避免交互阻塞
  - 由于 oh-my-zsh 会覆盖 `.zshrc`，确保后续自定义配置追加发生在其安装之后

  **Must NOT do**:
  - 不调用 `chsh`
  - 不假设用户没有既有配置

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 涉及用户 shell 配置文件覆盖风险
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: T6、T12、T13
  - **Blocked By**: T1、T2

  **References**:
  - Metis 审查指出 oh-my-zsh 安装会覆盖 `.zshrc`
  - 用户允许自动修改配置文件，但仍需优先保护可恢复性

  **Acceptance Criteria**:
  - [ ] 备份文件存在，例如 `~/.zshrc.backup.YYYYMMDD*`
  - [ ] `$HOME/.oh-my-zsh` 目录存在
  - [ ] 脚本未调用 `chsh`

  **QA Scenarios**:
  ```
  Scenario: oh-my-zsh 安装成功且生成备份
    Tool: Bash
    Preconditions: 用户家目录可写
    Steps:
      1. 执行 oh-my-zsh 安装阶段
      2. 运行 `test -d "$HOME/.oh-my-zsh"`
      3. 检查 `ls "$HOME"/.zshrc.backup.*` 是否至少返回 1 个文件
    Expected Result: oh-my-zsh 已安装，备份已生成
    Failure Indicators: 无备份文件；安装目录不存在
    Evidence: .sisyphus/evidence/task-5-omz-backup.txt

  Scenario: 脚本不尝试切换默认 shell
    Tool: Bash
    Preconditions: setup-mac.sh 已实现
    Steps:
      1. 搜索脚本文本中的 `chsh`
      2. 断言无匹配
    Expected Result: 不存在主动切换 shell 的实现
    Evidence: .sisyphus/evidence/task-5-no-chsh.txt
  ```

  **Commit**: YES
  - Message: `feat(shell): 添加 oh-my-zsh 无人值守安装`

- [x] 6. 配置 powerlevel10k、MesloLGS NF 字体与 zsh 主题加载

  **What to do**:
  - 安装 powerlevel10k 主题目录
  - 下载 MesloLGS NF 4 个字体文件到 `~/Library/Fonts/`
  - 创建 `templates/p10k.zsh` 或通过 heredoc 写入 `.p10k.zsh`
  - 在 `.zshrc` 中写入 `ZSH_THEME="powerlevel10k/powerlevel10k"` 与 `POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true`
  - 追加必要插件（仅限用户范围内合理最小集合，如 `git`，不要扩范围）

  **Must NOT do**:
  - 不引入额外不在范围内的美化插件集合
  - 不依赖用户首次手动运行 `p10k configure`

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 配置明确，文件边界清晰
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2
  - **Blocks**: T10、T12、T13
  - **Blocked By**: T5、T3

  **References**:
  - `~/Library/Fonts/` - 字体落点
  - `.p10k.zsh` - 防止首次向导阻塞的核心配置
  - `POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true` - 明确禁用配置向导

  **Acceptance Criteria**:
  - [ ] 4 个 MesloLGS NF 字体文件存在于 `~/Library/Fonts/`
  - [ ] `.p10k.zsh` 存在
  - [ ] `.zshrc` 中包含 theme 与 wizard disable 配置

  **QA Scenarios**:
  ```
  Scenario: 字体和主题配置写入成功
    Tool: Bash
    Preconditions: oh-my-zsh 已安装
    Steps:
      1. 执行 p10k 与字体安装阶段
      2. 检查 `~/Library/Fonts/MesloLGS NF Regular.ttf`
      3. 检查 `$HOME/.p10k.zsh`
      4. grep `.zshrc` 中的 `powerlevel10k/powerlevel10k`
    Expected Result: 字体、主题配置、p10k 配置全部就位
    Failure Indicators: 任一关键文件缺失
    Evidence: .sisyphus/evidence/task-6-p10k-fonts.txt

  Scenario: 新 zsh 会话不触发配置向导
    Tool: Bash
    Preconditions: `.zshrc` 与 `.p10k.zsh` 已写入
    Steps:
      1. 运行 `zsh -i -c 'echo READY'`
      2. 断言输出包含 `READY`
      3. 断言输出中不包含 `p10k configure` 或交互提示
    Expected Result: 新 shell 直接启动，无向导阻塞
    Evidence: .sisyphus/evidence/task-6-p10k-no-wizard.txt
  ```

  **Commit**: YES
  - Message: `feat(shell): 添加 powerlevel10k 与字体配置`

- [x] 7. 安装 nvm、LTS Node 并完成 npm 全局环境准备

  **What to do**:
  - 安装 nvm，并将其加载片段追加到 `.zshrc`
  - 在当前脚本进程中 `source "$NVM_DIR/nvm.sh"`
  - 安装 LTS Node，并设置 `nvm alias default lts/*`
  - 确保后续 `npm install -g` 在同一进程可用

  **Must NOT do**:
  - 不使用过旧或未指定策略的 Node 版本
  - 不把 `source nvm.sh` 交给用户手动执行

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: nvm 是 shell 函数，当前进程与新 shell 行为都要兼顾
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2
  - **Blocks**: T9、T10、T12、T13
  - **Blocked By**: T2

  **References**:
  - `$HOME/.nvm` - 默认安装目录
  - `command -v nvm` 需要在已 source 的 shell 中执行
  - `nvm install --lts` 与 `nvm alias default lts/*`

  **Acceptance Criteria**:
  - [ ] 当前脚本进程中可执行 `node --version` 与 `npm --version`
  - [ ] 新 shell 中 `zsh -i -c 'node --version'` 返回 0
  - [ ] `.zshrc` 中 nvm 初始化只出现一次

  **QA Scenarios**:
  ```
  Scenario: 当前进程完成 nvm 与 node 安装
    Tool: Bash
    Preconditions: nvm 安装逻辑已实现
    Steps:
      1. 执行 nvm 安装阶段
      2. 在同一进程中运行 `node --version`
      3. 在同一进程中运行 `npm --version`
    Expected Result: 两条命令都成功输出版本号
    Failure Indicators: `node: command not found` 或 `npm: command not found`
    Evidence: .sisyphus/evidence/task-7-node-current-process.txt

  Scenario: 新 zsh 会话可识别 node
    Tool: Bash
    Preconditions: `.zshrc` 已追加 nvm 初始化
    Steps:
      1. 运行 `zsh -i -c 'node --version && npm --version'`
      2. 断言退出码为 0
    Expected Result: 新 shell 正常继承 nvm 环境
    Evidence: .sisyphus/evidence/task-7-node-new-shell.txt
  ```

  **Commit**: YES
  - Message: `feat(toolchain): 添加 nvm 与 LTS Node 安装`

- [x] 8. 安装 uv 并完成 PATH 收尾

  **What to do**:
  - 安装 uv
  - 确保 `$HOME/.local/bin` 被正确写入 shell 配置
  - 验证当前 shell 与新 zsh shell 中都能使用 `uv --version`

  **Must NOT do**:
  - 不额外创建 Python 项目或虚拟环境
  - 不依赖用户手动 `export PATH=...`

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: 安装简单，关键在 PATH 收尾与幂等性
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2
  - **Blocks**: T10、T12、T13
  - **Blocked By**: T2、T3

  **References**:
  - `$HOME/.local/bin` - uv 默认安装位置
  - `.zprofile` / `.zshrc` PATH 收尾策略

  **Acceptance Criteria**:
  - [ ] 当前进程执行 `uv --version` 成功
  - [ ] `zsh -i -c 'uv --version'` 成功
  - [ ] PATH 追加无重复

  **QA Scenarios**:
  ```
  Scenario: uv 在当前会话可用
    Tool: Bash
    Preconditions: uv 安装逻辑已实现
    Steps:
      1. 执行 uv 安装阶段
      2. 运行 `uv --version`
    Expected Result: 输出 uv 版本号
    Failure Indicators: `uv: command not found`
    Evidence: .sisyphus/evidence/task-8-uv-current-process.txt

  Scenario: uv 在新 zsh 会话可用
    Tool: Bash
    Preconditions: PATH 配置已写入
    Steps:
      1. 运行 `zsh -i -c 'uv --version'`
      2. 断言退出码为 0
    Expected Result: 新 shell 中 uv 可直接使用
    Evidence: .sisyphus/evidence/task-8-uv-new-shell.txt
  ```

  **Commit**: YES
  - Message: `feat(toolchain): 添加 uv 安装与 PATH 配置`

- [x] 9. 安装 OpenAI Codex CLI、Claude Code，并整理人工授权摘要

  **What to do**:
  - 在 Node/npm 环境就绪后安装 OpenAI Codex CLI 与 Claude Code
  - 将 CLI 安装与登录分离：安装自动完成，登录仅输出清晰中文步骤
  - 为两者分别提供版本验证命令与“未登录并不算安装失败”的说明
  - 若官方安装方式发生变化，执行期先校验包名/命令名再落地

  **Must NOT do**:
  - 不把 API Key 写入源码
  - 不把登录失败视作安装失败
  - 不混淆 OpenAI Codex CLI 与 GitHub Copilot CLI

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 外部 CLI 生态变化快，且有认证边界
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2
  - **Blocks**: T10、T11、T12、T13
  - **Blocked By**: T7

  **References**:
  - Metis 结论：OpenAI Codex CLI 可通过 npm 包安装，认证通过 `OPENAI_API_KEY` 或 `codex login`
  - Metis 结论：Claude Code 安装与登录应分离，浏览器授权属于允许的人工步骤

  **Acceptance Criteria**:
  - [ ] `codex --version` 可运行（或当前官方等效版本命令）
  - [ ] `claude --version` 可运行
  - [ ] 最终摘要明确区分“已安装”和“待授权”

  **QA Scenarios**:
  ```
  Scenario: 两个 CLI 都已安装
    Tool: Bash
    Preconditions: Node/npm 已就绪
    Steps:
      1. 执行 CLI 安装阶段
      2. 运行 `codex --version`
      3. 运行 `claude --version`
    Expected Result: 两个命令都输出版本号
    Failure Indicators: 任一命令不存在或退出非 0
    Evidence: .sisyphus/evidence/task-9-cli-versions.txt

  Scenario: 未登录时仍给出正确指引
    Tool: Bash
    Preconditions: 不预先配置 OPENAI_API_KEY / ANTHROPIC_API_KEY
    Steps:
      1. 执行安装脚本到完成
      2. 检查最终中文摘要
      3. 断言包含 `codex login` / `OPENAI_API_KEY` 与 `claude auth login` 等指引
    Expected Result: 安装成功但授权待完成的状态被清晰表达
    Evidence: .sisyphus/evidence/task-9-auth-summary.txt
  ```

  **Commit**: YES
  - Message: `feat(toolchain): 添加 Codex 与 Claude Code 安装`

- [x] 10. 编写自检脚本、幂等性验证脚本与 GitHub Actions 校验流程

  **What to do**:
  - 创建 `scripts/self-check.sh`，逐项验证 brew、uv、nvm/node、GUI 应用、oh-my-zsh、p10k、字体、codex、claude、PATH
  - 创建 `scripts/test-idempotency.sh`，执行两次主脚本并验证第二次运行不重复写配置、不异常失败
  - 创建 `.github/workflows/verify-setup.yml`，在 macOS runner 上执行 shellcheck 与尽可能多的无交互校验

  **Must NOT do**:
  - 不把“人工点击登录成功”作为 CI 成功条件
  - 不让自检脚本静默吞掉失败项

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 涉及脚本质量门禁和持续验证
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2
  - **Blocks**: T13
  - **Blocked By**: T3、T6、T7、T8、T9

  **References**:
  - 本计划 `## Verification Strategy > 12 项安装后验收命令清单` - 自检脚本必须完整覆盖这 12 项命令
  - `.sisyphus/plans/macbook-initial-setup-script.md` Success Criteria 区块

  **Acceptance Criteria**:
  - [ ] `bash scripts/self-check.sh` 可输出 PASS/FAIL 明细
  - [ ] `bash scripts/test-idempotency.sh` 第二次执行退出 0
  - [ ] GitHub Actions 工作流语法正确，并覆盖 shellcheck + macOS 验证

  **QA Scenarios**:
  ```
  Scenario: 自检脚本输出完整验证结果
    Tool: Bash
    Preconditions: 所有安装阶段已完成
    Steps:
      1. 运行 `bash scripts/self-check.sh`
      2. 断言输出包含 brew、uv、node、codex、claude 等检查项
      3. 断言最终有 PASS/FAIL 汇总
    Expected Result: 自检报告完整可读
    Failure Indicators: 无汇总；缺关键检查项；异常退出
    Evidence: .sisyphus/evidence/task-10-self-check.txt

  Scenario: 幂等性脚本验证第二次执行安全
    Tool: Bash
    Preconditions: 主脚本可重复执行
    Steps:
      1. 运行 `bash scripts/test-idempotency.sh`
      2. 断言第二次运行退出码为 0
      3. 断言配置片段未重复增加
    Expected Result: 重复执行安全、结果稳定
    Evidence: .sisyphus/evidence/task-10-idempotency.txt
  ```

  **Commit**: YES
  - Message: `test(verify): 添加自检与幂等性验证`

- [x] 11. 编写 README 与最终中文用户指引

  **What to do**:
  - 在 `README.md` 中提供最短路径使用说明：下载、执行、可能看到的提示、需要人工做的最后几步
  - 将“首次打开 iTerm2/Chrome 的安全确认”“iTerm2 切换字体”“Codex/Claude 登录方式”写成非技术用户能看懂的中文步骤
  - 确保 README 不展开技术细节，不与脚本帮助文本冲突

  **Must NOT do**:
  - 不写成面向工程师的长篇手册
  - 不把非技术用户必须知道的最后一步散落在多个文件

  **Recommended Agent Profile**:
  - **Category**: `writing`
    - Reason: 以用户文案清晰度为核心
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 3
  - **Blocks**: T13
  - **Blocked By**: T9

  **References**:
  - 用户画像：非技术背景
  - 允许的人工步骤边界：密码、浏览器授权、Gatekeeper、iTerm2 字体设置

  **Acceptance Criteria**:
  - [ ] README 中能在 1 分钟内看懂如何开始执行
  - [ ] README 明确列出所有必要人工步骤
  - [ ] README 无超范围安装说明

  **QA Scenarios**:
  ```
  Scenario: README 对非技术用户足够直接
    Tool: Bash
    Preconditions: README.md 已编写
    Steps:
      1. 读取 README.md
      2. 断言前 30 行内出现“如何运行”“需要手动做什么”两类说明
    Expected Result: 用户能快速找到开始方式与人工步骤
    Evidence: .sisyphus/evidence/task-11-readme-scan.txt

  Scenario: README 不包含超范围安装内容
    Tool: Bash
    Preconditions: README.md 已编写
    Steps:
      1. 搜索 README 中的软件名
      2. 检查是否出现 VS Code、git、pnpm 等超范围条目
    Expected Result: 文档范围与计划一致
    Evidence: .sisyphus/evidence/task-11-readme-scope.txt
  ```

  **Commit**: YES
  - Message: `docs: 添加安装说明与人工步骤指引`

- [x] 12. 串联主脚本各阶段并统一收口用户体验

  **What to do**:
  - 将预检、安装、配置、自检、最终摘要整合进单一执行流
  - 确保阶段顺序正确：预检 → brew/CLT → GUI → oh-my-zsh → p10k/字体 → nvm/node → codex/claude → uv → 自检 → 人工步骤摘要
  - 统一输出风格、阶段标题、成功/跳过/失败提示，确保重复执行体验一致

  **Must NOT do**:
  - 不在不同阶段使用不一致的错误风格
  - 不改变已确认范围与顺序约束

  **Recommended Agent Profile**:
  - **Category**: `deep`
    - Reason: 这是整体整合任务，需处理阶段顺序与依赖关系
  - **Skills**: `[]`

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: T13
  - **Blocked By**: T1、T2、T3、T5、T6、T7、T8、T9

  **References**:
  - 本计划 Execution Strategy 中的关键路径
  - Metis 明确的顺序要求：先 oh-my-zsh，再写 `.zshrc` 自定义；先 source nvm，再 npm 全局安装

  **Acceptance Criteria**:
  - [ ] 从头到尾执行顺序符合计划
  - [ ] 每阶段都有清晰的中文标题与结果
  - [ ] 最终输出同时包含安装结果摘要与人工步骤摘要

  **QA Scenarios**:
  ```
  Scenario: 主脚本从头到尾完整串联
    Tool: Bash
    Preconditions: 所有阶段函数已实现
    Steps:
      1. 运行 `bash setup-mac.sh`
      2. 观察输出顺序
      3. 断言包含预检、安装、自检、人工步骤摘要四大部分
    Expected Result: 整体流程完整，输出可读
    Failure Indicators: 阶段缺失；顺序错误；最终无总结
    Evidence: .sisyphus/evidence/task-12-full-flow.txt

  Scenario: 第二次执行以跳过为主而非重复安装
    Tool: Bash
    Preconditions: 已完成一次成功执行
    Steps:
      1. 再次运行 `bash setup-mac.sh`
      2. 断言输出中多处出现“已安装，跳过”或等效提示
    Expected Result: 重复执行体验稳定，不重复破坏配置
    Evidence: .sisyphus/evidence/task-12-second-run.txt
  ```

  **Commit**: YES
  - Message: `feat(setup): 串联完整安装流程`

- [x] 13. 执行最终本地验证并归档证据

  **What to do**:
  - 在 Apple Silicon macOS 环境执行全部验证命令
  - 保存 `shellcheck` 输出、自检输出、幂等性验证输出、关键版本命令输出到 `.sisyphus/evidence/`
  - 核对成功标准与 README/脚本输出是否一致

  **Must NOT do**:
  - 不在未收集证据的情况下声称完成
  - 不用“应该可以”代替真实命令结果

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
    - Reason: 以验证和证据为核心
  - **Skills**: [`superpowers:verification-before-completion`]
    - `superpowers:verification-before-completion`: 强制在宣布完成前先拿到命令证据

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: F1-F4
  - **Blocked By**: T3、T4、T5、T6、T7、T8、T9、T10、T11、T12

  **References**:
  - `shellcheck setup-mac.sh scripts/self-check.sh scripts/test-idempotency.sh`
  - `bash scripts/self-check.sh`
  - `zsh -i -c 'brew --version && node --version && uv --version'`
  - `bash scripts/test-idempotency.sh`

  **Acceptance Criteria**:
  - [ ] 关键验证命令都已实际执行
  - [ ] `.sisyphus/evidence/` 中有对应输出文件
  - [ ] 最终结论基于证据而非推测

  **QA Scenarios**:
  ```
  Scenario: 全量验证命令真实执行
    Tool: Bash
    Preconditions: 实现工作全部完成
    Steps:
      1. 运行 shellcheck 命令
      2. 运行自检脚本
      3. 运行新 zsh 环境版本验证
      4. 运行幂等性验证
    Expected Result: 关键命令全部返回成功并保存输出
    Failure Indicators: 任一命令失败；未保存证据
    Evidence: .sisyphus/evidence/task-13-final-verification.txt

  Scenario: 证据文件齐全
    Tool: Bash
    Preconditions: 所有验证已执行
    Steps:
      1. 列出 `.sisyphus/evidence/`
      2. 核对 task-1 至 task-13 关键证据文件是否存在
    Expected Result: 证据文件完整，可供复核
    Evidence: .sisyphus/evidence/task-13-evidence-index.txt
  ```

  **Commit**: NO


---

## Final Verification Wave

- [x] F1. **计划符合性审计** — `oracle`
  对照本计划逐项核对：目标工具是否全部覆盖、禁止项是否未出现、人工步骤是否仅限允许范围、证据文件是否齐全。

  **QA Scenarios**:
  ```
  Scenario: 对照计划完成符合性审计
    Tool: Bash
    Preconditions: 所有实现任务已完成，计划文件与证据目录可读
    Steps:
      1. 读取 `.sisyphus/plans/macbook-initial-setup-script.md`
      2. 列出 `.sisyphus/evidence/`
      3. 逐项核对 T1-T13 的关键证据文件是否存在
      4. 检查最终实现未超出目标工具清单
    Expected Result: 输出 Must Have / Must NOT Have / Evidence 三部分审计结论
    Failure Indicators: 缺证据文件；出现超范围内容；关键交付物缺失
    Evidence: .sisyphus/evidence/final-f1-plan-compliance.txt
  ```

- [x] F2. **脚本质量复核** — `unspecified-high`
  运行 `shellcheck`、检查重复写入风险、检查未处理的 `set -e` 逃逸点、检查中文提示是否清晰。

  **QA Scenarios**:
  ```
  Scenario: 静态检查与脚本质量复核
    Tool: Bash
    Preconditions: `setup-mac.sh`、`scripts/self-check.sh`、`scripts/test-idempotency.sh` 已存在
    Steps:
      1. 运行 `shellcheck setup-mac.sh scripts/self-check.sh scripts/test-idempotency.sh`
      2. 搜索脚本中的重复追加风险点和未处理错误分支
      3. 检查中文提示文本是否存在于帮助、失败、人工步骤摘要中
    Expected Result: shellcheck 通过，且无明显质量红旗
    Failure Indicators: shellcheck 报错；发现重复写入漏洞；中文提示缺失
    Evidence: .sisyphus/evidence/final-f2-script-quality.txt
  ```

- [x] F3. **真实执行 QA** — `unspecified-high`
  在 Apple Silicon macOS 环境从干净状态运行脚本，验证安装、PATH、生效、重复执行、自检结果。

  **QA Scenarios**:
  ```
  Scenario: 在真实环境完成安装与重复执行验证
    Tool: Bash
    Preconditions: Apple Silicon macOS 环境，网络正常，用户具备 sudo 权限
    Steps:
      1. 运行 `bash setup-mac.sh`
      2. 运行 `bash scripts/self-check.sh`
      3. 运行 `zsh -i -c 'brew --version && node --version && uv --version'`
      4. 再运行一次 `bash setup-mac.sh`
      5. 断言第二次执行以“已安装，跳过”为主且退出码为 0
    Expected Result: 首次安装成功，自检通过，第二次执行幂等
    Failure Indicators: 首次执行失败；PATH 未生效；第二次执行报错；自检失败
    Evidence: .sisyphus/evidence/final-f3-real-qa.txt
  ```

- [x] F4. **范围漂移检查** — `deep`
  比对最终变更，确认没有超出：brew、uv、nvm、iTerm2、Chrome、oh-my-zsh、powerlevel10k、Codex、Claude Code 之外的额外安装或配置。

  **QA Scenarios**:
  ```
  Scenario: 检查范围是否漂移
    Tool: Bash
    Preconditions: 所有实现任务已完成
    Steps:
      1. 读取 `setup-mac.sh`、`README.md`、`scripts/self-check.sh`、`.github/workflows/verify-setup.yml`
      2. 搜索是否出现 VS Code、pnpm、yarn、git config、ssh key 等超范围内容
      3. 核对最终输出与计划中的 IN / OUT 范围
    Expected Result: 无额外安装项、无超范围配置、无未说明的副作用
    Failure Indicators: 出现额外软件安装；写入了 API Key；调用了 `brew upgrade` 或 `chsh`
    Evidence: .sisyphus/evidence/final-f4-scope-fidelity.txt
  ```

---

## Commit Strategy

- `feat(setup): 搭建主入口脚本与预检框架`
- `feat(shell): 添加 oh-my-zsh 与 powerlevel10k 自动配置`
- `feat(toolchain): 添加 nvm node uv codex claude 安装`
- `test(verify): 添加自检 幂等性 与 macOS 验证工作流`

---

## Success Criteria

### 验证命令
```bash
bash setup-mac.sh --help
shellcheck setup-mac.sh scripts/self-check.sh scripts/test-idempotency.sh
bash scripts/self-check.sh
zsh -i -c 'brew --version && node --version && uv --version'
bash scripts/test-idempotency.sh
```

### 最终检查清单
- [ ] 所有目标工具都被脚本覆盖
- [ ] 所有 shell 配置修改前都有备份
- [ ] 自检脚本与幂等性验证脚本存在且可运行
- [ ] 仅保留必要人工授权步骤
- [ ] 无超范围安装内容
