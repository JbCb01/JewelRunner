"""Generuje animacje combo tricków Stelly (64x64, pixel-art) dla wszystkich skinów.

Postać jest składana jak kukiełka z części wyciętych z oryginalnego sprite'a
(głowa, tułów, rękawica, buty) + kończyny rysowane w stylu oryginału
(2 px rdzeń + 1 px ciemny kontur). Obroty części używają algorytmu RotSprite
(3x Scale2x -> obrót -> próbkowanie), dzięki czemu kontury zostają czyste.

Animacje (wszystkie zaczynają się i kończą tą samą pozą "LINK", więc tricki
płynnie przechodzą jeden w drugi):
  trick_flip    – [Trick] + ←/→   salto w przód w kulce
  trick_star    – [Trick] + ↑     "Gwiazda": rozłożenie w X z piruetem
  trick_finish  – [Trick] + ↓     "Wielki Finał": zwinięta poza z celującą dłonią
                                  (kończy combo, ostatnie 2 klatki się zapętlają)

Skiny dostają te same klatki przemapowane paletą (mapa kolorów jest wyliczana
z porównania klatek skoku skinu i domyślnej postaci).

Użycie:  py -3 tools/trick_anim.py [katalog_projektu] [katalog_podglądu]
"""
import glob
import math
import os
import re
import sys

import numpy as np
from PIL import Image

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
PREVIEW = sys.argv[2] if len(sys.argv) > 2 else None
SRC = os.path.join(ROOT, "assets/sprites/player/trick/Stellysiadanabutliodvanisha1.png")

OUT_C = (31, 16, 42, 255)       # kontur
ARM_C = (131, 77, 196, 255)     # ręce (fiolet głowy)
ARM_S = (57, 9, 71, 255)        # cień rąk
LEG_C = (109, 128, 250, 255)    # nogi (niebieski)
LEG_S = (125, 45, 160, 255)     # cień nóg
GLOVE = (255, 255, 255, 255)
GLOVE_S = (166, 133, 159, 255)
SPARK = (174, 226, 255, 255)
SPARK2 = (255, 255, 255, 255)

# ---------------------------------------------------------------- części
src = np.array(Image.open(SRC).convert("RGBA"))


def _crop(mask_fn, x0, y0, x1, y1):
    part = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
    for y in range(y0, y1):
        for x in range(x0, x1):
            if src[y, x, 3] and mask_fn(x, y):
                part[y - y0, x - x0] = src[y, x]
    return part, (x0, y0)


# lewa granica głowy w wierszach, w których ręka przylega do konturu
_HEAD_LEFT = {31: 25, 32: 26, 33: 26, 34: 28, 35: 29, 36: 31}


def _head_mask(x, y):
    if 21 <= y <= 30:
        return x >= 24
    if y in _HEAD_LEFT:
        return x >= _HEAD_LEFT[y]
    return True


HEAD, HEAD_O = _crop(_head_mask, 19, 10, 54, 37)
HEAD_PIVOT = (36.0 - HEAD_O[0], 36.0 - HEAD_O[1])          # szyja
TORSO, TORSO_O = _crop(lambda x, y: y >= 37 or x >= 31, 29, 36, 43, 46)
TORSO_PIVOT = (35.5 - TORSO_O[0], 37.0 - TORSO_O[1])        # góra tułowia
GLOVE_IMG, GLOVE_O = _crop(lambda x, y: not (y >= 31 and x >= 22), 15, 20, 25, 32)
GLOVE_PIVOT = (21.5 - GLOVE_O[0], 30.0 - GLOVE_O[1])        # nadgarstek
SHOE_IMG, SHOE_O = _crop(lambda x, y: x <= 31, 23, 48, 32, 62)
SHOE_PIVOT = (29.0 - SHOE_O[0], 50.0 - SHOE_O[1])           # kostka (but wisi w dół)
# Tułów ma 9 px wysokości: biodra są ~8 px pod górą tułowia
TORSO_LEN = 8.0


