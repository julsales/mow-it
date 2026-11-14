# Audits the base models: does every piece hang together and does every
# moving piece have room to move? Prints one line per problem and renders a
# 4-view sheet per model (with a stand-in rider) to out/audit/<model>.png
# (`python3 art/tools/sheet.py audit` joins the views).
#
#   flatpak run org.blender.Blender -b --factory-startup \
#       --python $PWD/art/tools/audit.py -- [model names…]
#
# Checks (per model, on the pieces before they are joined):
#   FLOAT   a piece, or a group of pieces, that touches nothing else
#   SWEEP   a turning piece (wheel, drum, rotor…) that cuts through a fixed
#           one somewhere along its turn
#   GROUND  a piece under the ground; a wheel that doesn't reach it
#   CLEAR   a piece inside the rider's body (build.clearance)
# Pieces meant to float are listed in FLOATERS.

import math
import os
import sys

import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import build  # noqa: E402
import lib  # noqa: E402
from models import HAND, MODELS  # noqa: E402

OUT = os.path.join(build.OUT, "audit")
os.makedirs(OUT, exist_ok=True)

TOUCH = 0.03  # studs: closer than this counts as joined
FLOATERS = {"Orbit", "Portal"}  # rigs that hover on purpose
# Axis each kind of rig turns around (roblox axes), as in ToolAnimations.
TURNS = {"Spin": "x", "Reel": "x", "Drum": "x", "Rotor": "y", "Head": "y", "Portal": "y", "Prop": "z", "Drill": "z"}
VIEWS = [  # (label, camera direction in Blender axes, orthographic)
    ("front", (-0.75, 1.0, 0.6), False),
    ("side", (1, 0, 0.05), True),
    ("back", (0.8, -1.0, 0.7), False),
    ("top", (0, 0.001, 1), True),
]


def rb(v):
    return Vector((v.x, v.z, -v.y))


class Piece:
    def __init__(self, o):
        self.o = o
        self.grp = o.get("grp", "Dark")
        self.rig = o.get("rig")
        self.verts = [o.matrix_world @ v.co for v in o.data.vertices]
        self.polys = [tuple(p.vertices) for p in o.data.polygons]
        self.tree = BVHTree.FromPolygons(self.verts, self.polys)
        xs, ys, zs = zip(*self.verts)
        self.lo = Vector((min(xs), min(ys), min(zs)))
        self.hi = Vector((max(xs), max(ys), max(zs)))
        self.mid = (self.lo + self.hi) / 2

    def label(self):
        m = rb(self.mid)
        return f"{self.grp}{'#' + self.rig if self.rig else ''}@({m.x:.2f},{m.y:.2f},{m.z:.2f})"

    def inside(self, p):
        loc, normal, _, _ = self.tree.find_nearest(p)
        return loc is not None and (p - loc).dot(normal) < -1e-4

    def near(self, p):
        loc, _, _, dist = self.tree.find_nearest(p, TOUCH)
        return loc is not None


def touching(a, b):
    if any(a.lo[i] > b.hi[i] + TOUCH or b.lo[i] > a.hi[i] + TOUCH for i in range(3)):
        return False
    if a.tree.overlap(b.tree):
        return True
    return any(b.near(p) or b.inside(p) for p in a.verts) or any(a.near(p) or a.inside(p) for p in b.verts)


def check_float(pieces, extras_of):
    """Pieces must form one connected lump. Optional extras are judged
    against the base model plus their own extra only."""
    n = len(pieces)
    adj = {i: set() for i in range(n)}
    for i in range(n):
        for j in range(i + 1, n):
            if touching(pieces[i], pieces[j]):
                adj[i].add(j)
                adj[j].add(i)
    problems = []
    extras = sorted({e for e in extras_of if e})
    for extra in [None] + extras:
        members = [i for i in range(n) if extras_of[i] in (None, extra)]
        seen = set()
        lumps = []
        for i in members:
            if i in seen:
                continue
            lump, todo = [], [i]
            seen.add(i)
            while todo:
                k = todo.pop()
                lump.append(k)
                for m in adj[k]:
                    if m in members and m not in seen:
                        seen.add(m)
                        todo.append(m)
            lumps.append(lump)
        lumps.sort(key=len, reverse=True)
        for lump in lumps[1:]:
            if all(pieces[k].rig in FLOATERS for k in lump):
                continue
            if extra is None or any(extras_of[k] == extra for k in lump):
                names = ", ".join(pieces[k].label() for k in lump[:4])
                problems.append(f"FLOAT {'[' + extra + '] ' if extra else ''}{len(lump)} piece(s): {names}")
    return problems


def turn_axis(rig):
    for prefix, axis in TURNS.items():
        if rig.startswith(prefix):
            return axis
    return None


