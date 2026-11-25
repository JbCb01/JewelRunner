"""Level 1 (SYNERGY_CLASSIC) v2 for JewelRunner - larger, parallax background, checkpoints,
power-up jewels, trampolines, abyss with checkpoint respawn.

Reach of the reworked player (measured in Godot, measure_moves.gd):
  apex: jump 60, jump+DJ 105 | same-height centre travel: jump ~130, jump+DJ ~252,
  jump+dash ~260, jump+DJ+dash ~385 | 18px headroom: jump+DJ 80, jump+dash 128, all 175
Design rules (16px tiles):  plain gap <=6 | DJ-or-dash gap 11 | DJ+dash leap 20 (same height)
  DJ ledge 5 high | climb wall 8 high | ceiling-dash pit 8 under a 3-high corridor
"""
import os, re, sys
from PIL import Image, ImageDraw

ROOT, OUT = sys.argv[1], sys.argv[2]
WRITE = '--write' in sys.argv
T = 16
C0, C1 = 0, 323
R0, R1 = -14, 22
GROUND = 19
grid = {}
SOLID = set('#B')
jewels, enemies, decor, labels, checkpoints, trampolines = [], [], [], [], [], []


def fill(c0, c1, r0, r1, ch):
    for c in range(c0, c1 + 1):
        for r in range(r0, r1 + 1):
            if ch == '.':
                grid.pop((c, r), None)
            else:
                grid[(c, r)] = ch


NORMAL, JEW, SPEED, IMMUNITY = 0, 1, 2, 3


def J(c, r, kind=NORMAL, secret=None):
    jewels.append((c * T + 8, r * T + 8, kind, secret))


def E(c, floor_r):
    enemies.append((c * T + 8, floor_r * T - 9))


def D(name, c, floor_r):
    if name == 'palm':
        decor.append(('palm_trunk', c + 1, floor_r))
        decor.append(('palm_top', c, floor_r - 3))
        return
    decor.append((name, c, floor_r))


def CP(c, floor_r):
    checkpoints.append((c * T + 8, floor_r * T - 24))


def TR(c, floor_r, bounce):
    # pad sits flush in a 1-tile notch of the floor, so you can run straight onto it
    grid.pop((c, floor_r), None)
    trampolines.append((c * T + 8, floor_r * T + 8, bounce))


def LBL(name, text, x, y, w=150):
    labels.append((name, text, x, y, w))


# ================================================================== START c0-23
fill(0, 1, R0, R1, 'B')
fill(2, 23, GROUND, R1, '#')
fill(9, 11, 17, 18, '#')
fill(15, 17, 19, 20, '.'); fill(15, 17, 20, 20, '^')
SPAWN = (72, GROUND * T - 15)
J(10, 14); J(16, 15); J(21, 16)
for n, c in (('tree', 3), ('sign', 6), ('flowers', 8), ('bush_s', 13), ('rock', 20)):
    D(n, c, GROUND)

# ================================================================== FORK 1 c24-74
fill(24, 74, GROUND, R1, '#')
fill(26, 35, 11, 16, '#'); fill(26, 26, 11, 16, 'B')          # hill, brick face = climb (128)
fill(28, 34, 17, 17, 'v')                                     # LOW: tunnel ceiling spikes -> slide
fill(29, 32, R0, 8, 'B'); fill(29, 32, 9, 9, 'v')             # HIGH: hanging pillar -> slide
fill(42, 54, 11, 15, '#')                                     # island + corridor roof (48px headroom)
fill(44, 51, 19, 20, '.'); fill(44, 51, 20, 20, '^')          # LOW: 8-wide pit under the roof -> dash
E(58, GROUND)
fill(62, 66, 14, 18, '#')                                     # LOW: 80px ledge -> double jump
# HIGH: 18-wide leap island(c54) -> hub1(c73), lands off-screen -> double jump + dash
J(27, 9); J(39, 7); J(47, 9); J(51, 9, SPEED); J(63, 6)
J(31, 18); J(37, 17); J(43, 17, IMMUNITY); J(48, 17); J(64, 12); J(70, 17)
D('flowers', 34, 11); D('palm', 43, 11); D('bush_s', 53, 11)
for n, c in (('bush', 24), ('flowers', 36), ('rock', 56), ('tree', 66), ('mushroom', 72)):
    D(n, c, GROUND)

