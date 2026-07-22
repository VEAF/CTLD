#!/usr/bin/env python3
"""translate_i18n.py — Fill empty i18n stubs via the Claude API.

Reads src/CTLD_i18n_*.lua, identifies stubs (value == EN value),
and fills them using Claude claude-haiku-4-5-20251001, one batch call per language.
Writes results back in-place. Non-blocking: any error prints a WARNING and exits 0.

Requirements: pip install anthropic
Usage:        python tools/build/translate_i18n.py
Environment:  ANTHROPIC_API_KEY must be set.
"""

import os
import re
import sys
import json
from pathlib import Path

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
MODEL     = "claude-haiku-4-5-20251001"
LANG_NAMES = {"fr": "French", "es": "Spanish", "ko": "Korean"}

# ---------------------------------------------------------------------------
# Parse a CTLD_i18n_XX.lua dict file into {key: value} (excludes translation_version)
# ---------------------------------------------------------------------------
_ENTRY_RE = re.compile(r'ctld\.i18n\["[^"]+"\]\["([^"]+)"\]\s*=\s*"((?:[^"\\]|\\.)*)"\s*')

def _parse_dict(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    result = {}
    for m in _ENTRY_RE.finditer(text):
        key, val = m.group(1), m.group(2)
        if key != "translation_version":
            result[key] = val
    return result

# ---------------------------------------------------------------------------
# Write translated values back into the Lua source file
# ---------------------------------------------------------------------------
def _apply_translations(path: Path, translations: dict[str, str], lang: str) -> int:
    text = path.read_text(encoding="utf-8")
    count = 0
    for key, new_val in translations.items():
        # Escape backslashes and double-quotes in the new value
        escaped = new_val.replace("\\", "\\\\").replace('"', '\\"')
        pattern  = r'(ctld\.i18n\["' + re.escape(lang) + r'"\]\["' + re.escape(key) + r'"\]\s*=\s*)"(?:[^"\\]|\\.)*"'
        replacement = r'\g<1>"' + escaped + '"'
        new_text, n = re.subn(pattern, replacement, text)
        if n:
            text = new_text
            count += 1
    if count:
        path.write_text(text, encoding="utf-8")
    return count

# ---------------------------------------------------------------------------
# Call Claude for one language
# ---------------------------------------------------------------------------
def _translate_batch(client, lang: str, lang_name: str, stubs: dict[str, str]) -> dict[str, str]:
    keys_json = json.dumps(stubs, ensure_ascii=False, indent=2)
    prompt = (
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
    message = client.messages.create(
        model=MODEL,
        max_tokens=4096,
        messages=[{"role": "user", "content": prompt}],
    )
    raw = message.content[0].text.strip()
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

    en_dict = _parse_dict(en_path)
    if not en_dict:
        print("[translate-i18n] WARNING: EN dict is empty — nothing to translate.", flush=True)
        return 0

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

        lang_dict = _parse_dict(lang_path)
        # A stub = key present in lang dict but value equals the EN value
        stubs = {k: v for k, v in en_dict.items() if lang_dict.get(k) == v}

        if not stubs:
            print(f"[translate-i18n] {lang}: no stubs — skipped.", flush=True)
            continue

        print(f"[translate-i18n] {lang}: translating {len(stubs)} stub(s) via Claude...", flush=True)
        try:
            translations = _translate_batch(client, lang, lang_name, stubs)
        except json.JSONDecodeError as e:
            print(f"[translate-i18n] WARNING: malformed JSON response for {lang}: {e}", flush=True)
            continue
        except Exception as e:
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
