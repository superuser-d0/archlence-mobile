"""Conforms the device screenshots to what Play's listing will actually accept.

The captures in `docs/screenshots/` come off a phone and are 1080x2400 --
the Pixel-class 9:20 that every modern Android screenshot is. Play's rule is
narrower than the hardware:

    "the maximum dimension of your screenshot can't be more than twice as
     long as the minimum dimension"

2400/1080 is 2.222:1, so the captures are over the limit as they stand and
the console refuses them. This was an open question in the roadmap -- whether
the 2:1 rule was still enforced -- and the answer is that it is.

The roadmap guessed the fix would be "padding to 1080x1920". That is not a
fix: 1920 is SHORTER than the 2400 we have, so it crops 480px off a screen
rather than padding it. The fix in the other direction costs nothing --
widen to 1200, because 2400/2 is 1200, and the result is exactly 2.000:1
with every pixel of the original still in it.

The pad is the capture's OWN edge column, stretched outward, rather than a
flat colour. That started as a flat `#131313` -- `launch_background` from
`android/app/src/main/res/values/colors.xml`, which is what the captures hold
down almost all of both edges -- and the guard below rejected it on the first
run. Almost all is not all: rows 2159-2160 are `#262626`, the hairline above
the bottom navigation, and it is full-bleed. A flat pad would have stopped
that rule 60px short of the new edge on three of the four screenshots -- a
clipped hairline, which is exactly the kind of thing nobody sees until it is
on the store. Replicating the edge continues it instead, which is what a
wider screen would have drawn anyway, and it needs no assumption about what
colour any future capture's edge happens to be.

Play also wants screenshots as 24-bit PNG with no alpha. The captures are
32-bit RGBA whose alpha channel is 255 everywhere, so it carries nothing and
flattening it is a re-encode rather than a change. (The app ICON is the
opposite case -- Play wants 32 bits WITH alpha there -- which is why
`emit_store_graphics.py` converts in the other direction.)

The captures are left untouched. They are evidence of what the real app drew
on a real device, and a listing asset is a derived thing:

    python3 tool/emit_store_screenshots.py docs/screenshots docs/store/screenshots
"""

from __future__ import annotations

import glob
import os
import sys

from PIL import Image

if len(sys.argv) != 3:
    raise SystemExit(__doc__)

source = os.path.abspath(sys.argv[1])
destination = os.path.abspath(sys.argv[2])
os.makedirs(destination, exist_ok=True)

# `launch_background` in android/app/src/main/res/values/colors.xml.
DARK = (19, 19, 19)

# Play's rule, as a number rather than a sentence.
MAX_RATIO = 2.0

# How many distinct colours a "background and rules" edge is allowed to have.
# These captures have two: #131313 and the #262626 hairline. The allowance is
# loose enough for a scrollbar or a second rule and tight enough that a
# screenshot with content at the edge trips it.
EDGE_COLOURS = 6

captures = sorted(glob.glob(os.path.join(source, "*.png")))
if len(captures) < 2:
    raise SystemExit(f"Play wants at least two screenshots; {source} has {len(captures)}")

for capture in captures:
    image = Image.open(capture)
    width, height = image.size

    # Widen to whatever the 2:1 rule needs, and no further. A capture that
    # already conforms is copied through at its own size.
    target = max(width, int(round(height / MAX_RATIO)))

    # The guard, and the reason this is a script rather than an image editor.
    # Stretching the edge outward is invisible while the edge is background
    # and full-bleed rules -- a handful of flat colours. If a capture ever
    # runs real CONTENT to its edge, replication smears that content sideways
    # for 60px, and nobody would notice until it was on the store. A busy
    # edge is the signal, so count what is actually in it.
    if target > width:
        rgb = image.convert("RGB")
        for name, column in (
            ("left", rgb.crop((0, 0, 1, height))),
            ("right", rgb.crop((width - 1, 0, width, height))),
        ):
            distinct = len(column.getcolors(maxcolors=height))
            if distinct > EDGE_COLOURS:
                raise SystemExit(
                    f"{os.path.basename(capture)}: {distinct} colours down the {name} "
                    f"edge, more than the {EDGE_COLOURS} a background-and-rules edge "
                    "has. Stretching it would smear real content -- crop or re-take it."
                )

    # 24-bit, no alpha. The captures' alpha is 255 everywhere; assert that
    # rather than discarding a channel that might have held something.
    if "A" in image.getbands():
        low, high = image.getchannel("A").getextrema()
        if (low, high) != (255, 255):
            raise SystemExit(
                f"{os.path.basename(capture)}: alpha runs {low}-{high}, not flat 255 -- "
                "flattening would change the picture."
            )

    rgb = image.convert("RGB")
    flat = Image.new("RGB", (target, height), DARK)
    pad = (target - width) // 2
    flat.paste(rgb, (pad, 0))
    # Continue each edge row outward at its own colour, so the hairline above
    # the navigation bar reaches the new edge instead of stopping short of it.
    if pad:
        flat.paste(rgb.crop((0, 0, 1, height)).resize((pad, height)), (0, 0))
        right = target - width - pad
        flat.paste(rgb.crop((width - 1, 0, width, height)).resize((right, height)),
                   (pad + width, 0))

    out = os.path.join(destination, os.path.basename(capture))
    flat.save(out)

    ratio = max(flat.size) / min(flat.size)
    if ratio > MAX_RATIO:
        raise SystemExit(f"{out} is {ratio:.3f}:1, still past Play's {MAX_RATIO}:1")
    if min(flat.size) < 320 or max(flat.size) > 3840:
        raise SystemExit(f"{out} is {flat.size}, outside Play's 320-3840px range")

    print(
        f"{out}  {width}x{height} -> {target}x{height}  "
        f"{ratio:.3f}:1  (was {height / width:.3f}:1)"
    )

print(f"{len(captures)} screenshots, Play wants at least 2")
