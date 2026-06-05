## SKIRMISH BOARDING — the VIEW onto the live crew-vs-crew melee ([[seabattle-research]]). The fight
## itself (your side YOU + AI mates vs an enemy crew, each on a [SkirmishBoard]) lives in the persistent
## [BoardingMelee] autoload so it keeps running whether or not you're watching — this scene just RENDERS
## it (your full board centred, the crews as windowed thumbnail columns down each side), forwards your
## input to the sim, and shows the result. You play YOUR board; clearing lines mails garbage to the foe
## you've TARGETED (click a board, or [A]/[D]); a whole side topped out ends it. You can STEP AWAY (Leave)
## and the melee fights on without you — rejoin from the deck. See [[live-melee-boarding]].
##
## Reuses the engine (board / [SkirmishAI] / [SkirmishWeapon]) via the autoload. Runs standalone (the
## .tscn starts a fresh melee) and as the VOYAGE boarding; the 1v1 skirmish_duel stays the Spar's match.
extends PuzzleScene


const PORTRAIT_SCENE : PackedScene = preload("res://components/portrait/portrait.tscn")

## Up to this many thumbnails show per side at once; a bigger crew scrolls.
const VISIBLE_PER_COL : int = 3

## Column geometry. Every board's TOP aligns at BOARD_TOP_Y and stacks DOWN. Each crew column has a
## CENTRE line, COL_INSET in from its screen edge; boards AND headers centre on it. The thumbnail SCALE
## is derived so VISIBLE_PER_COL fit between the top and COLUMN_BOTTOM. Your centre board is full-size.
const BOARD_TOP_Y : float = 140.0
const COLUMN_BOTTOM : float = 706.0
const COL_INSET : float = 190.0
const CTRL_ROW_H : float = 26.0
const THUMB_HEADER_H : float = 24.0
const THUMB_GAP : float = 12.0

const DAS_DELAY : float = 0.16
const DAS_REPEAT : float = 0.04

const TARGET_RING : Color = Color(0.98, 0.86, 0.42, 1.0)   # attacking a foe (gold)
const DEFEND_RING : Color = Color(0.55, 1.0, 0.66, 1.0)    # defending a mate (green)
const NAME_ALLY : Color = Color(0.72, 0.95, 0.76, 1.0)
const NAME_FOE : Color = Color(0.97, 0.70, 0.70, 1.0)


## The combatants are OWNED by the BoardingMelee autoload — these are just our local handles to them.
var _combatants : Array = []
var _player : BoardingCombatant
var _ui : CanvasLayer

## Window top index per side (which member is first-shown). Bigger crews scroll.
var _scroll_ally : int = 0
var _scroll_foe : int = 0
## One shared thumbnail scale, derived from the larger crew so both columns match.
var _thumb_scale : float = 0.45
var _ally_ctrl : Control
var _foe_ctrl : Control
var _ally_scroll_label : Label
var _foe_scroll_label : Label

var _das_dir : int = 0
var _das_timer : float = 0.0
var _das_charged : bool = false


func _ready() -> void:

	super._ready()
	# Start a FRESH melee only if none is running; otherwise we're RE-ATTACHING to a fight that's been
	# going on without us (rejoin). The sim owns the boards; we just reveal + position them here.
	var fresh : bool = not BoardingMelee.has_active()
	if fresh:
		BoardingMelee.start()
	_combatants = BoardingMelee.combatants()
	_player = BoardingMelee.player_combatant()
	for c in _combatants:
		if is_instance_valid(c.board):
			c.board.visible = true
	_build_ui()
	_layout()
	BoardingMelee.combatant_defeated.connect(_on_combatant_defeated)
	BoardingMelee.targets_changed.connect(_on_targets_changed)
	BoardingMelee.melee_resolved.connect(_on_melee_resolved)
	_update_highlight()
	_refresh_dots()
	_update_scroll_ui()
	BoardingMelee.set_player_present(true)
	if fresh:
		# A "READY? → GO!" beat that freezes every board + shows the controls before a NEW melee runs —
		# never on a rejoin (you're dropping back into a fight already in motion).
		add_child(ReadyOverlay.new())
	elif BoardingMelee.is_resolved():
		# Rejoined a melee that already finished while we were away → straight to the result.
		_on_melee_resolved(BoardingMelee.player_won())


# Leaving the scene: hand the player off + hide the boards (they stay under the autoload, ticking, so
# the melee survives this scene being freed). set_player_present(false) makes the undefended board fall.
func _exit_tree() -> void:

	if is_instance_valid(BoardingMelee):
		for c in BoardingMelee.combatants():
			if is_instance_valid(c.board):
				c.board.visible = false
		BoardingMelee.set_player_present(false)


