## Procedural weapon glyph for the inventory equip slots — a fist / sword / arrow drawn
## to fill its rect (placeholder art, same approach as [WoodIcon] / [OreIcon]: no lifted
## assets, just _draw shapes). Set [member weapon_id] to pick the glyph.
class_name WeaponIcon
extends Control


const STEEL : Color = Color(0.80, 0.82, 0.88, 1.0)
const STEEL_DK : Color = Color(0.55, 0.58, 0.66, 1.0)
const GOLD : Color = Color(0.86, 0.68, 0.30, 1.0)
const WOOD : Color = Color(0.48, 0.32, 0.17, 1.0)
const SKIN : Color = Color(0.86, 0.70, 0.52, 1.0)
const SKIN_DK : Color = Color(0.66, 0.50, 0.34, 1.0)
const FLETCH : Color = Color(0.50, 0.70, 0.95, 1.0)


var weapon_id : String = "brawl" :
	set(value):
		weapon_id = value
		queue_redraw()


func _draw() -> void:

	var c : Vector2 = size * 0.5
	var u : float = minf(size.x, size.y)
	match weapon_id:
		"sword":
			_draw_sword(c, u)
		"long_range":
			_draw_arrow(c, u)
		_:
			_draw_fist(c, u)


# An upright blade: steel point + blade, gold crossguard, wooden grip + pommel.
func _draw_sword(c: Vector2, u: float) -> void:

	var bw : float = u * 0.12
	# Blade.
	draw_rect(Rect2(c.x - bw * 0.5, c.y - u * 0.40, bw, u * 0.46), STEEL)
	# Point (triangle tip).
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - bw * 0.5, c.y - u * 0.40), Vector2(c.x + bw * 0.5, c.y - u * 0.40),
		Vector2(c.x, c.y - u * 0.50)]), STEEL)
	draw_rect(Rect2(c.x - bw * 0.5, c.y - u * 0.40, bw * 0.4, u * 0.46), STEEL_DK)  # edge shade
	# Crossguard.
	draw_rect(Rect2(c.x - u * 0.20, c.y + u * 0.05, u * 0.40, u * 0.07), GOLD)
	# Grip + pommel.
	draw_rect(Rect2(c.x - bw * 0.55, c.y + u * 0.12, bw * 1.1, u * 0.22), WOOD)
	draw_circle(Vector2(c.x, c.y + u * 0.36), u * 0.06, GOLD)


# A fist (brawl): a skin-tone block with four knuckles + a thumb.
func _draw_fist(c: Vector2, u: float) -> void:

	var w : float = u * 0.46
	var h : float = u * 0.40
	var top : float = c.y - h * 0.3
	draw_rect(Rect2(c.x - w * 0.5, top, w, h), SKIN)
	# Knuckles.
	for i in 4:
		var kx : float = c.x - w * 0.5 + w * (0.18 + 0.21 * float(i))
		draw_circle(Vector2(kx, top), u * 0.07, SKIN)
		draw_arc(Vector2(kx, top), u * 0.07, PI, TAU, 10, SKIN_DK, 1.5)
	# Finger creases + thumb.
	for i in 3:
		var lx : float = c.x - w * 0.5 + w * (0.30 + 0.21 * float(i))
		draw_line(Vector2(lx, top + u * 0.04), Vector2(lx, top + h * 0.7), SKIN_DK, 1.5)
	draw_circle(Vector2(c.x - w * 0.5 - u * 0.02, top + h * 0.55), u * 0.08, SKIN)


# A long-range arrow pointing up: steel head, wooden shaft, blue fletching.
func _draw_arrow(c: Vector2, u: float) -> void:

	# Shaft.
	draw_rect(Rect2(c.x - u * 0.03, c.y - u * 0.34, u * 0.06, u * 0.66), WOOD)
	# Head.
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - u * 0.12, c.y - u * 0.30), Vector2(c.x + u * 0.12, c.y - u * 0.30),
		Vector2(c.x, c.y - u * 0.48)]), STEEL)
	# Fletching (two angled fins at the tail).
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(c.x, c.y + u * 0.18), Vector2(c.x, c.y + u * 0.32),
			Vector2(c.x + s * u * 0.14, c.y + u * 0.32)]), FLETCH)