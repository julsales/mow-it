# The 15 base models (plus the themed late-game ones built from them).
# Roblox coords, studs. Hand tools: grip at the origin, tool pointing -Z,
# top +Y. Ground tools: origin on the ground under the player, machine in
# front (-Z) or around them (riders).
# Push/reel mowers leave the handle out: the game builds it fitted to
# the avatar's arms (ToolModels handle()).
#
# Every piece must hold on to something (audit.py checks it): wheels sit
# on axles or in forks, seats on pedestals, rims on spokes. The shared
# parts below keep those joints the same on every machine.

import math

from mathutils import Vector

from lib import arc_pts, ball, box, cyl, prism, rig, ring, wedge, wheel, xform

MODELS = {}
HAND = set()  # models held in the hand (the rest stand on the ground)


def model(fn=None, *, hand=False):
    def register(f):
        MODELS[f.__name__] = f
        if hand:
            HAND.add(f.__name__)
        return f

    return register(fn) if fn else register


# ------------------------------------------------------------ shared parts


def wheels(x, y, z, diameter, width, mount=None, inner=None, **look):
    """A pair of wheels at (±x, y, z) on one axle. `mount`: height of the
    underside the axle hangs from (adds a bracket up to it). `inner`:
    stub axles that only reach in to ±inner (when something turns between
    the wheels) instead of one beam across."""
    r = max(0.08, diameter * 0.07)
    for side in (-1, 1):
        wheel((side * x, y, z), diameter, width, **look)
        if inner is not None:
            cyl("Dark", (side * x, y, z), (side * inner, y, z), r, verts=8, bevel=0)
    if inner is None:
        cyl("Dark", (-x, y, z), (x, y, z), r, verts=8, bevel=0)
    if mount is not None:
        box("Dark", (0, (y + mount) / 2 + 0.05, z), (0.7, mount - y + 0.3, 0.5), bevel=0.06)


def caster(x, z, diameter, mount):
    """Small swivel wheel in a fork, its bridge at height `mount`."""
    r, w = diameter / 2, diameter * 0.45
    wheel((x, r, z), diameter, w, hub="Dark")
    for side in (-1, 1):
        box("Dark", (x + side * (w / 2 + 0.07), (r + mount) / 2, z), (0.08, mount - r + 0.12, 0.2), bevel=0.02)
    cyl("Dark", (x - w / 2 - 0.1, r, z), (x + w / 2 + 0.1, r, z), 0.05, verts=6, bevel=0)
    box("Dark", (x, mount, z), (w + 0.3, 0.12, 0.3), bevel=0.03)


def fender(x, y, z, r, width, wall=False, a0=10, a1=170):
    """Arched mudguard over a wheel centred at (x, y, z), clear of a tyre
    of radius `r`. `wall` closes its inner side (tractor seat walls)."""
    outer = arc_pts(0, 0, r + 0.16, a0, a1, 8)
    prism("Accent", outer + arc_pts(0, 0, r, a1, a0, 8), (x, y, z), (0, 0, 1), (0, 1, 0), width, bevel=0.03)
    if wall:
        side = 1 if x > 0 else -1
        prism("Accent", outer, (x - side * (width / 2 + 0.03), y, z), (0, 0, 1), (0, 1, 0), 0.14, bevel=0.03)


def track(x, y, z, length, height, width, count, hub="Accent2"):
    """Tank track: a rubber belt standing on the ground, cleats across it
    and `count` road wheels on its outer side."""
    side = 1 if x > 0 else -1
    box("Rubber", (x, y, z), (width, height, length), bevel=height * 0.24)
    n = int(length / 0.6)
    for i in range(n):
        cz = z - length / 2 + height * 0.3 + (length - height * 0.6) * i / (n - 1)
        for cy in (y + height / 2, y - height / 2 + 0.05):
            box("Rubber", (x, cy, cz), (width * 1.04, 0.1, 0.22), bevel=0.02)
    for i in range(count):
        wz = z - length / 2 + height / 2 + (length - height) * i / (count - 1)
        wheel((x + side * (width / 2 + 0.14), y, wz), height * 0.66, 0.28, hub=hub, spokes=4)


def seat(x, top, z, width=1.5, depth=1.25, back=1.7, floor=None):
    """Driver's seat: the cushion's top-centre is (x, top, z) (the game sits
    the player there, Config/ToolArt Seat), the backrest grows out of the
    cushion and a pedestal goes down to `floor`."""
    box("Seat", (x, top - 0.18, z), (width, 0.36, depth), bevel=0.14)
    box("Seat", (x, top + back / 2 - 0.25, z + depth / 2 + 0.02), (width, back, 0.3), bevel=0.12, rot=[("x", 6)])
    for side in (-1, 1):  # side bolsters
        box("Seat", (x + side * (width / 2 - 0.1), top + 0.02, z + 0.1), (0.2, 0.2, depth * 0.8), bevel=0.08)
    if floor is not None:
        box("Dark", (x, (top - 0.3 + floor) / 2, z), (width * 0.65, top - 0.3 - floor + 0.1, depth * 0.6), bevel=0.06)


def steering(base, hub, r):
    """Steering column from `base` to the wheel's `hub`; the rim faces down
    the column and three spokes hold it (the hands go at 3 and 9)."""
    b, h = Vector(base), Vector(hub)
    n = (h - b).normalized()
    cyl("Dark", base, hub, 0.1, verts=8)
    ring("SteeringWheel", hub, tuple(n), r, 0.08, seg=14, minor_seg=6)
    cyl("SteeringWheel", tuple(h - n * 0.06), tuple(h + n * 0.08), 0.16, verts=8)
    down = Vector((0, n.z, -n.y)).normalized() * -1  # in the rim's plane, toward the driver
    for d in (Vector((1, 0, 0)), Vector((-1, 0, 0)), down):
        cyl("SteeringWheel", hub, tuple(h + d * r), 0.05, verts=5, bevel=0)


def handrail(deck, z=-1.25, width=0.6):
    """Bar to hold for standing rides: at hand height, in front of the
    legs, its post sunk into the deck."""
    cyl("Dark", (0, deck - 0.2, z - 0.15), (0, deck + 2.45, z), 0.12, verts=8)
    cyl("SteeringWheel", (-width, deck + 2.5, z), (width, deck + 2.5, z), 0.13, verts=8)
    for side in (-1, 1):  # bright grips where the hands go (ToolModels GripL/GripR)
        cyl("Accent2", (side * width * 0.55, deck + 2.5, z), (side * (width + 0.05), deck + 2.5, z), 0.17, verts=8)


def vents(x, y, z, length, rows=3, gap=0.25):
    """Louvres on a side panel facing ±X (x = the panel's face)."""
    for i in range(rows):
        box("Dark", (x, y + i * gap, z), (0.06, 0.1, length), bevel=0)


# ---------------------------------------------------------------- hand tools


