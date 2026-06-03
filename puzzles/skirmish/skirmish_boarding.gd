## SKIRMISH BOARDING — the CREW-vs-CREW team fight ([[seabattle-research]]): your
## side (YOU + AI mates) versus an enemy crew, every combatant on their own
## [SkirmishBoard]. You play YOUR full-size board in the CENTRE and SEE the rest as
## thumbnails — your crew down the LEFT, the foes down the RIGHT. Clearing lines mails
## garbage to the foe you've TARGETED (click a foe board, or [A]/[D]). The boarding
## ends when one whole side is topped out — last crew standing wins. Reuses the duel's
## engine (board / [SkirmishAI] / [SkirmishWeapon]) unchanged.
##
## Scales to ANY crew sizes: each side is a windowed COLUMN showing up to
## VISIBLE_PER_COL fighters at an adaptive scale; bigger crews SCROLL (▲/▼ buttons +
## [A]/[D] moves your target and auto-scrolls it into view) — the YPP roster. Runs
## standalone (test the .tscn) and as the VOYAGE boarding (the ship deck launches it);
## the 1v1 skirmish_duel stays the Spar's friendly match. See [[combat-puzzle-direction]].
extends PuzzleScene


const PORTRAIT_SCENE : PackedScene = preload("res://components/portrait/portrait.tscn")


# --- Difficulty / garbage (mirrors the duel; playtest-tunable) ---------
const THINK_FAST : float = 0.45
const THINK_SLOW : float = 0.80
const BASE_BLUNDER : float = 0.30
const GARBAGE_FOR_LINES : Array[int] = [0, 1, 2, 4, 6]
## AI garbage is scaled by aggression + capped (no instant-KO spike); the PLAYER's
## is never scaled — same as the duel.
const AI_GARBAGE_BASE : float = 0.55
const MAX_GARBAGE_ROWS : int = 4
const LINES_SENT_BONUS : int = 50
const WIN_BONUS : int = 1000

## Default crew sizes (you + ALLY_COUNT mates vs FOE_COUNT foes). Tunable — the layout
## adapts to any sizes. 3 + 4 = a 4-a-side brawl where the foe column scrolls.
const ALLY_COUNT : int = 3
const FOE_COUNT : int = 4
## Up to this many thumbnails show per side at once; a bigger crew scrolls.
const VISIBLE_PER_COL : int = 3

## Column geometry. Every board's TOP aligns at BOARD_TOP_Y and stacks DOWN. Each crew
## column has a CENTRE line, COL_INSET in from its screen edge (symmetric about centre);
## boards AND their headers centre on that line, so a long name + dots never runs off
## the edge. The thumbnail SCALE is derived so VISIBLE_PER_COL fit between the top and
## COLUMN_BOTTOM (2-a-side look big, a packed roster shrinks). Your centre board is full.
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

## The enemy crew is GENERIC (sky-brigands / marines you're plundering), NOT the friendly cast —
## red names + menacing tints make "these are opponents" read instantly (YPP-style). Allies still
## come from the real cast (they're your jobbed crew).
const BRIGAND_NAMES : Array = [
	"Stormy Brigand", "Raging Brigandor", "Grim Marauder", "Black-Hearted Corsair",
	"Snarling Reaver", "Vile Cutthroat", "Rotten Knave", "Wretched Buccaneer",
	"Iron-Fanged Marine", "Bristling Privateer", "Scarred Rogue", "Ill-Tempered Swab",
]
const FOE_TINTS : Array = [
	Color(0.62, 0.20, 0.20, 1.0),   # blood red
	Color(0.45, 0.16, 0.22, 1.0),   # dark maroon
	Color(0.34, 0.30, 0.34, 1.0),   # ashen grey
	Color(0.30, 0.36, 0.24, 1.0),   # sickly olive
	Color(0.50, 0.28, 0.14, 1.0),   # rust
	Color(0.26, 0.22, 0.34, 1.0),   # bruise purple
]
const FOE_WEAPONS : Array = ["brawl", "sword", "long_range"]


