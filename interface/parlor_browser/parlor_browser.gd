## THE PARLOR TABLE BROWSER — the YPP-style lobby that replaces the old mode-cramming LobbyModal.
## A tabbed window (one tab per parlor game) listing the ACTIVE tables in the room: each row shows
## who's seated + their standing + the stakes + the open seat, with Join / Create-a-table. You scan
## it like walking into a busy parlor and pick a seat — instead of filling out a config form.
##
## Opened from any parlor table prop (ParlorTable.interact), focused on that game's tab. It launches
## the chosen game through THAT game's prop (ParlorTable.launch_table) so the buy-in, return-anchor,
## and PlayerState handoff stay in one tested place. Single-player today (NPC-hosted tables);
## CO-OP-READY — a real player's seat slots into the same {name, color, standing} row model later.
## See [[parlor-social-system]] + [[multiplayer-direction]].
class_name ParlorBrowser
extends CanvasLayer


## Emitted on Leave / dismiss (so the launching prop can drop its open-guard).
signal cancelled


## Tier names + colours mirrored EXACTLY from the Profile/Standings tab (profile_panel.gd) so a
## row's "Master" badge renders the same purple there and here (index-aligned to MASTERY_TIERS).
const TIER_NAMES : Array[String] = ["Greenhorn", "Hand", "Adept", "Master", "Ace", "Legend"]
const TIER_COLORS : Array[Color] = [
	Color(0.55, 0.50, 0.44),   # Greenhorn
	Color(0.50, 0.62, 0.40),   # Hand
	Color(0.38, 0.60, 0.74),   # Adept
	Color(0.58, 0.42, 0.74),   # Master
	Color(0.88, 0.56, 0.22),   # Ace
	Color(0.90, 0.32, 0.36),   # Legend
]
## Rapport with the host needed to take the open seat (mirrors ParlorTable.JOIN_AFFINITY_MIN — kept
## as a raw int because the gate sits inside the Stranger tier).
const JOIN_AFFINITY_MIN : int = 10
## How many NPC tables to roll per game tab.
const MIN_TABLES : int = 2
const MAX_TABLES : int = 3


# Per-game descriptor: parlor_config() (id/name/min_seats/max_seats/cash_cost/cash_note/charges_buy_in)
# + "prop" (the ParlorTable that launches it).
var _games : Array = []
var _focused_id : String = ""
var _active : Dictionary = {}
# game_id -> Array of table rows: {npcs:Array[NpcPersonality] (host = [0]), seats:int, free:bool,
# watchers:int}. Cached so re-tabbing is stable (the room doesn't reshuffle as you browse).
var _rows : Dictionary = {}
# Create sub-panel state.
var _creating : bool = false
var _create_seats : int = 2
var _create_free : bool = false
var _create_locked_free : bool = false
# Poker-only create config (the YPP "configure bet structure / stake / turn time"); ignored otherwise.
var _create_structure : int = PokerConfig.BetStructure.NO_LIMIT
var _create_min_bet : int = PokerConfig.STAKE_MIN_BETS[0]
var _create_turn_time : int = PokerConfig.DEFAULT_TURN_TIME

var _tab_row : HBoxContainer
var _body : VBoxContainer


static func create(props: Array, focused_id: String) -> ParlorBrowser:

	var b : ParlorBrowser = ParlorBrowser.new()
	b._focused_id = focused_id
	b._ingest(props)
	return b


# Build the per-game descriptors from the parlor-table props (one tab per distinct game id).
func _ingest(props: Array) -> void:

	var seen : Dictionary = {}
	for p in props:
		if not (p is ParlorTable):
			continue
		var cfg : Dictionary = (p as ParlorTable).parlor_config()
		var gid : String = String(cfg.get("id", ""))
		if gid.is_empty() or seen.has(gid):
			continue
		seen[gid] = true
		cfg["prop"] = p
		_games.append(cfg)
	_games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]) < String(b["name"]))


func _ready() -> void:

	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_active = _game_by_id(_focused_id)
	if _active.is_empty() and not _games.is_empty():
		_active = _games[0]
	_sync_create_defaults()
	_build_chrome()
	_render()
	get_tree().paused = true