# --- Layout: player centre, windowed crew columns ---------------------

func _layout() -> void:

	var vp : Vector2 = get_viewport().get_visible_rect().size
	var field_w : float = float(SkirmishBoard.COLS * SkirmishBoard.CELL)
	var preview_w : float = 4.0 * float(SkirmishBoard.CELL) * 0.82 + 24.0
	var block_w : float = field_w + 22.0 + preview_w
	_player.board.scale = Vector2.ONE
	_player.board.position = Vector2(round((vp.x - block_w) * 0.5), BOARD_TOP_Y)
	_thumb_scale = _compute_thumb_scale()
	var ctrl_y : float = BOARD_TOP_Y - THUMB_HEADER_H - CTRL_ROW_H - 6.0
	if _ally_ctrl != null:
		_ally_ctrl.position = Vector2(COL_INSET - 52.0, ctrl_y)
	if _foe_ctrl != null:
		_foe_ctrl.position = Vector2(vp.x - COL_INSET - 52.0, ctrl_y)
	_relayout_columns()
	_position_header(_player)


# One scale so VISIBLE_PER_COL thumbnails (of the larger crew) fill a column top-to-bottom.
func _compute_thumb_scale() -> float:

	var field_h : float = float(SkirmishBoard.ROWS * SkirmishBoard.CELL)
	var max_count : int = maxi(_members(false).size(), _members(true).size())
	var shown : int = clampi(max_count, 1, VISIBLE_PER_COL)
	var per : float = (COLUMN_BOTTOM - BOARD_TOP_Y) / float(shown)
	var s : float = (per - THUMB_HEADER_H - THUMB_GAP) / field_h
	return clampf(s, 0.22, 0.5)


func _relayout_columns(animate: bool = false) -> void:

	var vp : Vector2 = get_viewport().get_visible_rect().size
	var half : float = float(SkirmishBoard.COLS * SkirmishBoard.CELL) * _thumb_scale * 0.5
	_layout_column(_members(false), COL_INSET - half, _scroll_ally, animate)
	_layout_column(_members(true), vp.x - COL_INSET - half, _scroll_foe, animate)


# The non-player fighters on a side, ALIVE-FIRST then dead — a downed fighter drops to the bottom.
func _members(enemy: bool) -> Array:

	var live : Array = []
	var dead : Array = []
	for c in _combatants:
		if not c.is_player and c.enemy == enemy:
			if c.alive:
				live.append(c)
			else:
				dead.append(c)
	return live + dead


# Position the visible WINDOW [offset, offset+VISIBLE) of a column's thumbnails, TOP-aligned at
# BOARD_TOP_Y; others are hidden. When [param animate], boards that stay visible SLIDE to their slots.
func _layout_column(members: Array, x: float, offset: int, animate: bool = false) -> void:

	var board_h : float = float(SkirmishBoard.ROWS * SkirmishBoard.CELL) * _thumb_scale
	var slot : float = THUMB_HEADER_H + board_h + THUMB_GAP
	for i in members.size():
		var c : BoardingCombatant = members[i]
		var in_window : bool = i >= offset and i < offset + VISIBLE_PER_COL
		var was_visible : bool = c.board.visible
		if not in_window:
			c.board.visible = false
			if c.header != null:
				c.header.visible = false
			continue
		c.board.scale = Vector2(_thumb_scale, _thumb_scale)
		c.board.visible = true
		if c.header != null:
			c.header.visible = true
		var target : Vector2 = Vector2(x, round(BOARD_TOP_Y + float(i - offset) * slot))
		if animate and was_visible:
			_tween_member(c, target, _header_target(c, target))
		else:
			if c.move_tween != null and c.move_tween.is_valid():
				c.move_tween.kill()
			c.board.position = target
			_position_header(c)


