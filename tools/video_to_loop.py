"""Midjourney のループ動画（白背景）から、ボスの連番（透過・正方形のコマを横に並べた 1 枚）を作る。
使い方: python3 boss_anim.py <in.mp4> <out.png> [frames=24] [size=192]
 - 全コマを読み、縁からつながる白だけを透明にする（衣や目の白は残す）
 - 最初のコマに最も近いコマを後半から探して、そこまでをループ区間にする
 - 区間から均等に frames コマを選び、全コマ共通の外接矩形で切って正方形に収める
"""
import sys, os
import numpy as np
from PIL import Image
import imageio
from collections import deque

src, out = sys.argv[1], sys.argv[2]
NF = int(sys.argv[3]) if len(sys.argv) > 3 else 24
SIZE = int(sys.argv[4]) if len(sys.argv) > 4 else 192

frames = [np.asarray(f)[..., :3] for f in imageio.get_reader(src, "ffmpeg")]
print("frames", len(frames), frames[0].shape)

def cutout(rgb):
    a = rgb.astype(float); h, w, _ = a.shape
    lum = a.mean(-1); sat = a.max(-1) - a.min(-1)
    white = (lum > 188) & (sat < 46)          # 白〜薄い影（縁につながるもの）
    pure = (lum > 225) & (sat < 26)           # 純白の塊（隙間の白。牙は小さいので残す）
    # 白の連結成分：縁に触れるものは背景、触れない大きな塊（炎の隙間の白）も背景、小さい塊（牙・目）は残す
    from scipy import ndimage
    lab, n = ndimage.label(white)
    bg = np.zeros((h, w), bool)
    if n > 0:
        border = set(np.unique(np.concatenate([lab[0, :], lab[-1, :], lab[:, 0], lab[:, -1]])))
        for i in border:
            if i > 0: bg |= (lab == i)
    lab2, n2 = ndimage.label(pure & ~bg)
    if n2 > 0:
        sizes = ndimage.sum(pure & ~bg, lab2, index=np.arange(1, n2 + 1))
        for i in range(1, n2 + 1):
            if sizes[i - 1] > 900: bg |= (lab2 == i)
    alpha = np.ones((h, w))
    alpha[bg] = 0
    edge = np.zeros((h, w), bool)
    edge[1:, :] |= bg[:-1, :]; edge[:-1, :] |= bg[1:, :]; edge[:, 1:] |= bg[:, :-1]; edge[:, :-1] |= bg[:, 1:]
    edge &= ~bg
    alpha[edge] = np.clip((240 - lum[edge]) / 60, 0.1, 1)
    return np.dstack([a, alpha * 255]).astype(np.uint8)

# ループ区間：後半で最初のコマに最も近いところ
small = [np.asarray(Image.fromarray(f).resize((64, 64))).astype(float) for f in frames]
n = len(frames)
best, bestd = n - 1, 1e18
for i in range(int(n * 0.6), n):
    d = np.abs(small[i] - small[0]).mean()
    if d < bestd: bestd, best = d, i
print("loop end", best, "of", n, "diff", round(bestd, 2))
idx = [int(round(i * best / NF)) for i in range(NF)]
cut = [cutout(frames[i]) for i in idx]

# 共通の外接矩形
ys, xs = [], []
for c in cut:
    m = c[..., 3] > 16
    yy, xx = np.where(m)
    if len(yy): ys += [yy.min(), yy.max()]; xs += [xx.min(), xx.max()]
y0, y1, x0, x1 = min(ys), max(ys), min(xs), max(xs)
side = max(y1 - y0, x1 - x0) + 8
cy, cx = (y0 + y1) // 2, (x0 + x1) // 2
sheet = Image.new("RGBA", (SIZE * NF, SIZE), (0, 0, 0, 0))
for k, c in enumerate(cut):
    img = Image.fromarray(c, "RGBA")
    box = (cx - side // 2, cy - side // 2, cx - side // 2 + side, cy - side // 2 + side)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    crop = img.crop((max(box[0], 0), max(box[1], 0), min(box[2], img.width), min(box[3], img.height)))
    sq.paste(crop, (max(box[0], 0) - box[0], max(box[1], 0) - box[1]))
    sq = sq.resize((SIZE, SIZE), Image.LANCZOS)
    sheet.paste(sq, (SIZE * k, 0))
sheet.save(out)
print("saved", out, sheet.size)