# ---------------------------------------------------------------- RotSprite
def scale2x(a):
    p = np.pad(a, ((1, 1), (1, 1), (0, 0)), mode="edge")
    E = p[1:-1, 1:-1]
    B, H = p[:-2, 1:-1], p[2:, 1:-1]
    D, F = p[1:-1, :-2], p[1:-1, 2:]
    eq = lambda u, v: np.all(u == v, axis=2)
    e0 = np.where((eq(D, B) & ~eq(B, F) & ~eq(D, H))[..., None], D, E)
    e1 = np.where((eq(B, F) & ~eq(B, D) & ~eq(F, H))[..., None], F, E)
    e2 = np.where((eq(D, H) & ~eq(D, B) & ~eq(H, F))[..., None], D, E)
    e3 = np.where((eq(H, F) & ~eq(D, H) & ~eq(B, F))[..., None], F, E)
    h, w = a.shape[:2]
    out = np.zeros((h * 2, w * 2, 4), np.uint8)
    out[0::2, 0::2] = e0
    out[0::2, 1::2] = e1
    out[1::2, 0::2] = e2
    out[1::2, 1::2] = e3
    return out


_UP = {}


def up8(img):
    k = id(img)
    if k not in _UP:
        _UP[k] = scale2x(scale2x(scale2x(img)))
    return _UP[k]


def blit_rot(canvas, img, pivot, dest, angle_deg, flip_x=False, sx=1.0, sy=1.0):
    """Wkleja `img` tak, by punkt `pivot` trafił w `dest`, obrócony o angle (CW, stopnie)."""
    big = up8(img)
    h, w = big.shape[:2]
    a = math.radians(angle_deg)
    ca, sa = math.cos(a), math.sin(a)
    ys, xs = np.mgrid[0:64, 0:64]
    dx = xs + 0.5 - dest[0]
    dy = ys + 0.5 - dest[1]
    # odwrotny obrót
    lx = (ca * dx + sa * dy) / sx
    ly = (-sa * dx + ca * dy) / sy
    if flip_x:
        lx = -lx
    u = np.floor((lx + pivot[0]) * 8).astype(int)
    v = np.floor((ly + pivot[1]) * 8).astype(int)
    ok = (u >= 0) & (u < w) & (v >= 0) & (v < h)
    sample = np.zeros((64, 64, 4), np.uint8)
    sample[ok] = big[v[ok], u[ok]]
    m = sample[..., 3] > 0
    canvas[m] = sample[m]


# ---------------------------------------------------------------- kończyny
def _disk_line(mask, p0, p1, r):
    ys, xs = np.mgrid[0:64, 0:64]
    px, py = xs + 0.5, ys + 0.5
    x0, y0 = p0
    x1, y1 = p1
    vx, vy = x1 - x0, y1 - y0
    L2 = max(1e-6, vx * vx + vy * vy)
    t = np.clip(((px - x0) * vx + (py - y0) * vy) / L2, 0, 1)
    d = np.hypot(px - (x0 + t * vx), py - (y0 + t * vy))
    mask |= d <= r


def _dilate(m):
    o = m.copy()
    o[1:] |= m[:-1]
    o[:-1] |= m[1:]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o


def draw_limb(canvas, pts, col, shade, r=1.05):
    m = np.zeros((64, 64), bool)
    for a, b in zip(pts, pts[1:]):
        _disk_line(m, a, b, r)
    ring = _dilate(m) & ~m
    canvas[ring] = OUT_C
    canvas[m] = col
    # cień: dolna krawędź rdzenia
    low = m & ~np.roll(m, -1, axis=0)
    canvas[low & m] = shade


def outline_layer(canvas, layer):
    m = layer[..., 3] > 0
    ring = _dilate(m) & ~m
    canvas[ring] = OUT_C
    canvas[m] = layer[m]


def vec(angle, length):
    """kąt 0 = w dół, dodatni = w przód (+x)."""
    a = math.radians(angle)
    return (math.sin(a) * length, math.cos(a) * length)