func _exit_tree() -> void:

	if get_tree() != null:
		get_tree().paused = false


func _game_by_id(id: String) -> Dictionary:

	for g in _games:
		if String(g["id"]) == id:
			return g
	return {}


# --- Chrome (built once) ----------------------------------------------

func _build_chrome() -> void:

	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.58)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380.0
	panel.offset_top = -290.0
	panel.offset_right = 380.0
	panel.offset_bottom = 290.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var col : VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title_text : String = "PARLOR TABLES"
	if _games.size() == 1 and not _active.is_empty():
		title_text = "%s TABLES" % String(_active["name"]).to_upper()
	col.add_child(_make_title(title_text))
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", 8)
	_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_tab_row)
	col.add_child(_hsep())
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	col.add_child(_hsep())
	var leave : Button = _make_button("Leave", Color(0.95, 0.84, 0.56, 1.0))
	leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave.pressed.connect(_on_leave)
	col.add_child(leave)


# --- Render -----------------------------------------------------------

func _render() -> void:

	_render_tabs()
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	if _games.is_empty():
		_body.add_child(_make_caption("No parlor tables here."))
		return
	# No more browsing a list of NPC-hosted tables (it read as a cluttered mess) — the lobby opens
	# straight to setting up YOUR OWN table; you pick a seat + invite folk at the felt. See [[parlor-social-system]].
	_build_create_panel()


func _render_tabs() -> void:

	for c in _tab_row.get_children():
		_tab_row.remove_child(c)
		c.queue_free()
	if _games.size() <= 1:
		return   # single-game browser (opened from one table) — no tab bar needed
	for g in _games:
		var is_active : bool = String(g["id"]) == String(_active.get("id", ""))
		var btn : Button = _make_button(String(g["name"]),
			Color(0.98, 0.90, 0.55, 1.0) if is_active else Color(0.74, 0.72, 0.66, 1.0))
		btn.disabled = is_active
		btn.pressed.connect(_on_tab.bind(g))
		_tab_row.add_child(btn)


func _build_table_list() -> void:

	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	var list : VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 9)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for row in _rows_for(String(_active["id"])):
		list.add_child(_make_table_row(row))

	var create_btn : Button = _make_button("＋  Create your own table", Color(0.80, 1.0, 0.66, 1.0))
	create_btn.pressed.connect(_on_create_pressed)
	_body.add_child(create_btn)


# --- Table rows -------------------------------------------------------

# Lazily roll + cache this game's active tables (stable across re-tabbing this session).
func _rows_for(game_id: String) -> Array:

	if not _rows.has(game_id):
		_rows[game_id] = _generate_tables(_game_by_id(game_id))
	return _rows[game_id]


# Roll a handful of NPC-hosted tables for a game. Seeds the first row from the prop's world-hosted
# table (so it matches the floating host badge), then rolls a few more with distinct hosts, and
# GUARANTEES at least one FREE table so a broke / low-rapport player is never blocked.
func _generate_tables(game: Dictionary) -> Array:

	if game.is_empty():
		return []
	var out : Array = []
	var exclude_base : Array[NpcPersonality] = NpcRegistry.profiles_from_paths(
		PlayerState.last_lobby_seated_paths)
	var used_hosts : Array[NpcPersonality] = []
	var seeded : Dictionary = (game["prop"] as ParlorTable).hosted_table()
	var min_seats : int = int(game["min_seats"])
	var max_seats : int = int(game["max_seats"])
	var count : int = randi_range(MIN_TABLES, MAX_TABLES)
	var any_free : bool = false

	for i in count:
		var npcs : Array[NpcPersonality] = []
		var seats : int = randi_range(min_seats, max_seats)
		if i == 0 and not seeded.is_empty():
			# Match the world's floating host badge for this prop's game.
			for p in (seeded["seated"] as Array):
				if p is NpcPersonality:
					npcs.append(p)
			seats = maxi(npcs.size() + 1, min_seats)
		else:
			var excl : Array[NpcPersonality] = exclude_base.duplicate()
			excl.append_array(used_hosts)
			npcs = NpcRegistry.pick_for_lobby(seats - 1, PlayerState.get_affinity, excl)
		if npcs.is_empty():
			continue
		used_hosts.append(npcs[0])
		var free : bool = randf() < 0.4
		any_free = any_free or free
		var total_seats : int = maxi(seats, npcs.size() + 1)
		# Poker rows carry a stake/structure config (a real table you join AT that stake); other games
		# don't need one.
		var cfg : Dictionary = {}
		if String(game["id"]) == "poker":
			cfg = {"structure": randi() % 3, "min_bet": _weighted_stake(),
				"seats": total_seats, "turn_time": PokerConfig.DEFAULT_TURN_TIME}
		out.append({"npcs": npcs, "seats": total_seats, "free": free,
			"watchers": randi_range(0, 4), "config": cfg})
	# Guarantee a free table exists (the always-open seat).
	if not out.is_empty() and not any_free:
		out[out.size() - 1]["free"] = true
	return out


