#!/usr/bin/env python3
"""Draw the Dot Shell boot splash's images in the era's colors.

  build.py <ghostty dotshell.conf> <out dir>

The colors come from Dot Shell's Ghostty export (the era on screen when this
runs): background = the era's glass, cursor-color = its first tube,
selection-background = its unlit dot. The sign is the pixel font's DOT SHELL,
one dot per font pixel. Run by system/install.sh; rerun it after an era change
to repaint the splash.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/OTF/DepartureMonoNerdFont-Regular.otf"
PITCH = 8       # px per dot
DOT = 6         # dot diameter, px
TEXT = "DOT SHELL"


def colors(conf: Path) -> dict:
    out = {}
    for line in conf.read_text().splitlines():
        if "=" in line and not line.startswith("#"):
            k, v = (s.strip() for s in line.split("=", 1))
            out[k] = v
    return {"glass": out.get("background", "#000000"),
            "lit": out.get("cursor-color", "#ffb000"),
            "unlit": out.get("selection-background", "#202020")}


def dot(color: str) -> Image.Image:
    img = Image.new("RGBA", (PITCH, PITCH), (0, 0, 0, 0))
    o = (PITCH - DOT) / 2
    ImageDraw.Draw(img).ellipse((o, o, o + DOT - 1, o + DOT - 1), fill=color)
    return img


def main() -> None:
    conf, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    c = colors(conf)

    # The sign: the text at the font's own 11 px, no antialiasing, so every
    # font pixel is one dot; a board of unlit dots around it.
    font = ImageFont.truetype(FONT, 11)
    w = int(font.getlength(TEXT))
    mask = Image.new("1", (w, 11), 0)
    d = ImageDraw.Draw(mask)
    d.fontmode = "1"
    d.text((0, 0), TEXT, font=font, fill=1)
    pad = 3
    cols, rows = w + pad * 2, 11 + pad * 2
    lit, unlit = dot(c["lit"]), dot(c["unlit"])
    sign = Image.new("RGBA", (cols * PITCH, rows * PITCH), (0, 0, 0, 0))
    for y in range(rows):
        for x in range(cols):
            on = pad <= x < pad + w and pad <= y < pad + 11 and mask.getpixel((x - pad, y - pad))
            sign.alpha_composite(lit if on else unlit, (x * PITCH, y * PITCH))
    sign.save(out / "sign.png")
    lit.save(out / "lit.png")
    unlit.save(out / "dim.png")
    Image.new("RGB", (16, 16), c["glass"]).save(out / "bg.png")
    print(f"dotshell splash: {c['lit']} on {c['glass']} -> {out}")


if __name__ == "__main__":
    main()