def check_sweep(pieces):
    problems = []
    rigs = {}
    for p in pieces:
        if p.rig and turn_axis(p.rig):
            rigs.setdefault(p.rig, []).append(p)
    fixed = [p for p in pieces if not p.rig]
    for rig, members in rigs.items():
        pivot = lib.R(*lib.PIVOTS[rig])
        axis = lib._AXIS[turn_axis(rig)]
        pts = [v for m in members for v in m.verts]
        radius = max(((v - pivot) - axis * (v - pivot).dot(axis)).length for v in pts)
        hits = {}
        for step in range(16):
            m = Matrix.Translation(pivot) @ Matrix.Rotation(step * math.pi / 8, 4, axis) @ Matrix.Translation(-pivot)
            for v in pts:
                w = m @ v
                r = ((w - pivot) - axis * (w - pivot).dot(axis)).length
                if r < radius * 0.4:
                    continue  # near the axle: that's where it is mounted
                if rb(w).y < -0.3:  # tread and cutters may bite the grass, no deeper
                    hits["the ground"] = max(hits.get("the ground", 0), -rb(w).y)
                for f in fixed:
                    if all(f.lo[i] <= w[i] <= f.hi[i] for i in range(3)) and f.inside(w):
                        loc, _, _, _ = f.tree.find_nearest(w)
                        hits[f.label()] = max(hits.get(f.label(), 0), (w - loc).length)
        # thin fixed pieces (legs, fins): turn them backwards into the rig
        for f in fixed:
            for step in range(16):
                m = Matrix.Translation(pivot) @ Matrix.Rotation(-step * math.pi / 8, 4, axis) @ Matrix.Translation(-pivot)
                for v in f.verts:
                    w = m @ v
                    r = ((w - pivot) - axis * (w - pivot).dot(axis)).length
                    if r < radius * 0.4 or r > radius:
                        continue
                    for member in members:
                        if all(member.lo[i] <= w[i] <= member.hi[i] for i in range(3)) and member.inside(w):
                            loc, _, _, _ = member.tree.find_nearest(w)
                            hits[f.label()] = max(hits.get(f.label(), 0), (w - loc).length)
        for what, depth in sorted(hits.items()):
            if depth > 0.04:
                problems.append(f"SWEEP {rig} cuts {depth:.2f} into {what}")
    return problems


def check_ground(pieces):
    """Tyres stand on the ground (their tread may bite into it); road
    wheels inside a rubber track count when the track reaches it."""
    problems = []
    low = {}
    tracks = [p for p in pieces if not p.rig and p.grp == "Rubber" and min(rb(v).y for v in p.verts) < 0.08]
    for p in pieces:
        y = min(rb(v).y for v in p.verts)
        if p.rig and p.rig.startswith("Spin"):
            if p.grp == "Rubber" and len(p.verts) > 24 and not any(touching(p, t) for t in tracks):  # the tyre, not its tread blocks
                low[p.rig] = min(low.get(p.rig, 9), y)
        elif y < -0.05 and not p.rig:
            problems.append(f"GROUND {p.label()} is {-y:.2f} under the ground")
    for rig, y in sorted(low.items()):
        if abs(y) > 0.06:
            problems.append(f"GROUND wheel {rig} bottom at y={y:.2f}")
    return problems


def mannequin(name):
    """A blocky stand-in the size of a default avatar, where the game puts
    the player (build.RIDERS), so the sheets show the scale."""
    spec = build.RIDERS.get(name)
    made = []

    def part(c, s):
        made.append(lib.box("Mannequin", c, s, bevel=0.08))

    if not spec:
        return made
    kind, where = spec
    if kind == "stand":
        y = where
        part((0, y + 1.35, 0), (0.95, 2.7, 0.9))
        part((0, y + 3.6, 0), (1.9, 1.8, 0.95))
        part((0, y + 5.05, 0), (1.15, 1.1, 1.1))
    else:
        x, y, z = where
        part((x, y + 0.45, z - 0.55), (0.95, 0.9, 1.9))  # thighs
        part((x, y - 0.35, z - 1.2), (0.95, 1.5, 0.9))  # shins
        part((x, y + 1.25, z), (1.9, 1.8, 0.95))
        part((x, y + 2.7, z), (1.15, 1.1, 1.1))
    return made


def views(name):
    """The four views as out/audit/.<model>_<view>.png; `python3
    art/tools/sheet.py audit` joins them (Blender's Python has no Pillow)."""
    for label, direction, ortho in VIEWS:
        build.shoot(os.path.join(OUT, f".{name}_{label}.png"), direction, res=560, ortho=ortho)


def main():
    build.COLORS["Mannequin"] = (0.35, 0.6, 0.95)
    names = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    total = 0
    for name in names or list(MODELS):
        build.reset()
        MODELS[name]()
        objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
        pieces = [Piece(o) for o in objs]
        extras_of = [p.grp.split(".", 1)[1] if "." in p.grp else None for p in pieces]
        problems = check_float(pieces, extras_of)
        if name not in HAND:
            problems += check_sweep(pieces) + check_ground(pieces)
        problems += [f"CLEAR {hit}" for hit in build.clearance(name)]
        total += len(problems)
        print(f"AUDIT {name}: {len(pieces)} pieces, " + (f"{len(problems)} problem(s)" if problems else "ok"))
        for line in problems:
            print(f"AUDIT   {line}")
        mannequin(name)
        views(name)
    print(f"AUDIT total: {total} problem(s)")


if __name__ == "__main__":
    main()