# Slide a fighter's board + header from where they are to their new slot.
func _tween_member(c: BoardingCombatant, board_target: Vector2, hdr_target: Vector2) -> void:

	if c.move_tween != null and c.move_tween.is_valid():
		c.move_tween.kill()
	c.move_tween = create_tween().set_parallel(true)
	c.move_tween.tween_property(c.board, "position", board_target, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if c.header != null:
		c.move_tween.tween_property(c.header, "position", hdr_target, 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# Centre a fighter's header over its board (a long name + dots extends both ways, never off-screen).
func _position_header(c: BoardingCombatant) -> void:

	if c.header == null:
		return
	c.header.position = _header_target(c, c.board.position)


func _header_target(c: BoardingCombatant, board_pos: Vector2) -> Vector2:

	var bw : float = float(SkirmishBoard.COLS * SkirmishBoard.CELL) * c.board.scale.x
	var cx : float = board_pos.x + bw * 0.5
	return Vector2(round(cx - _header_width(c) * 0.5), board_pos.y - THUMB_HEADER_H)


func _header_width(c: BoardingCombatant) -> float:

	return 36.0 + float(c.cname.length()) * 8.5 + float(c.dot_count) * 12.0


# --- Per-frame: forward the player's input to the sim (the AI is driven in the autoload) ----

func _process(delta: float) -> void:

	if not BoardingMelee.player_alive():
		_das_dir = 0
		return
	BoardingMelee.player_soft_drop(
		Input.is_action_pressed("ui_down") or Input.is_action_pressed("ui_accept"))
	var dir : int = 0
	if Input.is_action_pressed("ui_right"):
		dir += 1
	if Input.is_action_pressed("ui_left"):
		dir -= 1
	if dir == 0:
		_das_dir = 0
		return
	if dir != _das_dir:
		_das_dir = dir
		_das_timer = 0.0
		_das_charged = false
		BoardingMelee.player_move(dir)
		return
	_das_timer += delta
	if not _das_charged:
		if _das_timer >= DAS_DELAY:
			_das_charged = true
			_das_timer = 0.0
			BoardingMelee.player_move(dir)
	else:
		while _das_timer >= DAS_REPEAT:
			_das_timer -= DAS_REPEAT
			BoardingMelee.player_move(dir)


func _unhandled_input(event: InputEvent) -> void:

	if BoardingMelee.player_alive():
		if event.is_action_pressed("ui_up"):
			BoardingMelee.player_rotate()
			get_viewport().set_input_as_handled()
			return
	# [A]/[D] cycle your target up/down the foe roster (auto-scrolling it into view).
	if not BoardingMelee.is_resolved() and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A:
			BoardingMelee.cycle_player_target(-1)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_D:
			BoardingMelee.cycle_player_target(1)
			get_viewport().set_input_as_handled()
			return
	# Click a VISIBLE board: a FOE to attack it, an ALLY to DEFEND them.
	if not BoardingMelee.is_resolved() and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		for c in _combatants:
			if c.is_player or not c.alive or not c.board.visible:
				continue
			if _board_rect(c.board).has_point(event.position):
				BoardingMelee.set_player_target(c)
				get_viewport().set_input_as_handled()
				return
	# Otherwise defer to PuzzleScene (click-to-dismiss after the boarding ends).
	super._unhandled_input(event)


# The on-screen field rect of a board (accounts for its thumbnail scale).
func _board_rect(board: SkirmishBoard) -> Rect2:

	var size : Vector2 = Vector2(SkirmishBoard.COLS * SkirmishBoard.CELL,
		SkirmishBoard.ROWS * SkirmishBoard.CELL) * board.scale
	return Rect2(board.position, size)


# --- Targeting + scrolling (view-side: the sim picks the target, we scroll/ring it) ---

func _on_targets_changed() -> void:

	_ensure_target_visible()
	_update_highlight()
	_refresh_dots()


# Set the foe scroll offset so the current target sits inside the window (no relayout).
func _scroll_to_target_offset() -> void:

	if _player.target == null:
		return
	var foes : Array = _members(true)
	var idx : int = foes.find(_player.target)
	if idx < 0:
		return
	if idx < _scroll_foe:
		_scroll_foe = idx
	elif idx >= _scroll_foe + VISIBLE_PER_COL:
		_scroll_foe = idx - VISIBLE_PER_COL + 1
	_scroll_foe = clampi(_scroll_foe, 0, maxi(0, foes.size() - VISIBLE_PER_COL))


# Scroll the foe column so the current target sits inside the visible window.
func _ensure_target_visible() -> void:

	_scroll_to_target_offset()
	_relayout_columns()
	_update_scroll_ui()


# A ▲/▼ button moved a column's window.
func _scroll_column(enemy: bool, dir: int) -> void:

	var max_off : int = maxi(0, _members(enemy).size() - VISIBLE_PER_COL)
	if enemy:
		_scroll_foe = clampi(_scroll_foe + dir, 0, max_off)
	else:
		_scroll_ally = clampi(_scroll_ally + dir, 0, max_off)
	_relayout_columns()
	_update_highlight()
	_refresh_dots()
	_update_scroll_ui()


# --- Sim signals: a fighter fell / the fight resolved -----------------

func _on_combatant_defeated(c: BoardingCombatant) -> void:

	_refresh_header(c)
	_announce_defeat(c)
	# The downed fighter drops to the bottom; keep your target on-screen; refresh dots (header widths)
	# BEFORE the slide, then animate everyone to their new slots.
	_scroll_to_target_offset()
	_refresh_dots()
	_relayout_columns(true)
	_update_highlight()
	_update_scroll_ui()


func _on_melee_resolved(player_won: bool) -> void:

	var res : Dictionary = BoardingMelee.last_result()
	_show_results(player_won, bool(res.get("is_new_best", false)))
	if res.get("ranked_up", false):
		add_child(MasteryToast.create(String(res["tier_name"])))
	_set_awaiting_dismiss(true)


# Stage 1: leaving ENDS this melee — clear it so it can't keep running invisibly under the autoload —
# then return the normal way (the voyage station/deck reads last_skirmish_won to bank the leg). The
# step-away-and-keep-fighting flow replaces this clear() in a later stage.
func _return_to_launching_scene() -> void:

	BoardingMelee.clear()
	super._return_to_launching_scene()


# A top-centre banner when any fighter falls — a foe down (good, green) or a mate fallen (bad, red).
func _announce_defeat(c: BoardingCombatant) -> void:

	if _ui == null:
		return
	var text : String
	if c.is_player:
		text = "You're down — yer crew fights on!"
	elif c.enemy:
		text = "%s is down!" % c.cname
	else:
		text = "%s has fallen!" % c.cname
	var col : Color = Color(0.74, 1.0, 0.74, 1.0) if c.enemy else Color(1.0, 0.55, 0.55, 1.0)
	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", col)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(560.0, 56.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp : Vector2 = get_viewport().get_visible_rect().size
	label.position = Vector2(vp.x * 0.5 - 280.0, 92.0)
	label.pivot_offset = label.size * 0.5
	_ui.add_child(label)
	var tw : Tween = create_tween()
	tw.tween_property(label, "position:y", 70.0, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.2)
	tw.tween_property(label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(label.queue_free)


# --- UI: title, roster headers, scroll controls, target ring, dots -----

func _build_ui() -> void:

	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)

	var title : Label = Label.new()
	title.text = "BOARDING  —  hold the deck!"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 4)
	title.position = Vector2(40.0, 18.0)
	_ui.add_child(title)

	for c in _combatants:
		_build_header(c)
	if _members(false).size() > VISIBLE_PER_COL:
		_build_scroll_ctrl(false)
	if _members(true).size() > VISIBLE_PER_COL:
		_build_scroll_ctrl(true)

	set_help_text("SKIRMISH — boarding (crew vs crew).\n\n"
		+ "• ←  → :  move    ↑ :  rotate    ↓ / SPACE :  soft drop\n"
		+ "• Clear lines to mail GARBAGE to the foe you've TARGETED (gold ring).\n"
		+ "• Incoming attacks land as grey X-blocks — they clog your stack + can't clear until they ripen.\n"
		+ "• CLICK a foe, or press [A] / [D], to switch your target.\n"
		+ "• CLICK a MATE to DEFEND them (green ring) — your clears un-bury THEIR board instead.\n"
		+ "• Big crews scroll — use the ▲ ▼ by a column ([A]/[D] auto-scrolls your target in).\n"
		+ "• The dots by each fighter show how many foes are on them.\n"
		+ "• The fight goes on with or without you — Leave to step away, then rejoin from the deck.\n"
		+ "• Top out a whole crew to win. Your mates fight on even if you fall.")


# A compact one-row header above a board: avatar + weapon swatch + name + target dots.
func _build_header(c: BoardingCombatant) -> void:

	var box : HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_ui.add_child(box)
	var avatar : Portrait = PORTRAIT_SCENE.instantiate()
	avatar.custom_minimum_size = Vector2(22.0, 22.0)
	avatar.setup(c.cname, c.portrait)
	box.add_child(avatar)
	var wpn : ColorRect = ColorRect.new()      # the weapon shown "on" the avatar
	wpn.custom_minimum_size = Vector2(6.0, 18.0)
	wpn.color = c.color
	box.add_child(wpn)
	var name_l : Label = Label.new()
	name_l.text = c.cname
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", NAME_FOE if c.enemy else NAME_ALLY)
	name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_l.add_theme_constant_override("outline_size", 3)
	box.add_child(name_l)
	var dots : HBoxContainer = HBoxContainer.new()
	dots.add_theme_constant_override("separation", 2)
	box.add_child(dots)
	c.header = box
	c.name_label = name_l
	c.dots_box = dots
	# A rejoin rebuilds headers for a fight already in progress — reflect any already-downed fighter.
	_refresh_header(c)


func _build_scroll_ctrl(enemy: bool) -> void:

	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_ui.add_child(row)
	var up : Button = _make_scroll_button("▲")
	up.pressed.connect(_scroll_column.bind(enemy, -1))
	row.add_child(up)
	var down : Button = _make_scroll_button("▼")
	down.pressed.connect(_scroll_column.bind(enemy, 1))
	row.add_child(down)
	var lbl : Label = Label.new()
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.84, 0.94, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("outline_size", 2)
	row.add_child(lbl)
	if enemy:
		_foe_ctrl = row
		_foe_scroll_label = lbl
	else:
		_ally_ctrl = row
		_ally_scroll_label = lbl


func _make_scroll_button(text: String) -> Button:

	var b : Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(0.97, 0.87, 0.55, 1.0))
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.18, 0.11, 0.06, 0.94)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		s.bg_color = bg
		s.border_color = Color(0.78, 0.58, 0.24, 1.0)
		s.set_border_width_all(2)
		s.set_corner_radius_all(6)
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 1
		s.content_margin_bottom = 1
		b.add_theme_stylebox_override(state, s)
	return b


