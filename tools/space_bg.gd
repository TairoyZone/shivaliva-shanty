## DEV-ONLY itch.io BACKGROUND renderer (not shipped). The game's REAL stardust-sky shader
## (components/stardust_sky.gdshader — twilight + twinkling jewel-hued stars) full-bleed on a CanvasLayer
## behind, with a few drifting floating isles (the MenuBackdrop look) on top, edges/horizon so the page
## content sits in clear sky. Captures user://shots/space_bg.png. "Our space" for the itch page background.
extends Control

const SKY_SHADER : Shader = preload("res://components/stardust_sky.gdshader")
const ISLE : Color = Color(0.30, 0.42, 0.34, 1.0)
const ISLE_LIT : Color = Color(0.46, 0.60, 0.48, 1.0)
const ISLE_EDGE : Color = Color(0.10, 0.16, 0.14, 1.0)
const ISLE_UNDER : Color = Color(0.16, 0.22, 0.30, 0.5)
# [pos(0..1 of the frame), scale] — spread to the edges + lower horizon so a page's centre column stays clear.
const ISLES : Array = [
	[Vector2(0.11, 0.24), 2.2], [Vector2(0.89, 0.18), 1.5], [Vector2(0.23, 0.83), 2.8],
	[Vector2(0.81, 0.87), 2.2], [Vector2(0.55, 0.93), 1.6], [Vector2(0.94, 0.52), 1.2],
	[Vector2(0.06, 0.60), 1.4]]


func _ready() -> void:

	set_anchors_preset(Control.PRESET_FULL_RECT)
	DirAccess.make_dir_recursive_absolute("user://shots")
	_hide_overlays()
	# The stardust-sky shader, full-bleed, on a LOW CanvasLayer so the isles (this Control's _draw) sit in front.
	var cl : CanvasLayer = CanvasLayer.new()
	cl.layer = -1
	add_child(cl)
	var sky : ColorRect = ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat : ShaderMaterial = ShaderMaterial.new()
	mat.shader = SKY_SHADER
	mat.set_shader_parameter("density", 62.0)       # a richer starfield for a hero background
	mat.set_shader_parameter("brightness", 1.2)
	mat.set_shader_parameter("jewel_chance", 0.30)
	sky.material = mat
	cl.add_child(sky)
	# Let the shader's TIME advance so the starfield twinkles into a full frame before we grab it.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.8).timeout
	_hide_overlays()
	await get_tree().process_frame
	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("user://shots/space_bg.png")
	await get_tree().process_frame
	get_tree().quit()


func _process(_dt: float) -> void:
	_hide_overlays()


func _hide_overlays() -> void:
	for g in [HUD, UserPanel, Overlay]:
		if g != null and (g is CanvasLayer or g is CanvasItem):
			g.visible = false


func _draw() -> void:

	var vp : Vector2 = get_viewport_rect().size
	for it in ISLES:
		_draw_isle(Vector2((it[0] as Vector2).x * vp.x, (it[0] as Vector2).y * vp.y), float(it[1]))


# A little floating landmass — rounded top, a peak, a soft buoyant under-glow (cloned from MenuBackdrop).
func _draw_isle(c: Vector2, s: float) -> void:

	var rad : float = 18.0 * s
	draw_circle(c + Vector2(0.0, rad * 0.7), rad * 1.3, ISLE_UNDER)
	draw_circle(c + Vector2(0.0, rad * 0.25), rad, ISLE)
	draw_arc(c + Vector2(0.0, rad * 0.25), rad, 0.0, TAU, 28, ISLE_EDGE, 1.6)
	var peak : PackedVector2Array = PackedVector2Array([
		c + Vector2(-rad * 0.62, 0.0), c + Vector2(0.0, -rad * 1.1), c + Vector2(rad * 0.62, 0.0)])
	draw_colored_polygon(peak, ISLE_LIT)
	draw_polyline(peak, ISLE_EDGE, 1.4)
