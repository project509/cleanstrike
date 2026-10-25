"""Cut tileable wall/roof swatches out of Vostok's trim-sheet textures.

Generated Customs buildings use these with world-space (triplanar) mapping,
so they share the look of Vostok's own buildings.
Usage: python -I textures.py <RTVProject> <out_dir>
Writes <name>_AL.png and <name>_NR.png (1024 px) plus swatches.json with the
real-world size (metres) each tile covers.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

P, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)

# name: (atlas base path without _AL/_NR, crop box as fractions, metres covered by the tile (w, h))
SWATCHES = {
    "metal_rust":   ("Assets/Garage_Highway/Files/TX_Garage_Highway_Exterior", (0.03, 0.02, 0.97, 0.50), (6.0, 3.2)),
    "brick_grey":   ("Assets/Office_Airfield/Files/TX_Office_Airfield_Exterior", (0.03, 0.02, 0.97, 0.52), (4.0, 2.2)),
    "brick_red":    ("Assets/Shack_Brick/Files/TX_Shack_Brick_Exterior", (0.03, 0.02, 0.97, 0.36), (4.0, 1.6)),
    "concrete":     ("Assets/Garage_Highway/Files/TX_Garage_Highway_Interior", (0.03, 0.02, 0.97, 0.38), (6.0, 2.4)),
    "roof_metal":   ("Assets/Garage_Highway/Files/TX_Garage_Highway_Roof", (0.03, 0.03, 0.84, 0.97), (5.0, 5.0)),
    "roof_tar":     ("Assets/Shack_Brick/Files/TX_Shack_Brick_Roof", (0.03, 0.02, 0.97, 0.48), (6.0, 3.0)),
    "metal_red":    ("Assets/Container_Shipping/Files/TX_Container_Shipping", (0.03, 0.03, 0.68, 0.43), (4.0, 2.6)),
    "slab":         ("Assets/Slab_Concrete/Files/TX_Slab_Concrete", (0.03, 0.03, 0.97, 0.97), (3.0, 3.0)),
}
SIZE = 1024


def seamless(a: np.ndarray) -> np.ndarray:
    """Cross-fade with a half-rolled copy so the tile wraps without seams."""
    h, w = a.shape[:2]
    rolled = np.roll(np.roll(a, h // 2, axis=0), w // 2, axis=1)
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum.reduce([xx, w - 1 - xx, yy, h - 1 - yy]).astype(np.float32)
    weight = np.clip(edge / (min(h, w) * 0.28), 0, 1)[..., None]
    return a * weight + rolled * (1 - weight)


meta = {}
for name, (base, (x0, y0, x1, y1), metres) in SWATCHES.items():
    for kind in ("AL", "NR"):
        src = None
        for ext in (".png", ".tga", ".jpg"):
            p = os.path.join(P, base + "_" + kind + ext)
            if os.path.exists(p):
                src = p
                break
        if src is None:
            if kind == "AL":
                print("missing", base)
            continue
        im = Image.open(src).convert("RGB")
        W, H = im.size
        crop = im.crop((int(x0 * W), int(y0 * H), int(x1 * W), int(y1 * H)))
        crop = crop.resize((SIZE, max(64, int(SIZE * metres[1] / metres[0]))), Image.LANCZOS)
        arr = seamless(np.asarray(crop, dtype=np.float32))
        Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(os.path.join(OUT, f"{name}_{kind}.png"))
    meta[name] = {"metres": metres}
json.dump(meta, open(os.path.join(OUT, "swatches.json"), "w"), indent=1)
print("swatches:", ", ".join(meta))
