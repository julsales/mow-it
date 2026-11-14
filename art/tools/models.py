# The 15 base models. Roblox coords, studs. Hand tools: grip at the
# origin, tool pointing -Z, top +Y. Ground tools: origin on the ground
# under the player, machine in front (-Z) or around them (riders).
# Push/reel mowers leave the handle out: the game builds it fitted to
# the avatar's arms (ToolModels handle()).

import math

from lib import arc_pts, ball, box, cyl, prism, ring, wedge, wheel

MODELS = {}


def model(fn):
    MODELS[fn.__name__] = fn
    return fn


# ---------------------------------------------------------------- hand tools


@model
def clipper():
    # Fat cartoon nail clipper: two jaws, a big lever with a coloured pad.
    box("Metal", (0, -0.16, -1.0), (0.62, 0.14, 2.1), bevel=0.05)
    box("Metal", (0, 0.02, -1.0), (0.62, 0.14, 2.1), bevel=0.05, rot=[("x", -5)])
    cyl("Chrome", (-0.33, -0.07, -2.05), (0.33, -0.07, -2.05), 0.2, verts=10)
    cyl("Dark", (-0.2, 0.25, -1.55), (0.2, 0.25, -1.55), 0.09, verts=8)
    box("Metal", (0, 0.42, -0.75), (0.56, 0.1, 1.75), bevel=0.04, rot=[("x", 8)])
    box("Accent", (0, 0.52, -0.55), (0.46, 0.08, 0.9), bevel=0.03, rot=[("x", 8)])
    ring("Accent", (0, -0.16, 0.35), (1, 0, 0), 0.24, 0.07, seg=10, minor_seg=5)


def _scissor_loop(side, color, big):
    r = 0.34 if big else 0.28
    ring(color, (side * 0.32, 0, 0.25), (0, 1, 0), r, 0.11, seg=10, minor_seg=6)


@model
def scissors_safety():
    # Chunky kid scissors: round plastic loops, short blunt blades.
    for side in (-1, 1):
        _scissor_loop(side, "Accent", True)
        box("Accent", (side * 0.14, 0, -0.25), (0.22, 0.18, 0.55), bevel=0.06, rot=[("y", side * 18)])
        pts = [(-0.11, 0), (0.11, 0), (0.1, 1.1), (0.0, 1.32), (-0.1, 1.1)]
        prism("Metal", pts, (side * 0.05, 0, -0.45), (side * 0.0 + 1, 0, 0), (side * 0.06, 0, -1), 0.06)
    ball("Chrome", (0, 0.06, -0.48), (0.16, 0.08, 0.16), seg=8, rings=4)


@model
def scissors_kitchen():
    for side in (-1, 1):
        ring("Accent", (side * 0.3, 0, 0.3), (0, 1, 0), 0.3 if side < 0 else 0.25, 0.1, seg=10, minor_seg=6)
        box("Accent", (side * 0.13, 0, -0.18), (0.2, 0.16, 0.5), bevel=0.05, rot=[("y", side * 15)])
        pts = [(-0.12, 0), (0.12, 0), (0.0, 1.9)]
        prism("Metal", pts, (side * 0.05, 0, -0.42), (1, 0, 0), (side * 0.07, 0, -1), 0.06)
    ball("Chrome", (0, 0.06, -0.45), (0.15, 0.08, 0.15), seg=8, rings=4)


@model
def shears():
    # Garden shears: long wooden handles, red grips, big curved blades.
    for side in (-1, 1):
        cyl("Wood", (side * 0.35, 0, 0.9), (side * 0.12, 0, -0.75), 0.12, verts=8)
        cyl("Accent", (side * 0.4, 0, 1.25), (side * 0.33, 0, 0.75), 0.15, verts=8)
        pts = [(-0.18, 0), (0.16, 0), (0.12, 0.9), (0.02, 1.7), (-0.08, 1.5), (-0.14, 0.8)]
        prism("Metal", pts, (side * 0.06, 0, -0.75), (1, 0, 0), (side * 0.1, 0, -1), 0.07)
    cyl("Chrome", (0, -0.12, -0.8), (0, 0.12, -0.8), 0.12, verts=8)
    box("Dark", (0, 0, -0.55), (0.32, 0.14, 0.28), bevel=0.04)


