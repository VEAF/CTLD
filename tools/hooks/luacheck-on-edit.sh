#!/usr/bin/env sh
# PostToolUse hook (Edit/Write/MultiEdit): run luacheck on an edited src/ Lua file.
# Best-effort and non-blocking: no-op if luacheck is not installed (e.g. Windows) beyond a
# one-time notice (see below) -- CI's luacheck job (TOOLING-LUACHECK-CI-RATCHET) is the real
# backstop either way. Reports issues on stderr so they surface to the agent; always exits 0.

input=$(cat)
path=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
norm=$(printf '%s' "$path" | tr '\\' '/')

case "$norm" in
    */src/*.lua|src/*.lua)
        if command -v luacheck >/dev/null 2>&1; then
            luacheck --config "${CLAUDE_PROJECT_DIR:-.}/.luacheckrc" "$path" 1>&2 \
                || echo "luacheck flagged issues in $path (see above)." >&2
        else
            # One-time notice, not silence: a plain marker file under .git/ (never git-tracked,
            # local to this clone). No session identifier is exposed to a PostToolUse hook, so
            # this is a deliberate approximation of "once" -- it never auto-resets; delete the
            # marker by hand to see the notice again.
            marker="${CLAUDE_PROJECT_DIR:-.}/.git/ctld-luacheck-notice-shown"
            if [ ! -f "$marker" ]; then
                echo "luacheck not installed -- local check skipped for $path; CI enforces this on your PR." >&2
                : > "$marker" 2>/dev/null || true
            fi
        fi
        ;;
esac

exit 0
