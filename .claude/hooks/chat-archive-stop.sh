#!/usr/bin/env bash
# Claude Code Stop 훅 — 응답이 끝날 때마다 세션 대화를
# keun4jang/claude-chat-archive 로 내보내고 커밋·푸시한다.
# 절대 turn을 막지 않는다 — 무슨 일이 있어도 항상 exit 0.
# 아카이브 저장소가 없는 환경에서는 조용히 건너뛴다.

set -uo pipefail

ARCHIVE_DIR="${CHAT_ARCHIVE_DIR:-/home/user/claude-chat-archive}"
PROJECT="quple-episode-0"
LOG_FILE="/tmp/chat-archive-export-${PROJECT}.log"

command -v node >/dev/null 2>&1 || exit 0
[ -d "$ARCHIVE_DIR/.git" ] || exit 0

INPUT="$(cat)"

FIELDS="$(node -e '
  try {
    const d = JSON.parse(require("fs").readFileSync(0, "utf8"));
    process.stdout.write([
      d.stop_hook_active ? "1" : "0",
      d.transcript_path || "",
      d.session_id || "",
      d.cwd || "",
    ].join("\n"));
  } catch {
    process.stdout.write("0\n\n\n");
  }
' <<< "$INPUT" 2>/dev/null)" || exit 0

STOP_HOOK_ACTIVE="$(sed -n '1p' <<< "$FIELDS")"
TRANSCRIPT_PATH="$(sed -n '2p' <<< "$FIELDS")"
SESSION_ID="$(sed -n '3p' <<< "$FIELDS")"
PROJECT_CWD="$(sed -n '4p' <<< "$FIELDS")"

[ "$STOP_HOOK_ACTIVE" = "1" ] && exit 0
[ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ] || exit 0
[ -n "$SESSION_ID" ] || exit 0

SOURCE_BRANCH="unknown"
if [ -n "$PROJECT_CWD" ] && [ -d "$PROJECT_CWD" ]; then
  SOURCE_BRANCH="$(git -C "$PROJECT_CWD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
fi

if ! node "$ARCHIVE_DIR/tools/export.mjs" \
  --transcript "$TRANSCRIPT_PATH" \
  --project "$PROJECT" \
  --session-id "$SESSION_ID" \
  --archive-dir "$ARCHIVE_DIR" \
  --source-repo "keun4jang/$PROJECT" \
  --source-branch "$SOURCE_BRANCH" \
  >"$LOG_FILE" 2>&1; then
  exit 0
fi

if [ -z "$(git -C "$ARCHIVE_DIR" config user.email 2>/dev/null)" ]; then
  git -C "$ARCHIVE_DIR" config user.email "claude-chat-archive@localhost" >/dev/null 2>&1
fi
if [ -z "$(git -C "$ARCHIVE_DIR" config user.name 2>/dev/null)" ]; then
  git -C "$ARCHIVE_DIR" config user.name "Claude Chat Archive Bot" >/dev/null 2>&1
fi

git -C "$ARCHIVE_DIR" add -A sessions/ >/dev/null 2>&1 || exit 0
git -C "$ARCHIVE_DIR" diff --cached --quiet && exit 0
git -C "$ARCHIVE_DIR" commit -q -m "auto: ${PROJECT} 세션 저장 (${SESSION_ID})" >/dev/null 2>&1 || exit 0
git -C "$ARCHIVE_DIR" push -q origin HEAD >/dev/null 2>&1 || exit 0

exit 0