func _update_scroll_ui() -> void:

	_set_scroll_label(false, _ally_scroll_label, _scroll_ally)
	_set_scroll_label(true, _foe_scroll_label, _scroll_foe)


func _set_scroll_label(enemy: bool, lbl: Label, off: int) -> void:

	if lbl == null:
		return
	var n : int = _members(enemy).size()
	var first : int = off + 1
	var last : int = mini(off + VISIBLE_PER_COL, n)
	lbl.text = "%d–%d / %d" % [first, last, n]


func _refresh_header(c: BoardingCombatant) -> void:

	if c.header != null:
		c.header.modulate = Color(1, 1, 1, 0.4) if not c.alive else Color(1, 1, 1, 1.0)
	if c.name_label != null:
		c.name_label.text = (c.cname + "  ✕") if not c.alive else c.cname


# A row of small dots by each fighter = how many enemies currently target them, each coloured by the
# attacker's weapon ([[seabattle-research]] target dots).
func _refresh_dots() -> void:

	for c in _combatants:
		if c.dots_box == null:
			continue
		for ch in c.dots_box.get_children():
			ch.queue_free()
		var n : int = 0
		for a in _combatants:
			if a.alive and a != c and a.target == c and a.enemy != c.enemy:
				var dot : ColorRect = ColorRect.new()
				dot.custom_minimum_size = Vector2(10.0, 10.0)
				dot.color = a.color
				c.dots_box.add_child(dot)
				n += 1
		c.dot_count = n
		_position_header(c)