func _make_table_row(row: Dictionary) -> Control:

	var npcs : Array = row["npcs"]
	var host : NpcPersonality = npcs[0] if not npcs.is_empty() else null
	var seats : int = int(row["seats"])
	var free : bool = bool(row["free"])
	var gid : String = String(_active["id"])
	var cfg : Dictionary = row.get("config", {})
	var is_poker : bool = gid == "poker"
	# Poker is affordable if you can cover the MIN buy-in for that table's stake (the buy-in itself is
	# chosen at the felt); other charged games gate on their flat cost.
	var min_buy : int = PokerConfig.buy_in_min(int(cfg.get("min_bet", 2))) if is_poker else 0
	var host_aff : int = PlayerState.get_affinity(host.npc_name) if host != null else 0
	# A FREE table is open seating — anyone can pull up a stool (so the guaranteed free row is always
	# joinable, never an all-locked screen). Cash tables still want rapport with the host.
	var can_join : bool = free or host_aff >= JOIN_AFFINITY_MIN
	var afford_cost : int = min_buy if is_poker else int(_active["cash_cost"])
	var affordable : bool = free or (not is_poker and not bool(_active["charges_buy_in"])) \
		or PlayerState.total_coins >= afford_cost
	var open_seats : int = maxi(seats - npcs.size(), 0)

	var rowp : PanelContainer = PanelContainer.new()
	rowp.add_theme_stylebox_override("panel", _row_style())
	var hb : HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	rowp.add_child(hb)

	# Left: host (standing badge + name), co-seated pips, stake + watchers.
	var info : VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hb.add_child(info)

	var head : HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	if host != null:
		# The host's parlor STANDING (a derived rank, YPP-style) + their name. Rapport isn't shown
		# here — it's expressed only through the Join gate, so the row reads one clear axis.
		head.add_child(_make_tier_pill(NpcRegistry.parlor_tier(host, gid)))
		head.add_child(_make_seat_name(host.npc_name, host.portrait_color, 18))
	info.add_child(head)

	if npcs.size() > 1:
		var pips : HBoxContainer = HBoxContainer.new()
		pips.add_theme_constant_override("separation", 6)
		var withlbl : Label = _make_caption("with")
		pips.add_child(withlbl)
		for i in range(1, npcs.size()):
			pips.add_child(_make_seat_name((npcs[i] as NpcPersonality).npc_name,
				(npcs[i] as NpcPersonality).portrait_color, 14))
		info.add_child(pips)

	var stake_txt : String
	if free:
		stake_txt = "Free table — just for fun"
	elif is_poker and not cfg.is_empty():
		stake_txt = PokerConfig.describe(cfg)
	elif not String(_active["cash_note"]).is_empty():
		stake_txt = String(_active["cash_note"])
	else:
		stake_txt = "Cash table"
	info.add_child(_make_caption("%s   ·   Watchers: %d" % [stake_txt, int(row["watchers"])]))

	# Right: seats + the Join action (gated by rapport, then affordability — never a dead end since
	# every tab also offers Create + a guaranteed free table).
	var right : VBoxContainer = VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 4)
	hb.add_child(right)
	var open_txt : String = ("%d open" % open_seats) if open_seats > 0 else "full"
	var seat_lbl : Label = _make_caption("%d / %d  ·  %s" % [npcs.size(), seats, open_txt])
	seat_lbl.add_theme_color_override("font_color", Color(0.92, 0.86, 0.62, 1.0))
	right.add_child(seat_lbl)

	if not can_join:
		var btn : Button = _make_button("Regulars only", Color(0.88, 0.66, 0.58, 1.0))
		btn.disabled = true
		right.add_child(btn)
	elif not affordable:
		var btn : Button = _make_button("Need %dg" % afford_cost, Color(0.88, 0.66, 0.58, 1.0))
		btn.disabled = true
		right.add_child(btn)
	else:
		var btn : Button = _make_button("Join  ▸", Color(0.80, 1.0, 0.62, 1.0))
		btn.pressed.connect(_on_join.bind(row))
		right.add_child(btn)
	return rowp


