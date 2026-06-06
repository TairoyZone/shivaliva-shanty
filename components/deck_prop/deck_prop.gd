@tool
## A PLACEABLE ship-deck prop (scene-per-component, see [[scene-per-component-principle]]). Drop instances
## into ship_deck.tscn, pick a [member kind] in the inspector, and DRAG it where you want — it paints
## itself in the editor (@tool). The interactable stations set a [member station_id]
## ("loft"/"patchworks"/"helm"/"plank") so the deck wires their interaction to THIS node's position; pure
## decoration leaves it "". ART-SWAP: drop a Sprite2D/AnimatedSprite2D child and the procedural glyph
## steps aside — no gameplay code to touch. Glyphs are the deck's old procedural props, moved here.
class_name DeckProp
extends Node2D

# Deck palette (mirrored here so the prop is self-contained).
const DECK : Color = Color(0.64, 0.47, 0.27, 1.0)
const DECK_DARK : Color = Color(0.46, 0.31, 0.16, 1.0)
const DECK_INSET : Color = Color(0.57, 0.41, 0.23, 1.0)
const STATION_LIVE : Color = Color(0.66, 0.90, 1.0, 1.0)
const STATION_IDLE : Color = Color(0.60, 0.64, 0.76, 1.0)
const SHADOW : Color = Color(0.0, 0.0, 0.0, 0.18)
const SAIL : Color = Color(0.88, 0.85, 0.76, 0.94)
const SAIL_SHADE : Color = Color(0.73, 0.69, 0.59, 0.94)
const RIGGING : Color = Color(0.20, 0.14, 0.08, 0.7)

@export_enum("loft", "patchworks", "navigation", "sailing", "gunnery", "mast", "cannon", "chest", "plank")
var kind : String = "mast":
	set(value):
		kind = value
		queue_redraw()
## The deck's interaction id ("loft" / "patchworks" / "helm" / "plank"); "" = pure decoration.
@export var station_id : String = ""
@export var marker_label : String = ""


func _draw() -> void:

	# ART-SWAP: a Sprite child supersedes the procedural glyph (no code change to replace the look).
	for c in get_children():
		if c is Sprite2D or c is AnimatedSprite2D:
			return
	if kind != "gunnery" and kind != "cannon":
		_draw_pedestal()   # bench/console props sit on a base; the cannon has its own footing
	match kind:
		"loft":
			_draw_loft()
		"patchworks":
			_draw_patchworks()
		"navigation":
			_draw_navigation()
		"sailing":
			_draw_sailing()
		"gunnery", "cannon":
			_draw_cannon()
		"mast":
			_draw_mast()
		"chest":
			_draw_chest()
		"plank":
			_draw_plank()


func _draw_pedestal() -> void:

	draw_circle(Vector2(0.0, 9.0), 20.0, SHADOW)
	draw_circle(Vector2(0.0, 5.0), 16.0, DECK_DARK)
	draw_arc(Vector2(0.0, 5.0), 16.0, 0.0, TAU, 20, DECK_INSET, 1.5)


func _draw_loft() -> void:

	draw_rect(Rect2(-12.0, -4.0, 24.0, 12.0), DECK_DARK)
	draw_rect(Rect2(-12.0, -4.0, 24.0, 12.0), STATION_LIVE, false, 2.0)
	var stone : PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -30.0), Vector2(10.0, -17.0), Vector2(0.0, -4.0), Vector2(-10.0, -17.0)])
	draw_colored_polygon(stone, Color(STATION_LIVE.r, STATION_LIVE.g, STATION_LIVE.b, 0.45))
	draw_polyline(PackedVector2Array([stone[0], stone[1], stone[2], stone[3], stone[0]]), STATION_LIVE, 2.0)


func _draw_navigation() -> void:

	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, Color(0.30, 0.19, 0.09, 1.0), 4.0)
	draw_circle(Vector2.ZERO, 5.0, Color(0.82, 0.66, 0.30, 1.0))
	for i in 6:
		var a : float = TAU * i / 6.0
		var d : Vector2 = Vector2(cos(a), sin(a))
		draw_line(d * 12.0, d * 20.0, DECK_DARK, 2.5)