## One fighter in the boarding: a board + its identity/AI state + who it attacks.
## (An inner class with no `extends` defaults to RefCounted.)
class Combatant:
	var board : SkirmishBoard
	var cname : String = "?"
	var weapon : String = "brawl"
	var color : Color = Color(0.92, 0.44, 0.40, 1.0)  # weapon colour (opaque)
	var portrait : Color = Color(0.6, 0.6, 0.65, 1.0)
	var skill : float = 0.5
	var aggr : float = 0.5
	var is_player : bool = false
	var enemy : bool = false           # true = the opposing crew
	var alive : bool = true
	var think_t : float = -1.0         # AI piece-place countdown (-1 = idle)
	var sent : int = 0
	var target : Combatant = null      # who this fighter mails garbage to
	# UI refs (built in _build_header, positioned in _layout)
	var header : Control
	var name_label : Label
	var dots_box : HBoxContainer
	var dot_count : int = 0            # live attacker dots (for centring the header)
	var move_tween : Tween            # active slide (defeated-shuffle); killed before a new one


var _combatants : Array = []
var _player : Combatant
var _over : bool = false
var _ui : CanvasLayer
## This fight's shuffled generic foe names + the next-foe index (so a boarding never repeats one).
var _foe_names : Array = []
var _foe_i : int = 0

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
	_build_combatants()
	for c in _combatants:
		add_child(c.board)
	_build_ui()
	_layout()
	for c in _combatants:
		c.board.lines_cleared.connect(_on_cleared.bind(c))
		c.board.game_over.connect(_on_ko.bind(c))
		if not c.is_player:
			c.board.piece_spawned.connect(_on_ai_spawned.bind(c))
	_init_targets()
	_update_highlight()
	_refresh_dots()
	_update_scroll_ui()
	# Each AI's FIRST piece spawned during its board's _ready (before we connected
	# piece_spawned), so wake the bots for it now — same as the duel.
	for c in _combatants:
		if not c.is_player:
			_on_ai_spawned(c)
	_apply_voyage_footing()


# Voyage "arrival footing": a strong Loft run pre-buries the brigand crew. The deck
# seeds PlayerState.voyage_boarding_seed (capped) from your lift; we spread that many
# garbage clumps across the foes. Harmless standalone (the seed is 0).
func _apply_voyage_footing() -> void:

	var clumps : int = PlayerState.voyage_boarding_seed
	PlayerState.voyage_boarding_seed = 0
	if clumps <= 0:
		return
	var foes : Array = _alive(true)
	if foes.is_empty():
		return
	for i in clumps:
		var foe : Combatant = foes[i % foes.size()]
		var atk : Dictionary = SkirmishWeapon.make_attack("brawl", 4, foe.board)
		foe.board.receive_attack(atk["shape"], atk["col"], atk["color"])


# --- Setup -------------------------------------------------------------

func _build_combatants() -> void:

	_combatants = []
	_player = Combatant.new()
	_player.board = SkirmishBoard.new()
	_player.is_player = true
	_player.cname = "You"
	_player.portrait = Color(0.95, 0.78, 0.34, 1.0)
	_player.weapon = PlayerState.equipped_weapon   # what you've equipped in the inventory
	_player.color = SkirmishWeapon.color_for(_player.weapon)
	_combatants.append(_player)

	# ALLIES = your jobbed crew, from the real cast. FOES = generic sky-brigands / marines.
	var cast : Array = NpcRegistry.all().duplicate()
	cast.shuffle()
	_foe_names = BRIGAND_NAMES.duplicate()
	_foe_names.shuffle()
	_foe_i = 0
	var ci : int = 0
	for _a in ALLY_COUNT:
		_combatants.append(_make_ai(cast[ci] if ci < cast.size() else null, false))
		ci += 1
	for _f in FOE_COUNT:
		_combatants.append(_make_ai(null, true))   # generic brigands — NOT the friendly cast