# ================================================================== HUB 1 c75-99 (top r11)
fill(73, 99, 11, R1, '#'); fill(73, 73, 11, 18, 'B')          # LOW: brick face 128 -> climb
CP(80, 11)
J(86, 8); J(93, 8)
D('palm', 77, 11); D('flowers', 83, 11); D('bigtree', 89, 11); D('fence', 95, 11); D('sign', 98, 11)

# ================================================================== FORK 2 c100-161
fill(100, 161, GROUND, R1, '#')
fill(102, 113, 11, 16, '#'); fill(114, 129, 11, 15, '#')      # overhang (drop hole c100-101)
fill(105, 110, 17, 17, 'v')                                   # LOW: crawl -> slide
fill(116, 123, 19, 20, '.'); fill(116, 123, 20, 20, '^')      # LOW: corridor pit -> dash
fill(106, 107, -6, 8, 'B'); fill(112, 113, -6, 10, 'B')       # SKY: wall-jump chimney (doorway r9-10)
fill(114, 126, -6, -6, '=')
fill(118, 121, R0, -9, 'B'); fill(118, 121, -8, -8, 'v')      # SKY: hanging pillar -> slide
fill(133, 140, -6, -6, '=')                                   # SKY: 6-wide plain gap before it
fill(159, 166, -6, -6, '=')                                   # SKY: 18-wide leap target (off-screen)
E(140, GROUND)
fill(154, 159, 14, 18, '#')                                   # LOW: 80px step -> double jump
J(100, 18, IMMUNITY); J(108, 18); J(120, 17); J(144, 17); J(156, 12)
J(109, 3); J(110, -3); J(123, -8); J(136, -8); J(149, -11)
J(165, -8, NORMAL, ('L1-SKY-LANE', 'Klejnot Koron Drzew', 'Legendarny'))
D('flowers', 103, 11)
for n, c in (('tree', 131), ('mushroom', 135), ('flowers', 146), ('rock', 152)):
    D(n, c, GROUND)

# ================================================================== HUB 2 c162-189 (top r6)
fill(160, 189, 6, R1, '#'); fill(160, 160, 6, 13, 'B')        # LOW: brick face 128 -> climb
CP(166, 6)
J(174, 3); J(182, 3)
TR(187, 6, -620.0)                                            # canopy launcher
D('palm', 170, 6); D('bush', 178, 6); D('sign', 185, 6)

# ================================================================== FORK 3 "abyss gardens" c190-251 (no ground!)
# CANOPY (r-2 bead bridges)
fill(190, 200, -2, -2, '=')
fill(204, 217, -2, -2, '=')
fill(206, 209, R0, -5, 'B'); fill(206, 209, -4, -4, 'v')      # hanging pillar -> slide
fill(236, 243, -2, -2, '=')                                   # 18-wide leap target (off-screen)
fill(244, 245, -10, -3, 'B'); fill(246, 251, -10, -10, 'B')   # 128 brick climb, then drop to hub3
J(193, -4); J(200, -6); J(213, -4); J(227, -6); J(240, -4, SPEED); J(250, -12)
# UNDERGROWTH (r15 islands over the abyss)
fill(191, 198, 15, 17, '#')                                   # U1
fill(210, 229, 15, 17, '#')                                   # U2 (11-wide gap before it -> DJ/dash)
fill(214, 221, 11, 12, 'B'); fill(214, 221, 13, 13, 'v'); fill(214, 221, 10, 10, '^')  # crawl slab
fill(227, 238, 10, 11, 'B'); fill(227, 238, 9, 9, '^')        # corridor roof over an 8-wide abyss gap
fill(238, 251, 15, 17, '#')                                   # U3
J(195, 13); J(204, 11); J(211, 13, IMMUNITY); J(217, 14); J(233, 13)
E(245, 15)
D('bush_s', 192, 15); D('flowers', 249, 15)