@model(hand=True)
def clipper():
    # Fat cartoon nail clipper: two jaws riveted together at the back, a
    # pin through them near the front, and a lever hooked on the pin.
    box("Metal", (0, -0.16, -1.0), (0.62, 0.14, 2.1), bevel=0.05)
    box("Metal", (0, 0.02, -1.0), (0.62, 0.14, 2.1), bevel=0.05, rot=[("x", -5)])
    box("Metal", (0, -0.07, 0.0), (0.62, 0.36, 0.34), bevel=0.08)  # the riveted end
    for y in (-0.13, 0.0):  # cutting lips
        box("Chrome", (0, y, -2.06), (0.62, 0.12, 0.1), bevel=0.03)
    cyl("Dark", (0, -0.26, -1.55), (0, 0.4, -1.55), 0.09, verts=8)  # the pin
    cyl("Chrome", (0, 0.38, -1.55), (0, 0.46, -1.55), 0.15, verts=8)
    with rig("Lever"):  # presses down around the pin when cutting
        box("Metal", (0, 0.42, -0.75), (0.56, 0.1, 1.9), bevel=0.04, rot=[("x", -6)])
        box("Accent", (0, 0.53, -0.4), (0.46, 0.08, 0.9), bevel=0.03, rot=[("x", -6)])
    ring("Accent", (0, -0.16, 0.38), (1, 0, 0), 0.24, 0.07, seg=10, minor_seg=5)


def _scissor_loop(side, color, big):
    r = 0.34 if big else 0.28
    ring(color, (side * 0.32, 0, 0.25), (0, 1, 0), r, 0.11, seg=10, minor_seg=6)


@model(hand=True)
def scissors_safety():
    # Chunky kid scissors: round plastic loops, short blunt blades.
    for side in (-1, 1):
        with rig("SnipL" if side < 0 else "SnipR"):  # open/close around the screw
            _scissor_loop(side, "Accent", True)
            box("Accent", (side * 0.14, 0, -0.25), (0.22, 0.18, 0.55), bevel=0.06, rot=[("y", side * 18)])
            pts = [(-0.11, 0), (0.11, 0), (0.1, 1.1), (0.0, 1.32), (-0.1, 1.1)]
            prism("Metal", pts, (side * 0.05, 0, -0.45), (1, 0, 0), (side * 0.06, 0, -1), 0.06)
    ball("Chrome", (0, 0.06, -0.48), (0.16, 0.08, 0.16), seg=8, rings=4)


@model(hand=True)
def scissors_kitchen():
    for side in (-1, 1):
        with rig("SnipL" if side < 0 else "SnipR"):
            ring("Accent", (side * 0.3, 0, 0.3), (0, 1, 0), 0.3 if side < 0 else 0.25, 0.1, seg=10, minor_seg=6)
            box("Accent", (side * 0.13, 0, -0.18), (0.2, 0.16, 0.5), bevel=0.05, rot=[("y", side * 15)])
            pts = [(-0.12, 0), (0.12, 0), (0.0, 1.9)]
            prism("Metal", pts, (side * 0.05, 0, -0.42), (1, 0, 0), (side * 0.07, 0, -1), 0.06)
    ball("Chrome", (0, 0.06, -0.45), (0.15, 0.08, 0.15), seg=8, rings=4)


@model(hand=True)
def shears():
    # Garden shears: long wooden handles, red grips, big curved blades.
    for side in (-1, 1):
        with rig("SnipL" if side < 0 else "SnipR"):
            cyl("Wood", (side * 0.35, 0, 0.9), (side * 0.12, 0, -0.75), 0.12, verts=8)
            cyl("Accent", (side * 0.4, 0, 1.25), (side * 0.33, 0, 0.75), 0.15, verts=8)
            cyl("Chrome", (side * 0.16, 0, -0.5), (side * 0.12, 0, -0.78), 0.14, verts=8)  # ferrule
            pts = [(-0.18, 0), (0.16, 0), (0.12, 0.9), (0.02, 1.7), (-0.08, 1.5), (-0.14, 0.8)]
            prism("Metal", pts, (side * 0.06, 0, -0.75), (1, 0, 0), (side * 0.1, 0, -1), 0.07)
    cyl("Chrome", (0, -0.12, -0.8), (0, 0.12, -0.8), 0.12, verts=8)
    box("Dark", (0, 0, -0.55), (0.32, 0.14, 0.28), bevel=0.04)


@model(hand=True)
def sickle():
    cyl("Wood", (0, 0, 0.55), (0, 0, -0.75), 0.15, verts=8)
    cyl("Accent", (0, 0, 0.6), (0, 0, 0.35), 0.17, verts=8)
    cyl("Chrome", (0, 0, -0.75), (0, 0, -0.95), 0.18, verts=8)
    # crescent: outer arc minus inner arc, in the YZ plane (u = -Z, v = +Y)
    cx, cy = 1.45, 0.95
    outer = arc_pts(cx, cy, 1.0, 200, 450, 14)
    inner = arc_pts(cx + 0.15, cy + 0.16, 0.78, 420, 215, 12)
    prism("Metal", outer + inner, (0, -0.05, 0), (0, 0, -1), (0, 1, 0), 0.07, bevel=0.015)


@model(hand=True)
def grass_whip():
    # A long shaft and a wavy serrated blade at the tip.
    cyl("Wood", (0, 0, 0.5), (0, 0, -2.4), 0.11, verts=8)
    cyl("Accent", (0, 0, 0.55), (0, 0, 0.1), 0.15, verts=8)
    cyl("Chrome", (0, 0, -2.35), (0, 0, -2.55), 0.15, verts=8)
    pts = [(0, 0)]
    for i in range(9):
        pts.append((0.14 * i + 0.07, 0.7 + (0.12 if i % 2 == 0 else 0)))
    pts += [(1.3, 0.55), (1.25, 0.0)]
    prism("Metal", pts, (0, -0.2, -2.45), (0, 0, -1), (0, 1, 0), 0.06, bevel=0.01)


@model(hand=True)
def hedge():
    # Hedge trimmer: grip at the origin, round body, D-handle, toothy bar.
    box("Accent", (0, 0.1, -0.55), (0.75, 0.75, 1.3), bevel=0.2)
    box("Accent2", (0, 0.1, -0.55), (0.8, 0.22, 1.2), bevel=0.05)
    cyl("HandleGrip", (0, 0, 0.45), (0, 0, -0.05), 0.16, verts=8)
    box("Dark", (0, 0.1, 0.3), (0.34, 0.5, 0.25), bevel=0.06)
    ring("Dark", (0, 0.55, -0.8), (1, 0, 0), 0.38, 0.08, seg=10, minor_seg=5)
    box("Dark", (0, 0.05, -1.3), (0.9, 0.5, 0.2), bevel=0.06)
    for side in (-1, 1):  # cooling slots
        vents(side * 0.38, 0.28, -0.55, 0.7, rows=2, gap=0.12)
    with rig("Buzz"):  # the toothed bar shakes while cutting
        box("Metal", (0, 0.0, -2.4), (0.36, 0.08, 2.2), bevel=0.02)
        for i in range(10):
            for side in (-1, 1):
                prism("Metal", [(0, 0), (0.18, 0), (0.09, 0.22)], (side * 0.18, 0, -1.45 - i * 0.2), (0, 0, -1), (side, 0, 0), 0.05, bevel=0.0)
    box("Battery.Battery", (0, -0.4, -0.35), (0.55, 0.35, 0.7), bevel=0.06)
    with rig("Buzz"):
        box("Accent.Saw", (0, 0.0, -2.4), (0.5, 0.12, 2.3), bevel=0.04)
        for i in range(12):
            box("Chrome.Saw", (0, 0, -1.3 - i * 0.2), (0.62, 0.06, 0.1), bevel=0.0)


