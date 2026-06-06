## Glow — a soft additive radial GLOW (no art, no 2D-lighting system — just an additive GradientTexture2D
## sprite, so it's rock-solid on our GL Compatibility target). Drop one on a forge, a lantern, a station
## marker, a gem for warmth/mood:
##   add_child(Glow.make(Color(1.0, 0.55, 0.18, 0.85), 80.0))
## Sits just behind its parent (z -1) and gently pulses by default. Placeholder-first. See [[godot-borrow-todo]].
class_name Glow
extends Sprite2D

var _color : Color = Color(1, 1, 1, 0.8)
var _radius : float = 60.0
var _pulse : bool = true


static func make(color: Color, radius: float = 60.0, pulse: bool = true) -> Glow:

	var g : Glow = Glow.new()
	g._color = color
	g._radius = radius
	g._pulse = pulse
	return g


func _ready() -> void:

	# A radial white→transparent disc; `modulate` tints it, additive blend makes it glow.
	var grad : Gradient = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex : GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	texture = tex
	modulate = _color
	scale = Vector2.ONE * (_radius / 64.0)   # the texture's bright core is ~64px radius
	var mat : CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = -1                              # sit just behind the prop it lights
	if _pulse:
		var base_a : float = _color.a
		var tw : Tween = create_tween().set_loops()
		tw.tween_property(self, "modulate:a", base_a * 0.6, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(self, "modulate:a", base_a, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