# ================================================================== HUB 3 c252-277 (top r7)
fill(252, 277, 7, R1, '#'); fill(252, 252, 7, 14, 'B')        # brick face 128 from U3 -> climb
CP(256, 7)
J(264, 4); J(272, 4)
D('palm', 260, 7); D('bigtree', 268, 7); D('sign', 276, 7)

# ================================================================== FINALE c278-323
fill(278, 321, GROUND, R1, '#')
J(280, 11); J(282, 15)                                        # caught while dropping (trick fall)
CP(285, GROUND)
J(288, 16, JEW)
fill(290, 303, 18, 18, '^')                                   # spike field ...
fill(292, 294, 16, 16, '='); fill(297, 299, 16, 16, '=')      # ... with bead stepping stones
J(293, 14); J(298, 14)
E(304, GROUND)
TR(308, GROUND, -620.0)
fill(312, 321, 9, 18, '#'); fill(312, 312, 9, 18, 'B')        # finish ledge (160 up: trampoline+DJ or climb)
FINISH = (317 * T + 8, 9 * T - 28)
J(315, 6); J(320, 6)
D('flowers', 313, 9); D('fence', 320, 9)
for n, c in (('pumpkin', 279), ('bush_s', 288), ('rock', 310)):
    D(n, c, GROUND)
fill(322, 323, R0, R1, 'B')
WIDTH = 324 * T

# ------------------------------------------------------------------ labels
LBL('LabelWall', 'Climb [{move_up}]', 344, 196, 80)
LBL('LabelTunnel', 'Slide [{crouch_slide}] >>', 300, 252, 100)
LBL('LabelPlatforms', 'Double Jump', 980, 190, 100)
LBL('LabelGap', 'Jump + Dash [{dash}]', 640, 262, 150)
LBL('LabelLeap', 'Leap: Double Jump + Dash >>', 760, 100, 220)
LBL('LabelChimney', 'Wall Jump ^', 1660, 120, 100)
LBL('LabelTrampoline', 'Trampoline ^', 2950, 40, 100)
LBL('LabelAirTrick', 'Tricks in air: [{trick_flip}] [{trick_star}], [{trick_finish}] = FINALE', 4372, 60, 340)


# ------------------------------------------------------------------ skill zones (PlayStyleProfiler sensors)
ZONES = []


def Z(tag, uid, c0, r0, c1, r1):
    ZONES.append((tag, uid, c0, r0, c1, r1))


Z('route:high', 'L1F1', 26, -6, 54, 10); Z('route:low', 'L1F1', 27, 17, 72, 18)
Z('wall_climb', 'L1F1', 24, 10, 26, 18); Z('slide', 'L1F1', 27, 17, 35, 18); Z('slide', 'L1F1', 28, 9, 33, 10)
Z('dash', 'L1F1', 42, 16, 54, 20); Z('dash', 'L1F1', 55, 0, 72, 10); Z('double_jump', 'L1F1', 59, 13, 66, 18)
Z('wall_climb', 'L1F1', 70, 10, 73, 18)
Z('route:sky', 'L1F2', 106, -13, 168, -1); Z('route:low', 'L1F2', 100, 17, 159, 18)
Z('wall_jump', 'L1F2', 108, -6, 111, 10); Z('slide', 'L1F2', 103, 17, 111, 18); Z('slide', 'L1F2', 117, -8, 122, -7)
Z('dash', 'L1F2', 114, 16, 129, 20); Z('dash', 'L1F2', 141, -12, 158, -5); Z('double_jump', 'L1F2', 150, 13, 159, 18)
Z('wall_climb', 'L1F2', 156, 5, 160, 13)
Z('route:canopy', 'L1F3', 190, -13, 251, -1); Z('route:under', 'L1F3', 191, 11, 251, 17)
Z('trampoline', 'L1F3', 185, 0, 189, 6); Z('slide', 'L1F3', 205, -4, 210, -3); Z('slide', 'L1F3', 213, 13, 222, 14)
Z('dash', 'L1F3', 218, -10, 235, -3); Z('dash', 'L1F3', 225, 12, 239, 17); Z('double_jump', 'L1F3', 199, 9, 209, 16)
Z('wall_climb', 'L1F3', 241, -10, 245, -3); Z('wall_climb', 'L1F3', 248, 6, 252, 14)
Z('trick', 'L1END', 278, 8, 283, 18); Z('trampoline', 'L1END', 306, 6, 310, 18)