# --- Create sub-panel -------------------------------------------------

func _build_create_panel() -> void:

	var g : Dictionary = _active
	_body.add_child(_make_subtitle("HOST A %s TABLE" % String(g["name"]).to_upper()))

	var min_s : int = int(g["min_seats"])
	var max_s : int = int(g["max_seats"])
	# Poker fills its open chairs by INVITING the cast in-scene, so it can't exceed 1 human + the cast
	# (= 9) — cap the picker so you can never host a table with a permanently-unfillable chair. (Real
	# "friends" over multiplayer can fill more, later.)
	if _is_poker():
		max_s = mini(max_s, 1 + NpcRegistry.all().size())
	if max_s > min_s:
		var seat_items : Array = []
		for n in range(min_s, max_s + 1):
			seat_items.append("%d players" % n)
		_body.add_child(_make_dropdown("Players", seat_items, _create_seats - min_s, _on_pick_seats.bind(min_s)))
	else:
		_body.add_child(_make_caption("%d players (heads-up)" % min_s))

	# Poker: configure the bet structure + stake (which sets blinds + buy-in range), each a DROPDOWN.
	# Other games have no extra config.
	if _is_poker():
		var struct_items : Array = []
		for s in 3:
			struct_items.append(PokerConfig.structure_name(s))
		_body.add_child(_make_dropdown("Bet structure", struct_items, _create_structure, _on_pick_structure))
		var stake_items : Array = []
		for mb in PokerConfig.STAKE_MIN_BETS:
			stake_items.append("min %d  ·  blinds %d/%d  ·  buy-in %d–%dg" % [
				mb, PokerConfig.small_blind(mb), PokerConfig.big_blind(mb),
				PokerConfig.buy_in_min(mb), PokerConfig.buy_in_max(mb)])
		var stake_idx : int = PokerConfig.STAKE_MIN_BETS.find(_create_min_bet)
		_body.add_child(_make_dropdown("Stake", stake_items, maxi(stake_idx, 0), _on_pick_stake))

	var free_check : CheckButton = CheckButton.new()
	free_check.text = "Free table — learn the ropes (no gold at stake)"
	free_check.button_pressed = _create_free
	free_check.disabled = _create_locked_free
	free_check.focus_mode = Control.FOCUS_NONE
	free_check.add_theme_font_size_override("font_size", 18)
	free_check.add_theme_color_override("font_color", Color(0.95, 0.88, 0.66, 1.0))
	free_check.toggled.connect(_on_create_free_toggled)
	_body.add_child(free_check)

	var note : String
	if _create_free:
		note = "No gold for the buy-in — playing free. No gold won or lost, just rapport." \
			if _create_locked_free else "Free table — no gold won or lost, just rapport."
	elif _is_poker():
		note = "Cash table — you'll buy in %d–%d gold when you sit." % [
			PokerConfig.buy_in_min(_create_min_bet), PokerConfig.buy_in_max(_create_min_bet)]
	else:
		note = "Cash table — %s." % String(g["cash_note"])
	_body.add_child(_make_caption(note))

	_body.add_child(_spacer(8))
	var btn_row : HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(btn_row)
	var sit : Button = _make_button("Sit down  ▸", Color(0.78, 1.0, 0.62, 1.0))
	sit.pressed.connect(_on_create_sit)
	btn_row.add_child(sit)


