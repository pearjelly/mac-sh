# MacBook 开发环境自动安装脚本

> 适用于全新 Apple Silicon MacBook（M1/M2/M3/M4）

一条命令，自动安装常用开发工具：

```bash
bash setup-mac.sh
```

---

## 安装内容

| 工具 | 说明 |
|---|---|
| Homebrew | macOS 包管理工具 |
| iTerm2 | 增强终端 |
| Google Chrome | 浏览器 |
| oh-my-zsh | Zsh 配置框架 |
| Powerlevel10k | 美观的终端主题 |
| MesloLGS NF | Powerlevel10k 推荐字体 |
| nvm + Node.js LTS | Node.js 版本管理 |
| uv | Python 包管理工具 |
| OpenAI Codex CLI | AI 编程助手（命令行） |
| Claude Code | AI 编程助手（命令行） |

---

## 快速开始

### 第一步：下载脚本

```bash
git clone https://github.com/your-username/mac-sh.git
cd mac-sh
```

> 或直接下载 ZIP，解压后进入目录。

### 第二步：赋予执行权限并运行

```bash
chmod +x setup-mac.sh
bash setup-mac.sh
```

脚本运行期间会提示输入 Mac 密码（安装 Homebrew 需要）。全程约 10–30 分钟，请保持网络畅通。

---

## 安装后必须手动完成的步骤

脚本完成后，以下步骤需要**手动操作**：

### 1. iTerm2 字体设置
1. 打开 iTerm2
2. 前往 **Preferences → Profiles → Text**
3. 将字体改为 **MesloLGS NF**

### 2. 配置 Codex CLI
```bash
export OPENAI_API_KEY="你的 OpenAI API Key"
codex
```

### 3. 配置 Claude Code
```bash
claude  # 首次运行，按提示在浏览器完成 OAuth 授权
```

---

## 演练模式（不实际安装）

```bash
bash setup-mac.sh --dry-run
```

---

## 安装后自检

```bash
bash scripts/self-check.sh
```

所有项目 PASS 表示安装成功。

---

## 常见问题

**Q：脚本运行时弹出"无法打开，因为无法验证开发者"怎么办？**  
A：前往「系统偏好设置 → 隐私与安全」，找到对应应用，点击「仍然打开」。

**Q：脚本运行失败了怎么办？**  
A：脚本支持重复执行，修复网络或权限问题后直接重新运行即可，已完成的步骤会自动跳过。

**Q：Powerlevel10k 没有显示图标？**  
A：请确认 iTerm2 字体已改为 MesloLGS NF（见上方"安装后步骤"）。
