# Decisions - macbook-initial-setup-script

## 已确认决策

| 决策 | 结论 | 来源 |
|------|------|------|
| 脚本方案 | 方案 A：单一主入口脚本 | 用户确认 |
| Codex 解释 | OpenAI Codex CLI（`@openai/codex`）| 用户确认 |
| API Key 存储 | 不写入源码；安装完成后提供手动步骤指引 | 用户确认 |
| shell 配置修改 | 允许自动修改 `.zshrc` 与 `.zprofile` | 用户确认 |
| 人工步骤保留 | 允许保留：sudo 密码、Gatekeeper 点击、浏览器 OAuth | 用户确认 |
| 验证标准 | 高标准：shellcheck + 自检 + 幂等 + GitHub Actions | 用户确认 |
| `brew upgrade` | 禁止执行 | Guardrail |
| `chsh` | 禁止调用 | Guardrail |
| 安装范围 | 严格限制 8 个工具，不引入 git/jq/pnpm/yarn/vscode 等 | Guardrail |
