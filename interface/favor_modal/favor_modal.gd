## A small FAVOUR offer from an NPC — the cozy "do a good turn first"
## rapport tap (the One Piece "earn their liking by helping" feeling). The
## [Npc] opens it when the player talks to an NPC that has a standing
## favour ([constant Npc.NPC_FAVORS]) and it hasn't been handled this
## visit. The NPC asks for a few of something the player already produces
## (wood/ore); handing it over grants rapport and a warm thank-you.
##
## Self-contained: does its own inventory check + spend +
## [method PlayerState.add_affinity] / [method PlayerState.record_favor].
## Styling clones the [HiringBoard] modal so every modal reads as one
## family. Slice 2 of [[parlor-social-system]].
class_name FavorModal
extends CanvasLayer


## Emitted when the modal closes (whether or not the favour was given), so
## the host NPC can drop its reference.
signal closed


var _npc_name : String = ""
var _item_id : String = "wood"
var _amount : int = 1
var _ask : String = ""
var _thanks : String = ""
var _affinity : int = 15
## True when this favour is already on the player's objectives (accepted
## earlier, not yet turned in) — drives the turn-in vs offer button set.
var _accepted : bool = false
var _favor_given : bool = false
var _closing : bool = false

var _vbox : VBoxContainer


static func create(config: Dictionary) -> FavorModal:

	var modal : FavorModal = FavorModal.new()
	modal._npc_name = String(config.get("npc_name", ""))
	modal._item_id = String(config.get("item_id", "wood"))
	modal._amount = int(config.get("amount", 1))
	modal._ask = String(config.get("ask", ""))
	modal._thanks = String(config.get("thanks", ""))
	modal._affinity = int(config.get("affinity", 15))
	modal._accepted = bool(config.get("accepted", false))
	return modal


func _ready() -> void:

	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _build_panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300.0
	panel.offset_top = -190.0
	panel.offset_right = 300.0
	panel.offset_bottom = 190.0
	add_child(panel)
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 16)
	panel.add_child(_vbox)
	_show_main()
	get_tree().paused = true


func _exit_tree() -> void:

	if get_tree() != null:
		get_tree().paused = false


# --- States ------------------------------------------------------------

func _show_main() -> void:

	_clear()
	_add_title(_npc_name)
	_add_body(_ask)
	var have : int = PlayerState.item_count(_item_id)
	var enough : bool = have >= _amount
	var hbox : HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	if enough:
		# Got the goods — hand them over right now (works whether or not it
		# was ever formally accepted; turn-in clears it from objectives).
		var give : Button = _make_walnut_button("Give  (%d %s)" % [_amount, _item_id],
			Color(0.78, 1.0, 0.62, 1.0))
		give.pressed.connect(_on_give)
		hbox.add_child(give)
		var later : Button = _make_walnut_button("Maybe later", Color(0.95, 0.84, 0.56, 1.0))
		later.pressed.connect(_on_close)
		hbox.add_child(later)
	elif _accepted:
		# Already on the objectives list — just a reminder, nothing to re-accept.
		_add_note("You have %d / %d %s — bring the rest back to finish." % [have, _amount, _item_id])
		var close : Button = _make_walnut_button("I'll bring it  ▸", Color(0.95, 0.84, 0.56, 1.0))
		close.pressed.connect(_on_close)
		hbox.add_child(close)
	else:
		# Offer it as a side-quest — ONLY tracked in objectives if accepted.
		_add_note("You have %d / %d %s — take it on and I'd be much obliged." % [have, _amount, _item_id])
		var accept : Button = _make_walnut_button("Accept  ▸", Color(0.78, 1.0, 0.62, 1.0))
		accept.pressed.connect(_on_accept)
		hbox.add_child(accept)
		var later : Button = _make_walnut_button("Maybe later", Color(0.95, 0.84, 0.56, 1.0))
		later.pressed.connect(_on_close)
		hbox.add_child(later)
	_vbox.add_child(hbox)


func _show_thanks(count: int) -> void:

	_clear()
	_add_title(_npc_name)
	_add_body(_thanks)
	var note : String = "+%d rapport" % _affinity
	if count > 1:
		note += "   ·   you've helped %s %d times" % [_short_name(), count]
	_add_note(note)
	var hbox : HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_child(hbox)
	var close : Button = _make_walnut_button("You're welcome  ▸", Color(0.95, 0.84, 0.56, 1.0))
	close.pressed.connect(_on_close)
	hbox.add_child(close)


# --- Handlers ----------------------------------------------------------

func _on_accept() -> void:

	# The ONLY path that puts a favour on the objectives log.
	PlayerState.accept_favor(_npc_name, _item_id, _amount)
	_on_close()


func _on_give() -> void:

	if _favor_given:
		return
	# Re-check at spend time (inventory can't change behind a paused tree,
	# but it keeps the spend honest and guards a fast double-click).
	if PlayerState.item_count(_item_id) < _amount:
		_show_main()
		return
	_favor_given = true
	# One atomic turn-in (spend + rapport + clear objective + count) → one save.
	var count : int = PlayerState.turn_in_favor(_npc_name, _item_id, _amount, _affinity)
	_show_thanks(count)


func _on_close() -> void:

	if _closing:
		return
	_closing = true
	if get_tree() != null:
		get_tree().paused = false
	closed.emit()
	queue_free()


# --- Build helpers -----------------------------------------------------

func _clear() -> void:

	for child in _vbox.get_children():
		child.queue_free()


func _add_title(text: String) -> void:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(label)


func _add_body(text: String) -> void:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.92, 0.82, 0.58, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(label)


func _add_note(text: String) -> void:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.74, 0.84, 0.72, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(label)


func _short_name() -> String:

	var parts : PackedStringArray = _npc_name.split(" ")
	return parts[parts.size() - 1] if parts.size() > 0 else _npc_name


func _build_panel_style() -> StyleBoxFlat:

	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.11, 0.06, 0.96)
	style.border_color = Color(0.78, 0.58, 0.24, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	return style


func _make_walnut_button(text: String, font_color: Color) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 19)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.22, 0.14, 0.08, 0.95)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		elif state == "disabled":
			bg = bg.darkened(0.30)
		s.bg_color = bg
		s.border_color = Color(0.78, 0.58, 0.24, 1.0) if state != "disabled" else Color(0.5, 0.42, 0.3, 1.0)
		s.border_width_left = 2
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 2
		s.corner_radius_top_left = 8
		s.corner_radius_top_right = 8
		s.corner_radius_bottom_right = 8
		s.corner_radius_bottom_left = 8
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		btn.add_theme_stylebox_override(state, s)
	return btn
