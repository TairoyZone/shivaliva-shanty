## THE FIGHTING-STYLE PICKER — the gym master's intro RPG beat. The first time you try to spar at the Cradle
## Gym, Hollow Ellison asks what kind of fighter you are; your pick sets your POWER TYPE (your Skirmish garbage
## profile) for every bout from here on. The gym ladder stays LOCKED until you choose. Emits chosen(weapon_id).
## A pause-tree CanvasLayer; chrome cloned from [SkirmishChallengeModal]. See [[combat-power-types]].
class_name PowerTypePicker
extends CanvasLayer


signal chosen(weapon_id: String)
signal cancelled

# True while we hand off straight to ANOTHER paused modal (the ladder) — so our deferred _exit_tree doesn't
# un-pause the tree the new modal just paused. Only the chaining handler sets it; a plain cancel still unpauses.
var _handing_off : bool = false


# The 4 types offered, in order (Brawler the all-rounder first). Concise taglines so the buttons stay tidy —
# the full DESCRIPTIONS live on [SkirmishWeapon].
const ORDER : Array[String] = ["brawl", "sword", "long_range", "mystic"]
const TAGLINES : Dictionary = {
	"brawl": "wide clump — clogs several columns (breadth)",
	"sword": "lingering blade — garbage is slow to clear",
	"long_range": "aimed snipe — hits the foe's weakest column",
	"mystic": "scatter — chaos strewn across the board",
}


func _ready() -> void:

	layer = 41
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	add_child(EscToClose.new(_on_cancel))   # ESC backs out (you just can't spar until you pick)
	get_tree().paused = true


func _exit_tree() -> void:

	if _handing_off:
		return   # the ladder modal we opened owns the pause now — don't clobber it
	if get_tree() != null:
		get_tree().paused = false


func _build() -> void:

	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -330.0
	panel.offset_top = -240.0
	panel.offset_right = 330.0
	panel.offset_bottom = 240.0
	add_child(panel)

	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	vbox.add_child(_make_title("WHAT KIND OF FIGHTER ARE YOU?"))
	vbox.add_child(_make_caption("Hollow Ellison sizes you up. \"Choose your style — it's how you'll fight from "
		+ "here on. Choose well: a fighter's way is set ONCE, and there's no taking it back.\""))

	for id in ORDER:
		var label : String = "%s   ·   %s" % [SkirmishWeapon.power_type_name(id), String(TAGLINES.get(id, ""))]
		var btn : Button = _make_walnut_button(label, SkirmishWeapon.color_for(id))
		btn.pressed.connect(_on_pick.bind(id))
		vbox.add_child(btn)

	var back : Button = _make_walnut_button("Not yet", Color(0.95, 0.84, 0.56, 1.0))
	back.pressed.connect(_on_cancel)
	vbox.add_child(back)


func _on_pick(weapon_id: String) -> void:

	# Hand off to the ladder (the receiver opens it + pauses). Don't unpause here — keep the tree paused so the
	# overworld behind the new modal stays frozen (the _handing_off flag stops our _exit_tree from unpausing).
	_handing_off = true
	chosen.emit(weapon_id)
	queue_free()


func _on_cancel() -> void:

	if get_tree() != null:
		get_tree().paused = false
	cancelled.emit()
	queue_free()


# --- Styling (cloned from SkirmishChallengeModal so the modals match) ---

func _make_title(text: String) -> Label:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_caption(text: String) -> Label:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.74, 0.80, 0.92, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(600.0, 0.0)
	return label


func _panel_style() -> StyleBoxFlat:

	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.11, 0.06, 0.96)
	style.border_color = Color(0.78, 0.58, 0.24, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	return style


func _make_walnut_button(text: String, font_color: Color) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.22, 0.14, 0.08, 0.95)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		s.bg_color = bg
		s.border_color = Color(0.78, 0.58, 0.24, 1.0)
		s.set_border_width_all(2)
		s.set_corner_radius_all(8)
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		btn.add_theme_stylebox_override(state, s)
	return btn
