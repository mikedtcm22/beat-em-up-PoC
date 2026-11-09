"""Stack images side by side with a label row: w3_compare.py <out.jpg> <width each> <img> [<img> ...] (LD-WORLD3 look-dev helper)."""
import sys
from PIL import Image
out, w = sys.argv[1], int(sys.argv[2])
ims = [Image.open(p).convert("RGB") for p in sys.argv[3:]]
ims = [i.resize((w, int(i.height * w / i.width)), Image.LANCZOS) for i in ims]
S = Image.new("RGB", (w * len(ims), max(i.height for i in ims)))
for k, i in enumerate(ims):
	S.paste(i, (k * w, 0))
S.save(out, quality=90)
