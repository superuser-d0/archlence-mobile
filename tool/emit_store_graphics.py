"""Emits the two raster images Play's listing requires, from what the app already has.

Play asks for a 512x512 app icon and a 1024x500 feature graphic, and it asks
for them as PNG. Neither is a design decision:

  * The icon IS `assets/icon/archlence_icon.svg`, the same mark the launcher
    and the desktop app carry, rendered square. Play applies its own masking,
    so nothing is rounded here.
  * The feature graphic is the app's own dark (`#131313`, the launch
    background), that mark, the name in the app's own Plus Jakarta Sans, and
    one line of slogan in the app's own green.

The slogan is NOT read from the ARB files, and that is deliberate rather than
an oversight. It began as `onboardingTagline` -- the sentence the app opens
with -- and read as a list on a banner: four nouns and a clause. A store
slogan and a first-run explanation are different jobs. This one is written
here, in one place, and changing it is an edit to this file.

The green is `tertiary` from `lib/theme/` -- #4EDEA3, the app's "positive
money" colour, the one the balance ring is drawn in. The mark keeps its own
#5444E5: that ground is the identity this app SHARES with the desktop client,
it is not an Obsidian Prime token, and a store icon that drifted from the
launcher would be two marks for one product.

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
# `tertiary` in `lib/theme/` -- "Positive money: income, growth, cash".
ACCENT = (0x4E, 0xDE, 0xA3)

icon_path = os.path.join(destination, "play_store_512.png")
drawing = svg2rlg(source)
scale = 512.0 / drawing.width
drawing.width = 512
drawing.height = 512
drawing.scale(scale, scale)
renderPM.drawToFile(drawing, icon_path, fmt="PNG", dpi=72, bg=MARK_GROUND)

# Play asks for the icon as a 32-bit PNG *with* alpha, where it asks for the
# feature graphic and the screenshots as 24-bit PNG *without* one. `renderPM`
# writes 24-bit, so the icon came out in the screenshots' format rather than
# its own. The mark is fully opaque and stays that way -- this adds an
# all-255 alpha channel to satisfy the format, and changes no pixel's colour.
Image.open(icon_path).convert("RGBA").save(icon_path)
print(f"{icon_path}  512x512, RGBA")

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
body_font = ImageFont.truetype(os.path.join(fonts, "PlusJakartaSans-500.ttf"), 33)

SLOGAN = "Paranızın kaydı sadece sizde."

left = 96 + side + 60
draw.text((left, 186), "Archlence", font=title_font, fill=INK)
draw.text((left, 300), SLOGAN, font=body_font, fill=ACCENT)

# The check that keeps this honest: nothing may reach the outer eighth, which
# is the band Play is free to crop.
edge = int(WIDTH * 0.875)
widest = max(
    draw.textbbox((left, 0), SLOGAN, font=body_font)[2],
    draw.textbbox((left, 0), "Archlence", font=title_font)[2],
)
if widest > edge:
    raise SystemExit(f"text reaches {widest}px of {WIDTH}, past the safe edge at {edge}")

banner_path = os.path.join(destination, "feature_graphic_1024x500.png")
banner.save(banner_path)
print(f"{banner_path}  {WIDTH}x{HEIGHT}, widest text {widest}px of {edge} allowed")
