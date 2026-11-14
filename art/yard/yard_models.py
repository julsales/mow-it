# Mow It! hay yard art: the baler, a hay bale, the stacking pallet and the
# silo with its bale elevator and sales counter (Shared/Config/HayYard.luau).
#
# Same kit and style as the tools (art/tools/lib.py, art/tools/README.md):
# chunky cartoon low-poly, one chamfer, flat colours, baked vertex shading.
# Authored in Roblox coordinates (studs, +Y up). The FRONT of every yard
# model is +Z (where the player stands), like the map props.
#
# Mesh names are colour groups (Config/HayYard.Paint); "Group#Rig" pieces
# move in the game (StarterPlayerScripts/Yard/RigPlayer):
#   baler  Shake (the whole body rattles), Flywheel, Plunger (the press
#          head), Cap (exhaust flap), Needle (gauge), Heap (grass in the
#          hopper)
#   silo   Belt (elevator cleats), Hatch (the door bales go in), Vane

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tools"))

import contextlib  # noqa: E402

import lib  # noqa: E402
from lib import ball, box, cyl, prism, rig, ring, wedge  # noqa: E402,F401

MODELS = {}


def model(fn):
    MODELS[fn.__name__] = fn
    return fn


@contextlib.contextmanager
def sub(name):
    """A moving piece mounted on another moving piece (the flywheel on the
    rattling body). lib.rig() would merge it into the outer rig; here it
    stays its own rig and Config/HayYard names its parent."""
    old = lib._RIG[0]
    lib._RIG[0] = name
    try:
        yield
    finally:
        lib._RIG[0] = old


def tyre(x, y, z, diameter, width, hub="Accent2"):
    """Parked wheel (no spin rig), its axle along Z."""
    r, hw = diameter / 2, width / 2
    side = 1 if z >= 0 else -1
    cyl("Rubber", (x, y, z - hw), (x, y, z + hw), r, verts=16, bevel=r * 0.25)
    cyl(hub, (x, y, z - hw * 1.04), (x, y, z + hw * 1.04), r * 0.58, verts=12, bevel=0.03)
    cyl("Chrome", (x, y, z + side * hw), (x, y, z + side * (hw + 0.1)), r * 0.22, verts=8, bevel=0.02)


# ------------------------------------------------------------------- baler
# Grass goes in the hopper (left), the press stomps it into the chamber
# and bales slide out of the mouth on the right (+X) along the roller tray.
BALER_MOUTH = (3.4, 2.8, 0)  # centre of the chamber mouth
BALER_TRAY_END = (5.75, 2.8, 0)  # where a finished bale sits before it is stacked
BALER_HOPPER = (-1.6, 6.4, 0)  # top of the hopper (grass is thrown in here)
BALER_EXHAUST = (1.9, 7.6, -0.9)


