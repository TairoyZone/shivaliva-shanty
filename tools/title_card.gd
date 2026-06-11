## DEV-ONLY title-card renderer (not shipped). Draws a procedural sky-island key frame + the title and captures
## it to user://shots/title_card.png at 1280x720. Placeholder-first: every pixel is drawn in-engine (_draw),
## on-brand with the game's own art. Save-safe (no writes). Hides the gameplay HUD/rail for a clean card.
extends Control

const SKY_TOP : Color = Color(0.97, 0.76, 0.55)
const SKY_MID : Color = Color(0.47, 0.36, 0.56)
const STARDUST : Color = Color(0.07, 0.05, 0.17)
const W : float = 1280.0
const H : float = 720.0


func _ready() -> void:

	set_anchors_preset(Control.PRESET_FULL_RECT)
	DirAccess.make_dir_recursive_absolute("user://shots")
	_hide_overlays()
	# Stacked title so it stays whole in BOTH the wide banner and the square (centre-cropped) cover.
	_make_centered("SHIVALIVA", 92, Color(0.99, 0.93, 0.68), 13, 96.0)
	_make_centered("SHANTY", 92, Color(0.99, 0.93, 0.68), 13, 192.0)
	_make_centered("A sky-pirate puzzle adventure", 32, Color(0.92, 0.87, 0.76), 6, 300.0)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	_hide_overlays()
	await get_tree().process_frame
	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("user://shots/title_card.png")
	await get_tree().process_frame
	get_tree().quit()


# Force the always-on overlays hidden (autoloads re-show themselves in their own _process, which runs BEFORE
# ours in tree order, so re-hiding every frame wins by capture time).
func _process(_dt: float) -> void:
	_hide_overlays()


func _hide_overlays() -> void:
	for g in [HUD, UserPanel, Overlay]:
		if g != null and (g is CanvasLayer or g is CanvasItem):
			g.visible = false


# A content-sized label positioned by measuring the text against its OWN font (no reliance on Control layout,
# which silently produced a zero-width box before).
func _make_centered(text: String, fsize: int, col: Color, outline: int, y: float) -> void:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.11, 0.05, 0.15))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var f : Font = l.get_theme_font("font")
	var tw : float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fsize).x
	l.position = Vector2((W - tw) * 0.5, y)


func _draw() -> void:

	var strips : int = 160
	for i in strips:
		var t : float = float(i) / float(strips - 1)
		var c : Color = SKY_TOP.lerp(SKY_MID, t / 0.55) if t < 0.55 else SKY_MID.lerp(STARDUST, (t - 0.55) / 0.45)
		draw_rect(Rect2(0.0, t * H, W, H / float(strips) + 1.2), c)
	for r in [320.0, 230.0, 150.0]:
		draw_circle(Vector2(W * 0.5, H * 0.46), r, Color(1.0, 0.86, 0.62, 0.07))
	for cl in [[230.0, 150.0, 130.0], [1000.0, 120.0, 100.0], [660.0, 80.0, 70.0], [430.0, 250.0, 90.0]]:
		_blob(Vector2(cl[0], cl[1]), cl[2], Color(1.0, 0.96, 0.88, 0.16))
	for i in 80:
		var gy : float = H * (0.60 + randf() * 0.40)
		draw_circle(Vector2(randf() * W, gy), randf_range(0.8, 2.6), Color(0.82, 0.80, 1.0, randf_range(0.15, 0.65)))
	_island(Vector2(W * 0.5, H * 0.70), 270.0)
	_ship(Vector2(W * 0.5 + 250.0, H * 0.52), 64.0)


func _blob(c: Vector2, r: float, col: Color) -> void:

	var pts : PackedVector2Array = PackedVector2Array()
	for i in 26:
		var a : float = float(i) / 26.0 * TAU
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_colored_polygon(pts, col)


func _island(c: Vector2, r: float) -> void:

	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.82, 0.0), c + Vector2(r * 0.82, 0.0), c + Vector2(r * 0.18, r * 1.15),
		c + Vector2(-r * 0.2, r * 1.15)]), Color(0.20, 0.13, 0.12))
	var top : PackedVector2Array = PackedVector2Array()
	for i in 30:
		var a : float = float(i) / 29.0 * PI
		top.append(c + Vector2(-cos(a) * r, -sin(a) * r * 0.32))
	top.append(c + Vector2(r, 6.0))
	top.append(c + Vector2(-r, 6.0))
	draw_colored_polygon(top, Color(0.24, 0.42, 0.27))
	var houses : Array = [[-86.0, 44.0, 40.0], [-30.0, 56.0, 48.0], [40.0, 40.0, 36.0], [96.0, 50.0, 34.0]]
	for hh in houses:
		var x : float = c.x + float(hh[0])
		var w : float = float(hh[2])
		var ht : float = float(hh[1])
		draw_rect(Rect2(x - w * 0.5, c.y - ht, w, ht), Color(0.16, 0.11, 0.16))
		draw_rect(Rect2(x - w * 0.5 - 4.0, c.y - ht - 12.0, w + 8.0, 14.0), Color(0.10, 0.07, 0.12))
		draw_rect(Rect2(x - 5.0, c.y - ht * 0.62, 10.0, 12.0), Color(1.0, 0.82, 0.45))
	draw_circle(Vector2(c.x - 150.0, c.y - 30.0), 26.0, Color(0.18, 0.36, 0.22))
	draw_rect(Rect2(c.x - 154.0, c.y - 14.0, 8.0, 22.0), Color(0.14, 0.09, 0.08))


func _ship(c: Vector2, s: float) -> void:

	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s, 0.0), c + Vector2(s, 0.0), c + Vector2(s * 0.66, s * 0.5),
		c + Vector2(-s * 0.66, s * 0.5)]), Color(0.34, 0.22, 0.16))
	draw_line(c, c + Vector2(0.0, -s * 1.35), Color(0.22, 0.15, 0.11), 4.0)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(3.0, -s * 1.28), c + Vector2(s * 0.85, -s * 0.5), c + Vector2(3.0, -s * 0.38)]),
		Color(0.96, 0.90, 0.78))
