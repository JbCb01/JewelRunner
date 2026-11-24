"""Module library authoring tool for JewelRunner levels 2-4.

Every module is a vertical slice of the level (rows -13..22, ground top = row 19) that starts and
ends on the ground, built with the same rules that were measured/verified for level 1:
  plain gap <= 6 tiles | DJ-or-dash gap 11 | DJ+dash leap 18 (same height) | DJ ledge 5 high
  climb wall >= 8 high | ceiling-dash pit 8 under a 3-high corridor | crawl clearance 2 tiles
Exports scripts/core/level_modules.gd (ASCII maps + metadata) and preview PNGs.

Legend:  # ground   B brick (climb-look)   = one-way bridge   T trampoline (flush notch)
         ~ liquid (damage)   ^ floor spikes   v ceiling spikes
         J jewel  1 invincibility  2 speed  3 shield  X secret slot   K checkpoint  @ spawn  $ finish
         E slime  A bat  R spider     decor (stands on the surface below): t g p b s f i n r m k
"""
import os, sys, json
from PIL import Image, ImageDraw

ROOT, OUT = sys.argv[1], sys.argv[2]
RTOP, RBOT, G = -13, 22, 19
MODULES = {}


class Mod:
    def __init__(self, mid, w, tags, tier=1, desc=''):
        self.id, self.w, self.tags, self.tier, self.desc = mid, w, tags, tier, desc
        self.g = {}
        self.labels, self.zones, self.checks, self.bounce = [], [], [], []
        MODULES[mid] = self

    def fill(self, c0, c1, r0, r1, ch):
        for c in range(c0, c1 + 1):
            for r in range(r0, r1 + 1):
                if ch == '.':
                    self.g.pop((c, r), None)
                else:
                    self.g[(c, r)] = ch
        return self

    def put(self, c, r, ch):
        assert (c, r) not in self.g or ch == 'T', f'{self.id}: cell {(c, r)} taken by {self.g.get((c, r))}, wanted {ch}'
        self.g[(c, r)] = ch
        return self

    def ground(self, c0=0, c1=None):
        return self.fill(c0, self.w - 1 if c1 is None else c1, G, RBOT, '#')

    def label(self, text, x, y):
        self.labels.append({'text': text, 'x': x, 'y': y})

    def zone(self, tag, c0, r0, c1, r1):
        self.zones.append({'tag': tag, 'rect': [c0, r0, c1, r1]})

    def check(self, **kw):
        self.checks.append(kw)

    def rows(self):
        return [''.join(self.g.get((c, r), '.') for c in range(self.w)) for r in range(RTOP, RBOT + 1)]


# ============================================================ utility modules
m = Mod('start', 14, ['start'], desc='Spawn pad')
m.ground(); m.put(3, 18, '@'); m.put(6, 18, 'i'); m.put(9, 18, 'f'); m.put(8, 16, 'J'); m.put(11, 16, 'J')

m = Mod('hub', 16, ['hub'], desc='Checkpoint rest stop')
m.ground(); m.put(4, 18, 'K'); m.put(8, 15, 'J'); m.put(11, 15, 'J'); m.put(12, 18, 'p'); m.put(2, 18, 'f')

m = Mod('finish', 22, ['finish', 'trampoline'], desc='Trampoline (or climb) onto the finish ledge')
m.ground(); m.put(6, G, 'T'); m.bounce = [-620.0]
m.fill(10, 21, 9, 18, '#').fill(10, 10, 9, 18, 'B')
m.put(16, 8, '$'); m.put(13, 6, 'J'); m.put(19, 6, 'J'); m.put(12, 8, 'f'); m.put(20, 8, 'n')
m.zone('trampoline', 4, 10, 9, 18); m.zone('wall_climb', 7, 8, 10, 18)
m.check(type='trampoline', start=[1, G], pad_c=6, target=[11, 9, 21, 9])

# ============================================================ single-mechanic modules
m = Mod('spike_bridges', 22, ['jump'], desc='Spike field crossed on bead stepping stones')
m.ground(); m.fill(4, 17, 18, 18, '^'); m.fill(6, 8, 16, 16, '='); m.fill(11, 13, 16, 16, '=')
m.put(7, 14, 'J'); m.put(12, 14, 'J'); m.put(2, 18, 'r'); m.put(20, 18, 's')
m.zone('jump', 3, 12, 18, 18)

