#!/usr/bin/env python3
"""Kenney Monster Builder（CC0）の部品を組み合わせ、作品の色に合わせて敵 12 種のスプライトを作る。
  python3 tools/make_enemy_sprites.py <kenney PNG/Double dir> <out dir>
"""
import sys, os
from PIL import Image, ImageOps, ImageChops
SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
S = 320   # 出力の一辺

def load(n):
    if not n.endswith(".png"): n += ".png"
    return Image.open(os.path.join(SRC, n)).convert("RGBA")

def tint(im, rgb):
    """白い部品を色で乗算（陰影は残る）"""
    r, g, b = rgb
    base = im.convert("RGBA")
    solid = Image.new("RGBA", base.size, (r, g, b, 255))
    mult = ImageChops.multiply(base, solid)
    mult.putalpha(base.split()[3])
    return mult

def fit(im, w, h=None):
    h = h or w
    return ImageOps.contain(im, (w, h))

def paste(canvas, part, cx, cy, w=None, h=None, rot=0):
    if w: part = fit(part, w, h)
    if rot: part = part.rotate(rot, expand=True, resample=Image.BICUBIC)
    canvas.alpha_composite(part, (int(cx - part.width / 2), int(cy - part.height / 2)))

# kind: (body letter, color, eyes(list of (name, x, y, w)), mouth(name, y, w), details(list of (name, x, y, w, rot)))
K = {
 "grunt":   ("C", (255,130,160), [("eye_cute_light",-40,-20,60),("eye_cute_light",40,-20,60)], ("mouth_closed_happy",40,80), []),
 "weaver":  ("F", (200,120,255), [("eye_human",0,-30,110)], ("mouthA",70,70), [("detail_white_antenna_small",0,-150,50,0)]),
 "charger": ("A", (255,90,110),  [("eye_angry_red",-42,-25,70),("eye_angry_red",42,-25,70)], ("mouth_closed_teeth",50,110), [("detail_white_horn_small",-70,-120,60,-20),("detail_white_horn_small",70,-120,60,20)]),
 "turret":  ("B", (140,210,255), [("eye_blue",0,-10,90),("eye_blue",-75,-40,40),("eye_blue",75,-40,40),("eye_blue",-60,50,36),("eye_blue",60,50,36),("eye_blue",0,85,32)], None, []),
 "splitter":("D", (120,255,170), [("eye_psycho_light",-45,-15,70),("eye_psycho_light",45,-15,70)], ("mouth_closed_fangs",55,90), []),
 "mini":    ("A", (120,255,170), [("eye_cute_dark",0,-10,90)], ("mouth_closed_happy",55,60), []),
 "spirit":  ("E", (180,220,255), [("eye_dead",-38,-20,60),("eye_dead",38,-20,60)], ("mouth_closed_sad",45,60), []),
 "lantern": ("F", (255,150,90),  [("eye_human",0,-40,120)], ("mouthC",60,90), [("detail_white_ear_round",0,-160,70,0)]),
 "kite":    ("A", (255,90,90),   [("eye_angry_red",-40,-20,70),("eye_angry_red",40,-20,70)], ("mouthB",50,80), []),
 "oni":     ("B", (220,70,80),   [("eye_angry_red",-45,-15,75),("eye_angry_red",45,-15,75)], ("mouth_closed_fangs",65,120), [("detail_white_horn_large",-70,-125,80,-15),("detail_white_horn_large",70,-125,80,15)]),
 "caster":  ("F", (220,195,255), [("eye_human",-35,-25,60),("eye_human",35,-25,60)], ("mouth_closed_sad",50,60), [("detail_white_antenna_large",0,-165,60,0)]),
 "bomber":  ("C", (255,160,70),  [("eye_psycho_dark",-40,-25,65),("eye_psycho_dark",40,-25,65)], ("mouthD",50,90), []),
}
sheet = Image.new("RGBA", (S * 6, S * 2), (40, 30, 60, 255))
for i, (kind, (body, col, eyes, mouth, details)) in enumerate(K.items()):
    cv = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    b = tint(load(f"body_white{body}.png"), col)
    bw = 250 if body != "F" else 190
    bh = 250 if body != "F" else 300
    rot = 45 if kind == "kite" else 0
    if kind == "mini": bw = bh = 170
    for (n, x, y, w, r) in details:
        paste(cv, tint(load(n), tuple(max(0, c - 40) for c in col)), S/2 + x, S/2 + y + (0 if body != "F" else 20), w, None, r)
    paste(cv, b, S/2, S/2 + (0 if body != "F" else 10), bw, bh, rot)
    for (n, x, y, w) in eyes: paste(cv, load(n), S/2 + x, S/2 + y, w)
    if mouth: paste(cv, load(mouth[0]), S/2, S/2 + mouth[1], mouth[2])
    cv.save(os.path.join(OUT, kind + ".png"), optimize=True)
    sheet.alpha_composite(cv, ((i % 6) * S, (i // 6) * S))
sheet.save(os.path.join(OUT, "_sheet.png"))
print("ok", len(K))
