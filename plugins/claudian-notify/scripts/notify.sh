#!/bin/bash
# claudian-notify：Obsidian 里的 Claude（Claudian 插件）回复完、或等你输入时，发一条 macOS 通知
#
# 用法（由插件的钩子调用，stdin 是 Claude Code 给钩子的 JSON）：
#   notify.sh stop          回复完（Stop 钩子）
#   notify.sh notification  等你批准或回答（Notification 钩子）
#   notify.sh test          立刻发一条测试通知，第一次用时顺便申请通知权限
#   CLAUDIAN_NOTIFY_FORCE=1 跳过「是否 Obsidian 会话、Obsidian 是否在前台」的检查（调试用）
#
# 规则：
# - 只管从 Obsidian 启动的会话（环境变量 __CFBundleIdentifier=md.obsidian），终端里的 Claude Code 不发
# - Obsidian 在最前面时不发：你正看着，不用提醒
# - 标题是 Claudian 里这段对话的标题（只读 <vault>/.claudian/sessions），正文是最后一条回复的开头
# - 点通知回到 Obsidian
#
# 通知由 terminal-notifier 发。第一次运行时在 ~/Applications 下做一个带 Obsidian 图标的副本
# 「Claudian Notify.app」，这样通知左边显示的是 Obsidian 的图标；做不成就用原版 terminal-notifier，
# 再不行退回 osascript。

set -u
event="${1:-stop}"
input=""
[ -t 0 ] || input=$(cat)

APP_NAME="Claudian Notify"
APP="$HOME/Applications/$APP_NAME.app"
BUNDLE_ID="dev.ameng.claudian-notify"
MAX_CHARS=90

JQ=$(command -v jq || echo /usr/bin/jq)

# ---------- 要不要发 ----------
if [ "$event" != "test" ] && [ "${CLAUDIAN_NOTIFY_FORCE:-}" != "1" ]; then
  [ "${__CFBundleIdentifier:-}" = "md.obsidian" ] || exit 0
  front=$(lsappinfo info -only name "$(lsappinfo front)" 2>/dev/null)
  case "$front" in *Obsidian*) exit 0 ;; esac
fi

get() { [ -n "$input" ] && printf '%s' "$input" | "$JQ" -r "$1 // empty" 2>/dev/null; }
sid=$(get '.session_id')
transcript=$(get '.transcript_path')
vault="${CLAUDE_PROJECT_DIR:-$(get '.cwd')}"
vault="${vault:-$PWD}"

# ---------- 标题 ----------
# Claudian 里的对话标题 → Claude 自动起的标题 → 「Claudian · 文件夹名」
title=""
if [ -n "$sid" ] && [ -d "$vault/.claudian/sessions" ]; then
  meta=$(grep -rl --include='*.meta.json' "\"sessionId\": *\"$sid\"" "$vault/.claudian/sessions" 2>/dev/null | head -1)
  [ -n "$meta" ] && title=$("$JQ" -r '.title // empty' "$meta" 2>/dev/null)
fi
if [ -z "$title" ] && [ -n "$transcript" ] && [ -f "$transcript" ]; then
  title=$(grep '"type":"ai-title"' "$transcript" | tail -1 | "$JQ" -r '.aiTitle // empty' 2>/dev/null)
fi
[ -n "$title" ] || title="Claudian · $(basename "$vault")"

# ---------- 正文 ----------
case "$event" in
  test)
    title="Claudian Notify"
    msg="通知已就绪：Claude 回复完时会在这里提醒你" ;;
  stop)
    msg=$(get '.last_assistant_message')
    if [ -z "$msg" ] && [ -n "$transcript" ] && [ -f "$transcript" ]; then
      msg=$(grep '"type":"assistant"' "$transcript" | tail -40 |
        "$JQ" -r '[.message.content[]? | select(.type=="text") | .text] | join(" ") | gsub("\n"; " ")' 2>/dev/null |
        grep -v '^ *$' | tail -1)
    fi
    [ -n "$msg" ] || msg="Claude 回复完了" ;;
  *)
    msg=$(get '.message')
    [ -n "$msg" ] || msg="Claude 在等你回复" ;;