@model
def sickle():
    cyl("Wood", (0, 0, 0.55), (0, 0, -0.75), 0.15, verts=8)
    cyl("Accent", (0, 0, 0.6), (0, 0, 0.35), 0.17, verts=8)
    cyl("Chrome", (0, 0, -0.75), (0, 0, -0.95), 0.18, verts=8)
    # crescent: outer arc minus inner arc, in the YZ plane (u = -Z, v = +Y)
    cx, cy = 1.45, 0.95
    outer = arc_pts(cx, cy, 1.0, 200, 450, 14)
    inner = arc_pts(cx + 0.15, cy + 0.16, 0.78, 420, 215, 12)
    prism("Metal", outer + inner, (0, -0.05, 0), (0, 0, -1), (0, 1, 0), 0.07, bevel=0.015)


@model
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


@model
def hedge():
    # Hedge trimmer: grip at the origin, round body, D-handle, toothy bar.
    box("Accent", (0, 0.1, -0.55), (0.75, 0.75, 1.3), bevel=0.2)
    box("Accent2", (0, 0.1, -0.55), (0.8, 0.22, 1.2), bevel=0.05)
    cyl("HandleGrip", (0, 0, 0.45), (0, 0, -0.05), 0.16, verts=8)
    box("Dark", (0, 0.1, 0.3), (0.34, 0.5, 0.25), bevel=0.06)
    ring("Dark", (0, 0.55, -0.8), (1, 0, 0), 0.38, 0.08, seg=10, minor_seg=5)
    box("Dark", (0, 0.05, -1.3), (0.9, 0.5, 0.2), bevel=0.06)
    box("Metal", (0, 0.0, -2.4), (0.36, 0.08, 2.2), bevel=0.02)
    for i in range(10):
        for side in (-1, 1):
            prism("Metal", [(0, 0), (0.18, 0), (0.09, 0.22)], (side * 0.18, 0, -1.45 - i * 0.2), (0, 0, -1), (side, 0, 0), 0.05, bevel=0.0)
    box("Battery.Battery", (0, -0.4, -0.35), (0.55, 0.35, 0.7), bevel=0.06)
    box("Accent.Saw", (0, 0.0, -2.4), (0.5, 0.12, 2.3), bevel=0.04)
    for i in range(12):
        box("Chrome.Saw", (0, 0, -1.3 - i * 0.2), (0.62, 0.06, 0.1), bevel=0.0)


@model
def string_trimmer():
    cyl("HandleGrip", (0, 0, 0.4), (0, 0, -0.1), 0.15, verts=8)
    box("Accent", (0, 0.05, 0.9), (0.55, 0.65, 0.9), bevel=0.18)
    box("Accent2", (0, 0.42, 0.9), (0.3, 0.12, 0.6), bevel=0.04)
    cyl("Metal", (0, 0, 0.45), (0, -0.55, -3.6), 0.08, verts=8)
    # assist handle
    cyl("Dark", (0, 0, -0.9), (0, 0.45, -0.95), 0.06, verts=6)
    cyl("Dark", (-0.32, 0.45, -0.95), (0.32, 0.45, -0.95), 0.08, verts=8)
    # head + guard + spool + strings
    box("Dark", (0, -0.6, -3.75), (0.35, 0.35, 0.45), bevel=0.08)
    cyl("Accent", (0, -0.72, -3.55), (0, -0.78, -3.55), 0.55, verts=14, bevel=0.02)
    cyl("Dark", (0, -0.82, -3.85), (0, -1.0, -3.85), 0.2, verts=10)
    for a in (0, 120, 240):
        r = math.radians(a)
        cyl("Accent2", (0, -0.95, -3.85), (math.cos(r) * 0.6, -0.95, -3.85 + math.sin(r) * 0.6), 0.025, verts=4, bevel=0)
    # Volt Whacker: lightning fins
    prism("Light.Bolt", [(0, 0), (0.3, 0), (0.12, 0.25), (0.35, 0.25), (-0.05, 0.75), (0.08, 0.38), (-0.15, 0.38)], (0.3, 0.1, 0.9), (0, 0, -1), (0, 1, 0), 0.06)
    prism("Light.Bolt", [(0, 0), (0.3, 0), (0.12, 0.25), (0.35, 0.25), (-0.05, 0.75), (0.08, 0.38), (-0.15, 0.38)], (-0.3, 0.1, 0.9), (0, 0, -1), (0, 1, 0), 0.06)


