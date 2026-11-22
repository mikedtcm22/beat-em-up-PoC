"""Contact sheets for a judge: python3 -I tools/look/judge_sheets.py <judge_set_dir> [per_sheet=6]
Writes sheet_NN.jpg (3x2 grid, each cell labelled with its id only). Needs PIL."""
import glob, os, sys
from PIL import Image, ImageDraw
d = sys.argv[1]
n = int(sys.argv[2]) if len(sys.argv) > 2 else 6
files = sorted(glob.glob(os.path.join(d, "j_*.jpg")))
cols, w, h = 3, 640, 360
for s in range(0, len(files), n):
	chunk = files[s:s + n]
	sheet = Image.new("RGB", (cols * w, ((len(chunk) + cols - 1) // cols) * h))
	dr = ImageDraw.Draw(sheet)
	for i, f in enumerate(chunk):
		sheet.paste(Image.open(f).resize((w, h)), ((i % cols) * w, (i // cols) * h))
		dr.rectangle(((i % cols) * w, (i // cols) * h, (i % cols) * w + 60, (i // cols) * h + 18), fill=(0, 0, 0))
		dr.text(((i % cols) * w + 4, (i // cols) * h + 3), os.path.basename(f)[2:4], fill=(255, 255, 255))
	sheet.save(os.path.join(d, f"sheet_{s // n + 1:02d}.jpg"), quality=90)
