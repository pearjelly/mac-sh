
## Task 2: precheck_phase() 实现

### 关键模式
- dry-run 下无 TTY 时 `sudo true` 会报错（no terminal）；用 `-t 0` 检测 TTY，dry-run 时跳过交互式 sudo
- `sudo -n true` 需要已缓存凭证；keepalive loop `while true; do sudo -n true; sleep 50; done &` 保持缓存有效
- `trap "kill $PID 2>/dev/null" EXIT INT TERM` 中双引号使 `$PID` 在注册时展开（需 shellcheck disable=SC2064）
- `xcode-select --install` 触发 GUI 弹窗，必须 `read -r -p` 等待用户确认
- 收集证据用 `2>&1 | tee`，但这会使 stdin 失去 TTY 属性
