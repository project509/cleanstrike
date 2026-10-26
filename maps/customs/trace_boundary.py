"""Trace Tarkov's playable boundary from re3mr's map (the white dotted line).

Usage: trace_boundary.py <re3mr map png> <layout.json> [preview.png]
Finds the dots, orders them into a closed loop (bridging gaps where extract
icons cover the line), simplifies to ~0.4 m, and writes playable_boundary
(metres, re3mr grid at 7.38 px/m) into layout.json.
"""
import json
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.spatial import cKDTree

Image.MAX_IMAGE_PIXELS = None
PPM = 7.38
src, layout = sys.argv[1], sys.argv[2]
img = Image.open(src).convert("RGB")
a = np.asarray(img).astype(np.int16)
H, W, _ = a.shape
white = (a[..., 0] > 235) & (a[..., 1] > 235) & (a[..., 2] > 235)
lab, n = ndimage.label(white)
sizes = ndimage.sum(white, lab, range(1, n + 1))
dots = []
for i, sl in enumerate(ndimage.find_objects(lab)):
    h = sl[0].stop - sl[0].start
    w = sl[1].stop - sl[1].start
    if 7 <= h <= 10 and 7 <= w <= 10 and abs(h - w) <= 3 and sizes[i] > 0.55 * h * w:
        dots.append(((sl[1].start + sl[1].stop) / 2, (sl[0].start + sl[0].stop) / 2))
pts = np.array(dots)
pts = pts[pts[:, 1] < 0.76 * H]                      # legend panel
tree = cKDTree(pts)
nb = np.array([len(tree.query_ball_point(p, 40)) - 1 for p in pts])
pts = pts[nb >= 2]

# Largest group of dots joined by short hops (drops strays in the title etc).
tree = cKDTree(pts)
pairs = tree.query_pairs(320)
parent = list(range(len(pts)))
def find(x):
    while parent[x] != x:
        parent[x] = parent[parent[x]]
        x = parent[x]
    return x
for i, j in pairs:
    parent[find(i)] = find(j)
roots = np.array([find(i) for i in range(len(pts))])
best = np.bincount(roots).argmax()
pts = pts[roots == best]

# Order: walk to the nearest unvisited dot; icons on the line leave gaps
# of a few dots, which the nearest-neighbour walk bridges.
left = set(range(len(pts)))
start = int(np.argmin(pts[:, 0]))
order = [start]
left.remove(start)
while left:
    cur = pts[order[-1]]
    idx = np.array(sorted(left))
    d = np.hypot(*(pts[idx] - cur).T)
    k = idx[int(np.argmin(d))]
    if d.min() > 700 and len(order) > 20:            # the rest are not on this loop
        break
    order.append(int(k))
    left.remove(int(k))
loop = pts[order] / PPM


def rdp(points, eps):
    if len(points) < 3:
        return points
    a, b = points[0], points[-1]
    ab = b - a
    n = np.hypot(*ab) or 1.0
    rel = points - a
    d = np.abs(ab[0] * rel[:, 1] - ab[1] * rel[:, 0]) / n
    i = int(np.argmax(d))
    if d[i] > eps:
        return np.vstack([rdp(points[: i + 1], eps)[:-1], rdp(points[i:], eps)])
    return np.vstack([a, b])


far = int(np.argmax(np.hypot(*(loop - loop[0]).T)))
simple = np.vstack([rdp(loop[: far + 1], 0.4)[:-1], rdp(np.vstack([loop[far:], loop[:1]]), 0.4)[:-1]])
L = json.load(open(layout, encoding="utf-8"))
L["playable_boundary"] = [[round(float(x), 1), round(float(z), 1)] for x, z in simple]
L["playable_boundary_source"] = "traced from re3mr's dotted boundary line (trace_boundary.py)"
json.dump(L, open(layout, "w", encoding="utf-8"), indent=1)
perim = float(np.sum(np.hypot(*np.diff(np.vstack([simple, simple[:1]]), axis=0).T)))
print(f"dots {len(pts)}, ordered {len(order)}, boundary {len(simple)} points, perimeter {perim:.0f} m")

if len(sys.argv) > 3:
    sc = 1600 / W
    prev = img.resize((1600, int(H * sc)))
    dr = ImageDraw.Draw(prev)
    dr.line([(x * PPM * sc, z * PPM * sc) for x, z in np.vstack([simple, simple[:1]])], fill=(0, 255, 0), width=2)
    for i, (x, z) in enumerate(simple):
        dr.ellipse([x * PPM * sc - 2, z * PPM * sc - 2, x * PPM * sc + 2, z * PPM * sc + 2], fill=(255, 255, 0))
    prev.save(sys.argv[3])