m = Mod('pool_bridges', 22, ['jump'], desc='Liquid pool (lava / ice water) crossed on stepping stones')
m.ground(); m.fill(4, 17, G, 20, '.'); m.fill(4, 17, 20, 20, '~'); m.fill(6, 8, 17, 17, '='); m.fill(11, 13, 17, 17, '=')
m.put(7, 15, 'J'); m.put(12, 15, 'J'); m.put(2, 18, 'r'); m.put(19, 18, 'b')
m.zone('jump', 3, 12, 18, 20)

for mid, top in (('climb_wall', 11), ('climb_wall_high', 10)):
    m = Mod(mid, 18, ['wall_climb'], tier=1 if top == 11 else 2, desc=f'Brick wall {G - top} tiles high: climb [W]')
    m.ground(); m.fill(6, 11, top, 18, '#').fill(6, 6, top, 18, 'B')
    m.put(9, top - 2, 'J'); m.put(3, 16, 'J'); m.put(14, 16, 'J'); m.put(8, top - 1, 's')
    m.label('Climb [W]', 24, top * 16 - 40)
    m.zone('wall_climb', 2, top - 1, 6, 18)
    m.check(type='climb', start=[4, G], target=[7, top, 11, top])
    m.check(type='climb_dj', start=[4, G], target=[7, top, 11, top])

m = Mod('chimney', 18, ['wall_jump', 'wall_climb'], tier=2, desc='Wall-jump chimney (4 wide) up to a ledge')
m.ground(); m.fill(4, 5, 7, 16, 'B'); m.fill(10, 11, 7, 18, 'B'); m.fill(12, 14, 7, 18, '#')
m.put(7, 13, 'J'); m.put(8, 9, 'J'); m.put(13, 5, 'J'); m.put(16, 18, 'f')
m.label('Wall Jump ^', 70, 80)
m.zone('wall_jump', 6, 6, 9, 18)
m.check(type='chimney', start=[2, G], shaft=[6, 9], top_row=7)

m = Mod('dash_corridor', 20, ['dash'], desc='Spike pit under a low ceiling: jump + dash')
m.ground(); m.fill(6, 13, G, 20, '.'); m.fill(6, 13, 20, 20, '^')
m.fill(4, 15, 13, 15, 'B'); m.fill(4, 15, 12, 12, '^')
m.put(10, 17, 'J'); m.put(17, 16, 'J'); m.put(1, 18, 'r')
m.label('Jump + Dash [Shift]', 40, 232)
m.zone('dash', 4, 16, 15, 20)
m.check(type='corridor', start=[2, G], edge_c=6, target=[14, G, 16, G])

