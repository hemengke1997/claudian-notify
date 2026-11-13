---
description: 发一条测试通知，第一次用时申请 macOS 通知权限
---

运行下面的命令，然后用一两句话告诉用户结果：

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh" test
```

告诉用户：如果没看到通知，打开「系统设置 → 通知」，找到 **Claudian**（图标是 Obsidian 的）并打开「允许通知」，再运行一次 `/claudian-notify:test`。如果列表里没有 Claudian，先确认装了 terminal-notifier（`brew install terminal-notifier`）。
