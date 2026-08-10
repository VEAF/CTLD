#!/usr/bin/env python3
"""translate_i18n.py — Fill empty i18n stubs via Claude.

Reads src/CTLD_i18n_*.lua, identifies stubs (empty, or value == EN value),
and fills them using claude-haiku-4-5-20251001, one batch call per language.
Writes results back in-place. Non-blocking: any error prints a WARNING and exits 0.

Two backends, tried in this order:
  1. Anthropic API, when ANTHROPIC_API_KEY is set (pip install anthropic).
  2. Claude Code CLI (`claude`), as a local fallback when no API key is set —
     authenticates via a Claude Code subscription instead of a separate API key.

Usage:        python tools/build/translate_i18n.py
"""

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from i18n_dict_utils import parse_dict, parse_keep_en

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
MODEL     = "claude-haiku-4-5-20251001"
LANG_NAMES = {"fr": "French", "es": "Spanish", "ko": "Korean"}
CLI_TIMEOUT_SECONDS = 120

# ---------------------------------------------------------------------------
# A stub is an entry not worth keeping as-is: empty (generate_i18n_dicts.ps1's
# convention for a freshly-added non-EN key), or still a verbatim copy of the
# EN text (the pre-existing convention this predicate used to check alone).
# ---------------------------------------------------------------------------
def _is_stub(lang_value: str | None, en_value: str) -> bool:
    return lang_value == en_value or lang_value == ""


def _collect_stubs(
    en_dict: dict[str, str], lang_dict: dict[str, str], keep_en: set[str]
) -> dict[str, str]:
    return {
        k: v for k, v in en_dict.items()
        if k not in keep_en and _is_stub(lang_dict.get(k), v)
    }

# ---------------------------------------------------------------------------
# Write translated values back into the Lua source file
# ---------------------------------------------------------------------------
def _apply_translations(path: Path, translations: dict[str, str], lang: str) -> int:
    text = path.read_text(encoding="utf-8")
    count = 0
    for key, new_val in translations.items():
        # Escape backslashes and double-quotes in the new value
        escaped = new_val.replace("\\", "\\\\").replace('"', '\\"')
        # Anchored to line start (MULTILINE) so a "-- STALE: " commented line - which no
        # longer starts with "ctld.i18n[...]" at column 0 - is never matched and rewritten.
        pattern = re.compile(
            r'^(ctld\.i18n\["' + re.escape(lang) + r'"\]\["' + re.escape(key) + r'"\]\s*=\s*)"(?:[^"\\]|\\.)*"',
            re.MULTILINE,
        )
        replacement = r'\g<1>"' + escaped + '"'
        new_text, n = pattern.subn(replacement, text)
        if n:
            text = new_text
            count += 1
    if count:
        path.write_text(text, encoding="utf-8")
    return count

# ---------------------------------------------------------------------------
# Which backend to attempt: the API is first-priority and unchanged whenever a
# key is available; the CLI is only ever a fallback for its absence, never for
# an API-side failure (a present-but-invalid key does not fall back to the CLI).
# ---------------------------------------------------------------------------
def _select_backend(has_api_key: bool) -> str:
    return "api" if has_api_key else "cli"


def _build_prompt(lang_name: str, stubs: dict[str, str]) -> str:
    keys_json = json.dumps(stubs, ensure_ascii=False, indent=2)
    return (
        f"You are a professional military aviation simulator (DCS World) translator.\n"
        f"Translate the following English strings to {lang_name}.\n"
        f"Context: these are UI labels and messages for a logistics/transport dispatcher mod.\n"
        f"Rules:\n"
        f"- Keep proper nouns (unit names, zone names, coalition names) untranslated.\n"
        f"- Preserve %1, %2, ... placeholders exactly as-is.\n"
        f"- Return ONLY a JSON object mapping each English key to its {lang_name} translation.\n"
        f"- No extra keys, no commentary, no markdown fences.\n\n"
        f"Input (key = English text to translate):\n{keys_json}"
    )

# ---------------------------------------------------------------------------
# Backend 1: Anthropic API (ANTHROPIC_API_KEY)
# ---------------------------------------------------------------------------
def _translate_batch_api(client, lang_name: str, stubs: dict[str, str]) -> dict[str, str]:
    message = client.messages.create(
        model=MODEL,
        max_tokens=4096,
        messages=[{"role": "user", "content": _build_prompt(lang_name, stubs)}],
    )
    raw = message.content[0].text.strip()
    return json.loads(raw)