@model(hand=True)
def string_trimmer():
    cyl("HandleGrip", (0, 0, 0.5), (0, 0, -0.1), 0.15, verts=8)
    box("Accent", (0, 0.05, 0.9), (0.55, 0.65, 0.9), bevel=0.18)
    box("Accent2", (0, 0.42, 0.9), (0.3, 0.12, 0.6), bevel=0.04)
    for side in (-1, 1):
        vents(side * 0.28, 0.0, 0.95, 0.5, rows=2, gap=0.14)
    cyl("Metal", (0, 0, 0.45), (0, -0.55, -3.6), 0.08, verts=8)
    # assist handle, clamped on the shaft
    cyl("Dark", (0, -0.2, -0.9), (0, 0.45, -0.95), 0.06, verts=6)
    cyl("Dark", (-0.32, 0.45, -0.95), (0.32, 0.45, -0.95), 0.08, verts=8)
    # head + guard + spool + strings
    box("Dark", (0, -0.6, -3.75), (0.35, 0.35, 0.45), bevel=0.08)
    cyl("Accent", (0, -0.7, -3.5), (0, -0.78, -3.5), 0.55, verts=14, bevel=0.02)
    with rig("Head"):  # spool and strings whirl while cutting
        cyl("Dark", (0, -0.72, -3.75), (0, -1.0, -3.75), 0.2, verts=10)
        for a in (0, 90, 180, 270):
            r = math.radians(a)
            cyl("Accent2", (math.cos(r) * 0.05, -0.95, -3.75 + math.sin(r) * 0.05), (math.cos(r) * 0.6, -0.95, -3.75 + math.sin(r) * 0.6), 0.025, verts=4, bevel=0)
    # Volt Whacker: lightning fins
    bolt = [(0, 0), (0.3, 0), (0.12, 0.25), (0.35, 0.25), (-0.05, 0.75), (0.08, 0.38), (-0.15, 0.38)]
    for side in (-1, 1):
        prism("Light.Bolt", bolt, (side * 0.3, 0.1, 0.9), (0, 0, -1), (0, 1, 0), 0.06)


# -------------------------------------------------------------- push mowers


@model
def reel():
    z = -3.0
    # the reel turns between the wheels, so they only get stub axles
    wheels(1.25, 0.8, z, 1.6, 0.32, inner=0.95, hub="Accent", spokes=5)
    for side in (-1, 1):
        box("Accent", (side * 1.0, 0.7, z + 0.15), (0.12, 1.0, 1.7), bevel=0.05)
    box("Accent", (0, 1.14, z + 0.1), (2.0, 0.12, 1.0), bevel=0.04)  # cover over the reel
    with rig("Reel"):  # the spiral blades roll with the wheels
        cyl("Dark", (-0.95, 0.6, z), (0.95, 0.6, z), 0.08, verts=8)
        for x in (-0.9, 0.0, 0.9):  # discs carrying the blades
            cyl("Metal", (x - 0.03, 0.6, z), (x + 0.03, 0.6, z), 0.41, verts=10, bevel=0)
        for i in range(5):
            a = math.radians(i * 72)
            for k in range(4):
                a2 = a + k * 0.18
                x0 = -0.9 + k * 0.45
                cyl("Metal", (x0, 0.6 + math.sin(a2) * 0.38, z + math.cos(a2) * 0.38), (x0 + 0.45, 0.6 + math.sin(a2 + 0.18) * 0.38, z + math.cos(a2 + 0.18) * 0.38), 0.05, verts=5, bevel=0)
    cyl("Dark", (-1.0, 0.2, z + 0.9), (1.0, 0.2, z + 0.9), 0.18, verts=10)  # rear roller
    box("Metal", (0, 0.25, z - 0.38), (1.95, 0.06, 0.4), bevel=0.02)  # bed knife
    # Turbo: twin chrome exhausts + a scoop
    for x in (-0.55, 0.55):
        cyl("Chrome.Turbo", (x, 1.15, z + 0.4), (x, 1.42, z + 1.1), 0.13, verts=10)
    wedge("Accent2.Turbo", (0, 1.4, z - 0.1), (1.5, 0.45, 0.9))
    # Electric: battery box on top
    box("Battery.Battery", (0, 1.38, z + 0.1), (1.1, 0.4, 0.6), bevel=0.08)
    box("Light.Battery", (0, 1.6, z + 0.1), (0.5, 0.06, 0.25), bevel=0.02)


@model
def push():
    z = -4.0  # deck well ahead of the player: the handle slants back to the hands
    # dome deck
    ball("Accent", (0, 0.95, z), (3.1, 1.0, 3.2), seg=14, rings=6)
    box("Accent", (0, 0.65, z), (3.0, 0.45, 3.1), bevel=0.2)
    box("Dark", (0, 0.4, z), (3.15, 0.18, 3.2), bevel=0.06)
    box("Chrome", (0, 0.6, z - 1.7), (2.6, 0.3, 0.25), bevel=0.1)
    for dz in (-1.15, 1.15):  # wheels outside the deck, axles through it
        wheels(1.84, 0.5, z + dz, 1.0, 0.38, hub="Accent2")
    # engine
    cyl("Dark", (0, 1.35, z - 0.1), (0, 2.1, z - 0.1), 0.65, verts=12, bevel=0.1)
    for y in (1.6, 1.85):  # cooling fins
        cyl("Metal", (0, y, z - 0.1), (0, y + 0.06, z - 0.1), 0.71, verts=12, bevel=0)
    cyl("Accent2", (0, 2.1, z - 0.1), (0, 2.35, z - 0.1), 0.5, verts=12, bevel=0.06)
    cyl("Chrome", (0.35, 2.3, z - 0.5), (0.35, 2.5, z - 0.5), 0.14, verts=8)
    box("Metal", (-0.55, 1.75, z + 0.35), (0.35, 0.5, 0.4), bevel=0.06)
    cyl("Chrome", (0.6, 1.7, z + 0.2), (0.6, 1.7, z + 0.8), 0.1, verts=8)  # exhaust
    cyl("Dark", (-0.55, 1.9, z - 0.3), (-0.95, 1.9, z - 0.3), 0.06, verts=6)  # pull cord
    box("Dark", (-1.0, 1.9, z - 0.3), (0.1, 0.12, 0.34), bevel=0.03)
    # grass bag
    box("Fabric.Bag", (0, 1.3, z + 1.95), (1.45, 1.2, 1.0), bevel=0.25)
    box("Dark.Bag", (0, 1.0, z + 1.5), (1.5, 0.4, 0.2), bevel=0.04)
    # Deluxe: headlight pods, racing stripe, chrome spoiler over the bag
    for x in (-0.95, 0.95):
        box("Accent2.Deluxe", (x, 0.98, z - 1.25), (0.5, 0.36, 0.5), bevel=0.1)
        cyl("Light.Deluxe", (x, 0.98, z - 1.45), (x, 0.98, z - 1.56), 0.17, verts=10)
    box("Accent2.Deluxe", (0, 1.43, z), (0.5, 0.06, 3.1), bevel=0.02)
    box("Chrome.Deluxe", (0, 2.1, z + 1.3), (2.4, 0.08, 0.5), bevel=0.03)
    for x in (-1.1, 1.1):
        box("Chrome.Deluxe", (x, 1.45, z + 1.3), (0.1, 1.3, 0.12), bevel=0.02)


