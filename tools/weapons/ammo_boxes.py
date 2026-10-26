"""CleanStrike Weapons Pack: box art for the pack's new calibres.

Paints a 512x512 texture for the game's ammo box model (the vanilla .45 ACP /
.308 boxes share one layout: a cross unwrap, front label at 80..256 x
80..192) with original labels under a made-up maker, "Nordvek".
Usage: python -I tools/weapons/ammo_boxes.py  ->  mods/WeaponsPack/CSWeaponsPack/Ammo/<art>_Box.png
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "mods", "WeaponsPack", "CSWeaponsPack", "Ammo")
FONTS = "C:/Windows/Fonts/"

# face rectangles (x0, y0, x1, y1) in the 512 texture
FRONT = (80, 80, 256, 192)
BACK = (320, 80, 496, 192)
END_L = (16, 80, 80, 192)
END_R = (256, 80, 320, 192)
TOP = (80, 192, 256, 256)
BOTTOM = (80, 16, 256, 80)

BOXES = {
    "Ammo_50AE": {"cal": ".50 AE", "load": "300 GR  JHP", "count": 20, "body": (74, 22, 24), "accent": (214, 170, 72), "ink": (245, 236, 220)},
    "Ammo_127x55": {"cal": "12.7×55", "load": "STs-130  SUBSONIC", "count": 20, "body": (70, 78, 52), "accent": (196, 182, 120), "ink": (232, 228, 206), "military": True},
    "Ammo_50BMG": {"cal": ".50 BMG", "load": "M33 BALL  660 GR", "count": 10, "body": (92, 84, 58), "accent": (40, 38, 30), "ink": (236, 230, 210), "military": True},
    "Ammo_57x28": {"cal": "5.7×28", "load": "SS190  FMJ", "count": 50, "body": (28, 30, 34), "accent": (232, 120, 32), "ink": (240, 240, 240)},
    "Ammo_PowerCell": {"cal": "PLASMA CELLS", "load": "HANDLE WITH CARE", "count": 20, "body": (150, 128, 96), "accent": (60, 230, 150), "ink": (24, 30, 26), "homemade": True},
}


def font(name, size, bold=True):
    try:
        f = ImageFont.truetype(FONTS + name, size)
        if name == "bahnschrift.ttf":
            f.set_variation_by_name("Bold" if bold else "Regular")
        return f
    except OSError:
        return ImageFont.truetype(FONTS + "arialbd.ttf", size)


def fit_font(draw, text, name, max_w, max_h):
    size = max_h
    while size > 6:
        f = font(name, size)
        b = draw.textbbox((0, 0), text, font=f)
        if b[2] - b[0] <= max_w and b[3] - b[1] <= max_h:
            return f
        size -= 1
    return font(name, 6)


def text_center(draw, rect, text, f, fill):
    b = draw.textbbox((0, 0), text, font=f)
    x = (rect[0] + rect[2]) / 2 - (b[2] - b[0]) / 2 - b[0]
    y = (rect[1] + rect[3]) / 2 - (b[3] - b[1]) / 2 - b[1]
    draw.text((x, y), text, font=f, fill=fill)


def rotated_text(img, rect, text, fname, fill, angle):
    w, h = rect[2] - rect[0], rect[3] - rect[1]
    tw, th = (h, w) if angle in (90, 270) else (w, h)
    layer = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = fit_font(d, text, fname, int(tw * 0.86), int(th * 0.62))
    text_center(d, (0, 0, tw, th), text, f, fill)
    layer = layer.rotate(angle, expand=True)
    img.alpha_composite(layer, (rect[0], rect[1]))


def cardboard(color, rng):
    a = np.zeros((512, 512, 3), np.float32) + np.array(color, np.float32)
    grain = rng.normal(0, 7, (512, 512, 1)).astype(np.float32)
    streak = np.repeat(rng.normal(0, 5, (1, 512, 1)), 512, axis=0).astype(np.float32)
    a = np.clip(a + grain + streak, 0, 255).astype(np.uint8)
    return Image.fromarray(a).convert("RGBA").filter(ImageFilter.GaussianBlur(0.6))


def cartridge(draw, x, y, length, dia, brass=(196, 160, 82), tip=(150, 108, 70)):
    case = int(length * 0.68)
    draw.rounded_rectangle((x, y, x + case, y + dia), radius=2, fill=brass, outline=(110, 86, 40))
    draw.rectangle((x - 2, y - 1, x + 2, y + dia + 1), fill=(150, 120, 60))
    draw.polygon([(x + case, y), (x + length, y + dia / 2), (x + case, y + dia)], fill=tip, outline=(90, 64, 40))


def barcode(draw, rect, rng):
    x = rect[0]
    while x < rect[2]:
        w = int(rng.integers(1, 3))
        if rng.random() > 0.35:
            draw.rectangle((x, rect[1], x + w - 1, rect[3]), fill=(20, 20, 20))
        x += w + 1


def paint(art, b):
    rng = np.random.default_rng(abs(hash(art)) % (2 ** 32))
    img = cardboard(b["body"], rng)
    d = ImageDraw.Draw(img)
    ink, acc = b["ink"], b["accent"]
    home = b.get("homemade", False)
    # front label
    fx0, fy0, fx1, fy1 = FRONT
    if home:
        d.rectangle((fx0 + 6, fy0 + 10, fx1 - 6, fy1 - 10), fill=(226, 222, 200))          # taped paper label
        for tx in (fx0 + 2, fx1 - 30):
            d.rectangle((tx, fy0 + 4, tx + 28, fy0 + 16), fill=(200, 196, 160, 220))
        f = fit_font(d, b["cal"], "segoepr.ttf", fx1 - fx0 - 24, 26)
        text_center(d, (fx0, fy0 + 18, fx1, fy0 + 58), b["cal"], f, (30, 120, 70))
        f2 = fit_font(d, b["load"], "segoepr.ttf", fx1 - fx0 - 30, 14)
        text_center(d, (fx0, fy0 + 60, fx1, fy0 + 80), b["load"], f2, (150, 40, 30))
        f3 = fit_font(d, "20 SHOTS EACH · DO NOT SHAKE", "segoepr.ttf", fx1 - fx0 - 30, 11)
        text_center(d, (fx0, fy0 + 82, fx1, fy1 - 12), "20 SHOTS EACH · DO NOT SHAKE", f3, (40, 40, 40))
        d.ellipse((fx1 - 40, fy0 + 20, fx1 - 18, fy0 + 42), outline=(40, 200, 120), width=3)
    else:
        d.rectangle((fx0, fy0, fx1, fy0 + 18), fill=acc)
        text_center(d, (fx0, fy0, fx1, fy0 + 18), "NORDVEK", fit_font(d, "NORDVEK", "bahnschrift.ttf", 80, 13), b["body"])
        if b.get("military"):
            d.rectangle((fx0 + 6, fy0 + 24, fx1 - 6, fy1 - 8), outline=ink, width=2)
        f = fit_font(d, b["cal"], "bahnschrift.ttf", fx1 - fx0 - 24, 34)
        text_center(d, (fx0, fy0 + 22, fx1, fy0 + 62), b["cal"], f, ink)
        f2 = fit_font(d, b["load"], "bahnschrift.ttf", fx1 - fx0 - 30, 13)
        text_center(d, (fx0, fy0 + 64, fx1, fy0 + 80), b["load"], f2, acc)
        cnt = "%d CARTRIDGES" % b["count"]
        text_center(d, (fx0, fy0 + 82, fx1, fy0 + 96), cnt, fit_font(d, cnt, "bahnschrift.ttf", 110, 11), ink)
        cartridge(d, fx0 + 40, fy1 - 14, 96, 8)
    # back: small print, barcode, warning
    bx0, by0, bx1, by1 = BACK
    small = font("bahnschrift.ttf", 7, False)
    for i in range(9):
        w = int(rng.integers(60, 150))
        d.rectangle((bx0 + 8, by0 + 10 + i * 9, bx0 + 8 + w, by0 + 13 + i * 9), fill=tuple(int(c * 0.75) for c in ink))
    d.rectangle((bx1 - 64, by1 - 34, bx1 - 8, by1 - 8), fill=(236, 236, 230))
    barcode(d, (bx1 - 60, by1 - 31, bx1 - 12, by1 - 14), rng)
    d.text((bx1 - 60, by1 - 15), "6 41 2077 09", font=small, fill=(20, 20, 20))
    d.polygon([(bx1 - 84, by1 - 8), (bx1 - 72, by1 - 30), (bx1 - 60 - 24 + 36, by1 - 8)], outline=acc, width=2)
    # ends, top and bottom
    for rect, ang in ((END_L, 90), (END_R, 270)):
        rotated_text(img, rect, b["cal"], "segoepr.ttf" if home else "bahnschrift.ttf", ink if not home else (30, 120, 70), ang)
    d = ImageDraw.Draw(img)
    top = "%s · %d" % (b["cal"], b["count"])
    text_center(d, TOP, top, fit_font(d, top, "segoepr.ttf" if home else "bahnschrift.ttf", 150, 26), ink if not home else (30, 30, 30))
    rotated_text(img, BOTTOM, "NORDVEK" if not home else "WORKSHOP BATCH 7", "bahnschrift.ttf", tuple(int(c * 0.8) for c in ink), 180)
    # wear
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    yy, xx = np.mgrid[0:512, 0:512]
    a *= (0.93 + 0.07 * rng.random((512, 512, 1))).astype(np.float32)
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, art + "_Box.png"))
    print("wrote", art)


if __name__ == "__main__":
    for art, b in BOXES.items():
        paint(art, b)
