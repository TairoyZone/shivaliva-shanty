## TradeWindow — the YPP "Trade Negotiation" reskin: a two-column handover where YOU offer goods (+ a gold
## gift) and the NPC offers GOLD back (a fair barter) plus rapport. Click-to-add from your bag (Troy's call),
## a two-way reward (they pay you), an "I'm Ready" confirm + Reject. Opened from an NPC's radial "Trade",
## and the favour handover routes through it too (favour mode pre-loads the ask → confirming IS the trade).
## Built 2026-06-08; player↔player reuses the same window per side once co-op netcode lands. Modal family
## styling (clones [FavorModal]). See [[parlor-social-system]] + the YPP Trade article.
class_name TradeWindow
extends CanvasLayer


signal closed

const GROUP : StringName = &"trade_window"
const LIKED_RATE : float = 1.0      # the NPC pays the FULL (delivery-equal) price for an item they want...
const PLAIN_RATE : float = 0.5      # ...and a discount for goods they don't — so Trade never out-pays the delivery sinks
const GOLD_STEP : int = 5

var _npc_name : String = ""
var _npc_color : Color = Color(0.6, 0.6, 0.7, 1.0)
var _liked_item : String = ""             # an item this NPC especially wants → a barter bonus
var _favor : Dictionary = {}              # {item_id, amount, affinity, thanks} → FAVOUR mode (fixed offer); else GENERAL
var _grant_rapport : bool = true          # false once you've already traded this NPC this visit (no rapport farm)
var _on_traded : Callable = Callable()    # called on a successful trade so the Npc can set its per-visit gates

var _offer_items : Dictionary = {}        # {item_id: qty} the player puts up
var _offer_gold : int = 0                 # an optional gold gift the player adds
var _npc_gold : int = 0                   # gold the NPC offers back (computed)
var _npc_rapport : int = 0
var _npc_willing : bool = false
var _npc_note : String = ""
var _executed : bool = false

var _panel : PanelContainer
var _dim : ColorRect
var _content : VBoxContainer


static func open(host: Node, config: Dictionary) -> void:

	if host == null or host.get_tree() == null:
		return
	if host.get_tree().get_first_node_in_group(GROUP) != null:
		return
	var w : TradeWindow = TradeWindow.new()
	w._npc_name = String(config.get("npc_name", "Trader"))
	w._npc_color = config.get("npc_color", Color(0.6, 0.6, 0.7, 1.0))
	w._liked_item = String(config.get("liked_item", ""))
	w._grant_rapport = bool(config.get("grant_rapport", true))
	w._on_traded = config.get("on_traded", Callable())
	var fav : Dictionary = config.get("favor", {})
	if fav.has("item_id") and fav.has("amount") and fav.has("affinity"):
		w._favor = fav.duplicate()   # a malformed/partial favor dict degrades to a general trade
	host.get_tree().root.add_child(w)