func _draw_sailing() -> void:

	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 24, Color(0.78, 0.68, 0.44, 1.0), 4.0)
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 20, Color(0.70, 0.60, 0.38, 1.0), 4.0)


func _draw_patchworks() -> void:

	draw_rect(Rect2(-18.0, -6.0, 36.0, 7.0), Color(0.50, 0.34, 0.18, 1.0))
	draw_line(Vector2(-13.0, -2.0), Vector2(-6.0, 14.0), DECK_DARK, 3.0)
	draw_line(Vector2(13.0, -2.0), Vector2(6.0, 14.0), DECK_DARK, 3.0)
	var ppr : Rect2 = Rect2(-13.0, -24.0, 26.0, 16.0)
	draw_rect(ppr, Color(0.10, 0.09, 0.18, 1.0))
	draw_rect(Rect2(ppr.position.x, ppr.position.y, 26.0, 5.0), Color(0.62, 0.46, 0.27, 1.0))
	draw_rect(Rect2(ppr.position.x, ppr.position.y + 10.0, 26.0, 5.0), Color(0.62, 0.46, 0.27, 1.0))
	draw_rect(ppr, STATION_IDLE, false, 1.5)


func _draw_cannon() -> void:

	draw_circle(Vector2(0.0, 7.0), 10.0, SHADOW)
	draw_rect(Rect2(-9.0, -6.0, 22.0, 11.0), Color(0.20, 0.21, 0.24, 1.0))   # barrel
	draw_rect(Rect2(9.0, -4.0, 6.0, 7.0), Color(0.10, 0.11, 0.13, 1.0))      # muzzle
	draw_circle(Vector2(-5.0, 6.0), 4.0, Color(0.30, 0.20, 0.10, 1.0))       # carriage wheels
	draw_circle(Vector2(7.0, 6.0), 4.0, Color(0.30, 0.20, 0.10, 1.0))


func _draw_mast() -> void:

	draw_circle(Vector2(0.0, 6.0), 14.0, SHADOW)
	draw_circle(Vector2.ZERO, 8.0, DECK_DARK)
	var top : Vector2 = Vector2(0.0, -86.0)
	draw_line(Vector2.ZERO, top, DECK_DARK, 6.0)
	draw_line(Vector2.ZERO, top, Color(0.42, 0.28, 0.14, 1.0), 3.0)
	var yard_y : float = top.y + 16.0
	var yl : Vector2 = Vector2(-32.0, yard_y)
	var yr : Vector2 = Vector2(32.0, yard_y)
	draw_line(yl, yr, DECK_DARK, 4.0)
	var bl : Vector2 = Vector2(-27.0, -30.0)
	var br : Vector2 = Vector2(27.0, -30.0)
	var belly : Vector2 = Vector2(0.0, -20.0)
	draw_colored_polygon(PackedVector2Array([yl, yr, br, belly, bl]), SAIL)
	draw_colored_polygon(PackedVector2Array([yr, br, belly]), SAIL_SHADE)
	draw_line(yl, Vector2(-16.0, 2.0), RIGGING, 1.0)
	draw_line(yr, Vector2(16.0, 2.0), RIGGING, 1.0)


func _draw_chest() -> void:

	draw_circle(Vector2(0.0, 12.0), 18.0, SHADOW)
	draw_rect(Rect2(-16.0, -4.0, 32.0, 15.0), Color(0.46, 0.30, 0.14, 1.0))   # box
	draw_rect(Rect2(-16.0, -11.0, 32.0, 8.0), Color(0.55, 0.37, 0.18, 1.0))   # lid
	draw_rect(Rect2(-16.0, -11.0, 32.0, 22.0), Color(0.90, 0.74, 0.34, 1.0), false, 2.0)
	draw_rect(Rect2(-3.0, -6.0, 6.0, 7.0), Color(0.93, 0.79, 0.40, 1.0))      # clasp


func _draw_plank() -> void:

	var quad : PackedVector2Array = PackedVector2Array([
		Vector2(-20.0, -8.0), Vector2(20.0, 0.0), Vector2(34.0, 46.0), Vector2(-10.0, 40.0)])
	draw_colored_polygon(quad, Color(0.48, 0.32, 0.16, 1.0))
	draw_polyline(quad + PackedVector2Array([quad[0]]), Color(0.30, 0.19, 0.09, 1.0), 2.0)
