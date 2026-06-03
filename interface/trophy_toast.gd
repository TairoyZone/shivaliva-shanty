## A "TROPHY EARNED!" notification — pops when the player first earns a trophy (the YPP
## "Ye Received a Trophy!" beat). Self-contained + self-freeing, on a high layer + process-
## always, so it plays over ANY scene (overworld or mid-puzzle). Add it to the tree ROOT
## (not the hideable HUD) so it shows even while the HUD is hidden:
##   get_tree().root.add_child(TrophyToast.create("Skirmisher"))
## Placeholder-first procedural art (gold medallion + star). See [Trophies] / [[profile-standings-tab]].
class_name TrophyToast
extends CanvasLayer


const REST_Y : float = 64.0      # the panel's settled top offset
const GOLD : Color = Color(0.96, 0.78, 0.32, 1.0)

var _trophy_name : String = ""


static func create(trophy_name: String) -> TrophyToast:

	var t : TrophyToast = TrophyToast.new()
	t._trophy_name = trophy_name
	return t


func _ready() -> void:

	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS

	var panel : PanelContainer = PanelContainer.new()
	var sb : StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.11, 0.04, 0.97)
	sb.border_color = GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 24
	sb.content_margin_right = 28
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = REST_Y - 28.0   # starts a touch high, slides down
	panel.modulate.a = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	# Gold medallion + star (the trophy).
	var disc : PanelContainer = PanelContainer.new()
	var ds : StyleBoxFlat = StyleBoxFlat.new()
	ds.bg_color = GOLD
	ds.border_color = Color(1.0, 0.94, 0.66, 1.0)
	ds.set_border_width_all(2)
	ds.set_corner_radius_all(28)
	disc.add_theme_stylebox_override("panel", ds)
	disc.custom_minimum_size = Vector2(52, 52)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var star : Label = Label.new()
	star.text = "★"
	star.add_theme_font_size_override("font_size", 30)
	star.add_theme_color_override("font_color", Color(0.32, 0.20, 0.05, 1.0))
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disc.add_child(star)
	row.add_child(disc)

	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	var head : Label = Label.new()
	head.text = "TROPHY EARNED!"
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Color(0.98, 0.84, 0.40, 1.0))
	head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	head.add_theme_constant_override("outline_size", 2)
	col.add_child(head)
	var name_l : Label = Label.new()
	name_l.text = _trophy_name
	name_l.add_theme_font_size_override("font_size", 23)
	name_l.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82, 1.0))
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_l.add_theme_constant_override("outline_size", 3)
	col.add_child(name_l)

	# Slide down + fade in, hold, fade out, free.
	var tw : Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "offset_top", REST_Y, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.26)
	tw.chain().tween_interval(2.2)
	tw.chain().tween_property(panel, "modulate:a", 0.0, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)