func _update_highlight() -> void:

	for c in _combatants:
		c.board.set_highlight(Color(0, 0, 0, 0))
	if _player.target != null and _player.target.alive:
		var ring : Color = DEFEND_RING if _player.target.enemy == _player.enemy else TARGET_RING
		_player.target.board.set_highlight(ring)


# --- Results -----------------------------------------------------------

func _show_results(player_won: bool, is_new_best: bool) -> void:

	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 9
	add_child(layer)
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var panel : PanelContainer = PanelContainer.new()
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.10, 0.16, 0.97)
	s.border_color = Color(0.5, 0.55, 0.82, 1.0)
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.content_margin_left = 48
	s.content_margin_right = 48
	s.content_margin_top = 30
	s.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", s)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	if player_won:
		_add_result_label(vbox, "DECK TAKEN!", 44, Color(0.72, 1.0, 0.72, 1.0))
		_add_result_label(vbox, "Yer crew won the boarding.", 22, Color(0.95, 0.92, 0.62, 1.0))
	else:
		_add_result_label(vbox, "REPELLED", 44, Color(0.95, 0.55, 0.55, 1.0))
		_add_result_label(vbox, "The enemy crew held the deck.", 22, Color(0.92, 0.84, 0.6, 1.0))
	var sent : int = _player.sent if _player != null else 0
	_add_result_label(vbox, "Attack sent:  %d" % sent, 18, Color(0.85, 0.9, 1.0, 1.0))
	if is_new_best:
		_add_result_label(vbox, "A new best!", 17, Color(0.7, 1.0, 0.7, 1.0))
	_add_result_label(vbox, "Click anywhere to head back", 15, Color(0.6, 0.66, 0.78, 1.0))


func _add_result_label(parent: VBoxContainer, text: String, size: int, color: Color) -> void:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
