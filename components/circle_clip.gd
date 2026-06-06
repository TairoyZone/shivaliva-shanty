## CircleClip — a reusable CIRCULAR MASK via clip_children (borrow). Any Control content added as a child is
## clipped to a circle — round avatars/portraits/thumbnails with no per-asset masking, art-swap-friendly.
##   frame.add_child(CircleClip.wrap(ProfileAvatar.new(), 168.0))
## The parent's drawn circle is the mask (not rendered); the child fills the rect and shows through it.
## See [[godot-borrow-todo]] / [[scene-per-component-principle]].
class_name CircleClip
extends Control

var diameter : float = 96.0


## Wrap [param content] in a circle of [param d] px; the content is stretched to fill + clipped round.
static func wrap(content: Control, d: float = 96.0) -> CircleClip:

	var c : CircleClip = CircleClip.new()
	c.diameter = d
	c.custom_minimum_size = Vector2(d, d)
	c.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


func _ready() -> void:

	custom_minimum_size = Vector2(diameter, diameter)
	size = Vector2(diameter, diameter)
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY   # the circle masks children; the parent itself isn't drawn


func _draw() -> void:

	draw_circle(size * 0.5, diameter * 0.5, Color.WHITE)