# ------------------------------------------------------------------- riders


@model
def rider():
    # Classic lawn tractor: hood in front, the driver sits over the rear
    # axle (Config/ToolArt Seat) with the feet on the plate.
    box("Dark", (0, 0.95, -0.9), (2.6, 0.5, 5.4), bevel=0.12)
    box("Accent", (0, 1.2, 1.2), (2.7, 0.3, 1.4), bevel=0.12)  # rear deck
    box("Tread", (0, 1.23, -0.75), (2.2, 0.08, 1.3), bevel=0.02)  # foot plate
    for side in (-1, 1):
        fender(side * 1.8, 0.85, 1.25, 1.0, 0.96)
    # hood
    box("Accent", (0, 1.8, -2.55), (2.4, 1.25, 2.2), bevel=0.35)
    wedge("Accent", (0, 2.26, -2.05), (2.3, 0.45, 1.1), rot=[("y", 180)])
    box("Dark", (0, 1.8, -3.68), (1.7, 0.85, 0.1), bevel=0.03)
    for i in range(4):
        box("Chrome", (0, 1.5 + i * 0.2, -3.73), (1.6, 0.06, 0.05), bevel=0)
    for x in (-0.85, 0.85):
        cyl("Light", (x, 2.12, -3.6), (x, 2.12, -3.78), 0.2, verts=10)
    box("Accent2", (0, 2.43, -2.55), (0.4, 0.05, 2.0), bevel=0.02)
    for side in (-1, 1):
        vents(side * 1.2, 1.6, -2.6, 1.2)
    box("Dark", (0, 2.2, -1.5), (1.6, 0.6, 0.25), bevel=0.06, rot=[("x", 18)])  # dashboard
    seat(0, 2.4, 0.6, width=1.6, floor=1.35)
    steering((0, 1.9, -1.6), (0, 3.2, -1.05), 0.55)
    cyl("Dark", (1.0, 1.1, 0.25), (1.12, 2.25, 0.05), 0.05, verts=6)  # gear lever
    ball("Accent2", (1.12, 2.3, 0.04), (0.24, 0.24, 0.24), seg=8, rings=5)
    # mow deck under the chassis, blade spindles on top, chute on the right
    box("Accent", (0, 0.52, -0.9), (4.2, 0.42, 2.2), bevel=0.14)
    box("Dark", (0, 0.3, -0.9), (4.26, 0.14, 2.26), bevel=0.04)
    for x in (-1.7, 1.7):
        cyl("Dark", (x, 0.7, -0.9), (x, 0.84, -0.9), 0.36, verts=10, bevel=0.03)
    box("Dark", (2.25, 0.48, -0.9), (0.5, 0.3, 1.0), bevel=0.06, rot=[("z", -14)])
    wheels(1.65, 0.55, -2.8, 1.1, 0.5, mount=0.7, hub="Accent2")
    wheels(1.8, 0.85, 1.25, 1.7, 0.75, hub="Accent2", tread=True)
    # exhaust, rear bumper and lights
    cyl("Chrome", (1.0, 2.0, -1.9), (1.0, 2.8, -1.9), 0.12, verts=8)
    box("Chrome", (0, 0.95, 1.85), (2.4, 0.3, 0.15), bevel=0.05)
    for x in (-1.0, 1.0):
        box("Tail", (x, 1.2, 1.9), (0.4, 0.18, 0.08), bevel=0.02)


@model
def zeroturn():
    # Zero-turn: low and wide, big rear tyres, two lap bars, wide front deck.
    box("Dark", (0, 0.9, -0.2), (2.4, 0.5, 4.0), bevel=0.12)
    box("Accent", (0, 1.4, 1.08), (2.8, 0.9, 2.0), bevel=0.25)  # engine cover, the seat sits on it
    box("Accent2", (0, 1.88, 1.6), (1.8, 0.08, 0.9), bevel=0.03)
    box("Dark", (0, 2.2, 1.65), (1.4, 0.6, 0.7), bevel=0.1)  # engine
    cyl("Chrome", (-0.85, 2.3, 2.02), (0.85, 2.3, 2.02), 0.15, verts=8)  # muffler
    for side in (-1, 1):
        vents(side * 1.4, 1.2, 1.1, 1.2)
    seat(0, 2.15, 0.4, back=1.45)
    box("Tread", (0, 1.17, -1.2), (2.0, 0.08, 1.6), bevel=0.02)
    for side in (-1, 1):  # lap bars: up beside the legs, then in over the thighs
        cyl("Dark", (side * 1.1, 1.0, -0.35), (side * 1.1, 3.35, -0.9), 0.07, verts=6)
        cyl("SteeringWheel", (side * 1.16, 3.35, -0.9), (side * 0.3, 3.35, -0.9), 0.1, verts=8)
    # wide deck, front casters
    box("Accent", (0, 0.55, -2.6), (5.0, 0.45, 2.0), bevel=0.18)
    box("Dark", (0, 0.32, -2.6), (5.05, 0.12, 2.05), bevel=0.03)
    for x in (-1.6, 1.6):
        cyl("Dark", (x, 0.74, -2.6), (x, 0.88, -2.6), 0.5, verts=10, bevel=0.03)
    box("Dark", (2.72, 0.5, -2.6), (0.6, 0.3, 1.0), bevel=0.06, rot=[("z", -14)])
    for x in (-1.6, 1.6):
        caster(x, -4.1, 0.8, 0.92)
        cyl("Dark", (x, 0.72, -3.4), (x, 0.92, -4.0), 0.08, verts=6)
    wheels(1.95, 1.0, 1.0, 2.0, 0.95, hub="Accent2", tread=True)
    # roll bar (pro)
    for x in (-1.3, 1.3):
        cyl("Dark.Rops", (x, 1.6, 1.9), (x, 5.9, 1.9), 0.1, verts=8)
    cyl("Dark.Rops", (-1.3, 5.9, 1.9), (1.3, 5.9, 1.9), 0.1, verts=8)
    for x in (-0.9, 0.9):
        cyl("Light.Rops", (x, 5.9, 1.86), (x, 5.9, 1.66), 0.15, verts=8)


