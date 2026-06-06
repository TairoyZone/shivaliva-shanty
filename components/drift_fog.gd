## DriftFog — drifting wispy cloud mist behind the world, for depth (a thin moving layer between the
## SkyBackdrop and the scene). A full-viewport ColorRect running stardust_fog.gdshader on a low CanvasLayer
## (-5: above the SkyBackdrop at -10, below the world at 0). Drop on a sky scene:
##   add_child(DriftFog.make(Color(0.78, 0.82, 0.95, 0.9)))
## Resizes with the window. Placeholder-first; tune via the shader uniforms. See [[godot-borrow-todo]].
class_name DriftFog
extends CanvasLayer

const FOG_SHADER : Shader = preload("res://components/stardust_fog.gdshader")

var _color : Color = Color(0.78, 0.82, 0.95, 1.0)
var _rect : ColorRect


static func make(color: Color = Color(0.78, 0.82, 0.95, 1.0)) -> DriftFog:

	var f : DriftFog = DriftFog.new()
	f._color = color
	return f


func _ready() -> void:

	layer = -5   # above the SkyBackdrop (-10), below the world (0)
	_rect = ColorRect.new()
	var mat : ShaderMaterial = ShaderMaterial.new()
	mat.shader = FOG_SHADER
	mat.set_shader_parameter("fog_color", _color)
	_rect.material = mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:

	if is_instance_valid(_rect):
		_rect.size = get_viewport().get_visible_rect().size
		_rect.position = Vector2.ZERO