# -------------------------------------------------------------- push mowers


@model
def reel():
    z = -3.0
    for x in (-1.25, 1.25):
        wheel((x, 0.8, z), 1.6, 0.32, hub="Accent", spokes=5)
    box("Accent", (-1.0, 0.75, z + 0.1), (0.12, 0.7, 1.5), bevel=0.05)
    box("Accent", (1.0, 0.75, z + 0.1), (0.12, 0.7, 1.5), bevel=0.05)
    cyl("Dark", (-1.0, 0.6, z), (1.0, 0.6, z), 0.08, verts=8)
    for i in range(5):
        a = math.radians(i * 72)
        for k in range(4):
            a2 = a + k * 0.18
            x0 = -0.9 + k * 0.45
            cyl("Metal", (x0, 0.6 + math.sin(a2) * 0.38, z + math.cos(a2) * 0.38), (x0 + 0.45, 0.6 + math.sin(a2 + 0.18) * 0.38, z + math.cos(a2 + 0.18) * 0.38), 0.05, verts=5, bevel=0)
    cyl("Dark", (-0.95, 0.2, z + 0.85), (0.95, 0.2, z + 0.85), 0.18, verts=10)
    box("Metal", (0, 0.25, z - 0.35), (1.9, 0.06, 0.5), bevel=0.02)
    # Turbo: twin chrome exhausts + a scoop
    for x in (-0.55, 0.55):
        cyl("Chrome.Turbo", (x, 1.0, z + 0.6), (x, 1.15, z + 1.2), 0.13, verts=10)
    wedge("Accent2.Turbo", (0, 1.15, z - 0.1), (1.5, 0.45, 0.9))
    # Electric: battery box on top
    box("Battery.Battery", (0, 1.2, z + 0.2), (1.1, 0.4, 0.6), bevel=0.08)
    box("Light.Battery", (0, 1.42, z + 0.2), (0.5, 0.06, 0.25), bevel=0.02)


@model
def push():
    z = -4.0  # deck well ahead of the player: the handle slants back to the hands
    # dome deck
    ball("Accent", (0, 0.95, z), (3.1, 1.0, 3.2), seg=14, rings=6)
    box("Accent", (0, 0.65, z), (3.0, 0.45, 3.1), bevel=0.2)
    box("Dark", (0, 0.4, z), (3.15, 0.18, 3.2), bevel=0.06)
    box("Chrome", (0, 0.6, z - 1.7), (2.6, 0.3, 0.25), bevel=0.1)
    for x in (-1.5, 1.5):
        for dz in (-1.15, 1.15):
            wheel((x, 0.5, z + dz), 1.0, 0.38, hub="Accent2")
    # engine
    cyl("Dark", (0, 1.35, z - 0.1), (0, 2.1, z - 0.1), 0.65, verts=12, bevel=0.1)
    cyl("Accent2", (0, 2.1, z - 0.1), (0, 2.35, z - 0.1), 0.5, verts=12, bevel=0.06)
    cyl("Chrome", (0.35, 2.3, z - 0.5), (0.35, 2.5, z - 0.5), 0.14, verts=8)
    box("Metal", (-0.55, 1.75, z + 0.35), (0.35, 0.5, 0.4), bevel=0.06)
    cyl("Chrome", (0.7, 1.7, z + 0.2), (0.7, 1.7, z + 0.75), 0.1, verts=8)
    # grass bag
    box("Fabric.Bag", (0, 1.3, z + 1.95), (1.45, 1.2, 1.0), bevel=0.25)
    box("Dark.Bag", (0, 1.0, z + 1.5), (1.5, 0.4, 0.2), bevel=0.04)
    # Deluxe: headlights, racing stripe, chrome spoiler
    for x in (-0.8, 0.8):
        cyl("Light.Deluxe", (x, 1.0, z - 1.55), (x, 1.0, z - 1.75), 0.2, verts=10)
    box("Accent2.Deluxe", (0, 1.43, z), (0.5, 0.06, 3.1), bevel=0.02)
    box("Chrome.Deluxe", (0, 1.9, z + 1.45), (2.4, 0.08, 0.5), bevel=0.03)
    for x in (-1.0, 1.0):
        box("Chrome.Deluxe", (x, 1.6, z + 1.4), (0.1, 0.55, 0.12), bevel=0.02)