func _make_ai(profile: NpcPersonality, enemy: bool) -> Combatant:

	var c : Combatant = Combatant.new()
	c.board = SkirmishBoard.new()
	c.enemy = enemy
	if enemy:
		# A GENERIC opponent (red name via NAME_FOE) — a sky-brigand or marine, not the cast.
		c.cname = String(_foe_names[_foe_i % _foe_names.size()]) if not _foe_names.is_empty() else "Brigand"
		c.portrait = FOE_TINTS[_foe_i % FOE_TINTS.size()]
		c.skill = randf_range(0.30, 0.70)
		c.aggr = randf_range(0.45, 0.80)
		c.weapon = String(FOE_WEAPONS[randi() % FOE_WEAPONS.size()])
		_foe_i += 1
	elif profile != null:
		c.cname = profile.npc_name
		c.portrait = profile.portrait_color
		# search_depth 1..5 → skill 0..1 (cast runs 2..4); aggression drives garbage.
		c.skill = clampf(float(profile.search_depth - 1) / 4.0, 0.0, 1.0)
		c.aggr = clampf(profile.aggression, 0.0, 1.0)
		var w : String = profile.skirmish_weapon
		c.weapon = w if not w.is_empty() else "brawl"
	else:
		c.cname = "Mate"
	c.color = SkirmishWeapon.color_for(c.weapon)
	c.board.set_ai_controlled(true, c.skill)
	c.board.set_show_preview(false)   # thumbnails drop the next-piece box (cleaner/narrower)
	return c


# --- Layout: player centre, windowed crew columns ---------------------

func _layout() -> void:

	var vp : Vector2 = get_viewport().get_visible_rect().size
	var field_w : float = float(SkirmishBoard.COLS * SkirmishBoard.CELL)
	# Centre the player's whole BLOCK (field + next-piece box) so the crew columns,
	# placed at equal side margins, leave equal gaps on both sides of you.
	var preview_w : float = 4.0 * float(SkirmishBoard.CELL) * 0.82 + 24.0
	var block_w : float = field_w + 22.0 + preview_w
	_player.board.scale = Vector2.ONE
	_player.board.position = Vector2(round((vp.x - block_w) * 0.5), BOARD_TOP_Y)
	_thumb_scale = _compute_thumb_scale()
	# Scroll-control rows, centred above each column's centre line.
	var ctrl_y : float = BOARD_TOP_Y - THUMB_HEADER_H - CTRL_ROW_H - 6.0
	if _ally_ctrl != null:
		_ally_ctrl.position = Vector2(COL_INSET - 52.0, ctrl_y)
	if _foe_ctrl != null:
		_foe_ctrl.position = Vector2(vp.x - COL_INSET - 52.0, ctrl_y)
	_relayout_columns()
	_position_header(_player)


# One scale so VISIBLE_PER_COL thumbnails (of the larger crew) fill a column top-to-
# bottom — fewer fighters ⇒ bigger boards; a packed roster ⇒ smaller, scrollable ones.
func _compute_thumb_scale() -> float:

	var field_h : float = float(SkirmishBoard.ROWS * SkirmishBoard.CELL)
	var max_count : int = maxi(_members(false).size(), _members(true).size())
	var shown : int = clampi(max_count, 1, VISIBLE_PER_COL)
	var per : float = (COLUMN_BOTTOM - BOARD_TOP_Y) / float(shown)
	var s : float = (per - THUMB_HEADER_H - THUMB_GAP) / field_h
	return clampf(s, 0.22, 0.5)


func _relayout_columns(animate: bool = false) -> void:

	var vp : Vector2 = get_viewport().get_visible_rect().size
	# Board x = column centre − half a board, so boards (and their centred headers)
	# sit on the column centre line.
	var half : float = float(SkirmishBoard.COLS * SkirmishBoard.CELL) * _thumb_scale * 0.5
	_layout_column(_members(false), COL_INSET - half, _scroll_ally, animate)
	_layout_column(_members(true), vp.x - COL_INSET - half, _scroll_foe, animate)


# The non-player fighters on a side, ALIVE-FIRST then dead — so a downed fighter drops
# to the bottom of its column and the living crew stays at the top (in the window).
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


