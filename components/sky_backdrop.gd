## SkyBackdrop — a drop-in procedural twinkling-Stardust-sky behind a scene. `add_child(SkyBackdrop.new())`
## puts a full-viewport ColorRect running stardust_sky.gdshader on a LOW CanvasLayer (-10), so it sits
## behind everything and stays fixed in screen space (a distant sky, not parented to the camera). Resizes
## with the window. For the ship deck (afloat in the sky) + any scene that wants the night sky. The flat
## `fallback_color` shows if the shader is ever stripped/fails. Placeholder-first; tune via the shader
## uniforms. See [[godot-borrow-todo]] / [[sky-canon]].
class_name SkyBackdrop
extends CanvasLayer

const SKY_SHADER : Shader = preload("res://components/stardust_sky.gdshader")

## The flat sky shown beneath the stars if the shader is unavailable. Set before add_child to match a scene.
var fallback_color : Color = Color(0.10, 0.09, 0.22, 1.0)

var _rect : ColorRect


func _ready() -> void:

	layer = -10
	_rect = ColorRect.new()
	_rect.color = fallback_color
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat : ShaderMaterial = ShaderMaterial.new()
	mat.shader = SKY_SHADER
	_rect.material = mat
	add_child(_rect)
	_fit()
	get_viewport().size_changed.connect(_fit)


# Cover the whole viewport (a Control under a CanvasLayer has no anchor parent, so size it explicitly).
func _fit() -> void:

	if is_instance_valid(_rect):
		_rect.size = get_viewport().get_visible_rect().size
		_rect.position = Vector2.ZERO