def rot_about(p, c, deg, sx=1.0):
    a = math.radians(deg)
    x, y = (p[0] - c[0]) * sx, p[1] - c[1]
    return (c[0] + x * math.cos(a) - y * math.sin(a), c[1] + x * math.sin(a) + y * math.cos(a))


# ---------------------------------------------------------------- pozy
BASE = dict(
    x=33.0, y=35.0,     # góra tułowia (szyja)
    rot=0.0,            # obrót całej postaci (CW)
    sx=1.0,             # skala pozioma (piruet)
    head=0.0,           # dodatkowe pochylenie głowy (CW = w przód)
    body=0.0,           # pochylenie tułowia
    af=(60.0, 100.0),   # ręka przednia: ramię, przedramię (kąty bezwzględne)
    ab=(-60.0, -100.0), # ręka tylna
    lf=(30.0, 0.0),     # noga przednia: udo, golenie(=but)
    lb=(-20.0, 0.0),    # noga tylna
    point=False,        # celujący palec na przedniej dłoni
    gf=0.0, gb=0.0,     # dodatkowy obrót rękawic
    spark=0,            # błyski
    front=True,         # przednia ręka nad głową
    pv=10.0,            # odległość punktu obrotu nad szyją
)

LINK = dict(BASE, head=4, body=6, af=(70, 55), ab=(-75, -55), lf=(115, 15), lb=(55, -15), front=False)

def P(**kw):
    d = dict(BASE)
    d.update(kw)
    return d


def lerp_pose(a, b, t):
    out = {}
    for k in BASE:
        va, vb = a[k], b[k]
        if isinstance(va, tuple):
            out[k] = tuple(x + (y - x) * t for x, y in zip(va, vb))
        elif isinstance(va, bool):
            out[k] = vb if t >= 0.5 else va
        elif isinstance(va, int) and k == "spark":
            out[k] = vb if t >= 0.5 else va
        else:
            out[k] = va + (vb - va) * t
    return out


def render(p):
    c = np.zeros((64, 64, 4), np.uint8)
    neck = (p["x"], p["y"])
    piv = (neck[0], neck[1] - p["pv"])     # punkt obrotu całej postaci (środek masy)
    R = p["rot"]
    sx = p["sx"]
    flip = sx < 0
    asx = max(0.08, abs(sx))
    sgn = -1 if flip else 1

    def W(pt):  # lokalny -> świat
        return rot_about(pt, piv, R, sx)

    def world_ang(a):  # kąt kończyny (0 = w dół, + = w przód) -> obrót CW sprite'a
        return (-a - R) if flip else (a - R)

    body_ang = p["body"]
    hb = vec(-body_ang, TORSO_LEN)
    hip = (neck[0] + hb[0], neck[1] + hb[1])
    sh = (neck[0] + hb[0] * 0.15, neck[1] + hb[1] * 0.15 + 1)

    def limb(base, a1, a2, l1, l2):
        j = (base[0] + vec(a1, l1)[0], base[1] + vec(a1, l1)[1])
        e = (j[0] + vec(a2, l2)[0], j[1] + vec(a2, l2)[1])
        return base, j, e

    def arm_layer(ang, glove_rot, pointing, side):
        s, el, h = limb((sh[0] + side, sh[1]), ang[0], ang[1], 7.5, 7.0)
        draw_limb(c, [W(s), W(el), W(h)], ARM_C, ARM_S, 1.0)
        g = np.zeros((64, 64, 4), np.uint8)
        G = 153.0 if flip else 207.0            # kierunek palców rękawicy w źródle
        theta = G - world_ang(ang[1]) + glove_rot * sgn
        blit_rot(g, GLOVE_IMG, GLOVE_PIVOT, W(h), theta, flip_x=flip, sx=1.0)
        if pointing:
            fdir = vec(ang[1], 1.0)
            tip0 = (h[0] + fdir[0] * 4.0, h[1] + fdir[1] * 4.0)
            tip1 = (h[0] + fdir[0] * 9.5, h[1] + fdir[1] * 9.5)
            fm = np.zeros((64, 64), bool)
            _disk_line(fm, W(tip0), W(tip1), 0.62)
            g[fm & (g[..., 3] == 0)] = GLOVE
        outline_layer(c, g)

    def leg_layer(ang, side):
        b, k, e = limb((hip[0] + side, hip[1]), ang[0], ang[1], 5.5, 4.0)
        draw_limb(c, [W(b), W(k), W(e)], LEG_C, LEG_S, 1.15)
        layer = np.zeros((64, 64, 4), np.uint8)
        blit_rot(layer, SHOE_IMG, SHOE_PIVOT, W(e), -world_ang(ang[1]), flip_x=flip, sx=1.0)
        outline_layer(c, layer)

    def head_layer():
        h = np.zeros((64, 64, 4), np.uint8)
        hang = R + (p["head"] + body_ang * 0.5) * sgn
        blit_rot(h, HEAD, HEAD_PIVOT, W((neck[0], neck[1] + 1)), hang, flip_x=flip, sx=asx)
        m = h[..., 3] > 0
        c[m] = h[m]

    arm_layer(p["ab"], p["gb"], False, -2)
    leg_layer(p["lb"], -1)
    t = np.zeros((64, 64, 4), np.uint8)
    blit_rot(t, TORSO, TORSO_PIVOT, W(neck), R + body_ang * sgn, flip_x=flip, sx=asx)
    outline_layer(c, t)
    leg_layer(p["lf"], 1)
    if p["front"]:
        head_layer()
        arm_layer(p["af"], p["gf"], p["point"], 2)
    else:
        arm_layer(p["af"], p["gf"], p["point"], 2)
        head_layer()
    if p["spark"]:
        _sparks(c, p["spark"], neck)
    return c