# ---------------------------------------------------------------------------
# Backend 2: Claude Code CLI, local fallback when no API key is set. No
# pre-flight availability check — any failure (binary not found, session not
# authenticated, non-zero exit, malformed JSON) is left to the caller's
# generic exception handling, same as an API-side failure.
# ---------------------------------------------------------------------------
def _strip_markdown_fence(text: str) -> str:
    """Claude sometimes wraps JSON output in a ```json ... ``` fence despite being asked not to."""
    text = text.strip()
    if text.startswith("```"):
        text = re.sub(r"^```[^\n]*\n", "", text)
        text = re.sub(r"\n```$", "", text)
    return text.strip()


def _translate_batch_cli(lang_name: str, stubs: dict[str, str]) -> dict[str, str]:
    # subprocess.run(["claude", ...]) without shell=True does not resolve PATHEXT on
    # Windows (claude is typically a .cmd shim there) - resolve the real path first.
    claude_bin = shutil.which("claude")
    if claude_bin is None:
        raise FileNotFoundError("claude CLI not found on PATH")
    # The prompt is passed via stdin, not as a CLI argument: it contains newlines and
    # JSON punctuation that a Windows .cmd shim's argv handling mangles unreliably.
    result = subprocess.run(
        [claude_bin, "-p", "--output-format", "json", "--model", MODEL],
        input=_build_prompt(lang_name, stubs),
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=CLI_TIMEOUT_SECONDS,
        check=True,
    )
    response = json.loads(result.stdout)
    raw = _strip_markdown_fence(response["result"])
    return json.loads(raw)

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent.parent
    src_dir   = repo_root / "src"

    en_path = src_dir / "CTLD_i18n_en.lua"
    if not en_path.exists():
        print(f"[translate-i18n] WARNING: EN dict not found at {en_path}", flush=True)
        return 0

    en_dict = parse_dict(en_path.read_text(encoding="utf-8"))
    if not en_dict:
        print("[translate-i18n] WARNING: EN dict is empty — nothing to translate.", flush=True)
        return 0

    backend = _select_backend(has_api_key=bool(os.environ.get("ANTHROPIC_API_KEY")))

    client = None
    if backend == "api":
        try:
            import anthropic
            client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
        except Exception as e:
            print(f"[translate-i18n] WARNING: Could not initialise Anthropic client: {e}", flush=True)
            return 0

    total = 0
    for lang, lang_name in LANG_NAMES.items():
        lang_path = src_dir / f"CTLD_i18n_{lang}.lua"
        if not lang_path.exists():
            print(f"[translate-i18n] WARNING: {lang_path.name} not found — skipping {lang}.", flush=True)
            continue

        lang_text = lang_path.read_text(encoding="utf-8")
        lang_dict = parse_dict(lang_text)
        keep_en = parse_keep_en(lang_text)

        stubs = _collect_stubs(en_dict, lang_dict, keep_en)

        if not stubs:
            print(f"[translate-i18n] {lang}: no stubs — skipped.", flush=True)
            continue

        print(f"[translate-i18n] {lang}: translating {len(stubs)} stub(s) via {backend}...", flush=True)
        try:
            if backend == "api":
                translations = _translate_batch_api(client, lang_name, stubs)
            else:
                translations = _translate_batch_cli(lang_name, stubs)
        except json.JSONDecodeError as e:
            print(f"[translate-i18n] WARNING: malformed JSON response for {lang}: {e}", flush=True)
            continue
        except Exception as e:
            if backend == "cli":
                print(
                    f"[translate-i18n] WARNING: Claude Code CLI translation failed for {lang} ({e}) "
                    f"— set ANTHROPIC_API_KEY or authenticate `claude` to enable i18n auto-translation.",
                    flush=True,
                )
            else:
                print(f"[translate-i18n] WARNING: API error for {lang}: {e}", flush=True)
            continue

        # Only write back keys that were actually stubs and got a non-empty translation
        to_write = {
            k: v for k, v in translations.items()
            if k in stubs and isinstance(v, str) and v and v != en_dict.get(k)
        }
        if not to_write:
            print(f"[translate-i18n] {lang}: no usable translations returned.", flush=True)
            continue

        written = _apply_translations(lang_path, to_write, lang)
        print(f"[translate-i18n] {lang}: wrote {written} translation(s).", flush=True)
        total += written

    print(f"[translate-i18n] Done. Total keys written: {total}.", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
