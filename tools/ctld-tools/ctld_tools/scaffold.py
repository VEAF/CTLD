"""The commented user-config.yaml starter (`gen-user --scaffold`).

Everything is commented out, so a fresh scaffold changes nothing until the MM
uncomments what they need. Both YAML styles are shown (block = readable, flow =
compact) — ruamel reads either.
"""

from __future__ import annotations

from pathlib import Path

SCAFFOLD = """\
# CTLD user-config — edit this file, validate it, then generate CTLD_userConfig.lua:
#   ctld-tools validate  --yaml user-config.yaml --src path/to/src
#   ctld-tools gen-user  --yaml user-config.yaml --src path/to/src --out CTLD_userConfig.lua
#
# You refer to crates and troop groups BY NAME — ctld-tools resolves everything else.
# Uncomment only what you want to change. Two YAML styles are shown; pick either.

# ---- Scalar settings (optional) ----
# settings:
#   numberOfTroops: 8
#   slingLoad: true

# ---- Crates ----
# crates:
#   add:
#     # block style (readable):
#     - section: Support         # F10 sub-menu
#       name: Ural Ammo          # label shown in the menu
#       unit: Ural-375           # DCS type name (validated)
#       side: 1                  # 1=RED, 2=BLUE, omit=both
#       cratesRequired: 2
#       weight_kg: 2000          # crate mass in kg (also its unique key)
#     # flow style (compact) — exactly the same:
#     - { section: Support, name: M-818 Truck, unit: "M 818", side: 2, weight_kg: 2500 }
#   remove:
#     - Heavy Tank - Abrams      # by name — no need to know its weight
#   patch:
#     - name: Humvee - TOW       # change one field, keep the rest
#       cratesRequired: 3

# ---- Troops ----
# troops:
#   add:
#     - name: Recon Team
#       inf: 3
#       jtac: 1
#   remove:
#     - 5x - Mortar Squad

# ---- Array settings (append) ----
# arrays:
#   transportPilotNames: [helicargo_custom_1]
#   troopZones:
#     - [pickzone_north, green, -1, yes, 0]
"""


def write_scaffold(out_path: str | Path) -> None:
    Path(out_path).write_text(SCAFFOLD, encoding="utf-8", newline="\n")
