## A sparring post in the Inn that launches a SKIRMISH DUEL. Extends [Puzzle]
## for the proximity / scene-launch wiring, but OVERRIDES [method interact] to
## first open the [SkirmishChallengeModal] — you pick a Cradle Rock islander to
## spar, then the duel loads against them. (Skirmish is versus-only; there is no
## solo play.) See [[combat-puzzle-direction]].
@tool
class_name SkirmishSign
extends Puzzle


# Open the "who do you want to spar?" picker instead of launching straight in.
func interact() -> void:

	if Engine.is_editor_hint():
		return
	var modal : SkirmishChallengeModal = SkirmishChallengeModal.new()
	modal.challenged.connect(_on_challenged)
	add_child(modal)


# Picker chose a foe — seat them (consumed by SkirmishDuel) + launch the duel
# down the normal Puzzle return-anchor + scene-change path.
func _on_challenged(profile: NpcPersonality) -> void:

	if profile != null:
		PlayerState.skirmish_opponent = profile.resource_path
	_launch_puzzle(true)


const POST_WIDTH : float = 9.0
const POST_HEIGHT : float = 100.0
const BOARD_W : float = 86.0
const BOARD_H : float = 70.0
const BASE_PEG_W : float = 26.0
const BASE_PEG_H : float = 4.0

const COLOR_POST_FILL : Color = Color(0.42, 0.26, 0.10, 1.0)
const COLOR_POST_FRAME : Color = Color(0.18, 0.10, 0.04, 1.0)
const COLOR_BOARD_FILL : Color = Color(0.22, 0.18, 0.28, 1.0)
const COLOR_BOARD_FRAME : Color = Color(0.52, 0.55, 0.78, 1.0)
const COLOR_BLADE : Color = Color(0.82, 0.86, 0.95, 1.0)
const COLOR_HILT : Color = Color(0.80, 0.62, 0.26, 1.0)


func _draw() -> void:

	# Base peg.
	var peg : Rect2 = Rect2(-BASE_PEG_W * 0.5, -BASE_PEG_H, BASE_PEG_W, BASE_PEG_H)
	draw_rect(peg, COLOR_POST_FILL)
	draw_rect(peg, COLOR_POST_FRAME, false, 1.0)
	# Post.
	var post : Rect2 = Rect2(-POST_WIDTH * 0.5, -POST_HEIGHT, POST_WIDTH, POST_HEIGHT)
	draw_rect(post, COLOR_POST_FILL)
	draw_rect(post, COLOR_POST_FRAME, false, 1.2)
	# Board.
	var by : float = -POST_HEIGHT
	var board : Rect2 = Rect2(-BOARD_W * 0.5, by, BOARD_W, BOARD_H)
	draw_rect(board, COLOR_BOARD_FILL)
	draw_rect(board, COLOR_BOARD_FRAME, false, 2.4)
	# Crossed cutlasses (two blades forming an X).
	var cx : float = 0.0
	var cy : float = by + BOARD_H * 0.5
	var r : float = BOARD_W * 0.32
	_draw_blade(Vector2(cx - r, cy + r), Vector2(cx + r, cy - r))
	_draw_blade(Vector2(cx + r, cy + r), Vector2(cx - r, cy - r))


func _draw_blade(from_pos: Vector2, to_pos: Vector2) -> void:

	# Blade.
	draw_line(from_pos, to_pos, COLOR_BLADE, 3.0)
	# Hilt guard at the start (bottom) end.
	var dir : Vector2 = (to_pos - from_pos).normalized()
	var perp : Vector2 = Vector2(-dir.y, dir.x)
	var guard : Vector2 = from_pos + dir * 12.0
	draw_line(guard - perp * 6.0, guard + perp * 6.0, COLOR_HILT, 3.0)
	# Pommel.
	draw_circle(from_pos, 3.0, COLOR_HILT)