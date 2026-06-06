## BoardingMelee — the PERSISTENT crew-vs-crew Skirmish simulation for a voyage boarding. Autoloaded so
## the fight SURVIVES scene changes: the melee runs in the BACKGROUND (your AI mates trade blows, your
## undefended board buries itself, a whole side can wipe) whether or not the player is watching. The
## boarding SCENE (skirmish_boarding.gd) is a thin VIEW that re-parents these boards in, renders the
## chrome, and forwards the player's input here. See [[live-melee-boarding]] + [[combat-puzzle-direction]].
##
## Lifecycle: start() builds the crews ONCE + owns every board as a child; _process drives the AI +
## garbage + win every frame (PROCESS_MODE_ALWAYS, so it keeps ticking while the player is off on the
## deck); melee_resolved fires ONCE a side wipes — the VIEW shows the results if it's attached, else the
## DECK resolves the leg. last_skirmish_won is written HERE at the side-wipe, so leaving never forfeits.
extends Node


## One side is wiped — the boarding is decided. [param player_won] = the player's crew held the deck.
signal melee_resolved(player_won: bool)
## A fighter just fell (the view announces it + re-lays-out its roster). Null-safe: no view = no-op.
signal combatant_defeated(c: BoardingCombatant)
## The player's target changed (the view re-rings + re-scrolls).
signal targets_changed


# --- Difficulty / garbage (mirrors the old duel; playtest-tunable) ---------
const THINK_FAST : float = 0.45
const THINK_SLOW : float = 0.80
const BASE_BLUNDER : float = 0.30
const GARBAGE_FOR_LINES : Array[int] = [0, 1, 2, 4, 6]
const AI_GARBAGE_BASE : float = 0.55
const MAX_GARBAGE_ROWS : int = 4
const LINES_SENT_BONUS : int = 50
const WIN_BONUS : int = 1000

## Default crew sizes (you + ALLY_COUNT mates vs FOE_COUNT foes). Tunable; the view's layout adapts.
const ALLY_COUNT : int = 3
const FOE_COUNT : int = 4

## The enemy crew is GENERIC (sky-brigands / marines), NOT the friendly cast — red names + menacing
## tints make "these are opponents" read instantly. Allies are your jobbed crew (the real cast).
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


var _combatants : Array = []
var _player : BoardingCombatant
var _active : bool = false
var _over : bool = false
var _player_won : bool = false
var _player_present : bool = false
## The mastery dict from the resolving record_puzzle_result + "player_won" — read by the resolver (view
## or deck) for the results panel / toast.
var _result : Dictionary = {}
## This fight's shuffled generic foe names + the next-foe index (so a boarding never repeats one).
var _foe_names : Array = []
var _foe_i : int = 0


func _ready() -> void:

	# Run + drive the fight even while the tree is paused-for-a-pause-leak or mid-scene-swap — the melee
	# is meant to keep going while the player is off the boarding scene. (The READY beat is handled by an
	# explicit paused-check in _process so a fresh fight still freezes for the lead-in.)
	process_mode = Node.PROCESS_MODE_ALWAYS


# --- Public state ------------------------------------------------------

func has_active() -> bool:
	return _active

func is_resolved() -> bool:
	return _over

func player_won() -> bool:
	return _player_won

func player_alive() -> bool:
	return _player != null and _player.alive and is_instance_valid(_player.board) and not _player.board.is_over()

func combatants() -> Array:
	return _combatants

func player_combatant() -> BoardingCombatant:
	return _player

func last_result() -> Dictionary:
	return _result


# --- Lifecycle ---------------------------------------------------------

# Build a FRESH melee (clears any spent prior one first). The boards are created + parented under THIS
# autoload + hidden; the view re-parents them in when it opens. Footing (Loft lift pre-buries foes, hull
# holes pre-bury you) is applied here so it can't double-apply on a re-attach.
func start(ally_count: int = ALLY_COUNT, foe_count: int = FOE_COUNT) -> void:

	clear()
	_build_combatants(ally_count, foe_count)
	for c in _combatants:
		add_child(c.board)
		# PAUSABLE (not the autoload's ALWAYS): the boards FREEZE on a real pause (the fresh-fight READY
		# beat, an open backpack) but keep ticking while the player is away on the deck (tree not paused).
		c.board.process_mode = Node.PROCESS_MODE_PAUSABLE
		c.board.visible = false   # the view reveals + positions them when it attaches
	for c in _combatants:
		c.board.lines_cleared.connect(_on_cleared.bind(c))
		c.board.game_over.connect(_on_ko.bind(c))
		if not c.is_player:
			c.board.piece_spawned.connect(_on_ai_spawned.bind(c))
	_init_targets()
	# Each AI's FIRST piece spawned during its board's _ready (before we connected piece_spawned), so
	# wake the bots for it now.
	for c in _combatants:
		if not c.is_player:
			_on_ai_spawned(c)
	_apply_voyage_footing()
	_active = true
	_over = false
	_player_won = false
	_result = {}


