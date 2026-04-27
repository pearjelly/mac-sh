# SCRIPTS - 验证工具

## OVERVIEW
安装后验收工具，独立于主安装脚本运行。两个脚本，均为 pure bash，无需依赖。

## WHERE TO LOOK
| 任务 | 文件 | 说明 |
|------|------|------|
| 新增验收项目 | `self-check.sh` | 追加到 checks 数组，格式统一 |
| 调整 CI skip 列表 | `self-check.sh` → `--ci` 分支 | 当前跳过 6 项：brew/iTerm2/Chrome/Codex/Claude/zsh-PATH |
| 修改幂等性逻辑 | `test-idempotency.sh` | dry-run × 2 后 md5 比对 |

## CONVENTIONS
- `self-check.sh` 输出：`[PASS]` / `[FAIL]` / `[SKIP]`，末尾汇总 `NP/NF/NS`
- `test-idempotency.sh` 哈希命令：`md5 -q <file>`（macOS 专用，非 `md5sum`）
- 两脚本均以非零退出码表示失败，供 CI 捕获

## ANTI-PATTERNS
- **禁止** 在 self-check.sh 中安装或修改任何文件（只读验证）
- **禁止** 将 `md5sum` 替换 `md5 -q`（Linux 命令，macOS 无效）
- **禁止** self-check.sh --ci 模式下对网络或 GUI 资源做断言
