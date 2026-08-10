#!/usr/bin/env python3
"""check_i18n_diff.py — Fail if a PR introduces a newly-empty non-EN i18n entry.

Compares each non-EN dictionary (src/CTLD_i18n_fr/es/ko.lua) at a given base ref against its
current (head) content. A key is "newly empty" when its head value is "" and it either did not
exist at base or held a non-empty value there — i.e. genuinely new to this PR, not part of the
pre-existing debt already on develop (a key already empty at base is left alone).

Usage:  python tools/build/check_i18n_diff.py <base_ref>
Exit:   0 if no newly-empty entries; 1 otherwise (offending keys printed to stdout).
"""

import subprocess
import sys
from pathlib import Path

from i18n_dict_utils import parse_dict

LANGS = ("fr", "es", "ko")


def find_new_empty_keys(base_text: str, head_text: str) -> list[str]:
    base_dict = parse_dict(base_text)
    head_dict = parse_dict(head_text)
    new_empty = [
        key
        for key, head_value in head_dict.items()
        if head_value == "" and base_dict.get(key) != ""
    ]
    return sorted(new_empty)


def _git_show(ref: str, path: str, cwd: Path) -> str:
    result = subprocess.run(
        ["git", "show", f"{ref}:{path}"],
        cwd=cwd, capture_output=True, text=True, encoding="utf-8",
    )
    if result.returncode != 0:
        # Absent at base (new file, or path didn't exist yet) — every head key is new.
        return ""
    return result.stdout


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_i18n_diff.py <base_ref>", file=sys.stderr)
        return 2
    base_ref = sys.argv[1]

    repo_root = Path(__file__).resolve().parent.parent.parent
    src_dir = repo_root / "src"

    total = 0
    for lang in LANGS:
        head_path = src_dir / f"CTLD_i18n_{lang}.lua"
        if not head_path.exists():
            continue
        head_text = head_path.read_text(encoding="utf-8")
        base_text = _git_show(base_ref, f"src/CTLD_i18n_{lang}.lua", cwd=repo_root)

        new_empty = find_new_empty_keys(base_text, head_text)
        if new_empty:
            print(f"[check-i18n-diff] {lang}: {len(new_empty)} newly-empty key(s):")
            for key in new_empty:
                print(f"  - {key}")
            total += len(new_empty)

    if total:
        print(f"[check-i18n-diff] {total} newly-empty i18n entry/entries introduced by this PR.")
        return 1

    print("[check-i18n-diff] No newly-empty i18n entries.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
