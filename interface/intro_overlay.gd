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


# The welcome body, worded for the platform — touch players use the stick + taps, not WASD / E / J keys.
func _body_for_platform() -> String:

	if not TouchEnv.is_touch():
		return BODY_TEXT
	return (BODY_TEXT \
		.replace("Move with WASD or the arrow keys, and press E to open doors, talk to folk, and work any station.",
			"Use the stick (bottom-left) to move, and tap doors, folk, and stations to interact.") \
		.replace(" (or press J)", ""))


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
	UiStyle.apply_title(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var body : Label = Label.new()
	body.text = _body_for_platform()
	body.add_theme_font_size_override("font_size", 18)
	UiStyle.apply_primary(body)
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

	# Routed through the central theme so the welcome panel recolors with Palette.use_scheme() (was a hardcoded brown).
	return UiStyle.panel(true)


func _make_button(text: String) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 20)
	UiStyle.style_button(btn, Palette.POSITIVE)   # "get to it" = a positive/confirm call-to-action
	return btn