# ================================================================== derived
def merge_rects(pred):
    used, rects = set(), []
    for r in range(R0, R1 + 1):
        c = C0
        while c <= C1:
            if pred(c, r) and (c, r) not in used:
                ce = c
                while ce + 1 <= C1 and pred(ce + 1, r) and (ce + 1, r) not in used:
                    ce += 1
                re_ = r
                while re_ + 1 <= R1 and all(pred(x, re_ + 1) and (x, re_ + 1) not in used for x in range(c, ce + 1)):
                    re_ += 1
                for x in range(c, ce + 1):
                    for y in range(r, re_ + 1):
                        used.add((x, y))
                rects.append((c, ce, r, re_))
                c = ce + 1
            else:
                c += 1
    return rects


solid_rects = merge_rects(lambda c, r: grid.get((c, r)) in SOLID)
bridge_runs = merge_rects(lambda c, r: grid.get((c, r)) == '=')
floor_spikes = merge_rects(lambda c, r: grid.get((c, r)) == '^')
ceil_spikes = merge_rects(lambda c, r: grid.get((c, r)) == 'v')


def tile_for(c, r):
    ch, above = grid.get((c, r)), grid.get((c, r - 1))
    if ch == '#':
        if above not in SOLID:
            return (0, 0)
        return (4, 1) if (c * 7 + r * 13) % 11 == 0 else (0, 1)
    if ch == 'B':
        return (1, 0) if above != 'B' else ((1, 1) if (c + r) % 3 else (1, 0))
    if ch == '=':
        return (6 + c % 3, 3)
    return None


tiles = {k: tile_for(*k) for k in grid if tile_for(*k)}
DECOR = {'tree': (0, 48, 16, 48), 'bigtree': (128, 64, 16, 48), 'palm_top': (32, 80, 48, 16),
         'palm_trunk': (48, 96, 16, 48), 'bush': (128, 112, 16, 16), 'bush_s': (16, 64, 16, 16),
         'flowers': (16, 96, 16, 16), 'sign': (64, 48, 16, 16), 'fence': (0, 96, 16, 16),
         'rock': (80, 112, 16, 16), 'mushroom': (160, 16, 16, 16), 'pumpkin': (96, 96, 16, 16)}
BG_Y = -413                     # Background-export.png row 405 sits at the top of the ground view (y=-8)

