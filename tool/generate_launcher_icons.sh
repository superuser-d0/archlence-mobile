#!/usr/bin/env bash
#
# Renders the raster icons from `assets/icon/archlence_icon.svg`: the legacy
# launcher PNGs, and the logo the launch screen centres.
#
# ONLY the legacy ones. Android 8 and up draw the adaptive icon in
# `res/mipmap-anydpi-v26/ic_launcher.xml`, whose foreground is a
# `VectorDrawable` and needs no rendering at all; these five PNGs are what
# API 24 and 25 fall back to. The app's `minSdk` is 24, so they are still
# reachable — the day it rises to 26 they can go.
#
# The output is checked in, like the drift and gen_l10n output, so a clone
# builds without running this. Run it after editing the SVG.
#
# Needs `rsvg-convert` (librsvg). ImageMagick's `convert` rasterises SVG
# through its own reader, which does not honour the `rx` on the ground and
# produces square corners.
set -euo pipefail

cd "$(dirname "$0")/.."
source_svg=assets/icon/archlence_icon.svg
res=android/app/src/main/res

# The five launcher sizes, in the order Android asks for them: 48dp at each
# density's own pixel ratio.
for entry in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  density=${entry%%:*}
  size=${entry##*:}
  out="$res/mipmap-$density/ic_launcher.png"
  mkdir -p "$(dirname "$out")"
  rsvg-convert -w "$size" -h "$size" "$source_svg" -o "$out"
  echo "wrote $out (${size}x${size})"
done

# The launch screen's logo: the same icon at 96dp, which is roughly what
# Android 12 draws its own splash icon at.
#
# A PNG rather than a reference to `@mipmap/ic_launcher`, and that is not a
# preference. From API 26 that name resolves to the adaptive-icon XML, and a
# `<bitmap>` pointing at a non-bitmap fails to inflate — the app would crash
# on the launch window, on every modern phone, before Flutter started.
for entry in mdpi:96 hdpi:144 xhdpi:192 xxhdpi:288 xxxhdpi:384; do
  density=${entry%%:*}
  size=${entry##*:}
  out="$res/drawable-$density/launch_logo.png"
  mkdir -p "$(dirname "$out")"
  rsvg-convert -w "$size" -h "$size" "$source_svg" -o "$out"
  echo "wrote $out (${size}x${size})"
done