# Position the visible WINDOW [offset, offset+VISIBLE) of a column's thumbnails, TOP-
# aligned at BOARD_TOP_Y (so they line up with the player board); others are hidden.
# When [param animate], boards that stay visible SLIDE to their new slots (the
# defeated-shuffle); visibility changes + the initial layout snap.
func _layout_column(members: Array, x: float, offset: int, animate: bool = false) -> void:

	var board_h : float = float(SkirmishBoard.ROWS * SkirmishBoard.CELL) * _thumb_scale
	var slot : float = THUMB_HEADER_H + board_h + THUMB_GAP
	for i in members.size():
		var c : Combatant = members[i]
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
func _tween_member(c: Combatant, board_target: Vector2, hdr_target: Vector2) -> void:

	if c.move_tween != null and c.move_tween.is_valid():
		c.move_tween.kill()
	c.move_tween = create_tween().set_parallel(true)
	c.move_tween.tween_property(c.board, "position", board_target, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if c.header != null:
		c.move_tween.tween_property(c.header, "position", hdr_target, 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# Centre a fighter's header over its board, so a long name + dots extends both ways and
# never runs off-screen (the right-column clip Troy caught).
func _position_header(c: Combatant) -> void:

	if c.header == null:
		return
	c.header.position = _header_target(c, c.board.position)


# Where the header sits if the board were at [param board_pos] — centred on the board.
func _header_target(c: Combatant, board_pos: Vector2) -> Vector2:

	var bw : float = float(SkirmishBoard.COLS * SkirmishBoard.CELL) * c.board.scale.x
	var cx : float = board_pos.x + bw * 0.5
	return Vector2(round(cx - _header_width(c) * 0.5), board_pos.y - THUMB_HEADER_H)


# Rough header width (avatar + weapon swatch + name + live target dots) for centring.
func _header_width(c: Combatant) -> float:

	return 36.0 + float(c.cname.length()) * 8.5 + float(c.dot_count) * 12.0


func _init_targets() -> void:

	# Assign in order so each pick SEES the ones before it — spreads targets out instead
	# of the whole crew ganging the first opponent (Troy).
	for c in _combatants:
		c.target = _pick_target_for(c)


# --- Per-frame: drive the AI boards + the player's input ---------------

func _process(delta: float) -> void:

	if _over:
		return
	# AI fighters: think-then-place, each on its own randomized clock.
	for c in _combatants:
		if c.is_player or not c.alive:
			continue
		if c.think_t >= 0.0:
			c.think_t -= delta
			if c.think_t <= 0.0:
				c.think_t = -1.0
				_ai_act(c)
	# Player input (only while your own board is live).
	if not _player.alive or _player.board.is_over():
		return
	_player.board.set_soft_drop(
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
		_player.board.move(dir)
		return
	_das_timer += delta
	if not _das_charged:
		if _das_timer >= DAS_DELAY:
			_das_charged = true
			_das_timer = 0.0
			_player.board.move(dir)
	else:
		while _das_timer >= DAS_REPEAT:
			_das_timer -= DAS_REPEAT
			_player.board.move(dir)


func _unhandled_input(event: InputEvent) -> void:

	if not _over and _player.alive and not _player.board.is_over():
		if event.is_action_pressed("ui_up"):
			_player.board.rotate_cw()
			get_viewport().set_input_as_handled()
			return
	# [A]/[D] cycle your target up/down the foe roster (auto-scrolling it into view).
	if not _over and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A:
			_cycle_target(-1)
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_D:
			_cycle_target(1)
			get_viewport().set_input_as_handled()
			return
	# Click a VISIBLE board: a FOE to attack it, an ALLY to DEFEND them.
	if not _over and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		for c in _combatants:
			if c.is_player or not c.alive or not c.board.visible:
				continue
			if _board_rect(c.board).has_point(event.position):
				_set_player_target(c)
				get_viewport().set_input_as_handled()
				return
	# Otherwise defer to PuzzleScene (click-to-dismiss after the boarding ends).
	super._unhandled_input(event)


func _set_player_target(t: Combatant) -> void:

	_player.target = t
	_update_highlight()
	_refresh_dots()


# The on-screen field rect of a board (accounts for its thumbnail scale).
func _board_rect(board: SkirmishBoard) -> Rect2:

	var size : Vector2 = Vector2(SkirmishBoard.COLS * SkirmishBoard.CELL,
		SkirmishBoard.ROWS * SkirmishBoard.CELL) * board.scale
	return Rect2(board.position, size)


# --- Targeting + scrolling --------------------------------------------

# Move the player's target to the prev/next ALIVE foe and scroll it into view.
func _cycle_target(dir: int) -> void:

	var live : Array = _alive(true)
	if live.is_empty():
		return
	var idx : int = live.find(_player.target)
	if idx < 0:
		idx = 0
	else:
		idx = (idx + dir + live.size()) % live.size()
	_player.target = live[idx]
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


# --- AI placement ------------------------------------------------------

func _on_ai_spawned(c: Combatant) -> void:

	if _over or not c.alive or c.board.is_over():
		return
	c.think_t = _ai_think_time(c.skill)


func _ai_think_time(skill: float) -> float:

	var base : float = THINK_FAST + (1.0 - skill) * (THINK_SLOW - THINK_FAST)
	var spread : float = lerpf(0.25, 0.70, 1.0 - skill)
	return base * randf_range(1.0 - spread, 1.0 + spread)


func _ai_act(c: Combatant) -> void:

	if _over or c.board.is_over() or c.board.piece_type() < 0:
		return
	var grid : Array = c.board.grid_rows()
	var piece : int = c.board.piece_type()
	var pl : Dictionary
	if randf() < BASE_BLUNDER * (1.0 - c.skill):
		pl = SkirmishAI.random_placement(grid, piece)
	else:
		pl = SkirmishAI.best_placement(grid, piece, c.skill)
	c.board.ai_place(int(pl["rot"]), int(pl["px"]))


# --- Garbage routing ---------------------------------------------------

func _on_cleared(count: int, src: Combatant) -> void:

	if _over or not src.alive:
		return
	var base : int = GARBAGE_FOR_LINES[clampi(count, 0, GARBAGE_FOR_LINES.size() - 1)]
	if base <= 0:
		return
	var h : int = base
	if not src.is_player:
		# AI garbage scales with aggression + is capped, so a soft foe barely
		# pressures you and no single hit is an instant KO (comeback-friendly).
		var sc : float = AI_GARBAGE_BASE + (1.0 - AI_GARBAGE_BASE) * src.aggr
		h = clampi(roundi(float(base) * sc), 0, MAX_GARBAGE_ROWS)
	if h <= 0:
		return
	# Re-pick only if our target is gone — a SAME-SIDE target is a deliberate DEFEND
	# (player-only; the AI's _pick_target_for always returns a cross-side foe).
	if src.target == null or not src.target.alive:
		src.target = _pick_target_for(src)
	if src.target == null:
		return
	if src.target.enemy == src.enemy:
		# Defending a crewmate: spend the budget un-burying THEM instead of attacking.
		src.target.board.relieve(h)
	else:
		var atk : Dictionary = SkirmishWeapon.make_attack(src.weapon, h, src.target.board, count)
		src.target.board.receive_attack(atk["shape"], atk["col"], atk["color"], atk["decay"])
		src.sent += h


# Pick an opponent, strongly favouring the LEAST-targeted one so attackers SPREAD OUT
# (Troy: don't all gang the first foe). Mild secondary leans only break near-ties: foes
# lean toward the player, mates toward the tallest stack; jitter scatters the rest.
func _pick_target_for(src: Combatant) -> Combatant:

	var opp : Array = _alive(not src.enemy)
	if opp.is_empty():
		return null
	var best : Combatant = opp[0]
	var best_score : float = -INF
	for o in opp:
		var score : float = -1000.0 * float(_attacker_count(o)) + randf() * 20.0
		if src.enemy:
			if o.is_player:
				score += 8.0
		else:
			score += float(_stack_height(o.board))
		if score > best_score:
			best_score = score
			best = o
	return best


# How many living fighters currently aim at [param target].
func _attacker_count(target: Combatant) -> int:

	var n : int = 0
	for a in _combatants:
		if a.alive and a != target and a.target == target:
			n += 1
	return n


func _stack_height(board: SkirmishBoard) -> int:

	var g : Array = board.grid_rows()
	for r in g.size():
		for c in g[r].size():
			if int(g[r][c]) >= 0:
				return g.size() - r
	return 0


# --- KO / win ----------------------------------------------------------

func _on_ko(_score: int, c: Combatant) -> void:

	if not c.alive:
		return
	c.alive = false
	c.board.defeat()   # freeze + flood the whole stack red so it reads as down
	c.board.set_highlight(Color(0, 0, 0, 0))
	_refresh_header(c)
	_announce_defeat(c)
	# Anyone aiming at the fallen fighter re-picks a live target.
	for o in _combatants:
		if o.alive and o.target == c:
			o.target = _pick_target_for(o)
	# If the player's target fell, swing to another live foe.
	if _player.target == c:
		var live : Array = _alive(true)
		_player.target = live[0] if not live.is_empty() else null
	# The downed fighter drops to the bottom; keep your target on-screen; refresh dots
	# (header widths) BEFORE the slide, then animate everyone to their new slots.
	_scroll_to_target_offset()
	_refresh_dots()
	_relayout_columns(true)
	_update_highlight()
	_update_scroll_ui()
	# A whole side down ends the boarding.
	if _alive(true).is_empty():
		_end_boarding(true)
	elif _alive(false).is_empty():
		_end_boarding(false)


# A top-centre banner when any fighter falls — a foe down (good, green) or a mate fallen
# (bad, red) — so you KNOW who just dropped on either crew (Troy).
func _announce_defeat(c: Combatant) -> void:

	if _ui == null:
		return
	var text : String
	if c.is_player:
		text = "You're down — yer crew fights on!"
	elif c.enemy:
		text = "%s is down!" % c.cname
	else:
		text = "%s has fallen!" % c.cname
	# Foe down = good (green); a mate (or you) falling = bad (red).
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


func _end_boarding(player_won: bool) -> void:

	if _over:
		return
	_over = true
	PlayerState.last_skirmish_won = player_won
	for c in _combatants:
		c.board.stop()
	var quality : int = (_player.board.score() + _player.sent * LINES_SENT_BONUS
		+ (WIN_BONUS if player_won else 0))
	var mastery : Dictionary = PlayerState.record_puzzle_result("skirmish", quality)
	_show_results(player_won, bool(mastery.get("is_new_best", false)))
	if mastery.get("ranked_up", false):
		add_child(MasteryToast.create(String(mastery["tier_name"])))
	_set_awaiting_dismiss(true)


# --- Helpers -----------------------------------------------------------

func _alive(enemy: bool) -> Array:

	var out : Array = []
	for c in _combatants:
		if c.alive and c.enemy == enemy:
			out.append(c)
	return out


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
	# Scroll controls for any side whose crew overflows the window (positioned in
	# _layout once the column x is known).
	if _members(false).size() > VISIBLE_PER_COL:
		_build_scroll_ctrl(false)
	if _members(true).size() > VISIBLE_PER_COL:
		_build_scroll_ctrl(true)

	set_help_text("SKIRMISH — boarding (crew vs crew).\n\n"
		+ "• ←  → :  move    ↑ :  rotate    ↓ / SPACE :  soft drop\n"
		+ "• Clear lines to mail GARBAGE to the foe you've TARGETED (gold ring).\n"
		+ "• CLICK a foe, or press [A] / [D], to switch your target.\n"
		+ "• CLICK a MATE to DEFEND them (green ring) — your clears un-bury THEIR board instead.\n"
		+ "• Big crews scroll — use the ▲ ▼ by a column ([A]/[D] auto-scrolls your target in).\n"
		+ "• The dots by each fighter show how many foes are on them.\n"
		+ "• Top out a whole crew to win. Your mates fight on even if you fall.")


# A compact one-row header above a board: avatar + weapon swatch + name + target dots.
func _build_header(c: Combatant) -> void:

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


func _refresh_header(c: Combatant) -> void:

	if c.header != null:
		c.header.modulate = Color(1, 1, 1, 0.4) if not c.alive else Color(1, 1, 1, 1.0)
	if c.name_label != null:
		c.name_label.text = (c.cname + "  ✕") if not c.alive else c.cname


# A row of small dots by each fighter = how many enemies currently target them,
# each coloured by the attacker's weapon ([[seabattle-research]] target dots).
func _refresh_dots() -> void:

	for c in _combatants:
		if c.dots_box == null:
			continue
		for ch in c.dots_box.get_children():
			ch.queue_free()
		var n : int = 0
		for a in _combatants:
			# Only ENEMY attackers count as dots — a mate defending you isn't an attack.
			if a.alive and a != c and a.target == c and a.enemy != c.enemy:
				var dot : ColorRect = ColorRect.new()
				dot.custom_minimum_size = Vector2(10.0, 10.0)
				dot.color = a.color
				c.dots_box.add_child(dot)
				n += 1
		c.dot_count = n
		_position_header(c)   # re-centre — the dots changed the header's width


func _update_highlight() -> void:

	for c in _combatants:
		c.board.set_highlight(Color(0, 0, 0, 0))
	if _player.target != null and _player.target.alive:
		# Green ring when DEFENDING a mate (same side), gold when attacking a foe.
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
	_add_result_label(vbox, "Garbage sent:  %d" % _player.sent, 18, Color(0.85, 0.9, 1.0, 1.0))
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
