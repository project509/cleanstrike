"""Draw layout.json over re3mr's map to check the tracing. Usage: overlay.py layout.json re3mr.png out.png"""
import json, sys
from PIL import Image, ImageDraw
Image.MAX_IMAGE_PIXELS = None
L = json.load(open(sys.argv[1]))
src = Image.open(sys.argv[2]).convert("RGB")
PPM, S = 7.38, 1.5
im = src.resize((int(src.size[0] / PPM * S), int(src.size[1] / PPM * S)), Image.LANCZOS)
d = ImageDraw.Draw(im, "RGBA")
P = lambda p: (p[0] * S, p[1] * S)
d.polygon([P(p) for p in L["playable_boundary"]], outline=(255, 255, 255, 255))
for r in L["roads"]:
    d.line([P(p) for p in r["points"]], fill=(255, 140, 0, 200), width=max(2, int(r["width"] * S)))
for r in L["rails"]:
    d.line([P(p) for p in r["points"]], fill=(200, 60, 255, 230), width=3)
d.line([P(p) for p in L["river"]["points"]], fill=(40, 120, 255, 110), width=int(L["river"]["width"] * S))
for b in L["bridges"]:
    d.line([P(b["from"]), P(b["to"])], fill=(255, 255, 0, 255), width=int(b["width"] * S))
for b in L["buildings"]:
    x0, z0, x1, z1 = b["rect"]
    d.rectangle([P((x0, z0)), P((x1, z1))], outline=(0, 255, 120, 255), width=2)
for t in L["tanks"]:
    (x, z), r = t["center"], t["radius"]
    d.ellipse([P((x - r, z - r)), P((x + r, z + r))], outline=(0, 255, 255, 255), width=2)
for c in L["chimneys"]:
    x, z = c["pos"]; d.ellipse([P((x - 3, z - 3)), P((x + 3, z + 3))], fill=(255, 0, 0, 255))
for e in L["exits"]:
    x, z = e["pos"]; d.rectangle([P((x - 4, z - 4)), P((x + 4, z + 4))], fill=(255, 40, 40, 255))
im.save(sys.argv[3])