@model
def baler():
    # --- chassis, parked on four fat wheels, with a tow hitch on a jack
    box("Dark", (-0.2, 1.25, 0), (7.0, 0.5, 3.4), bevel=0.1)
    for x in (-2.3, 2.0):
        cyl("Dark", (x, 0.75, -1.95), (x, 0.75, 1.95), 0.12, verts=8, bevel=0)
        box("Dark", (x, 0.95, 0), (0.6, 0.5, 0.6), bevel=0.06)
        for z in (-1.95, 1.95):
            tyre(x, 0.75, z, 1.5, 0.6)
    box("Dark", (-4.1, 1.25, 0), (1.3, 0.3, 0.5), bevel=0.06)
    cyl("Chrome", (-4.45, 1.3, 0), (-4.45, 0.1, 0), 0.12, verts=8, bevel=0)
    cyl("Dark", (-4.45, 0, 0), (-4.45, 0.12, 0), 0.38, verts=10, bevel=0.03)
    ring("Chrome", (-4.85, 1.25, 0), (0, 1, 0), 0.22, 0.07, seg=10, minor_seg=5)

    # --- loading deck in front of the hopper (the player stands here)
    for x in (-3.4, 0.2):
        box("Wood", (x, 0.2, 3.6), (0.4, 0.4, 2.4), bevel=0.05)
        box("Dark", (x, 0.75, 2.05), (0.22, 0.8, 0.9), bevel=0.04)  # bracket to the chassis
    for i in range(4):
        box("Wood", (-1.6, 0.47, 2.72 + i * 0.6), (4.4, 0.14, 0.52), bevel=0.04)
    box("Dark", (-1.6, 0.3, 2.42), (4.4, 0.25, 0.1), bevel=0.02)  # kick plate against the wheels

    # --- roller tray the bales slide out on, on its own legs
    for z in (-0.95, 0.95):
        box("Metal", (4.55, 1.95, z), (2.7, 0.3, 0.14), bevel=0.04)
        box("Dark", (5.75, 0.95, z), (0.2, 1.9, 0.2), bevel=0.04)
        cyl("Dark", (5.75, 0, z), (5.75, 0.1, z), 0.24, verts=8, bevel=0.02)
    box("Dark", (5.75, 0.7, 0), (0.14, 0.14, 1.9), bevel=0.02)
    for i in range(5):
        x = 3.6 + i * 0.5
        cyl("Chrome", (x, 1.93, -0.9), (x, 1.93, 0.9), 0.11, verts=8, bevel=0.02)
    box("Metal", (5.86, 2.2, 0), (0.12, 0.6, 2.04), bevel=0.03)  # end stop

    with rig("Shake"):
        # --- body: first piece is the rig's centre
        box("Accent", (-0.2, 3.0, 0), (6.0, 3.0, 3.4), bevel=0.5)
        box("Dark", (-0.2, 1.72, 0), (5.6, 0.5, 3.0), bevel=0.08)
        for z in (-1.71, 1.71):
            box("Accent2", (-0.2, 2.2, z), (5.4, 0.26, 0.06), bevel=0.02)
        for i in range(4):  # louvres on the back
            box("Dark", (-0.9 + i * 0.5, 3.4, -1.71), (0.3, 1.2, 0.06), bevel=0.02)
        # --- bale chamber and its mouth
        box("Metal", (2.6, 2.75, 0), (1.6, 2.1, 2.3), bevel=0.15)
        box("Dark", (3.38, 2.8, 0), (0.1, 1.7, 1.9), bevel=0.02)
        for z in (-1.0, 1.0):  # guide lips at the mouth
            box("Accent2", (3.5, 2.8, z), (0.3, 1.9, 0.12), bevel=0.04)
        # --- hopper
        cyl("Accent2", (-1.6, 4.3, 0), (-1.6, 6.2, 0), 1.0, verts=8, bevel=0.06, r2=1.9)
        cyl("Dark", (-1.6, 6.15, 0), (-1.6, 6.4, 0), 2.02, verts=8, bevel=0.06)
        cyl("Dark", (-1.6, 6.36, 0), (-1.6, 6.43, 0), 1.7, verts=8, bevel=0)
        with sub("Heap"):
            ball("Grass", (-1.6, 6.45, 0), (3.1, 1.1, 3.1), seg=8, rings=5)
            ball("Grass", (-1.1, 6.75, 0.5), (1.4, 0.8, 1.4), seg=6, rings=4)
            ball("Grass", (-2.2, 6.7, -0.4), (1.2, 0.7, 1.2), seg=6, rings=4)
        # --- motor box, exhaust stack with a flap, warning lamp
        box("Dark", (1.3, 4.9, -0.6), (2.0, 0.9, 1.6), bevel=0.2)
        for i in range(3):
            box("Metal", (0.7 + i * 0.5, 4.95, 0.21), (0.3, 0.5, 0.04), bevel=0.01)
        cyl("Chrome", (1.9, 5.3, -0.9), (1.9, 7.4, -0.9), 0.2, verts=10, bevel=0.03)
        cyl("Dark", (1.9, 6.0, -0.9), (1.9, 6.9, -0.9), 0.27, verts=10, bevel=0.04)
        with sub("Cap"):
            cyl("Dark", (1.66, 7.44, -1.05), (1.66, 7.44, -0.75), 0.05, verts=6, bevel=0)
            cyl("Dark", (1.9, 7.4, -0.9), (1.9, 7.48, -0.9), 0.27, verts=10, bevel=0.02)
        cyl("Dark", (0.55, 5.3, 0.5), (0.55, 5.5, 0.5), 0.32, verts=10, bevel=0.03)
        ball("Lamp", (0.55, 5.72, 0.5), (0.56, 0.6, 0.56), seg=8, rings=5)
        # --- press: an arm from the motor box holds the cylinder, the head
        # stomps on the chamber
        box("Dark", (1.9, 5.55, 0), (2.4, 0.5, 0.7), bevel=0.1)
        box("Dark", (2.6, 5.5, 0), (1.0, 1.0, 1.0), bevel=0.14)
        with sub("Plunger"):
            cyl("Chrome", (2.6, 4.1, 0), (2.6, 6.5, 0), 0.17, verts=10, bevel=0.03)
            box("Accent2", (2.6, 4.0, 0), (1.35, 0.45, 1.8), bevel=0.12)
        # --- pressure gauge on the front
        cyl("Chrome", (1.9, 3.75, 1.66), (1.9, 3.75, 1.82), 0.46, verts=12, bevel=0.03)
        cyl("Eye", (1.9, 3.75, 1.8), (1.9, 3.75, 1.85), 0.38, verts=12, bevel=0)
        with sub("Needle"):
            cyl("Dark", (1.9, 3.75, 1.84), (1.9, 3.75, 1.9), 0.07, verts=6, bevel=0)
            box("Tail", (1.9, 3.92, 1.88), (0.06, 0.34, 0.03), bevel=0)
        # --- flywheel on the front, on a stub axle
        cyl("Dark", (-1.3, 3.0, 1.6), (-1.3, 3.0, 1.9), 0.3, verts=8, bevel=0.03)
        with sub("Flywheel"):
            cyl("Chrome", (-1.3, 3.0, 1.85), (-1.3, 3.0, 2.22), 0.22, verts=8, bevel=0.03)
            ring("Accent2", (-1.3, 3.0, 2.02), (0, 0, 1), 1.05, 0.17, seg=16, minor_seg=6)
            for a in (0, 45, 90, 135):
                box("Dark", (-1.3, 3.0, 2.02), (0.14, 2.1, 0.1), bevel=0.02, rot=[("z", a)])
            box("Dark", (-1.3, 3.82, 2.02), (0.7, 0.34, 0.24), bevel=0.05)  # counterweight


