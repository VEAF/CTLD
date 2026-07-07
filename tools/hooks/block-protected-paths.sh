#!/usr/bin/env sh
# PreToolUse hook (Edit/Write/MultiEdit): block edits to protected paths.
#   - migration/source/**  : the immutable legacy parity reference
#   - CTLD_Next.lua         : the generated deliverable (edit src/ and rebuild)
# Reads the tool-call JSON on stdin, extracts file_path, exits 2 to block.

input=$(cat)
path=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)

# Normalize backslashes so Windows paths match the same patterns.
norm=$(printf '%s' "$path" | tr '\\' '/')

case "$norm" in
    */migration/source/*|migration/source/*)
        echo "Blocked: '$path' is under migration/source/ (immutable legacy parity reference). See dev/adr/0004." >&2
        exit 2
        ;;
    */CTLD_Next.lua|CTLD_Next.lua)
        echo "Blocked: 'CTLD_Next.lua' is a generated artifact. Edit files under src/ and rebuild with tools/build/merge_CTLD.ps1 (see dev/adr/0001)." >&2
        exit 2
        ;;
esac

exit 0
