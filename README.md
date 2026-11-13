# claudian-notify

在 Obsidian 里用 [Claudian](https://github.com/YishenTu/claudian) 和 Claude 聊天时，切去做别的事，Claude 回复完了却不知道？这个 Claude Code 插件会在那一刻发一条 macOS 通知：

- **标题**是这段对话在 Claudian 里的标题，**正文**是 Claude 回复的开头
- 左边是 **Obsidian 的图标**，点一下回到 Obsidian
- Claude 等你批准操作、或问你问题时也会提醒
- Obsidian 在最前面时不打扰；终端里用 Claude Code 不受影响
- 每段对话的通知各自一组，几段对话同时跑也分得清

## 需要

- macOS，Obsidian + Claudian 插件（Claude 模式）
- [Claude Code](https://code.claude.com)（Claudian 用的就是它）
- [terminal-notifier](https://github.com/julienXX/terminal-notifier)：`brew install terminal-notifier`
- jq：macOS 15 起系统自带；更早的系统 `brew install jq`

## 安装

在终端里运行：

```bash
brew install terminal-notifier
claude plugin marketplace add hemengke1997/claudian-notify
claude plugin install claudian-notify@claudian-notify
```

然后在 Claudian 里**新开一个对话**，输入 `/claudian-notify:test`：

1. 第一次会在 `~/Applications` 下生成「Claudian Notify.app」，系统会问是否允许它发通知，点**允许**
2. 没弹出询问的话，打开「系统设置 → 通知」，找到 **Claudian**（Obsidian 图标），打开「允许通知」
3. 想让通知停在屏幕上等你点掉，把样式改成「提醒」

之后每个新对话都会自动提醒。

## 卸载

```bash
claude plugin uninstall claudian-notify@claudian-notify
claude plugin marketplace remove claudian-notify
rm -rf ~/Applications/"Claudian Notify.app"
```

## 原理

- 插件注册 Claude Code 的两个钩子：`Stop`（一轮回复结束）和 `Notification`（等你输入）。Claudian 跑的就是 Claude Code，所以钩子在 Obsidian 里同样触发
- 脚本靠环境变量 `__CFBundleIdentifier=md.obsidian` 认出从 Obsidian 启动的会话；用 `lsappinfo` 看 Obsidian 是不是在最前面
- 标题从 `<vault>/.claudian/sessions/` 里按会话 ID 查（只读）；查不到就用 Claude 自动起的标题，再不行用文件夹名
- macOS 只认发通知的程序自己带的图标，所以第一次运行时把 terminal-notifier 复制一份，换上**你电脑上** Obsidian 的图标、重新签名（ad-hoc），存为 `~/Applications/Claudian Notify.app`。插件本身不带 Obsidian 的图标文件
- 这个副本没被允许发通知时，退回原版 terminal-notifier；没装 terminal-notifier 时退回系统自带的 `osascript`（有些系统上会被静默拦掉）

## 常见问题

- **没有通知**：确认是新开的对话（钩子在对话开始时加载）；运行 `/claudian-notify:test`；检查「系统设置 → 通知 → Claudian」是否允许；勿扰模式开着时通知不会弹出
- **想换提示音**：改 `scripts/notify.sh` 里的 `-sound default`，可用 `/System/Library/Sounds/` 里的名字，比如 `Glass`、`Hero`
- **升级 terminal-notifier 后**：副本不会跟着升级，删掉 `~/Applications/Claudian Notify.app`，下次通知时会重新生成

## License

MIT
