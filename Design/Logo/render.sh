#!/bin/sh
# Renders the app icon PNGs from the SVGs in this folder. Needs rsvg-convert and ImageMagick
# (brew install librsvg imagemagick). The opaque icons lose their alpha channel, which App Store
# validation rejects. The dark icon keeps it, because the system draws its own background behind it.
set -eu
cd "$(dirname "$0")"
ios=../../Temper/Assets.xcassets/AppIcon.appiconset
watch=../../TemperWatch/Assets.xcassets/AppIcon.appiconset

opaque() {
    rsvg-convert -w 1024 -h 1024 "$1" | magick - -alpha off "$2"
}

opaque app-icon.svg "$ios/AppIcon.png"
opaque app-icon-tinted.svg "$ios/AppIcon-Tinted.png"
rsvg-convert -w 1024 -h 1024 app-icon-dark.svg -o "$ios/AppIcon-Dark.png"
opaque watch-icon.svg "$watch/AppIcon.png"