# Tear down a spent melee — free the boards, drop the combatants. Called by start() (stale clear) + by
# the resolver after the leg's banked.
func clear() -> void:

	# Neutralize FIRST (before the deferred queue_free runs): a board that tops out in its last queued
	# frame would otherwise fire game_over → _on_ko on the emptied roster and drive a spurious resolve.
	# The handlers all bail on `not _active`, so flip it off up front.
	_active = false
	_over = false
	_player_present = false
	for c in _combatants:
		if c != null and is_instance_valid(c.board):
			c.board.queue_free()
	_combatants = []
	_player = null


# --- Setup -------------------------------------------------------------

func _build_combatants(ally_count: int, foe_count: int) -> void:

	_combatants = []
	_player = BoardingCombatant.new()
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
	for _a in ally_count:
		_combatants.append(_make_ai(cast[ci] if ci < cast.size() else null, false))
		ci += 1
	for _f in foe_count:
		_combatants.append(_make_ai(null, true))   # generic brigands — NOT the friendly cast


func _make_ai(profile: NpcPersonality, enemy: bool) -> BoardingCombatant:

	var c : BoardingCombatant = BoardingCombatant.new()
	c.board = SkirmishBoard.new()
	c.enemy = enemy
	if enemy:
		c.cname = String(_foe_names[_foe_i % _foe_names.size()]) if not _foe_names.is_empty() else "Brigand"
		c.portrait = FOE_TINTS[_foe_i % FOE_TINTS.size()]
		c.skill = randf_range(0.30, 0.70)
		c.aggr = randf_range(0.45, 0.80)
		c.weapon = String(FOE_WEAPONS[randi() % FOE_WEAPONS.size()])
		_foe_i += 1
	elif profile != null:
		c.cname = profile.npc_name
		c.portrait = profile.portrait_color
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


func _init_targets() -> void:

	# Assign in order so each pick SEES the ones before it — spreads targets out instead of the whole
	# crew ganging the first opponent.
	for c in _combatants:
		c.target = _pick_target_for(c)


# Voyage "arrival footing", two-sided: a strong Loft run pre-buries the brigand CREW (your reward),
# while a HOLED hull pre-buries your OWN board (the damaged-ship penalty). Harmless standalone (seed is
# 0 and ship condition is read only on a voyage). See [[ship-condition-research]].
func _apply_voyage_footing() -> void:

	var clumps : int = PlayerState.voyage_boarding_seed
	PlayerState.voyage_boarding_seed = 0
	var atk : Dictionary
	if clumps > 0:
		var foes : Array = _alive(true)
		if not foes.is_empty():
			for i in clumps:
				var foe : BoardingCombatant = foes[i % foes.size()]
				atk = SkirmishWeapon.make_attack("brawl", 4, foe.board)
				foe.board.receive_attack(atk["shape"], atk["col"], atk["color"])
	if PlayerState.voyage_active and _player != null:
		for _h in PlayerState.ship_open_holes():
			atk = SkirmishWeapon.make_attack("brawl", 4, _player.board)
			_player.board.receive_attack(atk["shape"], atk["col"], atk["color"])


# --- Per-frame: drive the AI boards (the player's input is pushed in by the view) -----

func _process(delta: float) -> void:

	if not _active or _over:
		return
	# Freeze during an explicit pause (the fresh-fight READY beat, or a backpack/ESC) — but keep running
	# the rest of the time, including while the player is away on the deck (the tree isn't paused then).
	if get_tree() != null and get_tree().paused:
		return
	for c in _combatants:
		if c.is_player or not c.alive:
			continue
		if c.think_t >= 0.0:
			c.think_t -= delta
			if c.think_t <= 0.0:
				c.think_t = -1.0
				_ai_act(c)


# --- AI placement ------------------------------------------------------

func _on_ai_spawned(c: BoardingCombatant) -> void:

	if _over or not c.alive or c.board.is_over():
		return
	c.think_t = _ai_think_time(c.skill)


func _ai_think_time(skill: float) -> float:

	var base : float = THINK_FAST + (1.0 - skill) * (THINK_SLOW - THINK_FAST)
	var spread : float = lerpf(0.25, 0.70, 1.0 - skill)
	return base * randf_range(1.0 - spread, 1.0 + spread)


func _ai_act(c: BoardingCombatant) -> void:

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