esac
# 去掉 Markdown 符号、并成一行、截断（按字符，不按字节）
msg=$(printf '%s' "$msg" | "$JQ" -Rrs --argjson n "$MAX_CHARS" '
  gsub("\\[\\[(?:[^\\]|]*\\|)?(?<t>[^\\]]*)\\]\\]"; "\(.t)")
  | gsub("[#*`>|]+"; "") | gsub("\\s+"; " ") | ltrimstr(" ")
  | if length > $n then .[0:$n] + "…" else . end')

# ---------- 发通知的程序 ----------
find_terminal_notifier_app() {
  local bin real app
  bin=$(command -v terminal-notifier || true)
  [ -n "$bin" ] || { [ -x /opt/homebrew/bin/terminal-notifier ] && bin=/opt/homebrew/bin/terminal-notifier; }
  [ -n "$bin" ] || { [ -x /usr/local/bin/terminal-notifier ] && bin=/usr/local/bin/terminal-notifier; }
  [ -n "$bin" ] || return 1
  real=$(readlink -f "$bin" 2>/dev/null || echo "$bin")
  app="$(dirname "$real")/../terminal-notifier.app"
  [ -d "$app" ] && { (cd "$app" && pwd); return 0; }
  return 1
}

find_obsidian_icon() {
  local o
  o=$(mdfind "kMDItemCFBundleIdentifier == 'md.obsidian'" 2>/dev/null | head -1)
  [ -n "$o" ] || o=/Applications/Obsidian.app
  [ -f "$o/Contents/Resources/icon.icns" ] && echo "$o/Contents/Resources/icon.icns"
}

# 做一个带 Obsidian 图标的 terminal-notifier 副本。macOS 只认发送程序自己的图标，所以只能这样换
build_app() {
  local src icon plist
  src=$(find_terminal_notifier_app) || return 1
  icon=$(find_obsidian_icon) || return 1
  [ -n "$icon" ] || return 1
  mkdir -p "$HOME/Applications"
  rm -rf "$APP"
  cp -R "$src" "$APP" || return 1
  rm -f "$APP"/Contents/Resources/*.icns
  cp "$icon" "$APP/Contents/Resources/Obsidian.icns"
  plist="$APP/Contents/Info.plist"
  plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$plist"
  plutil -replace CFBundleName -string "Claudian" "$plist"
  plutil -replace CFBundleDisplayName -string "Claudian" "$plist" 2>/dev/null ||
    plutil -insert CFBundleDisplayName -string "Claudian" "$plist"
  plutil -replace CFBundleIconFile -string "Obsidian" "$plist"
  codesign --force --deep -s - "$APP" >/dev/null 2>&1 || return 1
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null
  return 0
}

[ -x "$APP/Contents/MacOS/terminal-notifier" ] || build_app

group="claudian-${sid:-$(basename "$vault")}"
send_with() {
  "$1" -title "$title" -message "$msg" -sound default -activate md.obsidian -group "$group" >/dev/null 2>&1
}

if [ -x "$APP/Contents/MacOS/terminal-notifier" ] && send_with "$APP/Contents/MacOS/terminal-notifier"; then
  exit 0
fi
# 副本还没被允许发通知：第一次测试时打开它，让系统弹出授权请求
if [ "$event" = "test" ] && [ -d "$APP" ]; then
  open "$APP" --args -title "$title" -message "$msg" 2>/dev/null
fi
tn=$(command -v terminal-notifier || true)
if [ -n "$tn" ] && send_with "$tn"; then
  exit 0
fi
# 最后的退路：系统自带的 osascript（有些系统上会被静默拦掉）
osascript -e "display notification \"$(printf '%s' "$msg" | tr -d '"\\')\" with title \"$(printf '%s' "$title" | tr -d '"\\')\" sound name \"default\"" >/dev/null 2>&1
exit 0
