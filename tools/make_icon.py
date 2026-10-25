"""Render the Cleanstrike mark (dark rounded tile, amber strike) to .ico and .png."""
import sys
from PIL import Image, ImageDraw

def mark(size):
    s = size * 4  # supersample
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    r = int(s * 0.22)
    d.rounded_rectangle([0, 0, s - 1, s - 1], r, fill=(22, 24, 28, 255), outline=(48, 53, 60, 255), width=max(1, s // 64))
    # strike: a slanted parallelogram, plus a faint echo line
    w = s * 0.17
    x0, y0, x1, y1 = s * 0.30, s * 0.80, s * 0.70, s * 0.20
    d.polygon([(x0 - w / 2, y0), (x0 + w / 2, y0), (x1 + w / 2, y1), (x1 - w / 2, y1)], fill=(242, 181, 68, 255))
    e = s * 0.05
    ox = -s * 0.22
    d.polygon([(x0 - e / 2 + ox, y0 - s * 0.1), (x0 + e / 2 + ox, y0 - s * 0.1), (x1 + e / 2 + ox, y1 + s * 0.1), (x1 - e / 2 + ox, y1 + s * 0.1)], fill=(242, 181, 68, 110))
    return im.resize((size, size), Image.LANCZOS)

out = sys.argv[1]
big = mark(256)
big.save(out + ".png")
big.save(out + ".ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("wrote", out + ".ico")