# Default the create panel to a full table at the chosen game's stake (forced free if you can't
# afford the buy-in — play is never blocked).
func _sync_create_defaults() -> void:

	if _active.is_empty():
		return
	# Default poker to a comfortable 6-seat table (not the 10-max — only the 8-cast can fill, and a
	# packed ring crowds the felt); other games default to their max.
	var default_seats : int = 6 if _is_poker() else int(_active["max_seats"])
	_create_seats = clampi(default_seats, int(_active["min_seats"]), int(_active["max_seats"]))
	if _is_poker():
		# Poker is force-free only if you can't cover the lowest buy-in for the chosen stake.
		_create_locked_free = PlayerState.total_coins < PokerConfig.buy_in_min(_create_min_bet)
	else:
		_create_locked_free = bool(_active["charges_buy_in"]) \
			and PlayerState.total_coins < int(_active["cash_cost"])
	_create_free = _create_locked_free


# --- Handlers ---------------------------------------------------------

func _on_tab(game: Dictionary) -> void:

	_active = game
	_creating = false
	_sync_create_defaults()
	_render()


func _on_create_pressed() -> void:

	_creating = true
	_sync_create_defaults()
	_render()


func _on_create_back() -> void:

	_creating = false
	_render()


func _on_pick_seats(idx: int, min_s: int) -> void:

	_create_seats = clampi(min_s + idx, int(_active["min_seats"]), int(_active["max_seats"]))
	_render()


func _on_create_free_toggled(pressed: bool) -> void:

	if _create_locked_free:
		return
	_create_free = pressed
	_render()


# A labelled DROPDOWN (OptionButton) for a config picker — a label + a styled selector listing every
# option at once (no more click-to-cycle). `on_sel` receives the chosen item index.
func _make_dropdown(label_text: String, items: Array, selected: int, on_sel: Callable) -> Control:

	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var lbl : Label = _make_caption("%s:" % label_text)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.86, 0.62, 1.0))
	row.add_child(lbl)
	var opt : OptionButton = OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	for it in items:
		opt.add_item(String(it))
	if items.size() > 0:
		opt.selected = clampi(selected, 0, items.size() - 1)
	opt.item_selected.connect(on_sel)
	_style_option_button(opt)
	row.add_child(opt)
	return row


# Brass/dark theme for an OptionButton + its drop-down popup, to match the parlor panel.
func _style_option_button(opt: OptionButton) -> void:

	opt.add_theme_font_size_override("font_size", 17)
	opt.add_theme_color_override("font_color", Color(0.96, 0.90, 0.66, 1.0))
	opt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	opt.add_theme_constant_override("outline_size", 3)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
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
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		opt.add_theme_stylebox_override(state, s)
	var popup : PopupMenu = opt.get_popup()
	var panel : StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.16, 0.10, 0.05, 0.99)
	panel.border_color = Color(0.78, 0.58, 0.24, 1.0)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(6)
	popup.add_theme_stylebox_override("panel", panel)
	popup.add_theme_color_override("font_color", Color(0.90, 0.84, 0.62, 1.0))
	popup.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.6, 1.0))
	popup.add_theme_font_size_override("font_size", 16)
	var hov : StyleBoxFlat = StyleBoxFlat.new()
	hov.bg_color = Color(0.30, 0.20, 0.10, 1.0)
	hov.set_corner_radius_all(6)
	popup.add_theme_stylebox_override("hover", hov)


func _on_pick_structure(idx: int) -> void:

	_create_structure = clampi(idx, 0, 2)
	_render()


func _on_pick_stake(idx: int) -> void:

	_create_min_bet = PokerConfig.STAKE_MIN_BETS[clampi(idx, 0, PokerConfig.STAKE_MIN_BETS.size() - 1)]
	# A higher stake may price you out of a cash buy-in — re-check the force-free lock.
	_create_locked_free = PlayerState.total_coins < PokerConfig.buy_in_min(_create_min_bet)
	if _create_locked_free:
		_create_free = true
	_render()