for mid, gap, tier in (('dash_leap', 18, 2), ('dash_leap_short', 15, 1)):
    w = 26 + gap
    m = Mod(mid, w, ['dash', 'double_jump'] if gap == 18 else ['dash'], tier=tier, desc=f'{gap}-wide leap over the abyss, landing off-screen')
    m.fill(0, 7, G, RBOT, '#'); m.fill(6, 7, 17, 18, '#'); m.fill(8, 15, 15, RBOT, '#')
    L = 16 + gap
    m.fill(L, L + 5, 15, RBOT, '#'); m.fill(L + 6, L + 7, 17, RBOT, '#'); m.fill(L + 6, w - 1, G, RBOT, '#')
    m.put(2, 18, 'K'); m.put(11, 13, 'J'); m.put(16 + gap // 2, 10, 'J'); m.put(L + 2, 13, 'J')
    m.label('Leap: Double Jump + Dash >>' if gap == 18 else 'Leap: Dash [Shift] >>', 96, 150)
    m.zone('dash', 16, 4, L - 1, 14); m.zone('double_jump', 16, 4, L - 1, 14)
    m.check(type='leap', start=[9, 15], edge_c=16, target=[L, 15, L + 5, 15], need='DJ+dash' if gap == 18 else 'dash')

m = Mod('dj_ledges', 28, ['double_jump'], desc='Two 5-high ledges: double jump')
m.ground(); m.fill(6, 10, 14, 18, '#'); m.fill(11, 13, 18, 18, '^'); m.fill(14, 18, 9, 18, '#')
m.put(8, 12, 'J'); m.put(12, 10, 'J'); m.put(16, 7, 'J'); m.put(23, 16, 'J'); m.put(23, 18, 'E'); m.put(2, 18, 'f')
m.label('Double Jump', 70, 180)
m.zone('double_jump', 2, 8, 18, 18)
m.check(type='ledge', start=[1, G], face_c=6, target=[6, 14, 10, 14])

m = Mod('dj_islands', 34, ['double_jump'], tier=2, desc='Rising islands over the abyss')
m.fill(0, 5, G, RBOT, '#'); m.fill(10, 14, 14, 17, '#'); m.fill(19, 23, 9, 12, '#'); m.fill(28, 33, G, RBOT, '#')
m.put(12, 12, 'J'); m.put(17, 9, 'J'); m.put(21, 7, 'J'); m.put(26, 12, 'J'); m.put(31, 18, 'r')
m.zone('double_jump', 4, 6, 28, 18)

m = Mod('slide_crawl', 20, ['slide'], desc='Spiked crawl tunnel: slide [S] and stay down')
m.ground(); m.fill(4, 15, 9, 16, 'B'); m.fill(5, 14, 17, 17, 'v'); m.fill(4, 15, 8, 8, '^')
m.put(8, 18, 'J'); m.put(12, 18, 'J'); m.put(17, 16, 'J'); m.put(1, 18, 's')
m.label('Slide [S] >>', 0, 248)
m.zone('slide', 4, 17, 15, 18)
m.check(type='crawl', start=[1, G], crouch_c=3, end_c=17)

m = Mod('trampoline_tower', 26, ['trampoline', 'double_jump'], desc='Trampoline up a tall tower')
m.ground(); m.put(1, G, 'T'); m.bounce = [-620.0]
m.fill(8, 15, 7, 18, '#').fill(8, 8, 7, 18, 'B')
m.put(11, 4, 'J'); m.put(14, 4, '1'); m.put(20, 16, 'J'); m.put(12, 6, 'b')
m.label('Trampoline ^', 0, 220)
m.zone('trampoline', 0, 4, 8, 18)
m.check(type='trampoline', start=[-3, G], pad_c=1, target=[8, 7, 15, 7])

m = Mod('trick_well', 28, ['trick', 'trampoline'], desc='Launch onto a high perch, then a long trick fall')
m.ground(); m.put(2, G, 'T'); m.bounce = [-700.0]
m.fill(10, 15, 3, 18, '#').fill(10, 10, 3, 18, 'B')
m.put(13, 1, 'J'); m.put(18, 6, 'J'); m.put(19, 10, 'J'); m.put(20, 14, 'J'); m.put(25, 18, 'm')
m.label('Hold [Ctrl] while falling to recharge stamina', 200, 40)
m.zone('trick', 16, 3, 24, 18)
m.check(type='trampoline', start=[-3, G], pad_c=2, target=[10, 3, 15, 3])

m = Mod('enemy_run', 24, ['enemies', 'jump'], desc='Slime, bat and spider: stomp or dash past')
m.ground(); m.put(6, 18, 'E'); m.put(12, 15, 'A'); m.put(18, 18, 'R')
m.put(9, 16, 'J'); m.put(15, 16, '1'); m.put(21, 16, 'J'); m.put(3, 18, 'r'); m.put(22, 18, 'b')
m.zone('enemies', 0, 12, 23, 18)

# ============================================================ fork modules (from level 1)
m = Mod('fork_hill', 66, ['fork', 'wall_climb', 'slide', 'dash', 'double_jump'], tier=2,
        desc='L1 fork 1: high = climb, slide, DJ+dash leap | low = crawl, dash corridor, DJ ledge, climb')
m.ground(0, 65)
m.fill(2, 11, 11, 16, '#').fill(2, 2, 11, 16, 'B').fill(4, 10, 17, 17, 'v')
m.fill(5, 8, RTOP, 8, 'B').fill(5, 8, 9, 9, 'v')
m.fill(18, 30, 11, 15, '#'); m.fill(20, 27, G, 20, '.'); m.fill(20, 27, 20, 20, '^')
m.fill(38, 42, 14, 18, '#')
m.fill(49, 59, 11, 18, '#').fill(49, 49, 11, 18, 'B')
m.put(34, 18, 'E'); m.put(53, 10, 'K')
for c, r, k in ((3, 9, 'J'), (15, 7, 'J'), (23, 9, 'J'), (27, 9, '2'), (39, 6, 'J'), (7, 18, 'J'), (13, 17, 'J'),
                (19, 17, '3'), (24, 17, 'J'), (40, 12, 'J'), (46, 17, 'J'), (56, 8, 'J'), (58, 8, 'X')):
    m.put(c, r, k)
for c, r, k in ((10, 10, 'f'), (19, 10, 'p'), (29, 10, 's'), (0, 18, 'b'), (12, 18, 'f'), (32, 18, 'r'), (44, 18, 't'),
                (47, 18, 'm'), (51, 10, 'p'), (63, 18, 'f')):
    m.put(c, r, k)
m.label('Climb [W]', -40, 196); m.label('Slide [S] >>', -84, 252); m.label('Jump + Dash [Shift]', 256, 262)
m.label('Double Jump', 596, 190); m.label('Leap: Double Jump + Dash >>', 376, 100)
m.zone('route:high', 2, -6, 30, 10); m.zone('route:low', 3, 17, 48, 18)
m.zone('slide', 3, 17, 11, 18); m.zone('slide', 4, 9, 9, 10); m.zone('dash', 18, 16, 30, 20)
m.zone('dash', 31, 0, 48, 10); m.zone('double_jump', 35, 13, 42, 18); m.zone('wall_climb', 0, 10, 2, 18)
m.zone('wall_climb', 45, 10, 49, 18)
m.check(type='leap', start=[25, 11], edge_c=31, target=[49, 11, 59, 11], need='DJ+dash')
m.check(type='corridor', start=[17, G], edge_c=20, target=[28, G, 30, G])
m.check(type='crawl', start=[0, G], crouch_c=2, end_c=13)
m.check(type='climb', start=[0, G], target=[3, 11, 11, 11])
m.check(type='climb', start=[47, G], target=[50, 11, 59, 11])
m.check(type='ledge', start=[32, G], face_c=38, target=[38, 14, 42, 14])

m = Mod('fork_sky', 80, ['fork', 'wall_jump', 'wall_climb', 'slide', 'dash', 'double_jump'], tier=3,
        desc='L1 fork 2: sky = wall-jump chimney above the screen, slide, DJ+dash leap | low = crawl, dash corridor, DJ step, climb')
m.ground(0, 79)
m.fill(2, 13, 11, 16, '#').fill(2, 2, 11, 16, 'B').fill(14, 29, 11, 15, '#')
m.fill(5, 10, 17, 17, 'v'); m.fill(16, 23, G, 20, '.'); m.fill(16, 23, 20, 20, '^')
m.fill(6, 7, -6, 8, 'B'); m.fill(12, 13, -6, 10, 'B')
m.fill(14, 26, -6, -6, '='); m.fill(18, 21, RTOP, -9, 'B'); m.fill(18, 21, -8, -8, 'v')
m.fill(33, 40, -6, -6, '='); m.fill(59, 66, -6, -6, '=')
m.fill(54, 59, 14, 18, '#'); m.fill(60, 75, 6, 18, '#').fill(60, 60, 6, 13, 'B')
m.put(40, 18, 'E'); m.put(64, 5, 'K')
for c, r, k in ((0, 18, '3'), (8, 18, 'J'), (20, 17, 'J'), (44, 17, 'J'), (56, 12, 'J'), (9, 3, 'J'), (10, -3, 'J'),
                (23, -8, 'J'), (36, -8, 'J'), (49, -11, 'J'), (65, -8, 'X'), (68, 3, 'J'), (72, 3, 'J')):
    m.put(c, r, k)
for c, r, k in ((3, 10, 'f'), (31, 18, 't'), (35, 18, 'm'), (46, 18, 'f'), (52, 18, 'r'), (66, 5, 'p'), (72, 5, 'b'), (77, 18, 'r')):
    m.put(c, r, k)
m.label('Wall Jump ^', 60, 120); m.label('Slide [S] >>', -60, 248); m.label('Jump + Dash [Shift]', 230, 236)
m.zone('route:sky', 6, -13, 66, -1); m.zone('route:low', 3, 17, 59, 18); m.zone('wall_jump', 8, -6, 11, 10)
m.zone('slide', 3, 17, 11, 18); m.zone('slide', 17, -8, 22, -7); m.zone('dash', 14, 16, 29, 20)
m.zone('dash', 41, -12, 58, -5); m.zone('double_jump', 50, 13, 59, 18); m.zone('wall_climb', 55, 5, 60, 13)
m.zone('wall_climb', 0, 10, 2, 18)
m.check(type='chimney', start=[3, 11], shaft=[8, 11], top_row=-6)
m.check(type='leap', start=[34, -6], edge_c=41, target=[59, -6, 66, -6], need='DJ+dash')
m.check(type='corridor', start=[13, G], edge_c=16, target=[24, G, 28, G])
m.check(type='crawl', start=[0, G], crouch_c=2, end_c=13)
m.check(type='climb', start=[57, 14], target=[61, 6, 70, 6])

m = Mod('fork_canopy', 96, ['fork', 'trampoline', 'slide', 'dash', 'double_jump', 'wall_climb'], tier=3,
        desc='L1 fork 3: canopy = trampoline, slide, DJ+dash leap, climb | undergrowth = DJ gap, crawl, abyss dash corridor, climb')
m.fill(0, 11, G, RBOT, '#'); m.put(8, G, 'T'); m.bounce = [-820.0]
m.fill(12, 22, -2, -2, '='); m.fill(26, 39, -2, -2, '='); m.fill(28, 31, RTOP, -5, 'B'); m.fill(28, 31, -4, -4, 'v')
m.fill(58, 65, -2, -2, '='); m.fill(66, 67, -10, -3, 'B'); m.fill(68, 73, -10, -10, 'B')
m.fill(13, 20, 15, 17, '#'); m.fill(32, 51, 15, 17, '#')
m.fill(36, 43, 11, 12, 'B'); m.fill(36, 43, 13, 13, 'v'); m.fill(36, 43, 10, 10, '^')
m.fill(49, 60, 10, 11, 'B'); m.fill(49, 60, 9, 9, '^'); m.fill(60, 73, 15, 17, '#')
m.fill(74, 89, 7, RBOT, '#').fill(74, 74, 7, 14, 'B'); m.fill(90, 95, G, RBOT, '#')
m.put(67, 14, 'E'); m.put(78, 6, 'K')
for c, r, k in ((15, -4, 'J'), (22, -6, 'J'), (35, -4, 'J'), (49, -6, 'J'), (62, -4, '2'), (72, -12, 'J'), (70, -12, 'X'),
                (17, 13, 'J'), (26, 11, 'J'), (33, 13, '3'), (39, 14, 'J'), (55, 13, 'J'), (82, 4, 'J'), (86, 4, 'J')):
    m.put(c, r, k)
for c, r, k in ((2, 18, 'i'), (14, 14, 's'), (71, 14, 'f'), (80, 6, 'p'), (88, 6, 'g'), (93, 18, 'r')):
    m.put(c, r, k)
m.label('Trampoline ^', 40, 220)
m.zone('route:canopy', 12, -13, 73, -1); m.zone('route:under', 13, 9, 73, 17); m.zone('trampoline', 6, 10, 10, 18)
m.zone('slide', 27, -4, 32, -3); m.zone('slide', 35, 13, 44, 14); m.zone('dash', 40, -10, 57, -3)
m.zone('dash', 47, 12, 61, 17); m.zone('double_jump', 21, 9, 31, 16); m.zone('wall_climb', 63, -10, 67, -3)
m.zone('wall_climb', 70, 6, 74, 14)
m.check(type='trampoline', start=[3, G], pad_c=8, target=[12, -2, 22, -2])
m.check(type='leap', start=[33, -2], edge_c=40, target=[58, -2, 65, -2], need='DJ+dash')
m.check(type='jd_gap', start=[14, 15], edge_c=21, target=[32, 15, 40, 15])
m.check(type='corridor', start=[48, 15], edge_c=52, target=[60, 15, 66, 15])
m.check(type='crawl', start=[33, 15], crouch_c=35, end_c=45)
m.check(type='climb', start=[71, 15], target=[75, 7, 84, 7])
m.check(type='climb', start=[64, -2], target=[66, -10, 70, -10])

# ============================================================ level 2 signature fork: GLACIER
m = Mod('fork_glacier', 68, ['fork', 'wall_climb', 'slide', 'dash', 'double_jump', 'trampoline'], tier=2,
        desc='Iceflow fork: high = tower climb, bead hops, slide, DJ+dash leap to the crown | low = doorway, pool hop, crawl, DJ over water, climb')
m.ground(0, 67)
m.fill(4, 9, 11, 16, '#').fill(4, 4, 11, 16, 'B')                    # tower with a doorway (rows 17-18)
m.fill(13, 17, 9, 9, '='); m.fill(19, 30, 7, 7, '=')
m.fill(20, 22, RTOP, 4, 'B'); m.fill(20, 22, 5, 5, 'v')               # hanging pillar over the beads
m.fill(11, 19, G, 20, '.'); m.fill(11, 19, 20, 20, '~'); m.fill(14, 16, 17, 17, '=')   # pool 1 + stepping stone
m.fill(22, 28, 13, 16, 'B'); m.fill(23, 27, 17, 17, 'v'); m.fill(22, 28, 12, 12, '^')  # ice shelf crawl
m.fill(36, 43, G, 20, '.'); m.fill(36, 43, 20, 20, '~')               # pool 2: 8 wide, then up 64 -> DJ
m.fill(44, 48, 15, 18, '#')
m.fill(49, 62, 7, 18, '#').fill(49, 49, 7, 14, 'B')                   # crown plateau
m.put(55, 7, 'T'); m.bounce = [-660.0]; m.fill(55, 67, -4, -4, '=')    # secret perch above the screen
m.put(53, 6, 'K'); m.put(16, 13, 'A')
for c, r, k in ((7, 9, '2'), (15, 7, 'J'), (21, 6, 'J'), (40, 3, 'J'), (8, 18, 'J'), (15, 15, 'J'), (10, 17, '3'),
                (25, 18, 'J'), (38, 16, 'J'), (46, 13, 'J'), (52, 4, 'J'), (56, 4, 'J'), (58, -6, 'X')):
    m.put(c, r, k)
for c, r, k in ((2, 18, 'i'), (5, 10, 's'), (30, 18, 'r'), (31, 18, 'b'), (51, 6, 'g'), (64, 18, 'f')):
    m.put(c, r, k)
m.label('Climb [W]', 8, 150); m.label('Slide [S]', 330, 70); m.label('Leap: Double Jump + Dash >>', 380, 40)
m.label('Double Jump', 600, 210)
m.zone('route:high', 4, -6, 48, 10); m.zone('route:low', 4, 17, 48, 18); m.zone('wall_climb', 1, 10, 4, 16)
m.zone('slide', 19, 5, 23, 6); m.zone('dash', 31, -2, 48, 6); m.zone('slide', 21, 17, 29, 18)
m.zone('double_jump', 31, 12, 48, 18); m.zone('wall_climb', 45, 6, 49, 14); m.zone('trampoline', 53, -6, 57, 6)
m.check(type='climb', start=[2, G], target=[5, 11, 9, 11])
m.check(type='leap', start=[24, 7], edge_c=31, target=[49, 7, 62, 7], need='DJ+dash')
m.check(type='crawl', start=[19, G], crouch_c=21, end_c=29)
m.check(type='jd_gap', start=[30, G], edge_c=36, target=[44, 15, 48, 15], need='DJ')
m.check(type='climb', start=[46, 15], target=[50, 7, 59, 7])
m.check(type='trampoline', start=[50, 7], pad_c=55, target=[55, -4, 67, -4])

# ============================================================ level 3 signature fork: FURNACE
m = Mod('fork_furnace', 75, ['fork', 'wall_climb', 'trampoline', 'slide', 'dash', 'double_jump'], tier=2,
        desc='Blazing fork: high = climb the stack, trampoline to a bead line above the screen, slide, DJ+dash leap | low = crawl, lava corridor, DJ over lava, climb')
m.ground(0, 74)
m.fill(6, 11, 9, 16, '#').fill(6, 6, 9, 16, 'B'); m.fill(7, 10, 17, 17, 'v')      # furnace stack + crawl under it
m.put(9, 9, 'T'); m.bounce = [-620.0]
m.fill(12, 19, -3, -3, '='); m.fill(25, 38, -3, -3, '='); m.fill(27, 29, RTOP, -6, 'B'); m.fill(27, 29, -5, -5, 'v')
m.fill(57, 64, -3, -3, '=')                                                         # leap target, off-screen
m.fill(14, 25, 13, 15, 'B'); m.fill(14, 25, 12, 12, '^'); m.fill(16, 23, G, 20, '.'); m.fill(16, 23, 20, 20, '~')
m.fill(36, 46, G, 20, '.'); m.fill(36, 46, 20, 20, '~')                             # 11-wide lava: DJ/dash
m.fill(52, 56, 14, 18, '#'); m.fill(57, 70, 6, 18, '#').fill(57, 57, 6, 13, 'B')
m.put(30, 18, 'R'); m.put(41, 13, 'A'); m.put(61, 5, 'K')
for c, r, k in ((7, 7, 'J'), (13, -5, '2'), (22, -7, 'J'), (33, -5, 'J'), (47, -8, 'J'), (63, -5, 'X'),
                (8, 18, 'J'), (13, 17, '3'), (20, 17, 'J'), (33, 16, 'J'), (41, 15, 'J'), (54, 12, 'J'), (64, 3, 'J'), (67, 3, 'J')):
    m.put(c, r, k)
for c, r, k in ((2, 18, 'i'), (4, 18, 'k'), (27, 18, 'r'), (50, 18, 'k'), (59, 5, 't'), (68, 5, 'b'), (72, 18, 'r')):
    m.put(c, r, k)
m.label('Climb [W]', 40, 120); m.label('Slide [S] >>', 30, 248); m.label('Jump + Dash [Shift]', 220, 232)
m.label('Trampoline ^', 150, 110); m.label('Leap: Double Jump + Dash >>', 420, -90)
m.zone('route:high', 6, -13, 64, 8); m.zone('route:low', 6, 17, 56, 18); m.zone('wall_climb', 3, 8, 6, 16)
m.zone('trampoline', 7, 4, 11, 8); m.zone('slide', 26, -5, 30, -4); m.zone('dash', 39, -10, 56, -4)
m.zone('slide', 6, 17, 11, 18); m.zone('dash', 14, 16, 25, 20); m.zone('double_jump', 34, 12, 51, 18)
m.zone('wall_climb', 53, 5, 57, 13)
m.check(type='climb', start=[4, G], target=[7, 9, 8, 9])
m.check(type='leap', start=[31, -3], edge_c=39, target=[57, -3, 64, -3], need='DJ+dash')
m.check(type='corridor', start=[12, G], edge_c=16, target=[24, G, 30, G])
m.check(type='crawl', start=[2, G], crouch_c=4, end_c=13)
m.check(type='jd_gap', start=[32, G], edge_c=36, target=[47, G, 51, G])
m.check(type='climb', start=[54, 14], target=[58, 6, 66, 6])

# ============================================================ fixed level sequences
LEVELS = {
    2: {'name': 'Iceflow Ridge', 'secret': ['fork_glacier', 'SEC-LVL-2', 'Klejnot Lodowej Korony'],
        'sequence': ['start', 'spike_bridges', 'climb_wall', 'chimney', 'hub', 'fork_glacier', 'trick_well', 'dj_ledges',
                     'enemy_run', 'climb_wall_high', 'hub', 'trampoline_tower', 'pool_bridges', 'finish']},
    3: {'name': 'Blazing Trench', 'secret': ['fork_furnace', 'SEC-LVL-3', 'Klejnot Paleniska'],
        'sequence': ['start', 'slide_crawl', 'dash_corridor', 'enemy_run', 'hub', 'fork_furnace', 'dash_leap', 'pool_bridges',
                     'slide_crawl', 'hub', 'dj_islands', 'dash_corridor', 'finish']},
}

# ============================================================ sanity: edges on the ground
for mid, m in MODULES.items():
    for c in (0, m.w - 1):
        assert m.g.get((c, G)) == '#', f'{mid}: column {c} must be ground at row {G}'

# ============================================================ GDScript export
def gd_str(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


lines = ['extends RefCounted', 'class_name LevelModules', '',
         '## GENERATED by module_lib.py - module library shared by levels 2, 3 and the AI level (4).',
         '## Every module is a vertical slice (rows %d..%d, ground top = row %d) that starts and ends on the ground.' % (RTOP, RBOT, G),
         '## Legend: # ground, B brick, = one-way bridge, T trampoline, ~ liquid, ^ floor spikes, v ceiling spikes,',
         '##         J jewel, 1 invincibility, 2 speed, 3 shield, X secret slot, K checkpoint, @ spawn, $ finish,',
         '##         E slime, A bat, R spider; decor letters t g p b s f i n r m k stand on the surface below.',
         '', f'const TOP_ROW: int = {RTOP}', f'const BOTTOM_ROW: int = {RBOT}', f'const GROUND_ROW: int = {G}', '',
         'const MODULES: Dictionary = {']
for mid, m in MODULES.items():
    lines.append(f'\t"{mid}": {{')
    lines.append(f'\t\t"w": {m.w}, "tier": {m.tier}, "tags": {json.dumps(m.tags)},')
    lines.append(f'\t\t"desc": {gd_str(m.desc)},')
    lines.append(f'\t\t"bounce": {json.dumps(m.bounce)},')
    lines.append(f'\t\t"labels": {json.dumps(m.labels)},')
    lines.append(f'\t\t"zones": {json.dumps(m.zones)},')
    lines.append(f'\t\t"checks": {json.dumps(m.checks)},')
    lines.append('\t\t"map": [')
    for row in m.rows():
        lines.append(f'\t\t\t"{row}",')
    lines.append('\t\t]')
    lines.append('\t},')
lines.append('}')
lines.append('')
lines.append('## Hand-made level layouts built from the library (levels 2 and 3).')
lines.append('const LEVELS: Dictionary = {')
for lid, L in LEVELS.items():
    lines.append(f'\t{lid}: {json.dumps(L)},')
lines.append('}')
gd = '\n'.join(lines) + '\n'
open(os.path.join(ROOT, 'scripts/core/level_modules.gd'), 'w', encoding='utf8', newline='\n').write(gd)

# ============================================================ previews
TS = Image.open(os.path.join(ROOT, 'assets/tilesett.png')).convert('RGBA')
SPK = Image.open(os.path.join(ROOT, 'assets/Kolce.png')).convert('RGBA')
JWI = {k: Image.open(os.path.join(ROOT, f'assets/{n}.png')).convert('RGBA') for k, n in (('J', 'Jewel'), ('1', 'JewJewel'), ('2', 'SpeedJewel'), ('3', 'ImmunityJewel'), ('X', 'Jewel'))}
tile = lambda ax, ay: TS.crop((ax * 16, ay * 16, ax * 16 + 16, ay * 16 + 16))
SOLID = set('#BT')


def render(rows, path, scale=1):
    w, h = len(rows[0]), len(rows)
    img = Image.new('RGBA', (w * 16, h * 16), (30, 34, 48, 255))
    d = ImageDraw.Draw(img)
    at = lambda c, r: rows[r][c] if 0 <= r < h and 0 <= c < w else '.'
    for r in range(h):
        for c in range(w):
            ch = at(c, r)
            x, y = c * 16, r * 16
            if ch == '#':
                img.alpha_composite(tile(0, 0) if at(c, r - 1) not in SOLID else tile(0, 1), (x, y))
            elif ch == 'B':
                img.alpha_composite(tile(1, 0) if at(c, r - 1) != 'B' else tile(1, 1), (x, y))
            elif ch == '=':
                img.alpha_composite(tile(6 + c % 3, 3), (x, y))
            elif ch == 'T':
                img.alpha_composite(tile(1, 2), (x, y))
            elif ch == '~':
                img.alpha_composite(tile(4, 11), (x, y))
            elif ch == '^':
                img.alpha_composite(SPK, (x, y))
            elif ch == 'v':
                img.alpha_composite(SPK.transpose(Image.FLIP_TOP_BOTTOM), (x, y))
            elif ch in JWI:
                im = JWI[ch]
                img.alpha_composite(im, (x + 8 - im.width // 2, y + 8 - im.height // 2))
                if ch == 'X':
                    d.ellipse([x - 6, y - 6, x + 22, y + 22], outline=(255, 215, 0, 255), width=2)
            elif ch in 'EAR':
                d.rectangle([x, y + 4, x + 15, y + 15], fill={'E': (90, 200, 90, 255), 'A': (150, 90, 200, 255), 'R': (220, 60, 90, 255)}[ch])
            elif ch == 'K':
                d.line([x + 8, y - 40, x + 8, y + 15], fill=(230, 230, 230, 255), width=2); d.polygon([(x + 9, y - 40), (x + 26, y - 33), (x + 9, y - 26)], fill=(212, 110, 179, 255))
            elif ch == '@':
                d.rectangle([x - 1, y - 14, x + 17, y + 15], outline=(120, 255, 140, 255), width=2)
            elif ch == '$':
                d.rectangle([x - 8, y - 40, x + 24, y + 15], outline=(255, 215, 0, 255), width=3)
            elif ch.islower():
                d.text((x + 3, y + 2), ch, fill=(160, 230, 160, 255))
    d.line([(0, (-8 - RTOP * 16)), (w * 16, (-8 - RTOP * 16))], fill=(255, 80, 80, 200))
    img.save(path)
    return img


os.makedirs(OUT, exist_ok=True)
for lid, L in LEVELS.items():
    rows = [''] * (RBOT - RTOP + 1)
    for mid in L['sequence']:
        for i, row in enumerate(MODULES[mid].rows()):
            rows[i] += row
    rows = ['BB' + r + 'BB' for r in rows]
    im = render(rows, os.path.join(OUT, f'level{lid}_modules.png'))
    print(f'level {lid}: {len(rows[0])} cols = {len(rows[0]) * 16}px, jewels {sum(r.count(k) for r in rows for k in "J123X")}, '
          f'checkpoints {sum(r.count("K") for r in rows)}, enemies {sum(r.count(k) for r in rows for k in "EAR")}, trampolines {sum(r.count("T") for r in rows)}')
lib = Image.new('RGBA', (1, 1))
print('modules:', len(MODULES), 'export:', len(gd.splitlines()), 'lines')
