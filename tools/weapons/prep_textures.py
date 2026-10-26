"""Weapons Pack: prepare each gun's textures for gunsmith.gd.

For every material in textures.json writes, next to the gun's source
textures, prep/<material>_albedo.png, _normal.png (OpenGL convention),
_orm.png (R occlusion, G roughness, B metal) and _emission.png, all at most
1024 px. Usage: python -I prep_textures.py [GUN]
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SIZE = 1024


def load(path, mode):
    im = Image.open(path)
    im = im.convert(mode)
    if max(im.size) > SIZE:
        im = im.resize((SIZE, SIZE), Image.LANCZOS)
    return im


def channel(path, size, pick):
    im = Image.open(path)
    a = np.asarray(im.convert("RGB").resize(size, Image.LANCZOS), dtype=np.uint8)
    return a[:, :, {"r": 0, "g": 1, "b": 2}[pick]]


def main():
    jobs = json.load(open(os.path.join(HERE, "textures.json"), encoding="utf-8"))
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    for gun, spec in jobs.items():
        if only and gun != only:
            continue
        src = spec["dir"]
        out = os.path.join(src, "..", "prep")
        os.makedirs(out, exist_ok=True)
        for mat, t in spec["materials"].items():
            size = None
            if "albedo" in t:
                im = load(os.path.join(src, t["albedo"]), "RGB")
                size = im.size
                im.save(os.path.join(out, mat + "_albedo.png"))
            if "normal" in t:
                im = load(os.path.join(src, t["normal"]), "RGB")
                if t.get("dx"):
                    a = np.asarray(im).copy()
                    a[:, :, 1] = 255 - a[:, :, 1]
                    im = Image.fromarray(a)
                im.save(os.path.join(out, mat + "_normal.png"))
                size = size or im.size
            size = size or (SIZE, SIZE)
            if any(k in t for k in ("ao", "roughness", "metallic")):
                h, w = size[1], size[0]
                orm = np.zeros((h, w, 3), np.uint8)
                orm[:, :, 0] = channel(os.path.join(src, t["ao"]), size, t.get("ao_ch", "r")) if "ao" in t else 255
                orm[:, :, 1] = channel(os.path.join(src, t["roughness"]), size, t.get("rough_ch", "r")) if "roughness" in t else int(255 * t.get("rough", 0.55))
                orm[:, :, 2] = channel(os.path.join(src, t["metallic"]), size, t.get("metal_ch", "r")) if "metallic" in t else int(255 * t.get("metal", 0.6))
                Image.fromarray(orm).save(os.path.join(out, mat + "_orm.png"))
            if "emission" in t:
                load(os.path.join(src, t["emission"]), "RGB").save(os.path.join(out, mat + "_emission.png"))
            print(gun, mat, "ok")


if __name__ == "__main__":
    main()