# ------------------------------------------------------------------- riders


@model
def rider():
    # Classic lawn tractor. The player stands at the origin (RideLift 1.4):
    # foot deck under them, seat behind, wheel in front.
    box("Dark", (0, 0.95, -0.9), (2.6, 0.5, 5.4), bevel=0.12)
    box("Accent", (0, 1.25, 1.0), (3.0, 0.3, 1.8), bevel=0.12)  # rear fender deck
    box("Dark", (0, 1.25, -0.6), (2.2, 0.2, 1.6), bevel=0.05)  # foot plate
    # hood
    box("Accent", (0, 1.85, -2.55), (2.4, 1.2, 2.2), bevel=0.35)
    wedge("Accent", (0, 2.3, -2.05), (2.3, 0.45, 1.1), rot=[("y", 180)])
    box("Dark", (0, 1.85, -3.68), (1.7, 0.85, 0.1), bevel=0.03)
    for i in range(4):
        box("Chrome", (0, 1.55 + i * 0.2, -3.73), (1.6, 0.06, 0.05), bevel=0)
    for x in (-0.85, 0.85):
        cyl("Light", (x, 2.2, -3.62), (x, 2.2, -3.78), 0.2, verts=10)
    box("Accent2", (0, 2.47, -2.55), (0.4, 0.05, 2.0), bevel=0.02)
    # seat
    box("Seat", (0, 1.8, 1.3), (1.6, 0.35, 1.2), bevel=0.15)
    box("Seat", (0, 2.6, 1.85), (1.6, 1.3, 0.3), bevel=0.14, rot=[("x", -12)])
    # column + wheel
    cyl("Dark", (0, 1.9, -1.55), (0, 3.15, -1.05), 0.1, verts=8)
    ring("SteeringWheel", (0, 3.2, -1.02), (0, 0.9, 0.42), 0.55, 0.08, seg=14, minor_seg=6)
    cyl("SteeringWheel", (0, 3.2, -1.02), (0, 3.28, -0.98), 0.14, verts=8)
    # mow deck
    box("Dark", (0, 0.42, -0.9), (4.2, 0.35, 2.2), bevel=0.12)
    box("Accent2", (0, 0.62, -0.9), (4.25, 0.1, 2.25), bevel=0.03)
    wheel((-1.55, 0.55, -2.8), 1.1, 0.5, hub="Accent2")
    wheel((1.55, 0.55, -2.8), 1.1, 0.5, hub="Accent2")
    wheel((-1.75, 0.85, 1.25), 1.7, 0.75, hub="Accent2", tread=True)
    wheel((1.75, 0.85, 1.25), 1.7, 0.75, hub="Accent2", tread=True)
    # exhaust
    cyl("Chrome", (1.0, 2.0, -1.6), (1.0, 2.8, -1.6), 0.12, verts=8)