def _sparks(c, kind, neck):
    pts = {1: [(-20, -14), (21, 4)], 2: [(-22, 2), (22, -16), (4, 22)], 3: [(-18, -18), (24, -6), (-8, 22)]}[kind]
    for dx, dy in pts:
        x, y = int(neck[0] + dx), int(neck[1] + dy)
        for ox, oy, col in [(0, 0, SPARK2), (1, 0, SPARK), (-1, 0, SPARK), (0, 1, SPARK), (0, -1, SPARK)]:
            if 0 <= x + ox < 64 and 0 <= y + oy < 64 and c[y + oy, x + ox, 3] == 0:
                c[y + oy, x + ox] = col


# ---------------------------------------------------------------- choreografia
TUCK = dict(LINK, y=36.0, pv=3.0, head=10, body=18, af=(95, 150), ab=(-40, 100), lf=(140, 40), lb=(120, 20))
FLIP = [
    LINK,
    dict(TUCK, rot=25),
    dict(TUCK, rot=95),
    dict(TUCK, rot=165),
    dict(TUCK, rot=235),
    dict(TUCK, rot=305),
    lerp_pose(TUCK, LINK, 0.6),
    LINK,
]

STAR_OPEN = P(head=-8, body=-4, af=(115, 125), ab=(-115, -125), lf=(40, 25), lb=(-40, -25), front=True, spark=2)
STAR = [
    LINK,
    lerp_pose(LINK, STAR_OPEN, 0.55),
    STAR_OPEN,
    dict(STAR_OPEN, sx=0.5, spark=3),
    dict(STAR_OPEN, sx=-0.5, spark=3),
    dict(STAR_OPEN, sx=-1.0, spark=2),
    dict(STAR_OPEN, sx=-0.5, spark=1),
    dict(lerp_pose(STAR_OPEN, LINK, 0.5), sx=0.5, spark=0),
    LINK,
]

# "Wielki Finał" – poza z ilustracji referencyjnej: zwinięta sylwetka w kształt koła,
# głowa pochylona w przód, przednia dłoń wyciągnięta i celująca, druga dłoń przy głowie,
# nogi zawinięte pod spód w pierścień (przednia stopa z przodu, tylna z tyłu).
FIN_POSE = P(rot=10, head=8, body=6, af=(100, 112), ab=(-140, -175), gb=0,
             lf=(35, 95), lb=(-70, -120), point=True, front=True)
