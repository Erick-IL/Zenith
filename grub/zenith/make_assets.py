#!/usr/bin/env python3
"""Generate images for the GRUB theme \"Zenith\".

Background — wallpaper of Fav theme. Bootloader cannot read
Hyprland config, so image is placed next to theme and dimmed/vignetted
here so that menu text remains readable.

    python3 make_assets.py [ширина] [высота] [путь_к_обоям]
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

W = int(sys.argv[1]) if len(sys.argv) > 1 else 1920
H = int(sys.argv[2]) if len(sys.argv) > 2 else 1080
HERE = os.path.dirname(os.path.abspath(__file__))
WALL = sys.argv[3] if len(sys.argv) > 3 else os.path.join(HERE, "wallpaper.jpg")


def cover(img, w, h):
    """Scale \"cover\": fill w×h without borders, crop center."""
    iw, ih = img.size
    scale = max(w / iw, h / ih)
    nw, nh = int(iw * scale + 0.5), int(ih * scale + 0.5)
    img = img.resize((nw, nh), Image.LANCZOS)
    x = (nw - w) // 2
    y = (nh - h) // 2
    return img.crop((x, y, x + w, y + h))


def build_background():
    base = Image.open(WALL).convert("RGB")
    img = cover(base, W, H)

    # The wallpaper is already dark - dim it a little more so that the menu text is white
    # confidently read over any part of them.
    img = ImageEnhance.Brightness(img).enhance(0.62)
    img = ImageEnhance.Contrast(img).enhance(0.96)

    # Soft vignette: draws attention to the center, where the menu is, and draws attention
    # edges in black - there the tips are typed in muted gray.
    vign = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vign)
    maxd = math.hypot(W / 2, H / 2)
    step = 4
    for y in range(0, H, step):
        for x in range(0, W, step):
            d = math.hypot(x - W / 2, y - H / 2) / maxd
            vd.rectangle((x, y, x + step - 1, y + step - 1),
                         fill=int(min(255, 255 * d ** 2 * 1.1)))
    vign = vign.filter(ImageFilter.GaussianBlur(40))
    img = Image.composite(Image.new("RGB", (W, H), (3, 3, 4)), img, vign)

    # Light horizontal “background” under the menu column: smooth, dark
    # a stripe in the center so that the lines do not drown in the light bokeh spots.
    band = Image.new("L", (W, H), 0)
    bd = ImageDraw.Draw(band)
    bx0, bx1 = int(W * 0.30), int(W * 0.70)
    by0, by1 = int(H * 0.26), int(H * 0.80)
    bd.rectangle((bx0, by0, bx1, by1), fill=150)
    band = band.filter(ImageFilter.GaussianBlur(90))
    dark = Image.new("RGB", (W, H), (0, 0, 0))
    img = Image.composite(dark, img, band.point(lambda v: int(v * 0.55)))

    img.save(os.path.join(HERE, "background.png"))


def rounded(size, radius, fill, border, width=1):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius,
                        fill=fill, outline=border, width=width)
    return img


def slice9(img, name, corner):
    """Slice image into 9 parts for GRUB styled box."""
    w, h = img.size
    parts = {
        "nw": (0, 0, corner, corner),
        "n": (corner, 0, w - corner, corner),
        "ne": (w - corner, 0, w, corner),
        "w": (0, corner, corner, h - corner),
        "c": (corner, corner, w - corner, h - corner),
        "e": (w - corner, corner, w, h - corner),
        "sw": (0, h - corner, corner, h),
        "s": (corner, h - corner, w - corner, h),
        "se": (w - corner, h - corner, w, h),
    }
    for key, box in parts.items():
        img.crop(box).save(os.path.join(HERE, f"{name}_{key}.png"))


def build_boxes():
    # The highlighted item is a dark capsule with a glass outline.
    #
    # The angle specifies both the radius of the capsule and the frame margin that GRUB adds
    # to the line above and below. In theme.txt the gap between items (28) is larger
    # double angle (24), so the backlight does not interfere with its neighbors.
    corner = 12
    side = corner * 2 + 6
    sel = rounded((side, side), corner,
                  (10, 10, 12, 235), (255, 255, 255, 60))
    slice9(sel, "select", corner)

    # Console and bootloader message box: much more transparent than before. In it
    # GRUB prints "Loading Linux..." before starting the kernel, and is opaque
    # the fill read like a black window popping up in the middle of the screen.
    box = 14
    menu = rounded((box * 2 + 6, box * 2 + 6), box,
                   (8, 8, 10, 110), (255, 255, 255, 20))
    slice9(menu, "menu", box)


if __name__ == "__main__":
    build_background()
    build_boxes()
    print("done")