# -------------------------------------------------------------------- bale
BALE = (2.4, 1.5, 1.5)


@model
def bale():
    w, h, d = BALE
    box("Hay", (0, h / 2, 0), (w, h, d), bevel=0.16)
    for y in (0.45, 1.05):  # pressed layers
        box("Straw", (0, y, 0), (w + 0.02, 0.1, d + 0.02), bevel=0.02)
    for x in (-0.6, 0.6):
        box("Twine", (x, h / 2 + 0.015, 0), (0.12, h + 0.03, d + 0.06), bevel=0.03)
    # loose straws poking out of the ends
    for x, y, z, a in ((1.2, 1.0, 0.3, 20), (1.2, 0.5, -0.35, -15), (-1.2, 0.9, -0.2, 160), (-1.2, 0.4, 0.4, 195)):
        box("Straw", (x, y, z), (0.36, 0.07, 0.07), bevel=0, rot=[("z", a)])


# ------------------------------------------------------------------ pallet
# Bales are stacked on it: 3 across (X) x 2 deep (Z), layer on layer.
PALLET_TOP = 0.54


@model
def pallet():
    for x in (-3.6, 0, 3.6):
        box("Wood", (x, 0.2, 0), (0.5, 0.4, 3.7), bevel=0.05)
    for i in range(5):
        box("Wood", (0, 0.47, -1.55 + i * 0.775), (8.0, 0.14, 0.6), bevel=0.04)
    # back rail the stack leans on
    for x in (-3.8, 3.8):
        box("Wood", (x, 1.75, -1.72), (0.3, 3.1, 0.3), bevel=0.06)
        box("Dark", (x, 3.34, -1.72), (0.36, 0.1, 0.36), bevel=0.02)
    for y in (1.3, 2.6):
        box("Wood", (0, y, -1.76), (7.9, 0.26, 0.14), bevel=0.04)


