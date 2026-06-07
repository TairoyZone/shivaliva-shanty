@tool
## MenuGlyph — a tiny procedural icon for the HUD's quick-access buttons (Backpack / Hearts / Profile /
## Jobs), so the menu can be slim ICON-first instead of chunky text buttons. Placeholder-first _draw shapes
## in brass (a Sprite child could supersede later — art-swap). Centred on its rect; set [member kind].
class_name MenuGlyph
extends Control

const GOLD : Color = Color(0.96, 0.86, 0.50, 1.0)
const DARK : Color = Color(0.0, 0.0, 0.0, 0.55)
const HANDLE : Color = Color(0.55, 0.38, 0.18, 1.0)

@export_enum("bag", "heart", "star", "jobs", "book") var kind : String = "bag":
	set(value):
		kind = value
		queue_redraw()


func _draw() -> void:

	var c : Vector2 = size * 0.5
	match kind:
		"bag":
			_bag(c)
		"heart":
			_heart(c)
		"star":
			_star(c)
		"jobs":
			_jobs(c)
		"book":
			_book(c)


func _bag(c: Vector2) -> void:

	var body : Rect2 = Rect2(c.x - 9.0, c.y - 5.0, 18.0, 15.0)
	draw_rect(body, GOLD)
	draw_rect(body, DARK, false, 1.5)
	draw_rect(Rect2(c.x - 9.0, c.y - 8.0, 18.0, 5.0), GOLD)   # lid flap
	draw_line(Vector2(c.x - 9.0, c.y - 3.0), Vector2(c.x + 9.0, c.y - 3.0), DARK, 1.2)
	draw_arc(Vector2(c.x, c.y - 8.0), 4.0, PI, TAU, 10, GOLD, 2.0)   # top strap loop
	draw_rect(Rect2(c.x - 2.0, c.y - 1.0, 4.0, 4.0), DARK)   # buckle


func _heart(c: Vector2) -> void:

	draw_circle(c + Vector2(-4.0, -3.0), 4.6, GOLD)
	draw_circle(c + Vector2(4.0, -3.0), 4.6, GOLD)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-8.2, -1.0), c + Vector2(8.2, -1.0), c + Vector2(0.0, 9.0)]), GOLD)


func _star(c: Vector2) -> void:

	var pts : PackedVector2Array = PackedVector2Array()
	for i in 10:
		var ang : float = -PI * 0.5 + PI * float(i) / 5.0
		var r : float = 9.0 if i % 2 == 0 else 3.8
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(pts, GOLD)


func _jobs(c: Vector2) -> void:

	# A pickaxe: a wooden handle with a curved steel head (the Shoppe-Jobs = Mining/Woodcutting).
	draw_line(c + Vector2(-6.0, 8.0), c + Vector2(4.0, -8.0), HANDLE, 2.6)   # handle
	draw_arc(c + Vector2(4.0, -8.0), 7.5, PI * 0.05, PI * 0.95, 12, GOLD, 2.4)   # head
	draw_circle(c + Vector2(4.0, -8.0), 1.6, GOLD)   # collar


func _book(c: Vector2) -> void:

	# An open book (the Tutorials tab): two pages meeting at a central spine.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-1.0, -7.0), c + Vector2(-1.0, 7.0), c + Vector2(-9.0, 5.0), c + Vector2(-9.0, -5.0)]), GOLD)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(1.0, -7.0), c + Vector2(1.0, 7.0), c + Vector2(9.0, 5.0), c + Vector2(9.0, -5.0)]), GOLD)
	draw_line(c + Vector2(0.0, -7.0), c + Vector2(0.0, 7.0), DARK, 1.4)   # spine
	draw_line(c + Vector2(-7.0, -2.0), c + Vector2(-2.5, -1.2), DARK, 1.0)
	draw_line(c + Vector2(2.5, -1.2), c + Vector2(7.0, -2.0), DARK, 1.0)