func _on_cleared(count: int, src: BoardingCombatant) -> void:

	if not _active or _over or not src.alive:
		return
	if src.is_player and _player_present:
		Audio.play_sfx("clack")   # your line clear — only while you're at the board, not a background tick
	var base : int = GARBAGE_FOR_LINES[clampi(count, 0, GARBAGE_FOR_LINES.size() - 1)]
	if base <= 0:
		return
	var h : int = base
	if not src.is_player:
		var sc : float = AI_GARBAGE_BASE + (1.0 - AI_GARBAGE_BASE) * src.aggr
		h = clampi(roundi(float(base) * sc), 0, MAX_GARBAGE_ROWS)
	if h <= 0:
		return
	# Re-pick only if our target is gone — a SAME-SIDE target is a deliberate DEFEND (player-only; the
	# AI's _pick_target_for always returns a cross-side foe).
	if src.target == null or not src.target.alive:
		src.target = _pick_target_for(src)
	if src.target == null:
		return
	if src.target.enemy == src.enemy:
		src.target.board.relieve(h)   # defending a crewmate — un-bury THEM
	else:
		var atk : Dictionary = SkirmishWeapon.make_attack(src.weapon, h, src.target.board, count)
		src.target.board.receive_attack(atk["shape"], atk["col"], atk["color"], atk["decay"])
		src.sent += h


# Pick an opponent, strongly favouring the LEAST-targeted one so attackers SPREAD OUT. Mild secondary
# leans only break near-ties: foes lean toward the player, mates toward the tallest stack.
func _pick_target_for(src: BoardingCombatant) -> BoardingCombatant:

	var opp : Array = _alive(not src.enemy)
	if opp.is_empty():
		return null
	var best : BoardingCombatant = opp[0]
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


func _attacker_count(target: BoardingCombatant) -> int:

	var n : int = 0
	for a in _combatants:
		if a.alive and a != target and a.target == target:
			n += 1
	return n


func _stack_height(board: SkirmishBoard) -> int:

	var g : Array = board.grid_rows()
	for r in g.size():
		for col in g[r].size():
			if int(g[r][col]) >= 0:
				return g.size() - r
	return 0


# --- KO / win ----------------------------------------------------------

func _on_ko(_score: int, c: BoardingCombatant) -> void:

	if not _active or not c.alive:
		return
	c.alive = false
	c.board.defeat()   # freeze + flood the whole stack red so it reads as down
	c.board.set_highlight(Color(0, 0, 0, 0))
	# Anyone aiming at the fallen fighter re-picks a live target.
	for o in _combatants:
		if o.alive and o.target == c:
			o.target = _pick_target_for(o)
	# If the player's target fell, swing to another live foe.
	if _player != null and _player.target == c:
		var live : Array = _alive(true)
		_player.target = live[0] if not live.is_empty() else null
	combatant_defeated.emit(c)   # the view (if attached) announces + re-lays-out the roster
	# A whole side down ends the boarding.
	if _alive(true).is_empty():
		_resolve_melee(true)
	elif _alive(false).is_empty():
		_resolve_melee(false)


# The melee is decided. Write the outcome (the central fix — last_skirmish_won is set HERE, at the
# side-wipe, regardless of where the player is), bank the run as Skirmish mastery, and fire
# melee_resolved so whoever's listening (the view if present, else the deck) resolves the voyage leg.
func _resolve_melee(won: bool) -> void:

	if not _active or _over:
		return
	_over = true
	_player_won = won
	PlayerState.last_skirmish_won = won
	for c in _combatants:
		if is_instance_valid(c.board):
			c.board.stop()
	var quality : int = 0
	if _player != null and is_instance_valid(_player.board):
		quality = _player.board.score() + _player.sent * LINES_SENT_BONUS + (WIN_BONUS if won else 0)
	_result = PlayerState.record_puzzle_result("skirmish", quality)
	_result["player_won"] = won
	melee_resolved.emit(won)


# --- Helpers -----------------------------------------------------------

func _alive(enemy: bool) -> Array:

	var out : Array = []
	for c in _combatants:
		if c.alive and c.enemy == enemy:
			out.append(c)
	return out


# --- Player input passthrough (the view forwards keystrokes here) ------

func player_move(dir: int) -> void:
	if _player_present and player_alive():
		_player.board.move(dir)


func player_rotate() -> void:
	if _player_present and player_alive():
		_player.board.rotate_cw()


func player_soft_drop(on: bool) -> void:
	if _player_present and _player != null and _player.alive and is_instance_valid(_player.board):
		_player.board.set_soft_drop(on)


# Toggle whether the player is at the controls. When false (stepped away), input is ignored + soft-drop
# released, so the undefended board falls at plain gravity and buries itself.
func set_player_present(on: bool) -> void:
	_player_present = on
	if not on and _player != null and is_instance_valid(_player.board):
		_player.board.set_soft_drop(false)


func set_player_target(t: BoardingCombatant) -> void:
	if _player == null:
		return
	_player.target = t
	targets_changed.emit()


# Move the player's target to the prev/next ALIVE foe (the view scrolls it into view on targets_changed).
func cycle_player_target(dir: int) -> void:
	if _player == null:
		return
	var live : Array = _alive(true)
	if live.is_empty():
		return
	var idx : int = live.find(_player.target)
	if idx < 0:
		idx = 0
	else:
		idx = (idx + dir + live.size()) % live.size()
	_player.target = live[idx]
	targets_changed.emit()