# -------------------------------------------------------------------- silo
# Sold bales ride the elevator (left, -X) up into the hatch; customers buy
# at the counter in front (+Z).
SILO_ELEVATOR = ((-10.3, 1.35, 0), (-4.0, 7.75, 0))  # belt top surface: foot -> hatch
SILO_COUNTER = (0, 2.78, 4.3)  # top of the counter
SILO_WINDOW = (0, 3.7, 3.5)  # the serving hatch bales come out of
BELT_STEP = 1.2  # distance between cleats along the belt


@model
def silo():
    R = 3.5
    cyl("Stone", (0, 0, 0), (0, 0.6, 0), 4.0, verts=16, bevel=0.1)
    cyl("Body", (0, 0.55, 0), (0, 12.5, 0), R, verts=16, bevel=0.08)
    for y in (2.6, 5.6, 8.6, 11.6):
        cyl("Metal", (0, y, 0), (0, y + 0.26, 0), R + 0.07, verts=16, bevel=0.04)
    cyl("Roof", (0, 12.4, 0), (0, 12.75, 0), R + 0.5, verts=16, bevel=0.06)
    cyl("Roof", (0, 12.7, 0), (0, 15.4, 0), R + 0.4, verts=16, bevel=0.05, r2=0.5)
    ball("Metal", (0, 15.45, 0), (0.9, 0.9, 0.9), seg=8, rings=5)
    cyl("Dark", (0, 15.7, 0), (0, 16.75, 0), 0.07, verts=6, bevel=0)
    with rig("Vane"):
        ball("Dark", (0, 16.75, 0), (0.24, 0.24, 0.24), seg=6, rings=4)
        box("Dark", (0, 16.75, 0), (1.9, 0.08, 0.08), bevel=0)
        prism("Accent2", [(0, -0.3), (0.55, 0), (0, 0.3)], (0.95, 16.75, 0), (1, 0, 0), (0, 1, 0), 0.06, bevel=0)
        prism("Accent2", [(0, -0.28), (0.45, -0.28), (0.25, 0), (0.45, 0.28), (0, 0.28)], (-1.3, 16.75, 0), (1, 0, 0), (0, 1, 0), 0.06, bevel=0)

    # --- ladder up the back
    for x in (-0.5, 0.5):
        cyl("Metal", (x, 0.6, -R - 0.14), (x, 12.3, -R - 0.14), 0.06, verts=6, bevel=0)
    for i in range(14):
        y = 1.3 + i * 0.8
        cyl("Metal", (-0.5, y, -R - 0.14), (0.5, y, -R - 0.14), 0.05, verts=6, bevel=0)
    for y in (1.0, 6.0, 11.9):
        for x in (-0.5, 0.5):
            box("Metal", (x, y, -R - 0.02), (0.1, 0.1, 0.3), bevel=0)

    # --- hatch on the left, under a little roof
    box("Dark", (-3.5, 8.75, 0), (0.6, 2.7, 2.6), bevel=0.08)
    box("Roof", (-3.95, 10.25, 0), (1.5, 0.22, 3.0), bevel=0.05, rot=[("z", 18)])
    with rig("Hatch"):
        cyl("Dark", (-3.86, 9.95, -1.15), (-3.86, 9.95, 1.15), 0.08, verts=6, bevel=0)
        box("Wood", (-3.86, 8.8, 0), (0.14, 2.3, 2.2), bevel=0.04)
        box("Dark", (-3.95, 8.1, 0), (0.08, 0.14, 0.7), bevel=0.02)  # handle

    # --- bale elevator: belt on two rails, a boot at the foot, legs half way
    (x0, y0, _), (x1, y1, _) = SILO_ELEVATOR
    length = math.hypot(x1 - x0, y1 - y0)
    angle = math.degrees(math.atan2(y1 - y0, x1 - x0))
    ux, uy = (x1 - x0) / length, (y1 - y0) / length
    nx, ny = -uy, ux  # up, square to the belt
    mx, my = (x0 + x1) / 2, (y0 + y1) / 2
    tilt = [("z", angle)]
    box("Rubber", (mx - nx * 0.07, my - ny * 0.07, 0), (length + 0.5, 0.14, 1.7), bevel=0.03, rot=tilt)
    for z in (-0.95, 0.95):
        box("Accent", (mx + nx * 0.05, my + ny * 0.05, z), (length + 0.7, 0.5, 0.16), bevel=0.05, rot=tilt)
    with rig("Belt"):
        n = int(length / BELT_STEP)
        for i in range(n):
            t = (i + 0.5) * BELT_STEP
            box("Dark", (x0 + ux * t + nx * 0.1, y0 + uy * t + ny * 0.1, 0), (0.14, 0.24, 1.6), bevel=0.02, rot=tilt)
    # boot at the foot (the cleats come out of it), on two small wheels
    box("Accent", (x0 - 0.15, 0.95, 0), (1.7, 1.3, 2.3), bevel=0.2)
    box("Dark", (x0 - 0.15, 0.4, 0), (1.3, 0.3, 1.9), bevel=0.05)
    for z in (-1.2, 1.2):
        tyre(x0 - 0.15, 0.45, z, 0.9, 0.36)
    cyl("Dark", (x0 - 0.15, 0.45, -1.2), (x0 - 0.15, 0.45, 1.2), 0.08, verts=6, bevel=0)
    # legs
    t = length * 0.56
    lx, ly = x0 + ux * t, y0 + uy * t
    for z in (-1.1, 1.1):
        box("Dark", (lx, (ly - 0.1) / 2, z), (0.26, ly - 0.1, 0.26), bevel=0.05)
        cyl("Dark", (lx, 0, z), (lx, 0.1, z), 0.3, verts=8, bevel=0.02)
    box("Dark", (lx, ly * 0.45, 0), (0.18, 0.18, 2.2), bevel=0.03)
    box("Dark", (lx, ly - 0.42, 0), (0.3, 0.3, 2.3), bevel=0.04)  # cross beam under the rails

    # --- sales counter in front: serving hatch, counter, striped awning
    box("Dark", (0, 3.75, R - 0.08), (2.7, 2.0, 0.4), bevel=0.06)
    box("Wood", (0, 3.75, R + 0.1), (3.1, 2.4, 0.14), bevel=0.04)
    box("Dark", (0, 3.75, R + 0.12), (2.4, 1.8, 0.14), bevel=0.02)
    box("Wood", (0, 2.6, 4.25), (5.6, 0.36, 1.7), bevel=0.08)
    for x in (-2.4, 2.4):
        box("Wood", (x, 1.5, 4.3), (0.4, 1.9, 1.4), bevel=0.06)
        cyl("Wood", (x, 0.5, 5.0), (x, 6.2, 5.0), 0.16, verts=8, bevel=0.03)
    for i in range(6):
        group = "Accent2" if i % 2 == 0 else "Eye"
        box(group, (-2.5 + i * 1.0, 6.45, 4.3), (1.0, 0.2, 2.3), bevel=0.05, rot=[("x", 14)])
    box("Wood", (0, 6.72, 3.42), (6.0, 0.3, 0.3), bevel=0.05)  # awning rail on the wall