@model
def zeroturn():
    # Zero-turn: low and wide, big rear tyres, two lap bars, wide front deck.
    box("Dark", (0, 0.9, -0.2), (2.4, 0.5, 4.0), bevel=0.12)
    box("Accent", (0, 1.4, 1.3), (2.8, 0.9, 1.6), bevel=0.25)  # engine cover
    box("Accent2", (0, 1.88, 1.3), (1.8, 0.08, 1.2), bevel=0.03)
    box("Seat", (0, 2.0, 1.0), (1.5, 0.3, 1.0), bevel=0.12)
    box("Seat", (0, 2.7, 1.55), (1.5, 1.1, 0.28), bevel=0.12, rot=[("x", -10)])
    box("Dark", (0, 1.2, -1.2), (2.0, 0.15, 1.6), bevel=0.04)
    for x in (-0.7, 0.7):
        cyl("Dark", (x * 1.4, 1.4, -0.2), (x * 1.4, 2.7, -0.7), 0.07, verts=6)
        cyl("Dark", (x * 1.4, 2.7, -0.7), (x * 0.3, 2.7, -0.95), 0.07, verts=6)
    cyl("SteeringWheel", (-0.85, 2.7, -0.95), (0.85, 2.7, -0.95), 0.1, verts=8)
    # wide deck, front casters
    box("Accent", (0, 0.55, -2.6), (5.0, 0.45, 2.0), bevel=0.18)
    box("Dark", (0, 0.32, -2.6), (5.05, 0.12, 2.05), bevel=0.03)
    box("Chrome", (-2.55, 0.65, -2.6), (0.08, 0.3, 1.6), bevel=0.02)
    wheel((-1.4, 0.4, -3.8), 0.8, 0.4, hub="Dark")
    wheel((1.4, 0.4, -3.8), 0.8, 0.4, hub="Dark")
    wheel((-1.85, 1.0, 1.0), 2.0, 0.95, hub="Accent2", tread=True)
    wheel((1.85, 1.0, 1.0), 2.0, 0.95, hub="Accent2", tread=True)
    # roll bar (pro)
    for x in (-1.3, 1.3):
        cyl("Dark.Rops", (x, 1.6, 2.1), (x, 4.6, 2.1), 0.1, verts=8)
    cyl("Dark.Rops", (-1.3, 4.6, 2.1), (1.3, 4.6, 2.1), 0.1, verts=8)
    for x in (-0.9, 0.9):
        cyl("Light.Rops", (x, 4.6, 1.95), (x, 4.6, 1.75), 0.15, verts=8)