@model
def tractor():
    # Farm tractor: long hood, big treaded rear wheels under arched
    # fenders, exhaust stack, front mow deck on lift arms.
    box("Dark", (0, 1.65, -1.6), (2.2, 0.8, 6.0), bevel=0.12)
    box("Dark", (0, 1.6, -4.72), (1.6, 0.6, 0.3), bevel=0.06)  # nose weight
    box("Accent", (0, 2.65, -3.1), (2.5, 1.55, 3.2), bevel=0.4)
    wedge("Accent", (0, 3.3, -2.0), (2.4, 0.5, 1.0), rot=[("y", 180)])
    box("Dark", (0, 2.55, -4.72), (1.9, 1.1, 0.1), bevel=0.02)
    for i in range(5):
        box("Chrome", (0, 2.1 + i * 0.22, -4.78), (1.8, 0.07, 0.05), bevel=0)
    for x in (-0.95, 0.95):
        cyl("Light", (x, 3.05, -4.66), (x, 3.05, -4.84), 0.22, verts=10)
    box("Accent2", (0, 3.45, -3.1), (0.45, 0.05, 3.0), bevel=0.02)
    for side in (-1, 1):
        vents(side * 1.25, 2.4, -3.1, 1.8)
    # platform between the fenders, seat, dashboard
    box("Dark", (0, 1.95, 0.4), (2.9, 0.25, 2.6), bevel=0.05)
    box("Tread", (0, 2.09, -0.3), (2.2, 0.06, 1.1), bevel=0.02)
    for side in (-1, 1):
        fender(side * 2.05, 1.6, 1.0, 1.9, 1.1, wall=True)
        box("Tail", (side * 1.45, 2.3, 2.9), (0.14, 0.3, 0.1), bevel=0.02)
    seat(0, 3.075, 0.6, floor=2.075)
    box("Dark", (0, 3.0, -1.52), (1.8, 0.9, 0.3), bevel=0.08)
    steering((0, 2.0, -1.45), (0, 4.0, -0.95), 0.6)
    box("Dark", (0, 1.5, 1.55), (0.5, 0.3, 0.6), bevel=0.05)  # hitch
    # exhaust stack
    cyl("Chrome", (0.8, 3.3, -2.3), (0.8, 5.2, -2.3), 0.16, verts=10)
    cyl("Dark", (0.8, 5.2, -2.3), (0.8, 5.35, -2.3), 0.2, verts=10)
    wheels(1.75, 0.85, -3.7, 1.7, 0.65, mount=1.25, hub="Accent2", tread=True)
    wheels(2.05, 1.6, 1.0, 3.2, 1.0, hub="Accent2", tread=True)
    # front mow deck, hung from two lift arms, on its own casters
    box("Accent", (0, 0.52, -6.4), (6.0, 0.4, 2.0), bevel=0.15)
    box("Dark", (0, 0.3, -6.4), (6.05, 0.14, 2.05), bevel=0.04)
    box("Accent2", (0, 0.55, -7.42), (5.4, 0.2, 0.08), bevel=0.02)
    for x in (-1.8, 0, 1.8):
        cyl("Dark", (x, 0.7, -6.4), (x, 0.84, -6.4), 0.55, verts=10, bevel=0.03)
    for x in (-0.7, 0.7):
        cyl("Dark", (x, 1.5, -4.5), (x, 0.6, -5.7), 0.1, verts=6)
    for x in (-2.6, 2.6):
        caster(x, -7.85, 0.6, 0.76)
        cyl("Dark", (x, 0.66, -7.2), (x, 0.76, -7.75), 0.07, verts=6)
    # canopy (bigger tractors)
    for x in (-1.3, 1.3):
        for z in (-0.7, 1.5):
            cyl("Dark.Canopy", (x, 2.0, z), (x, 7.0, z), 0.09, verts=6)
    box("Accent2.Canopy", (0, 7.1, 0.4), (3.2, 0.2, 3.0), bevel=0.08)
    # Longhorn: bull horns on the hood
    for side in (-1, 1):
        cyl("Teeth.Horns", (side * 0.9, 3.4, -4.1), (side * 1.7, 3.6, -4.2), 0.18, verts=8, r2=0.1)
        cyl("Teeth.Horns", (side * 1.7, 3.6, -4.2), (side * 2.0, 4.1, -4.25), 0.1, verts=8, r2=0.03)
    # Royal: a golden crown on the hood
    cyl("Gold.Crown", (0, 3.4, -3.6), (0, 3.75, -3.6), 0.45, verts=10, bevel=0.03)
    for i in range(5):
        a = math.radians(i * 72)
        cyl("Gold.Crown", (math.cos(a) * 0.38, 3.7, -3.6 + math.sin(a) * 0.38), (math.cos(a) * 0.42, 4.15, -3.6 + math.sin(a) * 0.42), 0.1, verts=6, r2=0.02)
        ball("Light.Crown", (math.cos(a) * 0.42, 4.14, -3.6 + math.sin(a) * 0.42), (0.14, 0.14, 0.14), seg=6, rings=4)