FIN_WIND = dict(TUCK, rot=-20, head=16)
FINISH = [
    LINK,
    FIN_WIND,
    lerp_pose(FIN_WIND, FIN_POSE, 0.6),
    dict(FIN_POSE, rot=15, spark=1),
    dict(FIN_POSE, spark=3),
    dict(FIN_POSE, spark=2),
]

ANIMS = {
    "trick_flip": (FLIP, 26.0, False),
    "trick_star": (STAR, 32.0, False),
    "trick_finish": (FINISH, 20.0, False),
}
FOLDER = "combo"


def build_default():
    frames = {}
    for name, (poses, _fps, _loop) in ANIMS.items():
        frames[name] = [render(p) for p in poses]
    return frames


# ---------------------------------------------------------------- skiny
SKINS = {
    "": ("assets/sprites/player/jump/Stellyjump%d.png", "assets/sprites/player/trick/Stellysiadanabutliodvanisha%d.png"),
    "2077Stelly": ("assets/sprites/player/2077Stelly/Jump/2077Stellyjump%d.png", "assets/sprites/player/2077Stelly/Trick/2077StellyTrick%d.png"),
    "NoirStelly": ("assets/sprites/player/NoirStelly/Jump/NoirStellyjump%d.png", "assets/sprites/player/NoirStelly/Trick/NoirStellyTrick%d.png"),
    "OfficeStelly": ("assets/sprites/player/OfficeStelly/Jump/OfficeStellyjump%d.png", "assets/sprites/player/OfficeStelly/Trick/OfficeStellyTrick%d.png"),
    "PromissedStelly": ("assets/sprites/player/PromissedStelly/Jump/PromissedStellyjump%d.png", "assets/sprites/player/PromissedStelly/Trick/PromissedStellyTrick%d.png"),
    "RetroStelly": ("assets/sprites/player/RetroStelly/Jump/RetroStellyjump%d.png", "assets/sprites/player/RetroStelly/Trick/RetroStellyTrick%d.png"),
}


def palette_map(skin):
    jp, tp = SKINS[skin]
    base_j, base_t = SKINS[""]
    votes = {}
    pairs = [(base_t % i, tp % i) for i in (1, 10)] + [(base_j % i, jp % i) for i in range(1, 6)]
    for a, b in pairs:
        pa, pb = os.path.join(ROOT, a), os.path.join(ROOT, b)
        if not (os.path.exists(pa) and os.path.exists(pb)):
            continue
        A = np.array(Image.open(pa).convert("RGBA")).reshape(-1, 4)
        B = np.array(Image.open(pb).convert("RGBA")).reshape(-1, 4)
        for ca, cb in zip(map(tuple, A), map(tuple, B)):
            if ca[3] and cb[3]:
                votes.setdefault(ca, {}).setdefault(cb, 0)
                votes[ca][cb] += 1
    return {k: max(v.items(), key=lambda kv: kv[1])[0] for k, v in votes.items()}


def recolor(frame, pmap):
    out = frame.copy()
    flat = out.reshape(-1, 4)
    for i, px in enumerate(map(tuple, frame.reshape(-1, 4))):
        if px[3] and px in pmap:
            flat[i] = pmap[px]
    return out


def skin_dir(skin):
    if skin == "":
        return os.path.join(ROOT, "assets/sprites/player", FOLDER)
    return os.path.join(ROOT, "assets/sprites/player", skin, "Combo")


