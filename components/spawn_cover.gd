## SpawnCover — a static opaque strip placed ABOVE a falling-piece board (Mining / Loft / Lumberjacking) that
## hides the pieces which spawn off-screen above the grid and slide in. It REPLACES
## `clip_children = CLIP_CHILDREN_AND_DRAW`, whose per-composite stencil mask over a board's many child tiles is a
## heavy GL-Compatibility / WebGL cost — it re-runs whenever ANY child moves (a held cursor, a cascade), which is
## what made Mining jerky on a phone (Troy 2026-06-13, the mobile perf pass). Paint it the colour of whatever
## shows BEHIND the board (the scene background / project clear colour) so it blends in. Only the TOP needs
## covering on these boards: pieces enter from above and nothing overflows the other edges (extraction pops UP +
## fades within the board). Static helper, no instances. See [[touch-input-foundation]].
class_name SpawnCover
extends Object


## Add a cover the size of the board, sitting just ABOVE it (local y -board_size.y .. 0), painted [param backdrop].
static func add_above(board: Node2D, board_size: Vector2, backdrop: Color) -> void:

	var cover : ColorRect = ColorRect.new()
	cover.color = backdrop
	cover.position = Vector2(0.0, -board_size.y)
	cover.size = board_size
	cover.z_index = 50   # above the tiles (z 0); a HUD CanvasLayer still draws on top of this world-space cover
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(cover)
