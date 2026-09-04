# 白背景の絵を透過 PNG にする：白に近い画素を透明にし、縁を滑らかに。余白を切り落とす
import sys, os
from PIL import Image, ImageFilter
import numpy as np
src, dst = sys.argv[1], sys.argv[2]
lo = float(sys.argv[3]) if len(sys.argv) > 3 else 18.0   # これ未満の白距離は透明
hi = float(sys.argv[4]) if len(sys.argv) > 4 else 78.0   # これ以上は不透明
im = Image.open(src).convert("RGB")
a = np.asarray(im).astype(np.float32)
# 白からの距離（0=白）
dist = np.sqrt(((255.0 - a) ** 2).sum(axis=2))
alpha = np.clip((dist - lo) / max(hi - lo, 1.0), 0.0, 1.0)
# 髪など暗い部分は 1、背景の薄い影は消える
al = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))
rgba = im.convert("RGBA"); rgba.putalpha(al)
bbox = al.point(lambda v: 255 if v > 30 else 0).getbbox()
if bbox: rgba = rgba.crop(bbox)
rgba.thumbnail((900, 900))
rgba.save(dst, optimize=True)
print(dst, rgba.size, os.path.getsize(dst)//1024, "KB")