def main():
    frames = build_default()
    written = {}
    for skin in SKINS:
        pmap = palette_map(skin) if skin else {}
        d = skin_dir(skin)
        os.makedirs(d, exist_ok=True)
        prefix = skin if skin else "Stelly"
        for name, fr in frames.items():
            for i, f in enumerate(fr):
                img = recolor(f, pmap) if pmap else f
                path = os.path.join(d, "%s_%s%d.png" % (prefix, name, i + 1))
                Image.fromarray(img, "RGBA").save(path)
                written.setdefault(skin, {}).setdefault(name, []).append(os.path.relpath(path, ROOT).replace("\\", "/"))
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        sc = 5
        rows = [(s, n) for s in SKINS for n in ANIMS]
        W = max(len(v) for v in frames.values())
        sheet = Image.new("RGBA", (W * 64 * sc, len(ANIMS) * 64 * sc), (58, 52, 80, 255))
        for r, n in enumerate(ANIMS):
            for i, f in enumerate(frames[n]):
                im = Image.fromarray(f, "RGBA").resize((64 * sc, 64 * sc), Image.NEAREST)
                sheet.alpha_composite(im, (i * 64 * sc, r * 64 * sc))
        sheet.save(os.path.join(PREVIEW, "combo_default.png"))
        sk = Image.new("RGBA", (len(SKINS) * 64 * 3, 64 * 3), (58, 52, 80, 255))
        for i, s in enumerate(SKINS):
            p = os.path.join(ROOT, written[s]["trick_finish"][-1])
            sk.alpha_composite(Image.open(p).convert("RGBA").resize((192, 192), Image.NEAREST), (i * 192, 0))
        sk.save(os.path.join(PREVIEW, "combo_skins.png"))
    return written


TRES = {
    "": "scenes/player/player_sprite_frames.tres",
    "2077Stelly": "scenes/player/skins/2077_stelly.tres",
    "NoirStelly": "scenes/player/skins/noir_stelly.tres",
    "OfficeStelly": "scenes/player/skins/office_stelly.tres",
    "PromissedStelly": "scenes/player/skins/promissed_stelly.tres",
    "RetroStelly": "scenes/player/skins/retro_stelly.tres",
}
NL = "\n"


def patch_sprite_frames(written):
    """Dopisuje animacje trick_* do SpriteFrames każdego skina (idempotentnie)."""
    for skin, tres in TRES.items():
        path = os.path.join(ROOT, tres)
        if not os.path.exists(path):
            continue
        txt = open(path, encoding="utf-8").read()
        # usuń poprzednią wersję (ponowne generowanie)
        txt = re.sub(r'\[ext_resource type="Texture2D" path="[^"]*" id="cmb_[^"]*"\]\n', "", txt)
        txt = re.sub(r', \{\n"frames": \[\{\n"duration": 1\.0,\n"texture": ExtResource\("cmb_[\s\S]*?"name": &"trick_[a-z]+",\n"speed": [0-9.]+\n\}', "", txt)
        ext_lines, anims = [], []
        for name, (_poses, fps, loop) in ANIMS.items():
            frames = []
            for i, rel in enumerate(written[skin][name]):
                rid = "cmb_%s_%d" % (name, i + 1)
                ext_lines.append('[ext_resource type="Texture2D" path="res://%s" id="%s"]' % (rel, rid))
                frames.append('{' + NL + '"duration": 1.0,' + NL + '"texture": ExtResource("%s")' % rid + NL + '}')
            anims.append('{' + NL + '"frames": [' + ", ".join(frames) + '],' + NL
                         + '"loop": %s,' % ("true" if loop else "false") + NL
                         + '"name": &"%s",' % name + NL + '"speed": %s' % fps + NL + '}')
        last_ext = [m.end() for m in re.finditer(r'\[ext_resource [^\n]*\]\n', txt)][-1]
        txt = txt[:last_ext] + NL.join(ext_lines) + NL + txt[last_ext:]
        end = txt.rstrip().rfind("}]")
        txt = txt[:end] + "}, " + ", ".join(anims) + "]" + NL
        open(path, "w", encoding="utf-8", newline=NL).write(txt)
        print("patched", tres)


if __name__ == "__main__":
    w = main()
    patch_sprite_frames(w)
    for s, d in w.items():
        print(s or "default", {k: len(v) for k, v in d.items()})