@model
def combine():
    # Combine harvester: big grain tank body, a cab the driver sits in
    # (solid below, glass above), drive wheels in front beside the cab, a
    # wide header with a turning reel and an unloading auger on the side.
    box("Accent", (0, 4.0, 3.1), (3.4, 4.2, 4.6), bevel=0.4)
    box("Accent2", (0, 6.12, 3.1), (2.9, 0.16, 3.9), bevel=0.04)  # tank lid
    for side in (-1, 1):
        box("Accent2", (side * 1.7, 3.1, 3.1), (0.06, 0.3, 3.8), bevel=0)
        vents(side * 1.7, 4.4, 4.0, 1.6, rows=4)
        box("Tail", (side * 1.2, 2.8, 5.4), (0.4, 0.25, 0.08), bevel=0.02)
    box("Dark", (0, 1.9, 0.6), (3.0, 0.5, 6.8), bevel=0.1)  # chassis under the cab and the tank
    box("Tread", (0, 2.17, -1.6), (2.4, 0.06, 2.0), bevel=0.02)
    seat(0, 3.2, -0.2, floor=2.15)
    # cab
    for x in (-1.35, 1.35):
        for z in (-2.7, 0.7):
            cyl("Dark", (x, 2.1, z), (x, 7.1, z), 0.09, verts=6)
        box("Accent", (x, 2.9, -1.0), (0.12, 1.5, 3.4), bevel=0.03)
        box("Glass", (x, 5.3, -1.0), (0.06, 3.3, 3.4), bevel=0)
    box("Accent", (0, 2.9, -2.7), (2.7, 1.5, 0.12), bevel=0.03)
    box("Glass", (0, 5.3, -2.7), (2.7, 3.3, 0.06), bevel=0)
    box("Accent", (0, 7.2, -1.0), (3.1, 0.3, 3.9), bevel=0.1)
    for x in (-1.0, -0.35, 0.35, 1.0):
        cyl("Light", (x, 7.2, -2.9), (x, 7.2, -3.05), 0.13, verts=8)
    box("Dark", (0, 3.35, -2.5), (1.6, 0.5, 0.3), bevel=0.06)  # dashboard
    steering((0, 2.1, -2.2), (0, 4.1, -1.75), 0.5)
    for z in (-2.45, -1.75):  # ladder up to the cab, on the left
        cyl("Dark", (-1.55, 0.6, z), (-1.55, 2.2, z), 0.05, verts=6, bevel=0)
    for y in (0.9, 1.3, 1.7):
        box("Dark", (-1.55, y, -2.1), (0.12, 0.06, 0.7), bevel=0)
    # header: floor + back wall, cutter teeth, feed auger, reel in front
    box("Dark", (0, 0.4, -4.2), (7.5, 0.3, 1.6), bevel=0.06)
    box("Dark", (0, 1.1, -3.35), (7.5, 1.5, 0.3), bevel=0.08)
    for side in (-1, 1):
        box("Accent", (side * 3.8, 1.2, -4.1), (0.25, 1.7, 2.0), bevel=0.08)
    for i in range(14):
        box("Chrome", (-3.4 + i * 0.52, 0.4, -5.15), (0.12, 0.12, 0.5), bevel=0.0)
    cyl("Accent2", (-3.7, 0.9, -3.7), (3.7, 0.9, -3.7), 0.24, verts=8)
    for i in range(11):
        x = -3.3 + i * 0.66
        cyl("Accent2", (x - 0.03, 0.9, -3.7), (x + 0.03, 0.9, -3.7), 0.36, verts=8, bevel=0)
    with rig("Drum"):  # the header reel turns all the time
        cyl("Accent2", (-3.7, 1.75, -4.55), (3.7, 1.75, -4.55), 0.1, verts=8)
        for i in range(6):
            a = math.radians(i * 60)
            y, z = 1.75 + math.sin(a) * 0.72, -4.55 + math.cos(a) * 0.72
            cyl("Accent2", (-3.6, y, z), (3.6, y, z), 0.07, verts=6, bevel=0)
            for x in (-3.0, 0.0, 3.0):
                cyl("Accent2", (x, 1.75, -4.55), (x, y, z), 0.05, verts=5, bevel=0)
    box("Dark", (0, 1.45, -3.0), (1.6, 1.1, 1.0), bevel=0.1)  # feeder house
    # unloading auger and exhaust
    cyl("Accent", (-1.5, 5.2, 4.0), (-4.6, 6.2, 3.6), 0.28, verts=10)
    cyl("Accent", (-4.6, 6.2, 3.6), (-4.9, 5.5, 3.6), 0.28, verts=10)
    cyl("Chrome", (1.2, 6.0, 4.6), (1.2, 7.2, 4.6), 0.18, verts=8)
    wheels(2.35, 1.55, 0.1, 3.1, 1.0, hub="Accent2", tread=True)
    wheels(1.6, 0.85, 4.4, 1.7, 0.6, mount=1.9, hub="Accent2", tread=True)


@model
def drone():
    # Hover mower: the player stands on a round pad, four rotor arms with
    # propellers, spinning blades under the pad, skids on the ground.
    cyl("Accent", (0, 1.7, -0.4), (0, 2.2, -0.4), 2.0, verts=16, bevel=0.15)
    cyl("Tread", (0, 2.2, -0.4), (0, 2.28, -0.4), 1.6, verts=16, bevel=0.02)
    cyl("Accent2", (0, 1.45, -0.4), (0, 1.7, -0.4), 1.3, verts=16, bevel=0.06)
    for i in range(4):
        a = math.radians(45 + i * 90)
        ex, ez = math.cos(a) * 3.0, -0.4 + math.sin(a) * 3.0
        cyl("Dark", (math.cos(a) * 1.6, 1.95, -0.4 + math.sin(a) * 1.6), (ex, 2.1, ez), 0.14, verts=8)
        cyl("Accent", (ex, 1.9, ez), (ex, 2.5, ez), 0.35, verts=10, bevel=0.06)
        cyl("Light", (ex, 1.75, ez), (ex, 1.9, ez), 0.18, verts=8)
        with rig(f"Rotor{i + 1}"):
            for k in (0, 1):
                b = a + math.radians(90 * k + 20)
                box("Metal", (ex, 2.6, ez), (1.9, 0.05, 0.22), bevel=0.0, rot=[("y", -math.degrees(b))])
            cyl("Chrome", (ex, 2.5, ez), (ex, 2.68, ez), 0.1, verts=6)
    # blades below, short enough to miss the skid legs
    with rig("Rotor0"):
        for k in range(3):
            box("Metal", (0, 0.9, -0.4), (2.2, 0.06, 0.3), bevel=0.0, rot=[("y", k * 60)])
    cyl("Dark", (0, 0.85, -0.4), (0, 1.45, -0.4), 0.2, verts=8)
    # skids
    for x in (-1.2, 1.2):
        cyl("Dark", (x, 0.15, -2.0), (x, 0.15, 1.2), 0.1, verts=6)
        cyl("Dark", (x, 0.15, -1.2), (x * 0.8, 1.5, -1.0), 0.07, verts=6)
        cyl("Dark", (x, 0.15, 0.4), (x * 0.8, 1.5, 0.2), 0.07, verts=6)
    handrail(2.28)


