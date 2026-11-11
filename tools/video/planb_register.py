"""Registration of a paint-over keyframe to our frame: ECC affine on blurred edge maps; edge distances before/after; overlay; optional warped output.
Usage: python -I reg_check.py <ours.png> <key.jpg> <overlay.png> [<registered_out.png>]"""
import sys
import cv2
import numpy as np

ours_p, key_p, overlay_p = sys.argv[1:4]
reg_out = sys.argv[4] if len(sys.argv) > 4 else None
ours = cv2.imread(ours_p, cv2.IMREAD_COLOR)
key = cv2.imread(key_p, cv2.IMREAD_COLOR)
h, w = ours.shape[:2]
key = cv2.resize(key, (w, h), interpolation=cv2.INTER_AREA)

def edges(img):
	g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
	g = cv2.GaussianBlur(g, (5, 5), 1.5)
	e = cv2.Canny(g, 40, 110)
	return e

eo, ek = edges(ours), edges(key)

def dist_stats(e_from, e_to):
	dt = cv2.distanceTransform(255 - e_to, cv2.DIST_L2, 3)
	d = dt[e_from > 0]
	return np.percentile(d, 50), np.percentile(d, 75)

before = dist_stats(eo, ek)
s = 0.25
small = lambda e: cv2.GaussianBlur(cv2.resize(e.astype(np.float32) / 255.0, None, fx=s, fy=s, interpolation=cv2.INTER_AREA), (0, 0), 2.0)
warp = np.eye(2, 3, dtype=np.float32)
try:
	_, warp = cv2.findTransformECC(small(eo), small(ek), warp, cv2.MOTION_AFFINE, (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 300, 1e-6), None, 5)
	ok = True
except cv2.error as e:
	ok = False
warp_full = warp.copy()
warp_full[:, 2] /= s
key_reg = cv2.warpAffine(key, warp_full, (w, h), flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP, borderMode=cv2.BORDER_REPLICATE)
after = dist_stats(eo, edges(key_reg))
sx = np.hypot(warp[0, 0], warp[1, 0]); sy = np.hypot(warp[0, 1], warp[1, 1])
print(f"{key_p}: ecc {'ok' if ok else 'FAILED'}; scale {sx:.4f} x {sy:.4f}, shift {warp_full[0,2]:+.1f}, {warp_full[1,2]:+.1f} px; "
	f"our edges to key edges p50/p75: before {before[0]:.1f}/{before[1]:.1f} px, after {after[0]:.1f}/{after[1]:.1f} px")
ov = np.zeros((h, w, 3), np.uint8)
ov[:, :, 2] = eo
ov[:, :, 1] = edges(key_reg)
cv2.imwrite(overlay_p, cv2.resize(ov, (w // 2, h // 2), interpolation=cv2.INTER_AREA))
if reg_out:
	cv2.imwrite(reg_out, key_reg)
