## ShipChristening — the "name her!" moment right after buying a ship at Godfrey's drafting desk
## (the YPP christening beat — half the joy of a new hull is the name). A warm walnut [Modal]:
## type a name (≤24 chars), roll the dice for a sky-flavored suggestion, or skip — she keeps her
## class name until christened. Also opened from the dock to RE-christen. Writes
## PlayerState.christen_ship. ESC/skip is safe (never blocks the purchase).
class_name ShipChristening
extends Modal


const GROUP : StringName = &"ship_christening"

var _ship_id : String = ""
var _edit : LineEdit
var _done : bool = false   # one christen only — guards a double Enter / Enter+click during the close fade


static func open(host: Node, ship_id: String) -> void:

	if host == null or host.get_tree() == null:
		return
	if host.get_tree().get_first_node_in_group(GROUP) != null:
		return
	var m : ShipChristening = ShipChristening.new()
	m._ship_id = ship_id
	host.get_tree().root.add_child(m)


# --- Modal config -----------------------------------------------------

func _modal_group() -> StringName:
	return GROUP

func _modal_size() -> Vector2:
	return Vector2(440.0, 270.0)


func _build_content() -> void:

	var title : Label = Label.new()
	title.text = "CHRISTEN HER"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	var sub : Label = Label.new()
	sub.text = "Your %s awaits a name. What do they call her?" % ShipClasses.display(_ship_id)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.86, 0.78, 0.6, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	_content.add_child(sub)

	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_content.add_child(row)
	_edit = LineEdit.new()
	_edit.placeholder_text = "her name…"
	_edit.max_length = 24
	_edit.text = String(PlayerState.ship_custom_names.get(_ship_id, ""))   # re-christening shows the current name
	_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit.add_theme_font_size_override("font_size", 17)
	_edit.text_submitted.connect(func(_t: String) -> void: _on_christen())
	row.add_child(_edit)
	var dice : Button = Button.new()
	dice.text = "🎲"
	dice.tooltip_text = "Roll a name"
	dice.focus_mode = Control.FOCUS_NONE
	dice.add_theme_font_size_override("font_size", 17)
	dice.pressed.connect(_on_roll)
	row.add_child(dice)

	var btns : HBoxContainer = HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	_content.add_child(btns)
	var ok : Button = Button.new()
	ok.text = "Christen her"
	ok.add_theme_font_size_override("font_size", 17)
	ok.pressed.connect(_on_christen)
	btns.add_child(ok)
	var skip : Button = Button.new()
	skip.text = "Later"
	skip.add_theme_font_size_override("font_size", 15)
	skip.pressed.connect(_close)
	btns.add_child(skip)

	_edit.grab_focus()


func _on_roll() -> void:

	_edit.text = String(ShipClasses.NAME_IDEAS[randi() % ShipClasses.NAME_IDEAS.size()])


func _on_christen() -> void:

	if _done:
		return   # the buttons stay live during the 0.12s close fade — don't christen (and re-save) twice
	_done = true
	var typed : String = _edit.text.strip_edges()
	if not typed.is_empty():
		PlayerState.christen_ship(_ship_id, typed)
		PlayerState.log_event("Christened the %s" % typed, Color(0.95, 0.85, 0.5))
	_close()
