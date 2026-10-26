"""Cover art for Cleanstrike's own mods (512x512 icon.jpg in each mod folder).

Usage: python tools/make_mod_art.py
Draws at 1024 px and downsamples. Fonts: Black Ops One (SIL OFL, fetched once
into dist/cache/fonts) for titles, Segoe UI (Windows) for small labels.
"""
import math
import os
import urllib.request

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 1024
AMBER = (242, 181, 68)
AMBER_D = (176, 126, 34)
rng = np.random.default_rng(509)


def stencil_font(size):
    path = os.path.join(ROOT, "dist", "cache", "fonts", "BlackOpsOne-Regular.ttf")
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        urllib.request.urlretrieve(
            "https://github.com/google/fonts/raw/main/ofl/blackopsone/BlackOpsOne-Regular.ttf", path)
    return ImageFont.truetype(path, size)


def ui_font(size, bold=True):
    name = "segoeuib.ttf" if bold else "segoeui.ttf"
    return ImageFont.truetype(os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", name), size)


def noise(w, h, scale=1.0):
    return rng.random((h, w)) * scale


def background(glow_center=(512, 380), glow=(70, 52, 20)):
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.sqrt((x - S / 2) ** 2 + (y - S * 0.45) ** 2) / (S * 0.75)
    base = np.clip(1.0 - d, 0, 1)[..., None] * np.array([26, 28, 32]) + np.array([7, 8, 9])
    g = np.sqrt((x - glow_center[0]) ** 2 + (y - glow_center[1]) ** 2) / (S * 0.42)
    base += np.clip(1.0 - g, 0, 1)[..., None] ** 2 * np.array(glow)
    base += (noise(S, S, 14) - 7)[..., None]   # film grain
    # faint diagonal scratches
    img = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(60):
        x0, y0 = rng.integers(0, S, 2)
        ln = rng.integers(40, 220)
        a = math.radians(rng.uniform(20, 70))
        d.line([(x0, y0), (x0 + ln * math.cos(a), y0 + ln * math.sin(a))], fill=(255, 255, 255, rng.integers(4, 12)), width=1)
    return img


def vignette(img, strength=0.65):
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.sqrt((x - S / 2) ** 2 + (y - S / 2) ** 2) / (S * 0.72)
    v = 1.0 - np.clip(d, 0, 1) ** 2.2 * strength
    a = np.asarray(img).astype(np.float32) * v[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB")


def worn_text(img, text, font, cy, fill=(236, 233, 226), wear=0.16):
    """Centered stencil text with a worn, chipped finish and a soft shadow."""
    mask = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(mask)
    l, t, r, b = d.textbbox((0, 0), text, font=font)
    x = (S - (r - l)) / 2 - l
    y = cy - (b - t) / 2 - t
    d.text((x, y), text, font=font, fill=255)
    chips = (rng.random((S // 3, S // 3)) < wear).astype(np.uint8) * 255
    chips = Image.fromarray(chips, "L").resize((S, S), Image.NEAREST).filter(ImageFilter.GaussianBlur(1.2))
    worn = ImageChops.subtract(mask, chips.point(lambda v: 255 if v > 150 else 0))
    shadow = worn.filter(ImageFilter.GaussianBlur(10))
    img.paste((0, 0, 0), (0, 6), shadow.point(lambda v: v * 0.8))
    img.paste(fill, (0, 0), worn)
    return (r - l)


def dash_label(img, text, cy, size=46, color=(236, 233, 226)):
    f = stencil_font(size)
    w = worn_text(img, text, f, cy, fill=color, wear=0.08)
    d = ImageDraw.Draw(img)
    for side in (-1, 1):
        x0 = S / 2 + side * (w / 2 + 26)
        d.line([(x0, cy + 2), (x0 + side * 120, cy + 2)], fill=color, width=5)


def gradient_fill(mask, c0, c1, angle=45):
    """Fill a mask with a linear gradient (c0 -> c1)."""
    y, x = np.mgrid[0:mask.height, 0:mask.width].astype(np.float32)
    a = math.radians(angle)
    t = (x * math.cos(a) + y * math.sin(a))
    t = (t - t.min()) / max(1e-6, t.max() - t.min())
    rgb = np.array(c0)[None, None] * (1 - t[..., None]) + np.array(c1)[None, None] * t[..., None]
    out = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    out.putalpha(mask)
    return out


# ---------------------------------------------------------------- Tarkov Looting

def tarkov_looting():
    img = background(glow_center=(560, 360))
    d = ImageDraw.Draw(img, "RGBA")
    cell, cols, rows = 128, 5, 3
    gx, gy = (S - cell * cols) / 2, 196
    # container header, like the game's
    d.rectangle([gx, gy - 54, gx + cell * cols, gy - 4], fill=(20, 22, 25, 235))
    d.text((gx + 18, gy - 47), "DEAD SCAV  -  SEARCHING...", font=ui_font(26), fill=(200, 198, 190))
    # grid
    d.rectangle([gx, gy, gx + cell * cols, gy + cell * rows], fill=(14, 15, 17, 240))
    for c in range(cols + 1):
        d.line([(gx + c * cell, gy), (gx + c * cell, gy + rows * cell)], fill=(46, 50, 56), width=2)
    for r in range(rows + 1):
        d.line([(gx, gy + r * cell), (gx + cols * cell, gy + r * cell)], fill=(46, 50, 56), width=2)

    def cellbox(c, r, w=1, h=1, inset=3):
        return [gx + c * cell + inset, gy + r * cell + inset, gx + (c + w) * cell - inset, gy + (r + h) * cell - inset]

    # revealed rifle (4x1), weapon-tinted cell, short name
    b = cellbox(0, 0, 4, 1)
    d.rectangle(b, fill=(30, 30, 30, 255))
    x0, y0 = b[0] + 22, b[1] + 22

    def P(pts):
        return [(x0 + px, y0 + py) for px, py in pts]
    steel, wood, hi = (138, 144, 152), (120, 112, 104), (186, 192, 200)
    d.polygon(P([(0, 26), (96, 20), (112, 24), (112, 46), (96, 48), (10, 70), (0, 66)]), fill=wood)           # stock
    d.polygon(P([(106, 18), (236, 18), (236, 44), (106, 44)]), fill=steel)                                     # receiver
    d.polygon(P([(214, 10), (230, 10), (230, 18), (214, 18)]), fill=steel)                                     # rear sight
    d.polygon(P([(150, 44), (176, 44), (170, 80), (146, 78)]), fill=wood)                                      # pistol grip
    d.polygon(P([(196, 44), (228, 44), (238, 66), (252, 96), (226, 104), (212, 72)]), fill=steel)              # magazine
    d.polygon(P([(236, 20), (334, 20), (334, 42), (236, 42)]), fill=wood)                                      # handguard
    d.polygon(P([(236, 13), (322, 13), (322, 20), (236, 20)]), fill=steel)                                     # gas tube
    d.polygon(P([(334, 26), (446, 26), (446, 33), (334, 33)]), fill=steel)                                     # barrel
    d.polygon(P([(426, 14), (434, 14), (434, 26), (426, 26)]), fill=steel)                                     # front sight
    d.polygon(P([(446, 23), (462, 23), (462, 36), (446, 36)]), fill=steel)                                     # muzzle
    d.line(P([(106, 18), (236, 18)]), fill=hi, width=3)
    d.line(P([(334, 26), (446, 26)]), fill=hi, width=2)
    d.text((b[2] - 70, b[1] + 6), "AKM", font=ui_font(24), fill=(230, 228, 220))

    # unknown magazine (1x2): flat silhouette + "?"
    b = cellbox(4, 0, 1, 2)
    d.rectangle(b, fill=(26, 27, 29))
    mx, my = b[0] + 38, b[1] + 26
    mag = [(mx, my), (mx + 46, my), (mx + 50, my + 70), (mx + 64, my + 150), (mx + 70, my + 196), (mx + 22, my + 204),
           (mx + 14, my + 156), (mx + 2, my + 76)]
    d.polygon(mag, fill=(40, 42, 45))
    q = ui_font(64)
    d.text(((b[0] + b[2]) / 2, (b[1] + b[3]) / 2), "?", font=q, fill=(222, 220, 212), anchor="mm")

    # the item being searched (2x2): grey ghost + amber spinner
    b = cellbox(0, 1, 2, 2)
    d.rectangle(b, fill=(22, 23, 25))
    ghost = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(ghost)
    bx0, by0, bx1, by1 = b[0] + 46, b[1] + 70, b[2] - 46, b[3] - 40
    gd.rounded_rectangle([bx0, by0, bx1, by1], 14, fill=(150, 152, 150, 80))
    gd.rounded_rectangle([bx0 + 60, by0 - 30, bx1 - 60, by0 + 6], 8, fill=(150, 152, 150, 80))
    cx, cy = (bx0 + bx1) / 2, (by0 + by1) / 2
    gd.rectangle([cx - 14, cy - 44, cx + 14, cy + 44], fill=(150, 152, 150, 110))
    gd.rectangle([cx - 44, cy - 14, cx + 44, cy + 14], fill=(150, 152, 150, 110))
    img.paste(ghost, (0, 0), ghost)
    d = ImageDraw.Draw(img, "RGBA")
    sc = ((b[0] + b[2]) / 2, (b[1] + b[3]) / 2)
    d.ellipse([sc[0] - 46, sc[1] - 46, sc[0] + 46, sc[1] + 46], outline=(255, 255, 255, 40), width=9)
    d.arc([sc[0] - 46, sc[1] - 46, sc[0] + 46, sc[1] + 46], 200, 310, fill=AMBER + (255,), width=9)

    # small unknown item (1x1) + "?"
    b = cellbox(4, 2)
    d.rectangle(b, fill=(26, 27, 29))
    d.rounded_rectangle([b[0] + 36, b[1] + 30, b[2] - 36, b[3] - 26], 10, fill=(40, 42, 45))
    d.text(((b[0] + b[2]) / 2, (b[1] + b[3]) / 2), "?", font=ui_font(54), fill=(222, 220, 212), anchor="mm")

    # magnifier over the grid
    lens = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lens)
    lc, lr = (640, 520), 112
    ld.ellipse([lc[0] - lr, lc[1] - lr, lc[0] + lr, lc[1] + lr], fill=(242, 181, 68, 26))
    a = math.radians(45)
    hx0, hy0 = lc[0] + (lr + 6) * math.cos(a), lc[1] + (lr + 6) * math.sin(a)
    hx1, hy1 = hx0 + 150 * math.cos(a), hy0 + 150 * math.sin(a)
    shadow = Image.new("L", (S, S), 0)
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([lc[0] - lr - 14, lc[1] - lr - 14, lc[0] + lr + 14, lc[1] + lr + 14], outline=255, width=40)
    sd.line([(hx0, hy0), (hx1, hy1)], fill=255, width=48)
    img.paste((0, 0, 0), (8, 14), shadow.filter(ImageFilter.GaussianBlur(14)).point(lambda v: v * 0.7))
    img.paste(lens, (0, 0), lens)
    ring = Image.new("L", (S, S), 0)
    rd = ImageDraw.Draw(ring)
    rd.ellipse([lc[0] - lr - 12, lc[1] - lr - 12, lc[0] + lr + 12, lc[1] + lr + 12], outline=255, width=26)
    rd.line([(hx0, hy0), (hx1, hy1)], fill=255, width=40)
    rd.ellipse([hx1 - 20, hy1 - 20, hx1 + 20, hy1 + 20], fill=255)
    metal = gradient_fill(ring, (255, 214, 120), AMBER_D, angle=60)
    img.paste(metal, (0, 0), metal)
    d = ImageDraw.Draw(img, "RGBA")
    d.arc([lc[0] - lr + 18, lc[1] - lr + 18, lc[0] + lr - 18, lc[1] + lr - 18], 200, 250, fill=(255, 255, 255, 90), width=6)

    img = vignette(img)
    dash_label(img, "TARKOV", 770)
    worn_text(img, "LOOTING", stencil_font(176), 880)
    return img


# ---------------------------------------------------------------- Fixes Overhaul

def tool_mask(draw_fn, angle):
    m = Image.new("L", (S, S), 0)
    draw_fn(ImageDraw.Draw(m))
    return m.rotate(angle, resample=Image.BICUBIC, center=(S / 2, S / 2))


def fixes_overhaul():
    img = background(glow_center=(512, 380), glow=(80, 58, 18))
    cx, cy = S / 2, 380
    # crosshair ring, like the Cleanstrike logo
    ring = Image.new("L", (S, S), 0)
    rd = ImageDraw.Draw(ring)
    R = 268
    for start in (8, 98, 188, 278):
        rd.arc([cx - R, cy - R, cx + R, cy + R], start, start + 74, fill=255, width=16)
    for a in (0, 90, 180, 270):
        t = math.radians(a)
        rd.line([(cx + (R - 46) * math.cos(t), cy + (R - 46) * math.sin(t)),
                 (cx + (R + 70) * math.cos(t), cy + (R + 70) * math.sin(t))], fill=255, width=14)
    amber = gradient_fill(ring, (250, 205, 110), AMBER_D, angle=45)
    img.paste(amber, (0, 0), amber)

    oy = cy - S / 2   # tools are drawn around the canvas centre, then moved up

    def wrench(d):
        d.rounded_rectangle([cx - 250, S / 2 - 30, cx + 210, S / 2 + 30], 26, fill=255)
        d.ellipse([cx + 160, S / 2 - 92, cx + 344, S / 2 + 92], fill=255)
        d.polygon([(cx + 262, S / 2 - 34), (cx + 380, S / 2 - 60), (cx + 380, S / 2 + 60), (cx + 262, S / 2 + 34)], fill=0)
        d.ellipse([cx - 336, S / 2 - 78, cx - 180, S / 2 + 78], fill=255)
        hexr = 34
        d.polygon([(cx - 258 + hexr * math.cos(math.radians(60 * k)), S / 2 + hexr * math.sin(math.radians(60 * k))) for k in range(6)], fill=0)

    def driver_shaft(d):
        d.rectangle([cx - 30, S / 2 - 13, cx + 250, S / 2 + 13], fill=255)
        d.polygon([(cx + 250, S / 2 - 13), (cx + 300, S / 2 - 5), (cx + 300, S / 2 + 5), (cx + 250, S / 2 + 13)], fill=255)

    def driver_handle(d):
        d.rounded_rectangle([cx - 320, S / 2 - 44, cx - 30, S / 2 + 44], 38, fill=255)

    for fn, angle, c0, c1 in ((driver_shaft, -45, (220, 225, 232), (96, 102, 110)),
                             (driver_handle, -45, (70, 74, 80), (24, 26, 29))):
        m = tool_mask(fn, angle)
        sh = m.filter(ImageFilter.GaussianBlur(12))
        img.paste((0, 0, 0), (10, int(oy) + 14), sh.point(lambda v: v * 0.6))
        layer = gradient_fill(m, c0, c1, angle=30)
        img.paste(layer, (0, int(oy)), layer)
    # grip grooves on the handle
    gm = Image.new("L", (S, S), 0)
    gdraw = ImageDraw.Draw(gm)
    for k in range(5):
        x = cx - 290 + k * 54
        gdraw.rectangle([x, S / 2 - 30, x + 14, S / 2 + 30], fill=255)
    gm = gm.rotate(-45, resample=Image.BICUBIC, center=(S / 2, S / 2))
    img.paste((242, 181, 68), (0, int(oy)), gm.point(lambda v: v * 0.85))

    m = tool_mask(wrench, 45)
    img.paste((0, 0, 0), (12, int(oy) + 18), m.filter(ImageFilter.GaussianBlur(14)).point(lambda v: v * 0.7))
    layer = gradient_fill(m, (255, 222, 140), (150, 104, 24), angle=60)
    img.paste(layer, (0, int(oy)), layer)
    edge = ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(5)))
    img.paste((255, 240, 200), (0, int(oy)), edge.point(lambda v: v * 0.35))

    img = vignette(img)
    dash_label(img, "CLEANSTRIKE", 742, size=42)
    worn_text(img, "FIXES", stencil_font(168), 842)
    worn_text(img, "OVERHAUL", stencil_font(70), 946, fill=AMBER, wear=0.1)
    return img


def save(img, folder):
    out = os.path.join(ROOT, "mods", folder, "icon.jpg")
    img.resize((512, 512), Image.LANCZOS).save(out, quality=90, optimize=True)
    print("wrote", out)


if __name__ == "__main__":
    save(tarkov_looting(), "TarkovLooting")
    save(fixes_overhaul(), "FixesOverhaul")