@model
def tractor():
    # Farm tractor: long hood, big treaded rear wheels, exhaust stack,
    # front deck. Player stands at the origin (RideLift 2.2).
    box("Dark", (0, 1.65, -1.6), (2.2, 0.8, 6.0), bevel=0.12)
    box("Accent", (0, 2.65, -3.1), (2.5, 1.55, 3.2), bevel=0.4)
    wedge("Accent", (0, 3.3, -2.0), (2.4, 0.5, 1.0), rot=[("y", 180)])
    box("Dark", (0, 2.55, -4.72), (1.9, 1.1, 0.1), bevel=0.02)
    for i in range(5):
        box("Chrome", (0, 2.1 + i * 0.22, -4.78), (1.8, 0.07, 0.05), bevel=0)
    for x in (-0.95, 0.95):
        cyl("Light", (x, 3.05, -4.66), (x, 3.05, -4.84), 0.22, verts=10)
    box("Accent2", (0, 3.45, -3.1), (0.45, 0.05, 3.0), bevel=0.02)
    # cab platform, fenders, seat
    box("Dark", (0, 2.1, 0.4), (2.6, 0.25, 2.6), bevel=0.05)
    for x in (-1.45, 1.45):
        box("Accent", (x, 3.0, 0.9), (0.9, 0.25, 2.6), bevel=0.1)
        box("Accent", (x, 2.5, 2.05), (0.9, 1.0, 0.25), bevel=0.08)
    box("Seat", (0, 2.9, 1.3), (1.5, 0.35, 1.1), bevel=0.14)
    box("Seat", (0, 3.75, 1.85), (1.5, 1.4, 0.3), bevel=0.14, rot=[("x", -10)])
    cyl("Dark", (0, 2.3, -1.4), (0, 4.0, -0.95), 0.11, verts=8)
    ring("SteeringWheel", (0, 4.05, -0.92), (0, 0.9, 0.42), 0.6, 0.08, seg=14, minor_seg=6)
    cyl("SteeringWheel", (0, 4.05, -0.92), (0, 4.13, -0.88), 0.15, verts=8)
    # exhaust stack
    cyl("Chrome", (0.8, 3.3, -2.3), (0.8, 5.2, -2.3), 0.16, verts=10)
    cyl("Dark", (0.8, 5.2, -2.3), (0.8, 5.35, -2.3), 0.2, verts=10)
    # wheels
    wheel((-1.75, 0.85, -3.7), 1.7, 0.65, hub="Accent2", tread=True)
    wheel((1.75, 0.85, -3.7), 1.7, 0.65, hub="Accent2", tread=True)
    wheel((-2.05, 1.6, 1.0), 3.2, 1.0, hub="Accent2", tread=True)
    wheel((2.05, 1.6, 1.0), 3.2, 1.0, hub="Accent2", tread=True)
    # front mow deck
    box("Dark", (0, 0.45, -6.2), (6.0, 0.5, 2.0), bevel=0.15)
    box("Accent2", (0, 0.78, -6.2), (6.05, 0.15, 2.05), bevel=0.04)
    for x in (-2.6, 2.6):
        wheel((x, 0.3, -7.0), 0.6, 0.3, hub="Dark")
    cyl("Dark", (0, 1.2, -4.8), (0, 0.7, -5.4), 0.12, verts=6)
    # canopy (bigger tractors)
    for x in (-1.3, 1.3):
        for z in (-0.2, 2.0):
            cyl("Dark.Canopy", (x, 2.2, z), (x, 6.3, z), 0.09, verts=6)
    box("Accent2.Canopy", (0, 6.4, 0.9), (3.2, 0.2, 3.0), bevel=0.08)
    # Longhorn: bull horns on the hood
    for side in (-1, 1):
        cyl("Teeth.Horns", (side * 0.9, 3.4, -4.1), (side * 1.7, 3.6, -4.2), 0.18, verts=8, r2=0.1)
        cyl("Teeth.Horns", (side * 1.7, 3.6, -4.2), (side * 2.0, 4.1, -4.25), 0.1, verts=8, r2=0.03)
    # Royal: a golden crown on the hood
    cyl("Gold.Crown", (0, 3.45, -3.6), (0, 3.75, -3.6), 0.45, verts=10, bevel=0.03)
    for i in range(5):
        a = math.radians(i * 72)
        cyl("Gold.Crown", (math.cos(a) * 0.38, 3.75, -3.6 + math.sin(a) * 0.38), (math.cos(a) * 0.42, 4.15, -3.6 + math.sin(a) * 0.42), 0.1, verts=6, r2=0.02)
        ball("Light.Crown", (math.cos(a) * 0.44, 4.18, -3.6 + math.sin(a) * 0.44), (0.12, 0.12, 0.12), seg=6, rings=4)


