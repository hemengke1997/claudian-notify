# claudian-notify

Claude Code 插件：Obsidian 里的 Claude（Claudian）回复完或等输入时发 macOS 通知。用法和原理见 README

- 核心只有 `plugins/claudian-notify/scripts/notify.sh`（bash 3.2 能跑，只依赖系统自带命令、jq、terminal-notifier）和 `hooks/hooks.json`
- 版本号写在两处，改版本时一起改：`.claude-plugin/marketplace.json` 和 `plugins/claudian-notify/.claude-plugin/plugin.json`
- 不往仓库里放 Obsidian 的图标文件：图标在用户电脑上从已装的 Obsidian 复制
- 改完跑 `claude plugin validate .` 和 `claude plugin validate plugins/claudian-notify`，再用 `notify.sh test` 和 `CLAUDIAN_NOTIFY_FORCE=1` 实发一条