@model
def mowzilla():
    # A monster mower: tank treads, a big toothy grin, googly eyes, ram
    # horns, back spikes and flame exhausts. The player stands on top.
    box("Accent", (0, 2.6, -1.0), (5.0, 2.6, 7.4), bevel=0.6)
    box("Tread", (0, 3.9, 0.1), (2.4, 0.1, 2.2), bevel=0.02)  # where the player stands (RideLift 3.9)
    for x in (-2.8, 2.8):
        track(x, 1.05, -1.0, 7.6, 2.1, 0.9, 5)
    for side in (-1, 1):  # armour plates along the flanks
        for i in range(4):
            box("Accent2", (side * 2.5, 3.2, -3.0 + i * 1.4), (0.08, 0.7, 0.9), bevel=0.03, rot=[("x", 12)])
    # mouth + teeth
    box("Dark", (0, 1.65, -4.68), (4.0, 1.1, 0.2), bevel=0.1)
    # teeth: top and bottom rows chomp while it drives (ToolAnimations)
    with rig("JawTop"):
        for i in range(9):
            x = -1.8 + i * 0.45
            cyl("Teeth", (x, 2.2, -4.75), (x, 1.6, -4.85), 0.2, verts=4, r2=0.02)
    with rig("JawBottom"):
        for i in range(9):
            x = -1.8 + i * 0.45
            cyl("Teeth", (x + 0.22, 1.1, -4.75), (x + 0.22, 1.6, -4.85), 0.17, verts=4, r2=0.02)
    for x in (-0.5, 0.5):  # nostrils
        cyl("Dark", (x, 2.9, -4.62), (x, 2.9, -4.74), 0.16, verts=6)
    # eyes
    for x in (-1.2, 1.2):
        ball("Eye", (x, 4.0, -4.2), (1.6, 1.6, 1.1), seg=12, rings=8)
        ball("Dark", (x * 0.92, 3.9, -4.75), (0.7, 0.7, 0.25), seg=10, rings=6)
        box("Accent2", (x, 4.7, -4.3), (1.3, 0.25, 0.5), bevel=0.08, rot=[("z", -12 if x < 0 else 12)])
    # spikes down the back
    for i in range(5):
        z = 0.9 + i * 0.42
        cyl("Accent2", (0, 3.8, z), (0, 4.9 - i * 0.12, z + 0.3), 0.35, verts=5, r2=0.03)
    # exhausts with flames, rooted in the back deck
    for x in (-1.2, 1.2):
        cyl("Chrome", (x, 3.3, 1.8), (x, 5.2, 2.1), 0.25, verts=10)
        cyl("Light", (x, 5.2, 2.1), (x, 6.0, 2.3), 0.22, verts=8, r2=0.04)
    for side in (-1, 1):  # ram horns: out of the head's sides, curling down
        cyl("Teeth", (side * 2.2, 3.6, -3.4), (side * 3.0, 4.1, -3.3), 0.4, verts=8, r2=0.32)
        cyl("Teeth", (side * 3.0, 4.1, -3.3), (side * 3.5, 3.4, -3.6), 0.32, verts=8, r2=0.22)
        cyl("Teeth", (side * 3.5, 3.4, -3.6), (side * 3.3, 2.6, -4.1), 0.22, verts=8, r2=0.03)
    # front cutter drum, held by two arms outside its spikes
    for x in (-2.75, 2.75):
        cyl("Dark", (x, 0.75, -5.7), (x, 1.5, -4.6), 0.16, verts=6)
    with rig("Drum"):  # the cutter drum spins all the time
        cyl("Metal", (-2.5, 0.75, -5.7), (2.5, 0.75, -5.7), 0.5, verts=12)
        cyl("Dark", (-2.85, 0.75, -5.7), (2.85, 0.75, -5.7), 0.14, verts=8, bevel=0)
        for i in range(10):  # cone spikes all round the drum
            for k in (0, 1):
                a = math.radians(i * 36 + k * 180)
                x = -2.2 + i * 0.49
                base = (x, 0.75 + math.sin(a) * 0.45, -5.7 + math.cos(a) * 0.45)
                tip = (x, 0.75 + math.sin(a) * 0.9, -5.7 + math.cos(a) * 0.9)
                cyl("Chrome", base, tip, 0.14, verts=8, r2=0.01)
    handrail(3.95, width=0.7)


# ------------------------------------------------- the special late tools


@model
def mega_push():
    # Comically giant push mower: the classic mower blown up 2.6x, the
    # player rides a little wheeled platform hitched behind it.
    with xform(2.6, (0, 0, 2.7)):  # the grass bag ends right in front of the platform
        push()
    box("Dark", (0, 2.05, -0.15), (2.6, 0.3, 2.9), bevel=0.08)
    box("Tread", (0, 2.2, -0.15), (2.4, 0.06, 2.7), bevel=0.02)  # RideLift 2.2
    for x in (-1.0, 1.0):  # hitch bars into the mower's deck
        cyl("Dark", (x, 1.95, -0.9), (x, 1.6, -3.9), 0.12, verts=8)
    box("Dark", (0, 1.4, 0.1), (2.2, 1.1, 0.8), bevel=0.06)
    wheels(1.55, 0.9, 0.1, 1.8, 0.45, hub="Accent2")
    steering((0, 2.1, -1.45), (0, 4.6, -1.1), 0.4)


@model
def fortress():
    # Field Fortress: a combine turned into a little castle on wheels.
    combine()
    for x in (-1.7, 1.7):
        for z in (1.0, 5.2):  # towers on the tank's corners, above the wheels
            cyl("Stone", (x, 3.5, z), (x, 7.4, z), 0.7, verts=10, bevel=0.05)
            cyl("Accent", (x, 7.4, z), (x, 9.0, z), 0.85, verts=10, r2=0.05)
            cyl("Dark", (x, 8.8, z), (x, 9.8, z), 0.04, verts=4, bevel=0)
            prism("Accent2", [(0, 0), (0.8, -0.2), (0, -0.45)], (x, 9.8, z), (1, 0, 0), (0, 1, 0), 0.04, bevel=0)
    for i in range(5):  # battlements between the towers
        for z in (1.0, 5.2):
            box("Stone", (-1.0 + i * 0.5, 6.4, z), (0.3, 0.5, 0.35), bevel=0.04)
    box("Wood", (0, 3.3, 5.42), (1.6, 2.4, 0.12), bevel=0.04)  # castle gate on the back
    for y in (2.6, 4.0):
        box("Dark", (0, y, 5.5), (1.7, 0.12, 0.06), bevel=0)


@model
def swarm():
    # Drone Swarm: the hover pad plus three mini drones that circle it.
    drone()
    with rig("Orbit"):
        for i in range(3):
            a = math.radians(i * 120 + 30)
            with xform(0.32, (math.cos(a) * 4.6, 3.6, -0.4 + math.sin(a) * 4.6)):
                drone()


@model
def void():
    # VOID: an obsidian platform floating over a swirling portal that eats
    # the grass, purple crystals and shards orbiting around.
    cyl("Accent", (0, 1.7, -0.6), (0, 2.2, -0.6), 2.4, verts=8, bevel=0.15)  # platform (RideLift 2.2)
    cyl("Glow", (0, 1.62, -0.6), (0, 1.7, -0.6), 2.2, verts=8, bevel=0.02)
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        cyl("Crystal", (math.cos(a) * 2.0, 1.7, -0.6 + math.sin(a) * 2.0), (math.cos(a) * 2.6, 0.5, -0.6 + math.sin(a) * 2.6), 0.28, verts=5, r2=0.03)
    with rig("Portal"):  # spins around its own centre (a ring lying flat)
        ring("Glow", (0, 0.35, -4.2), (0, 1, 0), 1.8, 0.22, seg=16, minor_seg=6)
        ring("Accent2", (0, 0.35, -4.2), (0, 1, 0), 1.25, 0.12, seg=14, minor_seg=5)
        for i in range(6):
            a = math.radians(i * 60)
            box("Crystal", (math.cos(a) * 1.5, 0.35, -4.2 + math.sin(a) * 1.5), (0.18, 0.18, 0.9), bevel=0.02, rot=[("y", -i * 60 + 30)])
    # the arm that casts the portal: out over its centre, a crystal aimed down
    cyl("Accent", (0, 1.9, -2.6), (0, 2.0, -4.2), 0.2, verts=6)
    cyl("Crystal", (0, 2.0, -4.2), (0, 0.9, -4.2), 0.3, verts=5, r2=0.03)
    for x in (-1.6, 1.6):
        cyl("Crystal", (x, 2.1, 0.8), (x * 1.1, 5.4, 1.0), 0.45, verts=5, r2=0.04)
        cyl("Crystal", (x * 0.6, 2.1, 1.3), (x * 0.7, 4.2, 1.5), 0.3, verts=5, r2=0.03)
    handrail(2.2)
    with rig("Orbit"):  # shards circle the player
        for i in range(5):
            a = math.radians(i * 72)
            ball("Crystal", (math.cos(a) * 3.4, 4.2 + (i % 2) * 0.8, -0.6 + math.sin(a) * 3.4), (0.45, 0.9, 0.45), seg=5, rings=3)


