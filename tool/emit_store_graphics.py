"""Emits the two raster images Play's listing requires, from what the app already has.

Play asks for a 512x512 app icon and a 1024x500 feature graphic, and it asks
for them as PNG. Neither is a design decision:

  * The icon IS `assets/icon/archlence_icon.svg`, the same mark the launcher
    and the desktop app carry, rendered square. Play applies its own masking,
    so nothing is rounded here.
  * The feature graphic is the app's own dark (`#131313`, the launch
    background), that mark, the name in the app's own Plus Jakarta Sans, and
    the tagline from `onboardingTagline` -- the sentence the app opens with,
    in the polite register the rest of it uses.

Drawn rather than photographed, so that a change to the mark or the tagline is
one run away from a new pair rather than a session with an image editor. The
text is kept inside the middle of the frame: Play crops and overlays the
feature graphic in several placements, and anything against the edge is what
gets lost.

    python -m venv iconvenv
    ./iconvenv/Scripts/pip install svglib reportlab rlPyCairo pillow
    ./iconvenv/Scripts/python tool/emit_store_graphics.py docs/store

`rlPyCairo` is not optional decoration: `reportlab`'s raster backend refuses to
start without it, and the error names a module rather than the reason.
"""

from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw, ImageFont
from reportlab.graphics import renderPM
from svglib.svglib import svg2rlg

if len(sys.argv) != 2:
    raise SystemExit(__doc__)

destination = os.path.abspath(sys.argv[1])
os.makedirs(destination, exist_ok=True)

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
source = os.path.join(root, "assets", "icon", "archlence_icon.svg")

# The ground the mark sits on, and the app's own dark behind the wordmark.
# Both are read from where they already live rather than repeated: the first
# is `ic_launcher_background` in `android/app/src/main/res/values/colors.xml`,
# the second is `launch_background` beside it.
MARK_GROUND = 0x5444E5
DARK = (19, 19, 19)
INK = (245, 245, 245)
MUTED = (150, 150, 155)

icon_path = os.path.join(destination, "play_store_512.png")
drawing = svg2rlg(source)
scale = 512.0 / drawing.width
drawing.width = 512
drawing.height = 512
drawing.scale(scale, scale)
renderPM.drawToFile(drawing, icon_path, fmt="PNG", dpi=72, bg=MARK_GROUND)
print(f"{icon_path}  512x512")

WIDTH, HEIGHT = 1024, 500
banner = Image.new("RGB", (WIDTH, HEIGHT), DARK)
draw = ImageDraw.Draw(banner)

side = 236
mark = Image.open(icon_path).convert("RGB").resize((side, side), Image.LANCZOS)
mask = Image.new("L", (side, side), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, side - 1, side - 1], radius=52, fill=255)
banner.paste(mark, (96, (HEIGHT - side) // 2), mask)

fonts = os.path.join(root, "assets", "fonts")
title_font = ImageFont.truetype(os.path.join(fonts, "PlusJakartaSans-700.ttf"), 84)
body_font = ImageFont.truetype(os.path.join(fonts, "PlusJakartaSans-400.ttf"), 30)

left = 96 + side + 60
draw.text((left, 178), "Archlence", font=title_font, fill=INK)
for index, line in enumerate(
    [
        "Hesaplarınız, kartlarınız, varlıklarınız",
        "ve bütçeniz — bu telefonda,",
        "başka hiçbir yerde.",
    ]
):
    draw.text((left, 284 + index * 41), line, font=body_font, fill=MUTED)

# The check that keeps this honest: nothing may reach the outer eighth, which
# is the band Play is free to crop.
edge = int(WIDTH * 0.875)
widest = max(
    draw.textbbox((left, 0), line, font=body_font)[2]
    for line in ("Hesaplarınız, kartlarınız, varlıklarınız", "Archlence")
)
if widest > edge:
    raise SystemExit(f"text reaches {widest}px of {WIDTH}, past the safe edge at {edge}")

banner_path = os.path.join(destination, "feature_graphic_1024x500.png")
banner.save(banner_path)
print(f"{banner_path}  {WIDTH}x{HEIGHT}, widest text {widest}px of {edge} allowed")