@model
def combine():
    # Combine harvester: tall body, glass cab around the player, wide
    # header with a spinning reel in front, unloading auger on the side.
    box("Accent", (0, 3.0, 2.4), (3.6, 3.4, 4.6), bevel=0.35)
    box("Accent2", (0, 4.75, 2.4), (3.2, 0.12, 4.0), bevel=0.03)
    box("Dark", (0, 1.9, -0.2), (3.0, 0.5, 2.4), bevel=0.1)
    # cab (glass + roof); the player stands inside at the origin
    for x in (-1.25, 1.25):
        cyl("Dark", (x, 2.2, -1.2), (x, 5.4, -1.2), 0.09, verts=6)
        cyl("Dark", (x, 2.2, 0.8), (x, 5.4, 0.8), 0.09, verts=6)
    box("Glass", (0, 3.8, -1.2), (2.4, 3.0, 0.08), bevel=0)
    box("Glass", (-1.25, 3.8, -0.2), (0.08, 3.0, 1.9), bevel=0)
    box("Glass", (1.25, 3.8, -0.2), (0.08, 3.0, 1.9), bevel=0)
    box("Accent", (0, 5.55, -0.2), (2.9, 0.3, 2.5), bevel=0.1)
    for x in (-1.0, -0.35, 0.35, 1.0):
        cyl("Light", (x, 5.5, -1.42), (x, 5.5, -1.55), 0.13, verts=8)
    cyl("Dark", (0, 2.2, -0.9), (0, 3.6, -0.75), 0.1, verts=8)
    ring("SteeringWheel", (0, 3.65, -0.75), (0, 0.9, 0.42), 0.5, 0.07, seg=14, minor_seg=6)
    # header
    box("Dark", (0, 0.9, -3.3), (7.5, 1.1, 1.8), bevel=0.15)
    box("Accent", (-3.8, 1.2, -3.3), (0.25, 1.6, 2.0), bevel=0.08)
    box("Accent", (3.8, 1.2, -3.3), (0.25, 1.6, 2.0), bevel=0.08)
    for i in range(14):
        box("Chrome", (-3.4 + i * 0.52, 0.4, -4.3), (0.12, 0.12, 0.5), bevel=0.0)
    cyl("Accent2", (-3.6, 1.7, -3.9), (3.6, 1.7, -3.9), 0.1, verts=8)
    for i in range(6):
        a = math.radians(i * 60)
        y, z = 1.7 + math.sin(a) * 0.85, -3.9 + math.cos(a) * 0.85
        cyl("Accent2", (-3.6, y, z), (3.6, y, z), 0.07, verts=6, bevel=0)
        cyl("Accent2", (-3.0, 1.7, -3.9), (-3.0, y, z), 0.05, verts=5, bevel=0)
        cyl("Accent2", (3.0, 1.7, -3.9), (3.0, y, z), 0.05, verts=5, bevel=0)
    box("Dark", (0, 1.6, -1.9), (1.4, 1.0, 1.4), bevel=0.1)
    # auger pipe
    cyl("Accent", (-1.6, 4.4, 3.4), (-4.6, 5.4, 3.0), 0.28, verts=10)
    cyl("Accent", (-4.6, 5.4, 3.0), (-4.9, 4.7, 3.0), 0.28, verts=10)
    cyl("Chrome", (1.2, 4.7, 4.0), (1.2, 6.0, 4.0), 0.18, verts=8)
    wheel((-1.95, 1.55, 0.1), 3.1, 1.0, hub="Accent2", tread=True)
    wheel((1.95, 1.55, 0.1), 3.1, 1.0, hub="Accent2", tread=True)
    wheel((-1.7, 0.85, 4.2), 1.7, 0.6, hub="Accent2", tread=True)
    wheel((1.7, 0.85, 4.2), 1.7, 0.6, hub="Accent2", tread=True)


@model
def drone():
    # Hover mower: the player stands on a round pad, four rotor arms with
    # propellers, spinning blades under the pad, skids on the ground.
    cyl("Accent", (0, 1.7, -0.4), (0, 2.2, -0.4), 2.0, verts=16, bevel=0.15)
    cyl("Dark", (0, 2.2, -0.4), (0, 2.28, -0.4), 1.6, verts=16, bevel=0.02)
    cyl("Accent2", (0, 1.45, -0.4), (0, 1.7, -0.4), 1.3, verts=16, bevel=0.06)
    for i in range(4):
        a = math.radians(45 + i * 90)
        ex, ez = math.cos(a) * 3.0, -0.4 + math.sin(a) * 3.0
        cyl("Dark", (math.cos(a) * 1.6, 1.95, -0.4 + math.sin(a) * 1.6), (ex, 2.1, ez), 0.14, verts=8)
        cyl("Accent", (ex, 1.9, ez), (ex, 2.5, ez), 0.35, verts=10, bevel=0.06)
        cyl("Light", (ex, 1.75, ez), (ex, 1.9, ez), 0.18, verts=8)
        for k in (0, 1):
            b = a + math.radians(90 * k + 20)
            box("Metal", (ex, 2.6, ez), (1.9, 0.05, 0.22), bevel=0.0, rot=[("y", -math.degrees(b))])
        cyl("Chrome", (ex, 2.5, ez), (ex, 2.68, ez), 0.1, verts=6)
    # blades below
    for k in range(3):
        box("Metal", (0, 0.9, -0.4), (3.0, 0.06, 0.3), bevel=0.0, rot=[("y", k * 60)])
    cyl("Dark", (0, 0.85, -0.4), (0, 1.45, -0.4), 0.2, verts=8)
    # skids
    for x in (-1.2, 1.2):
        cyl("Dark", (x, 0.15, -2.0), (x, 0.15, 1.2), 0.1, verts=6)
        cyl("Dark", (x, 0.15, -1.2), (x * 0.8, 1.5, -1.0), 0.07, verts=6)
        cyl("Dark", (x, 0.15, 0.4), (x * 0.8, 1.5, 0.2), 0.07, verts=6)
    # hand rail in front
    cyl("Dark", (0, 2.2, -1.6), (0, 3.4, -1.3), 0.08, verts=6)
    cyl("SteeringWheel", (-0.6, 3.4, -1.3), (0.6, 3.4, -1.3), 0.1, verts=8)