# ================================================================== ASCII + preview
marks = {}
for x, y, k, s in jewels:
    marks[(x // T, y // T)] = 'S' if s else ('J' if k == 0 else 'P')
for x, y in enemies:
    marks[(x // T, (y + 9) // T - 1)] = 'E'
for x, y in checkpoints:
    marks[(x // T, (y + 24) // T - 1)] = 'C'
for x, y, b in trampolines:
    marks[(x // T, y // T)] = 'T'
with open(os.path.join(OUT, 'level2_ascii.txt'), 'w') as fh:
    for r in range(R0, R1 + 1):
        fh.write(f'{r:4} ' + ''.join(marks.get((c, r), grid.get((c, r), '.')) for c in range(C0, C1 + 1)) + '\n')

TS = Image.open(os.path.join(ROOT, 'assets/tilesett.png')).convert('RGBA')
SPK = Image.open(os.path.join(ROOT, 'assets/Kolce.png')).convert('RGBA')
BG = Image.open(os.path.join(ROOT, 'assets/Background-export.png')).convert('RGBA')
CPS = Image.open(os.path.join(ROOT, 'assets/Checkpoint_sheet.png')).convert('RGBA').crop((0, 0, 64, 96))
JW = {k: Image.open(os.path.join(ROOT, f'assets/{n}.png')).convert('RGBA') for k, n in
      ((0, 'Jewel'), (1, 'JewJewel'), (2, 'SpeedJewel'), (3, 'ImmunityJewel'))}
OY = -R0 * T
img = Image.new('RGBA', (WIDTH, (R1 - R0 + 1) * T), (20, 25, 35, 255))
for bx in range(0, WIDTH, BG.width):              # preview without parallax (scroll_scale.x applies in game)
    img.alpha_composite(BG, (bx, BG_Y + OY))
for (name, c, fr) in decor:
    x, y, w, h = DECOR[name]
    img.alpha_composite(TS.crop((x, y, x + w, y + h)), (c * T, fr * T - h + OY))
for (c, r), (ax, ay) in tiles.items():
    img.alpha_composite(TS.crop((ax * 16, ay * 16, ax * 16 + 16, ay * 16 + 16)), (c * T, r * T + OY))
sp15 = SPK.resize((24, 24), Image.NEAREST)
for c0, c1, r0, _ in floor_spikes:
    for x in range(c0 * T, (c1 + 1) * T, 24):
        w = min(24, (c1 + 1) * T - x)
        img.alpha_composite(sp15.crop((0, 0, w, 24)), (x, (r0 + 1) * T - 24 + OY))
spf = SPK.transpose(Image.FLIP_TOP_BOTTOM)
for c0, c1, r0, _ in ceil_spikes:
    for c in range(c0, c1 + 1):
        img.alpha_composite(spf, (c * T, r0 * T + OY))
for x, y in checkpoints:
    img.alpha_composite(CPS, (x - 15, y - 72 + OY))
tramp = TS.crop((16, 32, 32, 48))
for x, y, b in trampolines:
    img.alpha_composite(tramp, (x - 8, y - 8 + OY))
for x, y, k, s in jewels:
    im = JW[k]
    img.alpha_composite(im, (x - im.width // 2, y - im.height // 2 + OY))
    if s:
        ImageDraw.Draw(img).ellipse([x - 15, y - 15 + OY, x + 15, y + 15 + OY], outline=(255, 215, 0, 255), width=2)
d = ImageDraw.Draw(img)
for x, y in enemies:
    d.rectangle([x - 9, y - 9 + OY, x + 9, y + 9 + OY], fill=(220, 60, 90, 255))
fx, fy = FINISH
d.rectangle([fx - 16, fy - 28 + OY, fx + 16, fy + 28 + OY], outline=(255, 215, 0, 255), width=3)
for name, text, x, y, w in labels:
    d.text((x, y + OY), text, fill=(255, 255, 255, 255))
d.line([(0, -8 + OY), (WIDTH, -8 + OY)], fill=(255, 80, 80, 200), width=1)
img.save(os.path.join(OUT, 'level2_full.png'))
print('width', WIDTH, 'solid', len(solid_rects), 'bridges', len(bridge_runs), 'tiles', len(tiles),
      'jewels', len(jewels), 'required', -(-len(jewels) // 2), 'checkpoints', len(checkpoints))

if not WRITE:
    sys.exit()

# ================================================================== scene splice
P = os.path.join(ROOT, 'scenes/test_arena.tscn')
src = open(P, encoding='utf8').read()
blocks = re.split(r'\n(?=\[)', src)
hdr = lambda b: b.split('\n', 1)[0]


def attr(h, key):
    m = re.search(key + r'="([^"]*)"', h)
    return m.group(1) if m else None


subs, nodes, sid = [], [], [0]


def shape(w, h):
    sid[0] += 1
    i = f'RectangleShape2D_lvl{sid[0]}'
    subs.append(f'[sub_resource type="RectangleShape2D" id="{i}"]\nsize = Vector2({w}, {h})\n')
    return i


fmt = lambda v: f'{v:g}'
nodes.append('[node name="Geometry" type="Node2D" parent="."]\n')
# background: forest image, horizontal parallax, vertically fixed to the world (sky above the canopy)
nodes.append('[node name="BackgroundParallax" type="Parallax2D" parent="Geometry"]\nz_index = -10\n'
             'scroll_scale = Vector2(0.4, 1)\nrepeat_size = Vector2(928, 0)\nrepeat_times = 3\n')
nodes.append(f'[node name="Forest" type="Sprite2D" parent="Geometry/BackgroundParallax"]\ntexture_filter = 1\n'
             f'position = Vector2(0, {BG_Y})\ntexture = ExtResource("17_background_tex")\ncentered = false\n')
for n, (c0, c1, r0, r1) in enumerate(solid_rects, 1):
    w, h = (c1 - c0 + 1) * T, (r1 - r0 + 1) * T
    s = shape(w, h)
    nodes.append(f'[node name="Block{n}" type="StaticBody2D" parent="Geometry"]\nposition = Vector2({fmt(c0 * T + w / 2)}, {fmt(r0 * T + h / 2)})\ncollision_mask = 0\n')
    nodes.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Geometry/Block{n}"]\nshape = SubResource("{s}")\n')
for n, (c0, c1, r0, r1) in enumerate(bridge_runs, 1):
    w = (c1 - c0 + 1) * T
    s = shape(w, 8)
    nodes.append(f'[node name="Bridge{n}" type="StaticBody2D" parent="Geometry"]\nposition = Vector2({fmt(c0 * T + w / 2)}, {fmt(r0 * T + 4)})\ncollision_mask = 0\n')
    nodes.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Geometry/Bridge{n}"]\nshape = SubResource("{s}")\none_way_collision = true\n')
nodes.append(f'[node name="LevelBounds" type="Node2D" parent="Geometry"]\nscript = ExtResource("16_level_bounds")\n'
             f'limit_left = 0\nlimit_top = -208\nlimit_right = {WIDTH}\nlimit_bottom = 352\n')
data = bytearray(b'\x00\x00')
for (c, r), (ax, ay) in sorted(tiles.items(), key=lambda kv: (kv[0][1], kv[0][0])):
    data += (c & 0xFFFF).to_bytes(2, 'little') + (r & 0xFFFF).to_bytes(2, 'little')
    data += (0).to_bytes(2, 'little') + ax.to_bytes(2, 'little') + ay.to_bytes(2, 'little') + (0).to_bytes(2, 'little')
nodes.append('[node name="Tiles" type="TileMapLayer" parent="Geometry" groups=["visual_only"]]\ntexture_filter = 1\n'
             f'tile_map_data = PackedByteArray({", ".join(str(b) for b in data)})\ntile_set = ExtResource("18_tileset_world")\n')
nodes.append('[node name="Decor" type="Node2D" parent="Geometry"]\nz_index = -1\n')
for n, (name, c, fr) in enumerate(decor, 1):
    x, y, w, h = DECOR[name]
    nodes.append(f'[node name="{name.title().replace("_", "")}{n}" type="Sprite2D" parent="Geometry/Decor"]\ntexture_filter = 1\n'
                 f'position = Vector2({c * T}, {fr * T - h})\ntexture = ExtResource("15_tileset_tex")\ncentered = false\n'
                 f'region_enabled = true\nregion_rect = Rect2({x}, {y}, {w}, {h})\n')

nodes.append('[node name="Hazards" type="Node2D" parent="."]\n')
names = ['SpikesGap', 'SpikesGap2']
for n, (c0, c1, r0, r1) in enumerate(floor_spikes):
    w = (c1 - c0 + 1) * T
    nm = names[n] if n < 2 else f'SpikesFloor{n + 1}'
    s = shape(w - 4, 18)
    nodes.append(f'[node name="{nm}" type="Area2D" parent="Hazards"]\nposition = Vector2({fmt(c0 * T + w / 2)}, {(r0 + 1) * T - 12})\ncollision_layer = 16\ncollision_mask = 2\nscript = ExtResource("2_hazard")\n')
    nodes.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Hazards/{nm}"]\nposition = Vector2(0, 3)\nshape = SubResource("{s}")\n')
    nodes.append(f'[node name="TextureRect" type="TextureRect" parent="Hazards/{nm}"]\ntexture_filter = 1\ntexture_repeat = 2\n'
                 f'offset_left = {fmt(-w / 2)}\noffset_top = -12.0\noffset_right = {fmt(-w / 2 + w / 1.5)}\noffset_bottom = 4.0\n'
                 f'scale = Vector2(1.5, 1.5)\ntexture = ExtResource("14_kolce_tex")\nstretch_mode = 1\n')
for n, (c0, c1, r0, r1) in enumerate(ceil_spikes, 1):
    w = (c1 - c0 + 1) * T
    nm = f'SpikesCeiling{n}'
    s = shape(w - 4, 12)
    nodes.append(f'[node name="{nm}" type="Area2D" parent="Hazards"]\nposition = Vector2({fmt(c0 * T + w / 2)}, {r0 * T + 6})\ncollision_layer = 16\ncollision_mask = 2\nscript = ExtResource("2_hazard")\n')
    nodes.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Hazards/{nm}"]\nshape = SubResource("{s}")\n')
    nodes.append(f'[node name="TextureRect" type="TextureRect" parent="Hazards/{nm}"]\ntexture_filter = 1\ntexture_repeat = 2\n'
                 f'offset_left = {fmt(-w / 2)}\noffset_top = -6.0\noffset_right = {fmt(w / 2)}\noffset_bottom = 10.0\n'
                 f'texture = ExtResource("14_kolce_tex")\nstretch_mode = 1\nflip_v = true\n')
s = shape(WIDTH + 400, 64)                          # bottomless pit: lose 1 HP, respawn at the last checkpoint
nodes.append(f'[node name="AbyssZone" type="Area2D" parent="Hazards"]\nposition = Vector2({WIDTH // 2}, 420)\n'
             'collision_layer = 16\ncollision_mask = 2\nscript = ExtResource("2_hazard")\nis_abyss = true\n')
nodes.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Hazards/AbyssZone"]\nshape = SubResource("{s}")\n')

nodes.append('[node name="Checkpoints" type="Node2D" parent="."]\nz_index = 2\n')
for n, (x, y) in enumerate(checkpoints, 1):
    s = shape(36, 64)
    nodes.append(f'[node name="Checkpoint{n}" type="Area2D" parent="Checkpoints"]\nposition = Vector2({x}, {y})\n'
                 f'collision_layer = 0\ncollision_mask = 2\nscript = ExtResource("19_checkpoint")\ncheckpoint_id = "CP-{n}"\n')
    nodes.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Checkpoints/Checkpoint{n}"]\nposition = Vector2(0, -8)\nshape = SubResource("{s}")\n')
nodes.append('[node name="Zones" type="Node2D" parent="."]\n')
for n, (tag, uid, c0, r0, c1, r1) in enumerate(ZONES, 1):
    w, h = (c1 - c0 + 1) * T, (r1 - r0 + 1) * T
    zs = shape(w, h)
    nm = f'Zone{n}_{tag.replace(":", "_")}'
    nodes.append(f'[node name="{nm}" type="Area2D" parent="Zones"]\nposition = Vector2({fmt(c0 * T + w / 2)}, {fmt(r0 * T + h / 2)})\n'
                 f'collision_layer = 0\ncollision_mask = 2\nmonitorable = false\nscript = ExtResource("21_skill_zone")\ntag = "{tag}"\nmodule_uid = "{uid}"\n')
    nodes.append(f'[node name="CollisionShape2D" type="CollisionShape2D" parent="Zones/{nm}"]\nshape = SubResource("{zs}")\n')
nodes.append('[node name="Trampolines" type="Node2D" parent="."]\nz_index = 1\n')
for n, (x, y, b) in enumerate(trampolines, 1):
    nodes.append(f'[node name="Trampoline{n}" type="Area2D" parent="Trampolines"]\nposition = Vector2({x}, {y})\n'
                 f'collision_layer = 0\ncollision_mask = 2\nscript = ExtResource("20_trampoline")\nbounce_velocity = {fmt(b)}\n')

jewel_nodes = []
for n, (x, y, k, secret) in enumerate(jewels, 1):
    extra = f'jewel_type = {k}\n' if k else ''
    if secret:
        sid_, sname, rar = secret
        extra += f'is_secret_special = true\nspecial_id = "{sid_}"\nspecial_name = "{sname}"\nspecial_rarity = "{rar}"\n'
    jewel_nodes.append(f'[node name="Jewel{n}" parent="." instance=ExtResource("7_jewel_scene")]\nposition = Vector2({x}, {y})\n' + extra)
enemy_nodes = [f'[node name="{"EnemyMockup" if n == 1 else f"EnemyMockup{n}"}" parent="." instance=ExtResource("12_enemy_mockup")]\nposition = Vector2({x}, {y})\n'
               for n, (x, y) in enumerate(enemies, 1)]
label_nodes = [f'[node name="{name}" type="Label" parent="Labels"]\noffset_left = {x}.0\noffset_top = {y}.0\n'
               f'offset_right = {x + w}.0\noffset_bottom = {y + 23}.0\ntext = "{text}"\n' for name, text, x, y, w in labels]

GEN_SUB = re.compile(r'^(RectangleShape2D_lvl\d+|TileSetAtlasSource_lvl|TileSet_lvl)$')
MY_EXT = {'15_tileset_tex', '16_level_bounds', '17_background_tex', '18_tileset_world', '19_checkpoint', '20_trampoline', '21_skill_zone'}
LEVEL_ROOTS = ('Geometry', 'Hazards', 'Decor', 'Checkpoints', 'Trampolines', 'Zones')
out = []
for b in blocks:
    h = hdr(b)
    if h.startswith('[sub_resource') and GEN_SUB.match(attr(h, 'id') or ''):
        continue
    if h.startswith('[ext_resource') and attr(h, 'id') in MY_EXT:
        continue
    if h.startswith('[node'):
        name, parent = attr(h, 'name'), attr(h, 'parent')
        if parent and (parent in LEVEL_ROOTS + ('Labels',) or any(parent.startswith(r + '/') for r in LEVEL_ROOTS)):
            continue
        if parent == '.' and (name in LEVEL_ROOTS or name.startswith('Jewel') or name.startswith('EnemyMockup')):
            continue
        if name == 'Background' and parent == '.':
            b = re.sub(r'offset_right = .*', f'offset_right = {WIDTH + 400}.0', b)
            if 'z_index' not in b:
                b = b.replace('\noffset_left', '\nz_index = -20\noffset_left', 1)
        if name in ('RespawnPoint', 'Player') and parent == '.':
            b = re.sub(r'position = Vector2\([^)]*\)', f'position = Vector2({SPAWN[0]}, {SPAWN[1]})', b)
        if name == 'FinishGoal':
            b = re.sub(r'position = Vector2\([^)]*\)', f'position = Vector2({FINISH[0]}, {FINISH[1]})', b, count=1)
            out.extend(jewel_nodes + enemy_nodes)
        out.append(b)
        if name == 'Player' and parent == '.':
            out.extend(nodes)
        if name == 'Labels' and parent == '.':
            out.extend(label_nodes)
        continue
    out.append(b)

res = '\n'.join(out)
ext_new = ('[ext_resource type="Texture2D" path="res://assets/tilesett.png" id="15_tileset_tex"]\n\n'
           '[ext_resource type="Script" path="res://scripts/core/level_bounds.gd" id="16_level_bounds"]\n\n'
           '[ext_resource type="Texture2D" path="res://assets/Background-export.png" id="17_background_tex"]\n\n'
           '[ext_resource type="TileSet" path="res://assets/tileset_world.tres" id="18_tileset_world"]\n\n'
           '[ext_resource type="Script" path="res://scripts/core/checkpoint.gd" id="19_checkpoint"]\n\n'
           '[ext_resource type="Script" path="res://scripts/core/trampoline_pad.gd" id="20_trampoline"]\n\n'
           '[ext_resource type="Script" path="res://scripts/core/skill_zone.gd" id="21_skill_zone"]\n')
res = res.replace('\n[sub_resource', '\n' + ext_new + '\n[sub_resource', 1)
res = res.replace('\n[node name="TestArena"', '\n' + '\n'.join(subs) + '\n[node name="TestArena"', 1)
res = re.sub(r'\n{3,}', '\n\n', res)
open(P, 'w', encoding='utf8', newline='\n').write(res)
print('scene written')