func _on_create_sit() -> void:

	# Poker now seats AT THE FELT (pick a chair + invite folk) — launch with NO opponents. Other games
	# still auto-seat their AI here.
	var opponents : Array[NpcPersonality] = []
	if not _is_poker():
		opponents = NpcRegistry.pick_for_lobby(
			_create_seats - 1, PlayerState.get_affinity,
			NpcRegistry.profiles_from_paths(PlayerState.last_lobby_seated_paths))
	_launch(_active, _paths_of(opponents), _create_free, _create_poker_config())


func _on_join(row: Dictionary) -> void:

	_launch(_active, _paths_of(row["npcs"]), bool(row["free"]), row.get("config", {}))


func _is_poker() -> bool:

	return String(_active.get("id", "")) == "poker"


# The poker table config from the create-panel pickers (empty for non-poker games).
func _create_poker_config() -> Dictionary:

	if not _is_poker():
		return {}
	return PokerConfig.normalize({
		"structure": _create_structure,
		"min_bet": _create_min_bet,
		"seats": _create_seats,
		"turn_time": _create_turn_time,
	})


# A weighted random stake for a generated NPC poker table — mostly low, rarely high.
func _weighted_stake() -> int:

	var r : float = randf()
	if r < 0.6:
		return PokerConfig.STAKE_MIN_BETS[0]
	if r < 0.9:
		return PokerConfig.STAKE_MIN_BETS[1]
	return PokerConfig.STAKE_MIN_BETS[2]


func _on_leave() -> void:

	_close(true)


func _on_dim_input(event: InputEvent) -> void:

	if event is InputEventMouseButton and event.pressed:
		_close(true)


# Hand the chosen opponents + stake to the game's OWN prop (so its buy-in + return-anchor are right),
# unpausing first so the launched scene isn't frozen.
func _launch(game: Dictionary, paths: Array, free: bool, config: Dictionary = {}) -> void:

	if game.is_empty():
		return
	if get_tree() != null:
		get_tree().paused = false
	(game["prop"] as ParlorTable).launch_table(paths, free, config)
	queue_free()


func _close(emit_cancel: bool) -> void:

	if get_tree() != null:
		get_tree().paused = false
	if emit_cancel:
		cancelled.emit()
	queue_free()


func _paths_of(profiles: Array) -> Array:

	var out : Array = []
	for p in profiles:
		if p is NpcPersonality and not String((p as NpcPersonality).resource_path).is_empty():
			out.append((p as NpcPersonality).resource_path)
	return out


# --- Styling (cloned from the retired lobby so the modals match) ------

func _make_tier_pill(tier_idx: int) -> Control:

	var idx : int = clampi(tier_idx, 0, TIER_NAMES.size() - 1)
	var pill : PanelContainer = PanelContainer.new()
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = TIER_COLORS[idx].darkened(0.15)
	s.set_corner_radius_all(7)
	s.content_margin_left = 9
	s.content_margin_right = 9
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", s)
	var l : Label = Label.new()
	l.text = TIER_NAMES[idx]
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.06, 0.05, 0.04, 1.0))
	pill.add_child(l)
	return pill


func _make_seat_name(full_name: String, color: Color, size: int) -> Label:

	var l : Label = Label.new()
	l.text = full_name
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color.lightened(0.35))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	return l


func _make_title(text: String) -> Label:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _make_subtitle(text: String) -> Label:

	var l : Label = _make_title(text)
	l.add_theme_font_size_override("font_size", 22)
	return l


func _make_caption(text: String) -> Label:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.80, 0.84, 0.92, 1.0))
	return l


func _hsep() -> HSeparator:

	var sep : HSeparator = HSeparator.new()
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.78, 0.58, 0.24, 0.4)
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", s)
	return sep


func _spacer(h: float) -> Control:

	var c : Control = Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	return c


func _panel_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.11, 0.06, 0.97)
	s.border_color = Color(0.78, 0.58, 0.24, 1.0)
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 22
	s.content_margin_bottom = 22
	return s


func _row_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.13, 0.08, 0.04, 0.92)
	s.border_color = Color(0.5, 0.36, 0.18, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(9)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	return s


func _make_button(text: String, font_color: Color) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 18)
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
		s.set_border_width_all(2)
		s.set_corner_radius_all(8)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 7
		s.content_margin_bottom = 7
		btn.add_theme_stylebox_override(state, s)
	return btn
