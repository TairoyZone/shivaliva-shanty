## One-time opening welcome, shown the first time a fresh game lands the
## player in their shanty. Orients a brand-new player (who they are, what
## the island offers, what to aim for) WITHOUT gatekeeping, then flips
## [member PlayerState.has_seen_intro] so it never shows again.
##
## Self-contained + code-built (like the HiringBoard / results modals):
## just `add_child(IntroOverlay.new())`. Pauses the tree while open so the
## player can't wander off mid-welcome.
class_name IntroOverlay
extends CanvasLayer


const TITLE_TEXT : String = "WELCOME TO CRADLE ROCK"

const BODY_TEXT : String = (
	"This little shanty is yours now, newcomer.\n\n"
	+ "Move with WASD or the arrow keys, and press E to open doors, talk to folk, and work any station.\n\n"
	+ "Every job on Cradle Rock is a puzzle, and the folk pay good gold for a hand. Warm up wherever you "
	+ "fancy — lend a hand at Cogwise Godfrey's Workshop or Cinder Troy's Forge, or take a seat at the "
	+ "Inn's parlor tables.\n\n"
	+ "When you've found your feet, your road to the skies is the SKYDOCK: take the helm, sign onto a "
	+ "crew, and sail a jobbing voyage. No ship of your own needed yet — a few good voyages among the "
	+ "brigands will win you the gold for your very first one.\n\n"
	+ "Step outside when you're ready — and check your OBJECTIVES any time via the ! button up top "
	+ "(or press J) to see what to aim for next.")


var _panel : PanelContainer   # pop-in / dismiss target
var _dim : ColorRect


func _ready() -> void:

	layer = 50
	# Process while paused so the button still works after we freeze the world.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_tree().paused = true
	ModalFx.appear(_panel, _dim)   # fade + pop in (animate-everything)


func _build() -> void:

	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_dim = dim

	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330.0
	panel.offset_top = -230.0
	panel.offset_right = 330.0
	panel.offset_bottom = 230.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	_panel = panel

	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title : Label = Label.new()
	title.text = TITLE_TEXT
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var body : Label = Label.new()
	body.text = BODY_TEXT
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", Color(0.92, 0.84, 0.62, 1.0))
	body.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	body.add_theme_constant_override("outline_size", 2)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)

	var btn_row : HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)
	var begin : Button = _make_button("Let's get to it")
	begin.pressed.connect(_on_begin_pressed)
	btn_row.add_child(begin)


func _on_begin_pressed() -> void:

	ModalFx.dismiss(self, _panel, _dim, _do_begin)   # scale + fade out, THEN really close


func _do_begin() -> void:

	PlayerState.has_seen_intro = true
	if get_tree() != null:
		get_tree().paused = false
	queue_free()


func _panel_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.11, 0.06, 0.97)
	s.border_color = Color(0.78, 0.58, 0.24, 1.0)
	s.border_width_left = 3
	s.border_width_top = 3
	s.border_width_right = 3
	s.border_width_bottom = 3
	s.corner_radius_top_left = 14
	s.corner_radius_top_right = 14
	s.corner_radius_bottom_right = 14
	s.corner_radius_bottom_left = 14
	s.content_margin_left = 32
	s.content_margin_right = 32
	s.content_margin_top = 26
	s.content_margin_bottom = 26
	return s


func _make_button(text: String) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.78, 1.0, 0.62, 1.0))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	for state in ["normal", "hover", "pressed"]:
		var sb : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.22, 0.14, 0.08, 0.95)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		sb.bg_color = bg
		sb.border_color = Color(0.78, 0.58, 0.24, 1.0)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_right = 8
		sb.corner_radius_bottom_left = 8
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		btn.add_theme_stylebox_override(state, sb)
	return btn