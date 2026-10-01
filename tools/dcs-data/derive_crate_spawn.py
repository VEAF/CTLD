"""Derive the declared crate spawn distance of each native-cargo aircraft from its collision shell.

For each type, the static hull pieces of the collision shell are cut at crate height above the ground, and the
largest distance from the aircraft centre to that slice inside the declared sector is taken as the hull radius.
The declared ``crateSpawnDistance`` is that radius plus a margin (default 1.5 m).

Needs the ``edm_parser`` module of Blender_EDM_reverse and a DCS install; neither is part of this repo.

    set EDM_PARSER_DIR=C:\\path\\to\\Blender_EDM_reverse\\io_edm_importer
    set DCS_ROOT=E:\\Program Files\\Eagle Dynamics\\DCS World OpenBeta
    python tools/dcs-data/derive_crate_spawn.py
"""

import math
import os
import sys

CRATE_HEIGHT = 1.3  # metres above the ground that a crate (and what can touch it) occupies
MARGIN = 1.5  # metres added to the hull radius
MOVING = ("BLADE", "ROTOR", "PROP", "HUB", "SWASH")  # moving parts, in their own local frame

# type -> (collision shell relative to DCS_ROOT, sector, up axis index in the file or None to guess)
TYPES = {
    "UH-1H": (r"Bazar\World\Shapes\ab-212_collision.edm", "side", 1),
    "Mi-8MT": (r"Bazar\World\Shapes\Mi-8MTV2_collision.EDM", "side", 1),
    "C-130J-30": (r"CoreMods\aircraft\C130J\Shapes\C130J_30_COL.edm", "rear", 2),
    "CH-47Fbl1": (r"CoreMods\aircraft\CH-47F\Shapes\CH-47F_bl1_collision.edm", "side", None),
    "Mi-24P": (r"CoreMods\aircraft\Mi-24P\Shapes\mi-24p_collision.EDM", "side", 1),
}
# bearing window from the nose, in degrees
SECTORS = {"side": (60, 120), "rear": (135, 180), "front": (0, 45)}


def _is_static(mesh):
    return not (mesh.name and any(s in mesh.name.upper() for s in MOVING))


def _guess_up(meshes):
    """Up axis: the one where a wheel mesh holds the lowest point and the extent is the most asymmetric."""
    wheels = [m for m in meshes if m.name and "WHEEL" in m.name.upper()]
    static = [m for m in meshes if _is_static(m)]
    best = None
    for ax in range(3):
        low = min(min(p[ax] for p in m.positions) for m in static)
        if wheels and abs(min(min(p[ax] for p in m.positions) for m in wheels) - low) < 1e-3:
            high = max(max(p[ax] for p in m.positions) for m in static)
            asym = abs(low + high)
            if best is None or asym > best[1]:
                best = (ax, asym)
    return best[0] if best else None


def _slab_points(tri, up, lo, hi):
    pts = [p for p in tri if lo <= p[up] <= hi]
    for i in range(3):
        a, b = tri[i], tri[(i + 1) % 3]
        for plane in (lo, hi):
            if (a[up] - plane) * (b[up] - plane) < 0:
                t = (plane - a[up]) / (b[up] - a[up])
                pts.append(tuple(a[k] + t * (b[k] - a[k]) for k in range(3)))
    return pts


def hull_radius(path, sector, up, parse_edm_nodes):
    """Largest distance from the centre to the ground slice of the static hull inside the sector."""
    with open(path, "rb") as f:
        scene = parse_edm_nodes(f.read())
    meshes = [m for m in scene.meshes if m.positions]
    static = [m for m in meshes if _is_static(m)]
    if up is None:
        up = _guess_up(meshes)
    if up is None:
        raise ValueError("up axis cannot be guessed, give it in TYPES")
    lateral = [a for a in range(3) if a not in (0, up)][0]
    ground = min(min(p[up] for p in m.positions) for m in static)
    lo_b, hi_b = SECTORS[sector]
    radius = 0.0
    for m in static:
        for t in m.triangles:
            for p in _slab_points([m.positions[i] for i in t], up, ground, ground + CRATE_HEIGHT):
                bearing = math.degrees(math.atan2(abs(p[lateral]), p[0]))
                if lo_b <= bearing <= hi_b:
                    radius = max(radius, math.hypot(p[0], p[lateral]))
    return radius


def main():
    parser_dir = os.environ.get("EDM_PARSER_DIR")
    dcs_root = os.environ.get("DCS_ROOT")
    if not parser_dir or not dcs_root:
        sys.exit("set EDM_PARSER_DIR (io_edm_importer folder) and DCS_ROOT (DCS install folder)")
    sys.path.insert(0, parser_dir)
    from edm_parser import parse_edm_nodes  # noqa: PLC0415 - path set just above

    print(f"{'type':<10} {'sector':<6} {'radius':>8} {'declared':>10}  collision shell")
    for name, (rel, sector, up) in TYPES.items():
        path = os.path.join(dcs_root, rel)
        try:
            r = hull_radius(path, sector, up, parse_edm_nodes)
        except (OSError, ValueError) as e:
            print(f"{name:<10} {sector:<6}  skipped: {e}")
            continue
        print(f"{name:<10} {sector:<6} {r:7.1f}m {round(r + MARGIN, 1):9.1f}m  {rel}")


if __name__ == "__main__":
    main()
