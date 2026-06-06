## MoodTint — a per-location colour WASH over the world for cheap mood (a cool dim mine, a warm tavern, a
## cold high deck). A semi-transparent ColorRect on CanvasLayer 2 — ABOVE the world (layer 0) but BELOW the
## HUD (layer 10) + toasts (60) — so it tints the world and NEVER the interface. add_child(MoodTint.make(c)).
## The colour's ALPHA is the strength. Resizes with the window. Placeholder-first. See [[godot-borrow-todo]].
class_name MoodTint
extends CanvasLayer

var _tint : Color = Color(0, 0, 0, 0)
var _rect : ColorRect


static func make(tint: Color) -> MoodTint:

	var m : MoodTint = MoodTint.new()
	m._tint = tint
	return m


func _ready() -> void:

	layer = 2   # above the world, below the HUD (10) + toasts (60)
	_rect = ColorRect.new()
	_rect.color = _tint
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:

	if is_instance_valid(_rect):
		_rect.size = get_viewport().get_visible_rect().size
		_rect.position = Vector2.ZERO