func _ready() -> void:

	layer = 36
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	get_tree().paused = true

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(e: InputEvent) -> void: if e is InputEventMouseButton and e.pressed: _close())
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.offset_left = -330.0
	_panel.offset_top = -235.0
	_panel.offset_right = 330.0
	_panel.offset_bottom = 235.0
	add_child(_panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_panel.add_child(_content)

	# FAVOUR mode pre-loads the ask (the offer is fixed — confirming is the handover).
	if not _favor.is_empty():
		_offer_items[String(_favor["item_id"])] = int(_favor["amount"])

	_evaluate()
	_render()
	add_child(EscToClose.new(_close))
	ModalFx.appear(_panel, _dim)


func _exit_tree() -> void:

	if get_tree() != null:
		get_tree().paused = false


# --- evaluation (the NPC's barter brain) -------------------------------

func _evaluate() -> void:

	if not _favor.is_empty():
		var fid : String = String(_favor["item_id"])
		var amt : int = int(_favor["amount"])
		_npc_willing = int(_offer_items.get(fid, 0)) >= amt
		_npc_rapport = int(_favor["affinity"])
		_npc_gold = 0   # a favour is a KINDNESS — rapport only, no gold (gold reward is for general Trade selling)
		_npc_note = "Aye — that's just what I needed!" if _npc_willing else "I asked for %d %s." % [amt, _item_name(fid)]
		return
	var has_items : bool = not _offer_items.is_empty()
	_npc_gold = _barter_gold()
	var rap : int = (1 if has_items else 0) + (1 if _offer_gold > 0 else 0)
	_npc_rapport = rap if _grant_rapport else 0
	_npc_willing = has_items or _offer_gold > 0
	if has_items:
		_npc_note = "Fair enough — %d gold for that lot." % _npc_gold
	elif _offer_gold > 0:
		_npc_note = "A gift? Why, thank'ee kindly!"
	else:
		_npc_note = "Put something on the table, friend."


# What the NPC pays for the current item offer: FULL (delivery-equal) price for an item they want, a discount
# for the rest — so a general Trade never out-pays the dedicated delivery NPCs (an item's value IS that rate).
func _barter_gold() -> int:

	var g : int = 0
	for id in _offer_items:
		var rate : float = LIKED_RATE if (not _liked_item.is_empty() and String(id) == _liked_item) else PLAIN_RATE
		g += int(round(float(int(_offer_items[id]) * PlayerState.item_value(String(id))) * rate))
	return g


# --- offer edits (general mode) ----------------------------------------

func _add_item(item_id: String) -> void:

	if PlayerState.item_count(item_id) <= int(_offer_items.get(item_id, 0)):
		return
	_offer_items[item_id] = int(_offer_items.get(item_id, 0)) + 1
	_changed()


func _drop_item(item_id: String) -> void:

	var q : int = int(_offer_items.get(item_id, 0)) - 1
	if q <= 0:
		_offer_items.erase(item_id)
	else:
		_offer_items[item_id] = q
	_changed()


func _nudge_gold(delta: int) -> void:

	_offer_gold = clampi(_offer_gold + delta, 0, PlayerState.total_coins)
	_changed()


# Any change to the offer un-readies the deal + re-evaluates the NPC (YPP anti-scam parity).
func _changed() -> void:

	_evaluate()
	_render()


# --- execution ---------------------------------------------------------

func _confirm() -> void:

	if _executed or not _npc_willing:
		return
	# Snapshot-validate holdings (no UI rebuild mid-check), then re-evaluate after the gold clamp so the paid
	# figures match the FINAL offer.
	for id in _offer_items.keys():
		if PlayerState.item_count(String(id)) < int(_offer_items[id]):
			_changed()
			return
	_offer_gold = mini(_offer_gold, PlayerState.total_coins)
	_evaluate()
	if not _npc_willing:
		_render()
		return
	_executed = true

	if not _favor.is_empty():
		var fid : String = String(_favor["item_id"])
		var amt : int = int(_favor["amount"])
		PlayerState.turn_in_favor(_npc_name, fid, amt, int(_favor["affinity"]))   # spend + rapport + clear + count
		_show_done(String(_favor.get("thanks", "Thank'ee kindly!")), "+%d rapport" % int(_favor["affinity"]))
	else:
		if not PlayerState.execute_trade(_offer_items, _offer_gold, _npc_gold, _npc_name, _npc_rapport):
			_executed = false
			_changed()
			return
		var got : String = ("+%d gold" % _npc_gold) if _npc_gold > 0 else "much obliged"
		var rep : String = ("   ·   +%d rapport" % _npc_rapport) if _npc_rapport > 0 else ""
		_show_done("Pleasure doing business!", "%s%s" % [got, rep])
	if _on_traded.is_valid():
		_on_traded.call(not _favor.is_empty())


# --- rendering ---------------------------------------------------------

func _render() -> void:

	for c in _content.get_children():
		c.queue_free()

	_add_title("Trade  ·  %s" % _npc_name)
	if not _favor.is_empty():
		_add_hint(String(_favor.get("ask", "Hand over what they asked for.")))
	else:
		_add_hint("Offer goods from your bag — they'll pay a fair price.")

	var cols : HBoxContainer = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(cols)
	cols.add_child(_your_column())
	cols.add_child(_make_divider())
	cols.add_child(_their_column())

	_add_note(_npc_note, Color(0.74, 0.84, 0.72, 1.0) if _npc_willing else Color(0.86, 0.66, 0.5, 1.0))
	_content.add_child(_ready_row())


func _your_column() -> Control:

	var box : VBoxContainer = _column_box("You")
	# Current offer.
	box.add_child(_sub("Offering"))
	var offered : bool = false
	for id in _offer_items:
		offered = true
		var fixed : bool = not _favor.is_empty()   # favour offer is fixed
		box.add_child(_offer_row("%s ×%d" % [_item_name(String(id)), int(_offer_items[id])], String(id), fixed))
	if _offer_gold > 0:
		box.add_child(_make_caption("Gift: %d gold" % _offer_gold))
	if not offered and _offer_gold <= 0:
		box.add_child(_make_caption("(nothing yet)"))

	# Add-from-bag controls (general mode only — a favour offer is fixed).
	if _favor.is_empty():
		box.add_child(_sub("Add from your bag"))
		var any_item : bool = false
		for id in PlayerState.ITEM_DEFS:
			var sid : String = String(id)
			var have : int = PlayerState.item_count(sid)
			if have <= 0:
				continue
			any_item = true
			var spare : int = have - int(_offer_items.get(sid, 0))
			var b : Button = _make_walnut_button("+ %s  (%d)" % [_item_name(sid), spare], Color(0.82, 0.95, 0.7, 1.0))
			b.disabled = spare <= 0
			b.pressed.connect(_add_item.bind(sid))
			box.add_child(b)
		if not any_item:
			box.add_child(_make_caption("Your bag is empty."))
		box.add_child(_gold_gift_row())
	return box


func _their_column() -> Control:

	var box : VBoxContainer = _column_box(_npc_name)
	box.add_child(_sub("Offers you"))
	box.add_child(_make_caption("%d gold" % _npc_gold))
	if _npc_rapport > 0:
		box.add_child(_make_caption("+%d rapport" % _npc_rapport))
	if _npc_gold <= 0 and _npc_rapport <= 0:
		box.add_child(_make_caption("—"))
	return box


func _ready_row() -> Control:

	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	# NPC ready indicator (auto).
	var npc_state : Label = Label.new()
	npc_state.text = "✔ %s ready" % _short() if _npc_willing else "… %s considering" % _short()
	npc_state.add_theme_font_size_override("font_size", 15)
	npc_state.add_theme_color_override("font_color", Color(0.7, 0.92, 0.66, 1.0) if _npc_willing else Color(0.8, 0.75, 0.6, 1.0))
	row.add_child(npc_state)

	var ready : Button = _make_walnut_button("I'm Ready  ✔", Color(0.82, 1.0, 0.66, 1.0))
	ready.disabled = not _npc_willing
	ready.pressed.connect(_confirm)
	row.add_child(ready)

	var reject : Button = _make_walnut_button("Reject", Color(0.95, 0.78, 0.6, 1.0))
	reject.pressed.connect(_close)
	row.add_child(reject)
	return row


func _show_done(title: String, note: String) -> void:

	if is_instance_valid(_dim):
		_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE   # only the Done button / ESC closes the result — not a stray click
	for c in _content.get_children():
		c.queue_free()
	_add_title(title)
	_add_note(note, Color(0.98, 0.88, 0.46, 1.0))
	var row : HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ok : Button = _make_walnut_button("Done  ▸", Color(0.95, 0.84, 0.56, 1.0))
	ok.pressed.connect(_close)
	row.add_child(ok)
	_content.add_child(row)


# --- small build helpers -----------------------------------------------

func _column_box(header: String) -> VBoxContainer:

	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(250.0, 0.0)
	var h : Label = Label.new()
	h.text = header
	h.add_theme_font_size_override("font_size", 21)
	h.add_theme_color_override("font_color", _npc_color.lightened(0.4) if header == _npc_name else Color(0.82, 1.0, 0.74, 1.0))
	h.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	h.add_theme_constant_override("outline_size", 3)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(h)
	return box


func _offer_row(text: String, item_id: String, fixed: bool) -> Control:

	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_make_caption(text))
	if not fixed:
		var minus : Button = _make_walnut_button("−", Color(0.95, 0.8, 0.6, 1.0))
		minus.pressed.connect(_drop_item.bind(item_id))
		row.add_child(minus)
	return row


