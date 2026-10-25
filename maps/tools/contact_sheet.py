"""Lay gallery PNGs out as labelled contact sheets. Usage: contact_sheet.py <dir> <out_prefix> [cols] [rows]"""
import os, sys
from PIL import Image, ImageDraw, ImageFont
d, prefix = sys.argv[1], sys.argv[2]
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 4
rows = int(sys.argv[4]) if len(sys.argv) > 4 else 4
files = sorted(f for f in os.listdir(d) if f.endswith(".png"))
try:
    font = ImageFont.truetype("arial.ttf", 18)
except OSError:
    font = None
per = cols * rows
for s in range(0, len(files), per):
    sheet = Image.new("RGB", (cols * 480, rows * 300), (20, 20, 20))
    dr = ImageDraw.Draw(sheet)
    for k, f in enumerate(files[s:s + per]):
        x, y = (k % cols) * 480, (k // cols) * 300
        sheet.paste(Image.open(os.path.join(d, f)).convert("RGB"), (x, y))
        dr.rectangle([x, y + 270, x + 480, y + 300], fill=(0, 0, 0))
        dr.text((x + 6, y + 274), f[:-4], fill=(255, 220, 120), font=font)
    sheet.save(f"{prefix}_{s // per + 1}.png")
    print(f"{prefix}_{s // per + 1}.png", len(files[s:s + per]))
