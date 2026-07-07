#!/usr/bin/env sh
# PostToolUse hook (Edit/Write/MultiEdit): run luacheck on an edited src/ Lua file.
# Best-effort and non-blocking: no-op if luacheck is not installed (e.g. Windows).
# Reports issues on stderr so they surface to the agent; always exits 0.

input=$(cat)
path=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
norm=$(printf '%s' "$path" | tr '\\' '/')

case "$norm" in
    */src/*.lua|src/*.lua)
        if command -v luacheck >/dev/null 2>&1; then
            luacheck --config "${CLAUDE_PROJECT_DIR:-.}/.luacheckrc" "$path" 1>&2 \
                || echo "luacheck flagged issues in $path (see above)." >&2
        fi
        ;;
esac

exit 0