func _gold_gift_row() -> Control:

	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_make_caption("Gift gold"))
	var minus : Button = _make_walnut_button("−%d" % GOLD_STEP, Color(0.95, 0.8, 0.6, 1.0))
	minus.pressed.connect(_nudge_gold.bind(-GOLD_STEP))
	row.add_child(minus)
	row.add_child(_make_caption(str(_offer_gold)))
	var plus : Button = _make_walnut_button("+%d" % GOLD_STEP, Color(0.82, 0.95, 0.7, 1.0))
	plus.disabled = _offer_gold >= PlayerState.total_coins
	plus.pressed.connect(_nudge_gold.bind(GOLD_STEP))
	row.add_child(plus)
	return row


func _make_divider() -> Control:

	var sep : Panel = Panel.new()
	sep.custom_minimum_size = Vector2(2.0, 200.0)
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.78, 0.58, 0.24, 0.5)
	sep.add_theme_stylebox_override("panel", s)
	return sep


func _add_title(text: String) -> void:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 27)
	l.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(l)


func _add_hint(text: String) -> void:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(0.9, 0.81, 0.57, 1.0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(560.0, 0.0)
	_content.add_child(l)


func _add_note(text: String, color: Color) -> void:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(l)


func _sub(text: String) -> Control:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.66, 0.74, 0.62, 1.0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _make_caption(text: String) -> Label:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66, 1.0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _item_name(item_id: String) -> String:

	return String((PlayerState.ITEM_DEFS.get(item_id, {}) as Dictionary).get("name", item_id.capitalize()))


func _short() -> String:

	var parts : PackedStringArray = _npc_name.split(" ", false)
	return parts[parts.size() - 1] if parts.size() > 0 else _npc_name


func _close() -> void:

	ModalFx.dismiss(self, _panel, _dim, _do_close)


func _do_close() -> void:

	if get_tree() != null:
		get_tree().paused = false
	closed.emit()
	queue_free()


func _panel_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.11, 0.06, 0.97)
	s.border_color = Color(0.78, 0.58, 0.24, 1.0)
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(26)
	return s


func _make_walnut_button(text: String, font_color: Color) -> Button:

	var b : Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", font_color)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 2)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.22, 0.14, 0.08, 0.95)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		elif state == "disabled":
			bg = bg.darkened(0.34)
		s.bg_color = bg
		s.border_color = Color(0.78, 0.58, 0.24, 1.0) if state != "disabled" else Color(0.5, 0.42, 0.3, 1.0)
		s.set_border_width_all(2)
		s.set_corner_radius_all(8)
		s.content_margin_left = 13
		s.content_margin_right = 13
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		b.add_theme_stylebox_override(state, s)
	return b
