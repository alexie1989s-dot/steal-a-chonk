# Steal a Chonk - turn a baked view-color map (flat markings projected onto the model) into a region mask.
# Mask channels: R = primary fur, G = secondary fur, B = ear pink. Black/grey (no coverage) is filled from neighbours.
# Usage: python classify_regions.py <viewcolor.png> <out_mask.png> [--primary R,G,B] [--secondary R,G,B]
import sys, argparse
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("dst")
ap.add_argument("--primary", default="240,138,60")
ap.add_argument("--secondary", default="242,233,220")
ap.add_argument("--pink_min_r", type=float, default=170)
ap.add_argument("--median", type=int, default=5)
args = ap.parse_args()

a = np.asarray(Image.open(args.src).convert("RGB")).astype(np.float32)
r, g, b = a[..., 0], a[..., 1], a[..., 2]
p1 = np.array([float(x) for x in args.primary.split(",")]); p2 = np.array([float(x) for x in args.secondary.split(",")])

v = a.max(-1)
unknown = (v < 60) | ((a.max(-1) - a.min(-1)) < 22)            # black (no bake) or grey background
# pink: red-dominant with green ~ blue (orange/cream blends have green well above blue)
pink = (~unknown) & (r > args.pink_min_r) & (np.abs(g - b) < 18) & ((r - g) > 45)
# everything else: nearest point on the primary<->secondary segment
seg = p2 - p1; L2 = float(seg @ seg)
t = np.clip(((a - p1) @ seg) / L2, 0, 1)
primary = (~unknown) & (~pink) & (t < 0.5)
secondary = (~unknown) & (~pink) & (t >= 0.5)

lab = np.full(a.shape[:2], -1, np.int16); lab[primary] = 0; lab[secondary] = 1; lab[pink] = 2
idx = ndi.distance_transform_edt(lab < 0, return_distances=False, return_indices=True); lab = lab[idx[0], idx[1]]
if args.median > 1:
    lab = ndi.median_filter(lab, size=args.median)
mask = np.zeros(a.shape[:2] + (3,), np.uint8)
mask[..., 0] = (lab == 0) * 255; mask[..., 1] = (lab == 1) * 255; mask[..., 2] = (lab == 2) * 255
Image.fromarray(mask).save(args.dst)
n = lab.size
print("primary %.2f secondary %.2f pink %.2f  (unknown before fill %.2f)" % ((lab == 0).sum() / n, (lab == 1).sum() / n, (lab == 2).sum() / n, unknown.mean()))
