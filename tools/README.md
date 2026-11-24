# Level authoring tools (Python 3 + Pillow)

- `module_lib.py` – the module library for levels 2, 3 and the AI level (4). Edit modules / level
  sequences here, then regenerate `scripts/core/level_modules.gd`:
  `py -3 tools/module_lib.py . tools/preview` (also writes preview PNGs of levels 2 and 3).
- `level1_gen.py` – the hand-made level 1 (Mossy Circuit). Regenerates the level part of
  `scenes/test_arena.tscn` (geometry, tiles, hazards, checkpoints, jewels, zones...):
  `py -3 tools/level1_gen.py . tools/preview --write`

- `hud_assets.py` – pixel HUD assets (font, panels, icons) in `assets/ui/hud/`:
  `py -3 tools/hud_assets.py .`

Design rules the level tools follow (measured with the current player controller):
plain gap <= 6 tiles, double-jump-or-dash gap 11, double jump + dash leap 18 (same height),
double-jump ledge 5 high, climb wall >= 8 high, ceiling-dash pit 8 wide under a 3-high corridor,
crawl tunnels 2 tiles high.
