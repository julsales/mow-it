#!/usr/bin/env python3
"""Make upload-ready copies of the generated UI art (assets/UI/generated-v3).

Roblox stores images at most 1024 px per side, and the generated PNGs are
1.2k-2.2k px with uneven transparent margins. This trims each icon to its
visible pixels (plus a small even margin) and downsizes it, so every icon
fills its ImageLabel the same way. Skins (frame, button, banners, rays) keep
their full canvas because their slice margins depend on it.

Output: build/ui-upload/<name>.png (git-ignored). Upload those, then put
the returned rbxassetid values in Shared/Config/Interface.luau.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/UI/generated-v3'
OUT = ROOT / 'build/ui-upload'
def visible(image):
    # Faint stray pixels (alpha < 64) would widen the box unevenly.
    return image.split()[-1].point(lambda a: 255 if a >= 64 else 0).getbbox()


SKINS = {'window-frame': 512, 'button-base': 256, 'banner-base': 1024, 'offer-banner': 1024, 'rays': 512}
ICON_SIZE = 384
MARGIN = 0.04

OUT.mkdir(parents=True, exist_ok=True)
for path in sorted(SOURCE.glob('*.png')):
    image = Image.open(path).convert('RGBA')
    name = path.stem
    if name in SKINS:
        if name == 'window-frame':
            image = image.crop(visible(image))
        image.thumbnail((SKINS[name], SKINS[name]), Image.LANCZOS)
    else:
        image = image.crop(visible(image))
        side = round(max(image.size) * (1 + 2 * MARGIN))
        canvas = Image.new('RGBA', (side, side))
        canvas.alpha_composite(image, ((side - image.width) // 2, (side - image.height) // 2))
        image = canvas.resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS)
    image.save(OUT / f'{name}.png', optimize=True)
    print(f'{name}: {image.size}')
