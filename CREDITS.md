# Credits

## Engine
- [Godot Engine](https://godotengine.org/) 4.6

## Original work
Game design, code, and most current in-game art (c) Troy Pepito.

Most visuals in this MVP are procedural placeholders (drawn at runtime
via GDScript `_draw()` overrides). They are intentionally simple so they
can be swapped out one-by-one as real pixel-art assets are created.

## Third-party assets

### GDQuest — Isometric character + tileset
Additional assets CC-By 4.0 [GDQuest](https://www.gdquest.com/).

The isometric character spritesheet (`assets/iso/isometric_character.png` — 8 directions × 11 frames each = idle + run animations) and the dungeon tileset (`assets/iso/isometric_tiles.png` + `isometric_tileset.tres` + `switch_tile.gdshader`) are from the *Godot Node Essentials* project, `screens/tile_map_layer/isometric_dungeon_2d`, licensed under [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/). The character drives the player in `player.tscn` + `player.gd`; the tileset is used in `shore.tscn`, `tavern.tscn`, and `player_shanty_interior.tscn`.

### GDQuest — Spinning gem spritesheet (`0000-0004.png`)
Additional assets CC-By 4.0 [GDQuest](https://www.gdquest.com/).

Specifically: the 5-frame pixel-art spinning gem used in the Gem Drop
puzzle (`puzzles/gem_drop/assets/0000.png` through `0004.png`) is from
the *Learn 2D Gamedev with Godot 4* course, Module 14
("side_scroller_levels_solutions", at `assets/gem/`), licensed under
[CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/). Played at
10 fps with nearest-neighbor filtering. AI gems use the same sprite
with a ruby `modulate` tint.

## Acknowledgments
Gem Drop's rules are a from-scratch reimplementation inspired by the
genre of peg-and-paddle gambling games (Plinko, *Treasure Drop* from
Three Rings' *Puzzle Pirates*, etc.). No assets or code from those
games are used.