@model
def mowzilla():
    # A monster mower: tank treads, a big toothy grin, googly eyes,
    # back spikes and flame exhausts. The player stands on top.
    box("Accent", (0, 2.6, -1.0), (5.0, 2.6, 7.4), bevel=0.6)
    box("Dark", (0, 2.2, 0.2), (2.6, 0.2, 2.6), bevel=0.05)
    # treads
    for x in (-2.9, 2.9):
        box("Rubber", (x, 1.05, -1.0), (1.1, 2.1, 7.6), bevel=0.55)
        for i in range(8):
            wheel((x, 1.05, -4.0 + i * 0.86), 0.9, 1.15, hub="Dark")
    # mouth + teeth
    box("Dark", (0, 1.65, -4.68), (4.0, 1.1, 0.2), bevel=0.1)
    for i in range(9):
        x = -1.8 + i * 0.45
        cyl("Teeth", (x, 2.2, -4.75), (x, 1.6, -4.85), 0.2, verts=4, r2=0.02)
        cyl("Teeth", (x + 0.22, 1.1, -4.75), (x + 0.22, 1.6, -4.85), 0.17, verts=4, r2=0.02)
    # eyes
    for x in (-1.2, 1.2):
        ball("Eye", (x, 3.9, -4.2), (1.25, 1.25, 1.0), seg=12, rings=8)
        ball("Dark", (x * 0.94, 3.85, -4.72), (0.5, 0.5, 0.2), seg=10, rings=6)
        box("Accent2", (x, 4.7, -4.3), (1.3, 0.25, 0.5), bevel=0.08, rot=[("z", -12 if x < 0 else 12)])
    # spikes on the back
    for i in range(5):
        z = 0.8 + i * 0.6
        cyl("Accent2", (0, 3.85, z), (0, 4.9 - i * 0.12, z + 0.3), 0.35, verts=5, r2=0.03)
    # exhausts with flames
    for x in (-1.9, 1.9):
        cyl("Chrome", (x, 3.5, 1.6), (x, 5.2, 2.0), 0.25, verts=10)
        cyl("Light", (x, 5.2, 2.0), (x, 6.0, 2.25), 0.22, verts=8, r2=0.04)
    # front cutter drum
    cyl("Metal", (-2.6, 0.55, -5.3), (2.6, 0.55, -5.3), 0.5, verts=12)
    for i in range(10):
        box("Chrome", (-2.3 + i * 0.5, 0.55, -5.3), (0.1, 1.3, 0.12), bevel=0, rot=[("x", i * 36)])
    # rails to hold
    cyl("Dark", (0, 3.9, -1.6), (0, 5.0, -1.3), 0.1, verts=6)
    cyl("SteeringWheel", (-0.7, 5.0, -1.3), (0.7, 5.0, -1.3), 0.12, verts=8)