@model
def airship():
    # Sky Mower Carrier: a blimp with a gondola the player stands in and a
    # spinning blade disc hanging under it.
    box("Wood", (0, 2.05, -0.6), (2.6, 0.3, 3.4), bevel=0.08)  # gondola floor (RideLift 2.2)
    for x in (-1.3, 1.3):
        box("Accent", (x, 2.6, -0.6), (0.15, 0.9, 3.4), bevel=0.04)
        box("Accent2", (x, 3.08, -0.6), (0.22, 0.1, 3.5), bevel=0.03)  # rail cap
        for z in (-1.6, -0.6, 0.4):  # sandbags over the side
            ball("Fabric", (x * 1.12, 2.5, z), (0.4, 0.55, 0.4), seg=6, rings=4)
    box("Accent", (0, 2.6, -2.3), (2.6, 0.9, 0.15), bevel=0.04)
    box("Accent2", (0, 3.08, -2.3), (2.82, 0.1, 0.22), bevel=0.03)
    cyl("Light", (0, 2.7, -2.36), (0, 2.7, -2.5), 0.2, verts=8)  # prow lantern
    for x in (-1.26, 1.26):
        for z in (-2.2, 1.0):  # ropes up into the envelope
            cyl("Dark", (x, 2.2, z), (x * 0.6, 9.0, z * 0.8), 0.06, verts=5, bevel=0)
    ball("Accent2", (0, 10.2, -0.4), (4.6, 3.6, 9.0), seg=16, rings=10)
    for z in (-2.6, 0.2, 2.8):
        cyl("Accent", (0, 10.2, z - 0.15), (0, 10.2, z + 0.15), 2.0 if abs(z) < 1 else 1.6, verts=16, bevel=0.02)
    for rot in (0, 90):
        prism("Accent", [(0, 0), (1.6, 0.0), (1.9, 1.4), (0.6, 1.4)], (0, 10.2, 3.6), (0, 0, 1), (0, 1, 0) if rot == 0 else (1, 0, 0), 0.1)
        prism("Accent", [(0, 0), (1.6, 0.0), (1.9, -1.4), (0.6, -1.4)], (0, 10.2, 3.6), (0, 0, 1), (0, 1, 0) if rot == 0 else (1, 0, 0), 0.1)
    cyl("Dark", (0, 10.2, 5.0), (0, 10.2, 5.7), 0.1, verts=6)  # propeller shaft, behind the fins
    with rig("Prop"):  # tail propeller, spins around Z
        cyl("Chrome", (0, 10.2, 5.65), (0, 10.2, 5.95), 0.18, verts=8)
        for k in range(3):
            box("Metal", (0, 10.2, 5.8), (0.25, 1.6, 0.06), bevel=0, rot=[("z", k * 60)])
    cyl("Dark", (0, 2.0, -0.6), (0, 0.5, -0.6), 0.1, verts=6)
    with rig("Rotor0"):
        cyl("Metal", (0, 0.45, -0.6), (0, 0.55, -0.6), 1.8, verts=16, bevel=0.02)
        for k in range(6):
            box("Chrome", (0, 0.5, -0.6), (3.8, 0.05, 0.25), bevel=0, rot=[("y", k * 30)])
    steering((0, 2.1, -1.85), (0, 4.7, -1.5), 0.45)


@model
def drill():
    # Terra-Mower: an earth-drilling tank with a giant spinning drill nose,
    # rocks on its back and lava glowing through the cracks.
    box("Accent", (0, 2.0, -0.6), (4.0, 2.2, 5.6), bevel=0.45)
    box("Tread", (0, 3.1, 0.2), (2.4, 0.1, 2.2), bevel=0.02)  # top deck (RideLift 3.15)
    for x in (-2.35, 2.35):
        track(x, 0.9, -0.6, 6.2, 1.8, 0.9, 5, hub="Dark")
    for i, (x, z) in enumerate(((-1.25, 0.9), (1.25, 0.7), (0.85, 1.55), (-0.7, 1.65))):  # half sunk into the roof
        ball("Stone", (x, 3.05, z), (0.85 + i * 0.08, 0.7, 0.75), seg=6, rings=4)
    for x, z, ln in ((-2.0, -1.0, 1.4), (2.02, 0.4, 1.0), (-2.02, 1.4, 0.8)):
        box("Glow", (x, 2.3, z), (0.06, 0.12, ln), bevel=0, rot=[("x", 20)])
    cyl("Accent2", (0, 1.9, -3.2), (0, 1.9, -3.5), 1.55, verts=12, bevel=0.04)  # collar the drill turns in
    with rig("Drill"):  # spins around its own (Z) axis
        cyl("Metal", (0, 1.9, -3.5), (0, 1.9, -6.7), 1.4, verts=12, r2=0.06)
        for k in range(12):  # cone spikes spiralling round the drill
            t = k / 12
            a = math.radians(k * 75)
            z = -3.75 - t * 2.6
            r = (1.4 + (0.06 - 1.4) * (-3.5 - z) / 3.2) * 0.9  # just under the cone's surface
            base = (math.cos(a) * r, 1.9 + math.sin(a) * r, z)
            tip = (math.cos(a) * (r + 0.5), 1.9 + math.sin(a) * (r + 0.5), base[2] - 0.35)
            cyl("Chrome", base, tip, 0.2 - t * 0.08, verts=8, r2=0.01)
    for x in (-1.3, 1.3):  # headlight pods on the roof's front edge
        box("Dark", (x, 3.15, -2.9), (0.5, 0.32, 0.5), bevel=0.08)
        cyl("Light", (x, 3.15, -3.1), (x, 3.15, -3.2), 0.18, verts=8)
    cyl("Chrome", (1.3, 2.8, 1.4), (1.3, 4.6, 1.6), 0.2, verts=8)
    handrail(3.15)
