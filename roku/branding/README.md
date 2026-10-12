# Roku brand assets

The controller is **HiPhi Control**; the companion screensaver is **HiPhi Artwork**. Launcher and splash use the existing HiPhi dial mark without redrawing or recoloring it. Resting artwork retains its minimal status strip.

`hiphi-logo-512.png` is copied unchanged from `roon-knob/docs/images/hiphi-logo-512.png`, asset commit `a4b5a389e5c2d2f377426f03ed0f17488d21ed46` in the existing HiPhi firmware logo set. The hiphi.audio site uses Familjen Grotesk for its brand typography; the included font comes from Google Fonts, under the bundled SIL Open Font License. Font and source mark are build inputs, outside the shipped packages.

Run `python3 roku/scripts/branding.py` with ImageMagick to regenerate both HD/FHD launcher and splash variants. The committed PNGs are bundled directly; CI needs no font or rendering dependency. Profile-specific images override shared paths during packaging.
