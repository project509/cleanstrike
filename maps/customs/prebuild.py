"""Customs pre-build: turns layout.json into data the Godot builder consumes.

Outputs (into the given folder):
  heights.f32   float32 height grid, row-major (z rows, x columns), metres
  classes.u8    uint8 surface class per grid cell: 0 grass, 1 dirt, 2 concrete/asphalt, 3 water
  mask_0.png, mask_1.png   2048x2048 terrain road masks (R dirt, G asphalt, B concrete)
  trees.json    [[x, z, variant, scale, yaw], ...] in layout metres
  meta.json     grid and tile geometry for the builder

Usage: python -I prebuild.py layout.json out_dir
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

L = json.load(open(sys.argv[1], encoding="utf-8"))
OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1337)

# ------------------------------------------------------------------ grid
X0, Z0 = -100.0, 20.0           # terrain area in layout metres
TILE = 640.0                    # two 640 m tiles keep Vostok's texel density (600 m / tiling 120)
NT = 2
SPACING = 2.5
NX = int(TILE * NT / SPACING) + 1
NZ = int(TILE / SPACING) + 1
xs = X0 + np.arange(NX) * SPACING
zs = Z0 + np.arange(NZ) * SPACING
GX, GZ = np.meshgrid(xs, zs)


def raster(shapes, res, w, h, x0, z0, draw_fn):
    """Rasterise into a float mask using PIL at `res` metres per pixel."""
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    P = lambda p: ((p[0] - x0) / res, (p[1] - z0) / res)
    for s in shapes:
        draw_fn(d, s, P, res)
    return np.asarray(img, dtype=np.float32) / 255.0


def poly_fn(d, s, P, res):
    d.polygon([P(p) for p in s], fill=255)


def line_fn(width_key):
    def f(d, s, P, res):
        pts = [P(p) for p in s["points"]]
        wpx = max(1, int(round(s.get(width_key, 1.0) / res)))
        d.line(pts, fill=255, width=wpx, joint="curve")
        r = wpx / 2
        for x, y in pts:
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return f


def grid_mask(shapes, fn):
    return raster(shapes, SPACING, NX, NZ, X0, Z0, fn)


def dist_outside(mask, res):
    """Metres from each cell to the nearest cell inside `mask`."""
    return ndimage.distance_transform_edt(mask < 0.5) * res


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def smooth_noise(sigma_m, amp=1.0):
    n = ndimage.gaussian_filter(rng.standard_normal((NZ, NX)), sigma_m / SPACING, mode="reflect")
    return n / (np.abs(n).max() + 1e-9) * amp


# ------------------------------------------------------------------ masks on the height grid
inside = grid_mask([L["playable_boundary"]], poly_fn)
d_out = dist_outside(inside, SPACING)
forest = grid_mask([f["polygon"] for f in L["vegetation"]["forest"]], poly_fn)
forest_soft = ndimage.gaussian_filter(forest, 8 / SPACING)

river = L["river"]
river_line = grid_mask([{"points": river["points"], "w": 1.0}], line_fn("w"))
d_river = dist_outside(river_line, SPACING)
half_w = river["width"] / 2.0

roads = L["roads"]
road_mask = grid_mask(roads, line_fn("width"))
d_road = dist_outside(road_mask, SPACING)
rail_mask = grid_mask([{"points": r["points"], "w": 3.5} for r in L["rails"]], line_fn("w"))
d_rail = dist_outside(rail_mask, SPACING)

rects = [b["rect"] for b in L["buildings"]]
rect_polys = [[[r[0], r[1]], [r[2], r[1]], [r[2], r[3]], [r[0], r[3]]] for r in rects]
tank_polys = []
for t in L["tanks"]:
    (cx, cz), rr = t["center"], t["radius"] + 2
    tank_polys.append([[cx + rr * math.cos(a), cz + rr * math.sin(a)] for a in np.linspace(0, 2 * math.pi, 24, endpoint=False)])
pads = grid_mask(rect_polys + tank_polys, poly_fn)
d_pad = dist_outside(pads, SPACING)
yards = grid_mask([s["polygon"] for s in L["surfaces"]["concrete"] + L["surfaces"]["asphalt"]], poly_fn)

# ------------------------------------------------------------------ height field
H = np.zeros((NZ, NX), dtype=np.float64)

# South of the main road the land falls away toward the forest and dorms.
slope = L["terrain"]["south_slope"]
H -= slope["drop"] * smoothstep(slope["from_z"], slope["to_z"], GZ)

# Gentle relief: soft in the industrial zone, rolling in the forest, hilly outside.
n_big = smooth_noise(45.0)
n_small = smooth_noise(14.0)
amp = 0.35 + L["terrain"]["forest_south"]["undulation"] * forest_soft
amp = amp + np.clip(d_out / 40.0, 0, 1) * 4.0
H += n_big * amp + n_small * amp * 0.35

# Rising ground outside the boundary hides the map edge (lower toward the north backdrop).
rise_factor = 0.35 + 0.65 * smoothstep(150, 230, GZ)
river_corridor = 1.0 - smoothstep(half_w, half_w + 40, d_river)
H += np.clip(d_out, 0, 160) / 160.0 * 20.0 * rise_factor * (1.0 - river_corridor)

# Spoil heaps and rocky outcrops.
for m in L["terrain"]["mounds"]:
    cx, cz = m["center"]
    dd = np.hypot(GX - cx, GZ - cz)
    H += m["height"] * smoothstep(m["radius"], 0.0, dd) ** 1.5 * (1.0 + 0.25 * n_small)

# Flat building pads (each pad levels to its own average height).
labels, n = ndimage.label(pads > 0.5)
pad_h = ndimage.mean(H, labels, index=np.arange(1, n + 1)) if n else []
pad_target = np.zeros_like(H)
if n:
    nearest = ndimage.distance_transform_edt(labels == 0, return_distances=False, return_indices=True)
    nearest_label = labels[nearest[0], nearest[1]]
    pad_target = np.asarray(pad_h)[np.maximum(nearest_label - 1, 0)]
w_pad = 1.0 - smoothstep(0.0, 7.0, d_pad)
H = H * (1 - w_pad) + pad_target * w_pad

# Yards are levelled (keep large-scale shape, drop the bumps).
H_smooth = ndimage.gaussian_filter(H, 10 / SPACING)
w_yard = ndimage.gaussian_filter(yards, 3 / SPACING)
H = H * (1 - w_yard) + H_smooth * w_yard

# Roads and rails follow a smoothed version of the ground, with shoulders.
H_road = ndimage.gaussian_filter(H, 9 / SPACING)
w_road = 1.0 - smoothstep(4.5, 9.0, d_road)
w_rail = 1.0 - smoothstep(2.0, 6.0, d_rail)
river_core = 1.0 - smoothstep(half_w * 0.8, half_w + 6, d_river)
w_lin = np.maximum(w_road, w_rail) * (1.0 - river_core)
H = H * (1 - w_lin) + (H_road + 0.05 * w_rail) * w_lin

# Vostok treats anything below y = -2 m as water (Water.gd), so dry land is
# lifted to stay above 0.5 m and the river surface sits exactly at -2 m.
H = H - H[inside > 0.5].min() + 0.8
H = np.maximum(H, 0.5)

# River valley last so nothing fills it back in.
WATER_LEVEL = -2.0
bed = WATER_LEVEL - 3.5
carve = 1.0 - smoothstep(half_w * 0.45, half_w + 14.0, d_river)
H = H * (1 - carve) + bed * carve

H.astype(np.float32).tofile(os.path.join(OUT, "heights.f32"))

# ------------------------------------------------------------------ terrain masks (per tile)
MASK = 2048
MRES = TILE / MASK
masks = []
for t in range(NT):
    tx0 = X0 + t * TILE
    def M(shapes, fn):
        return raster(shapes, MRES, MASK, MASK, tx0, Z0, fn)
    concrete = M([s["polygon"] for s in L["surfaces"]["concrete"]], poly_fn)
    asphalt = np.maximum(M(roads_paved := [r for r in roads if r.get("surface", "asphalt") != "dirt"], line_fn("width")),
                         M([s["polygon"] for s in L["surfaces"]["asphalt"]], poly_fn))
    dirt = np.maximum(M([r for r in roads if r.get("surface") == "dirt"], line_fn("width")),
                      M([s["polygon"] for s in L["surfaces"]["dirt"]], poly_fn))
    ballast = M([{"points": r["points"], "w": 4.5} for r in L["rails"]], line_fn("w"))
    banks = M([{"points": river["points"], "w": river["width"] + 22}], line_fn("w"))
    # Wear: dirt creeps into concrete yards, grass verges along asphalt.
    wear = ndimage.gaussian_filter(np.random.default_rng(7 + t).standard_normal((MASK, MASK)), 6)
    wear = np.clip(wear / (np.abs(wear).max() + 1e-9) * 2.2, 0, 1)
    R = np.clip(np.maximum.reduce([dirt, ballast * 0.9, banks * 0.75]) + concrete * wear * 0.6, 0, 1)
    G = ndimage.gaussian_filter(asphalt, 0.8)
    B = np.clip(ndimage.gaussian_filter(concrete, 1.2) - G, 0, 1)
    rgb = (np.stack([R, G, B], axis=-1) * 255).astype(np.uint8)
    Image.fromarray(rgb, "RGB").save(os.path.join(OUT, f"mask_{t}.png"))
    masks.append(rgb)

# Surface classes on the height grid (for footsteps and collision).
classes = np.zeros((NZ, NX), dtype=np.uint8)
for t in range(NT):
    sl = (GX >= X0 + t * TILE) & (GX < X0 + (t + 1) * TILE + (1 if t == NT - 1 else 0))
    u = np.clip(((GX - (X0 + t * TILE)) / MRES).astype(int), 0, MASK - 1)
    v = np.clip(((GZ - Z0) / MRES).astype(int), 0, MASK - 1)
    m = masks[t][v, u].astype(np.float32) / 255.0
    cls = np.where(np.maximum(m[..., 1], m[..., 2]) > 0.5, 2, np.where(m[..., 0] > 0.5, 1, 0))
    classes[sl] = cls[sl]
classes[(H < WATER_LEVEL - 0.2) & (carve > 0.5)] = 3
classes.tofile(os.path.join(OUT, "classes.u8"))

# ------------------------------------------------------------------ trees (Poisson, 4 m apart)
veg = L["vegetation"]
margin = veg["clear_margin"]
density = np.full((NZ, NX), veg["industrial_density"], dtype=np.float32)
density = np.maximum(density, forest_soft.astype(np.float32) * veg["forest"][0]["density"])
density = np.where(inside < 0.5, np.maximum(density, veg["outside_density"] * smoothstep(0, 15, d_out)), density)
density *= 0.25 + 0.75 * smoothstep(150, 210, GZ)   # north backdrop is industry, not forest
density[d_road < margin["road"] + 4.5] = 0
density[d_rail < margin["rail"]] = 0
density[d_pad < margin["building"]] = 0
density[yards > 0.3] = 0
density[d_river < half_w + 4] = 0
density = ndimage.gaussian_filter(density, 1.0)

cand = rng.uniform([X0, Z0], [X0 + TILE * NT, Z0 + TILE], size=(90000, 2))
ci = np.clip(((cand[:, 0] - X0) / SPACING).astype(int), 0, NX - 1)
cj = np.clip(((cand[:, 1] - Z0) / SPACING).astype(int), 0, NZ - 1)
cand = cand[rng.random(len(cand)) < density[cj, ci]]
MIN_D = 4.0
cell = MIN_D / math.sqrt(2)
grid = {}
trees = []
for x, z in cand:
    gx, gz = int(x // cell), int(z // cell)
    ok = True
    for ox in range(-2, 3):
        for oz in range(-2, 3):
            q = grid.get((gx + ox, gz + oz))
            if q is not None and (q[0] - x) ** 2 + (q[1] - z) ** 2 < MIN_D * MIN_D:
                ok = False
                break
        if not ok:
            break
    if not ok:
        continue
    grid[(gx, gz)] = (x, z)
    trees.append([round(float(x), 2), round(float(z), 2), int(rng.integers(0, 4)),
                  round(float(rng.uniform(1.0, 2.0)), 3), round(float(rng.uniform(0, math.tau)), 3)])
json.dump(trees, open(os.path.join(OUT, "trees.json"), "w"))

json.dump({
    "x0": X0, "z0": Z0, "tile": TILE, "tiles": NT, "spacing": SPACING, "nx": NX, "nz": NZ,
    "water_level": WATER_LEVEL, "origin": L["origin"], "mask": MASK,
    "height_min": float(H.min()), "height_max": float(H.max()), "trees": len(trees),
}, open(os.path.join(OUT, "meta.json"), "w"), indent=1)
print(f"grid {NX}x{NZ}, heights {H.min():.1f}..{H.max():.1f} m, water {WATER_LEVEL:.1f} m, trees {len(trees)}")
