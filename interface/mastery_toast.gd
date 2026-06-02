## A brief "NEW RANK" flourish shown when a puzzle's mastery tier goes up.
## Self-contained + self-freeing: any puzzle result screen does
##   add_child(MasteryToast.create("Adept"))
## on a tier-up. Sits on a high layer + process-always so it plays over a
## paused/ended puzzle scene. See [[roadmap]] Phase 1.
class_name MasteryToast
extends CanvasLayer


var _tier_name : String = ""


static func create(tier_name: String) -> MasteryToast:

	var toast : MasteryToast = MasteryToast.new()
	toast._tier_name = tier_name
	return toast


func _ready() -> void:

	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var label : Label = Label.new()
	label.text = "NEW RANK\n%s" % _tier_name.to_upper()
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.3, 0.16, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(560.0, 140.0)
	var vp : Vector2 = get_viewport().get_visible_rect().size
	label.position = Vector2(vp.x * 0.5 - 280.0, vp.y * 0.20 - 70.0)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.4, 0.4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var tw : Tween = create_tween()
	tw.tween_property(label, "scale", Vector2(1.15, 1.15), 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "scale", Vector2(1.0, 1.0), 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(1.1)
	tw.tween_property(label, "modulate:a", 0.0, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)