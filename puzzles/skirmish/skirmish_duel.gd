## SKIRMISH DUEL — the versus match: YOUR board vs an AI opponent's, side by
## side. Clearing lines mails GARBAGE rows to the other board; topping a board
## out is the KO. The player NEVER plays Skirmish solo — this duel (challenged
## against a Cradle Rock NPC, or fought during a voyage) is the real Skirmish.
## See [[combat-puzzle-direction]] (versus-only).
##
## THIN SLICE: 1v1, no weapon classes / cancel window / teams yet. The opponent
## is a heuristic bot ([SkirmishAI]) placing one piece every AI_THINK_TIME on
## the main thread. Extends [VersusPuzzleScene] (situational-awareness hooks + talk-influence seam; open board).
extends VersusPuzzleScene


# Skirmish's YOU / foe headers sit above the boards, so the far top CORNERS are free — Leave to the top-left,
# Chat to the top-right, off the centre (Troy 2026-06-13, the red-arrow layout).
func _touch_buttons_at_corners() -> bool:
	return true


# TOUCH controls (mobile web): move + soft-drop are held, rotate is a tap. See [[touch-input-foundation]].
func _touch_spec() -> Array:
	return [
		{"label": "◄", "action": "ui_left", "hold": true, "side": "left"},
		{"label": "►", "action": "ui_right", "hold": true, "side": "left"},
		{"label": "↻", "action": "ui_up"},
		{"label": "▼", "action": "ui_down", "hold": true},
	]


const PORTRAIT_SCENE : PackedScene = preload("res://components/portrait/portrait.tscn")


const DAS_DELAY : float = 0.16
const DAS_REPEAT : float = 0.04
# --- Difficulty (scaled by the foe's NpcPersonality — see the design in
# [[combat-puzzle-direction]]; ALL of these are playtest-tunable) -------------
## A SHARP foe places a piece this fast; a WEAK foe is slowed toward THINK_SLOW.
const THINK_FAST : float = 0.45
const THINK_SLOW : float = 0.80
## Max chance (at skill 0) the foe BLUNDERS a piece to a random spot — the
## single biggest weak-foe lever. Scales with (1 - skill).
const BASE_BLUNDER : float = 0.30
## The foe's garbage = base × lerp(this, 1.0, aggression), capped at
## MAX_GARBAGE_ROWS so no single spike is an instant KO (comeback-friendly).
## The PLAYER's garbage is never scaled or capped — you chose the fight.
const AGGRESSION_GARBAGE_BASE : float = 0.50
const MAX_GARBAGE_ROWS : int = 4
## Garbage rows sent for clearing N lines (index = lines, 0..4). Tunable.
const GARBAGE_FOR_LINES : Array[int] = [0, 1, 2, 4, 6]
## Mastery (high-water-mark, so losing never lowers your rank — earn-and-keep):
## your board score + per-garbage-sent bonus + a win bonus.
const LINES_SENT_BONUS : int = 50
const WIN_BONUS : int = 1000

@onready var _player_board : SkirmishBoard = $PlayerBoard
@onready var _opponent_board : SkirmishBoard = $OpponentBoard

var _opponent_name : String = "Sparring Partner"
var _opponent_profile : NpcPersonality = null
## Derived from the foe's profile: skill (0..1 from search_depth) drives AI
## noise / blunder / pace; aggression drives their garbage output.
var _opponent_skill : float = 0.5
var _opponent_aggression : float = 0.5
## Equipped weapon — shapes the garbage you send. Unarmed = "brawl" (fists),
## the default for anyone with no weapon. The foe's comes from their NPC.
var _player_weapon : String = "brawl"
var _opponent_weapon : String = "brawl"
var _lines_sent : int = 0
var _opp_lines_sent : int = 0
var _duel_over : bool = false

var _das_dir : int = 0
var _das_timer : float = 0.0
var _das_charged : bool = false
var _ai_think_t : float = -1.0

var _you_lines_label : Label
var _opp_lines_label : Label


func _ready() -> void:

	super._ready()
	_player_weapon = PlayerState.equipped_weapon   # what you've equipped in the inventory
	_opponent_name = _resolve_opponent()
	# Chat-reachable + situationally aware foe — the poker hook in the duel too (Troy 2026-06-10). The scope
	# menu / RoomChat find them in the "npc" group; the SCENE feeds the live duel via npc_chat_context below.
	if _opponent_profile != null:
		var chat : OpponentChat = OpponentChat.new()
		add_child(chat)
		chat.setup(_opponent_profile)
		chat.position = Vector2(960.0, 70.0)   # up top, between the two boards
	_layout_boards()
	_opponent_board.set_ai_controlled(true, _opponent_skill)
	_player_board.lines_cleared.connect(_on_player_cleared)
	_opponent_board.lines_cleared.connect(_on_opponent_cleared)
	_player_board.game_over.connect(_on_player_ko)
	_opponent_board.game_over.connect(_on_opponent_ko)
	_opponent_board.piece_spawned.connect(_on_opponent_spawned)
	_build_ui()
	# The opponent's FIRST piece spawned during its own _ready (before we
	# connected to piece_spawned), so wake the bot for it now.
	_on_opponent_spawned()
	_apply_voyage_footing()
	# A "READY? → GO!" beat that freezes both boards + shows the controls before the match runs (so a
	# first-timer isn't dropped into falling blocks with the clock already going).
	add_child(ReadyOverlay.new())


# A Voyage boarding fight seeds the foe's board from the player's Loft run (the
# "arrival footing"): sail well → the brigand starts pre-buried under a clump or
# two. Capped + harmless outside a voyage (the field is 0). Touches Skirmish only
# as an external entry param. See [[loft-spec]] / [[voyage-loop-research]].
func _apply_voyage_footing() -> void:

	# Only a real voyage boarding fight seeds footing — a non-voyage Spar duel never
	# pre-buries a friendly foe with stale voyage state (mirrors skirmish_boarding).
	if not PlayerState.voyage_active:
		return
	var clumps : int = PlayerState.voyage_boarding_seed
	PlayerState.voyage_boarding_seed = 0
	for _i in clumps:
		var atk : Dictionary = SkirmishWeapon.make_attack("brawl", 4, _opponent_board)
		_opponent_board.receive_attack(atk["shape"], atk["col"], atk["color"])


func _layout_boards() -> void:

	var vp : Vector2 = get_viewport().get_visible_rect().size
	var field_w : int = SkirmishBoard.COLS * SkirmishBoard.CELL
	var field_h : int = SkirmishBoard.ROWS * SkirmishBoard.CELL
	var preview_w : int = SkirmishBoard.CELL * 4 + 16 + 22
	var board_w : int = field_w + preview_w
	var gap : int = 70
	var total : int = board_w * 2 + gap
	var top : float = round((vp.y - float(field_h)) * 0.5) + 16.0
	var left : float = round((vp.x - float(total)) * 0.5)
	_player_board.position = Vector2(left, top)
	_opponent_board.position = Vector2(left + float(board_w + gap), top)


func _process(delta: float) -> void:

	if _duel_over:
		return
	# Opponent: think-then-place.
	if _ai_think_t >= 0.0:
		_ai_think_t -= delta
		if _ai_think_t <= 0.0:
			_ai_think_t = -1.0
			_ai_act()
	# Player input (only while your board is live).
	if _player_board == null or _player_board.is_over():
		return
	_player_board.set_soft_drop(
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
		_player_board.move(dir)
		return
	_das_timer += delta
	if not _das_charged:
		if _das_timer >= DAS_DELAY:
			_das_charged = true
			_das_timer = 0.0
			_player_board.move(dir)
	else:
		while _das_timer >= DAS_REPEAT:
			_das_timer -= DAS_REPEAT
			_player_board.move(dir)


func _unhandled_input(event: InputEvent) -> void:

	if not _duel_over and _player_board != null and not _player_board.is_over():
		if event.is_action_pressed("ui_up"):
			_player_board.rotate_cw()
			get_viewport().set_input_as_handled()
			return
	# Defer to PuzzleScene for click-to-dismiss after the duel ends.
	super._unhandled_input(event)


# --- AI opponent -------------------------------------------------------

func _on_opponent_spawned() -> void:

	if _duel_over or _opponent_board.is_over():
		return
	_ai_think_t = _ai_think_time()


# Pace scales with skill: a weak foe places slower (you get breathing room). Each
# decision is RANDOMIZED around that base so the foe doesn't move like a metronome
# — sometimes it hesitates, sometimes it snaps. Weaker foes vary more (wider
# spread = more believable fumbling). See [[animate-everything-principle]].
func _ai_think_time() -> float:

	var base : float = THINK_FAST + (1.0 - _opponent_skill) * (THINK_SLOW - THINK_FAST)
	var spread : float = lerpf(0.25, 0.70, 1.0 - _opponent_skill)
	return base * randf_range(1.0 - spread, 1.0 + spread)


func _ai_act() -> void:

	if _duel_over or _opponent_board.is_over() or _opponent_board.piece_type() < 0:
		return
	# TABLE-TALK MOOD — the traveller in this foe's head plays them a touch worse (|bias| degrades skill),
	# and RILING them up (positive) also makes them blunder recklessly. Capped → an edge, not a cheat. Tick
	# ages the mood one step per decision. mood_bias()/tick come from [VersusPuzzleScene] → [NpcMood].
	var mb : float = mood_bias(_opponent_name)
	tick_opponent_mood(_opponent_name)
	var eff_skill : float = clampf(_opponent_skill - 0.22 * absf(mb), 0.0, 1.0)
	var eff_blunder : float = clampf(BASE_BLUNDER + 0.25 * maxf(mb, 0.0), 0.0, 1.0)
	var grid : Array = _opponent_board.grid_rows()
	var piece : int = _opponent_board.piece_type()
	var pl : Dictionary
	# A weak (or rattled) foe sometimes BLUNDERS a piece to a random spot; otherwise it plays the best
	# placement, degraded by skill-scaled noise inside best_placement.
	if randf() < eff_blunder * (1.0 - eff_skill):
		pl = SkirmishAI.random_placement(grid, piece)
	else:
		pl = SkirmishAI.best_placement(grid, piece, eff_skill)
	_opponent_board.ai_place(int(pl["rot"]), int(pl["px"]))


# --- Garbage exchange --------------------------------------------------

func _garbage_for(count: int) -> int:
	return GARBAGE_FOR_LINES[clampi(count, 0, GARBAGE_FOR_LINES.size() - 1)]


func _on_player_cleared(count: int) -> void:

	Audio.play_sfx("hit", 9.0)   # Skirmish line clear — a punchy impact (Troy 06-06)
	var h : int = _garbage_for(count)
	if h <= 0:
		return
	var attack : Dictionary = SkirmishWeapon.make_attack(_player_weapon, h, _opponent_board, count)
	_opponent_board.receive_attack(attack["shape"], attack["col"], attack["color"], attack["decay"])
	_lines_sent += h
	if _you_lines_label != null:
		_you_lines_label.text = "Attack sent:  %d" % _lines_sent


func _on_opponent_cleared(count: int) -> void:

	# The foe's garbage is scaled DOWN by their aggression and capped, so a soft
	# opponent barely pressures you and no single hit is an instant KO.
	var base : int = _garbage_for(count)
	if base <= 0:
		return
	var garbage_scale : float = AGGRESSION_GARBAGE_BASE + (1.0 - AGGRESSION_GARBAGE_BASE) * _opponent_aggression
	var h : int = clampi(roundi(float(base) * garbage_scale), 0, MAX_GARBAGE_ROWS)
	if h <= 0:
		return
	var attack : Dictionary = SkirmishWeapon.make_attack(_opponent_weapon, h, _player_board, count)
	_player_board.receive_attack(attack["shape"], attack["col"], attack["color"], attack["decay"])
	_opp_lines_sent += h
	if _opp_lines_label != null:
		_opp_lines_label.text = "Attack sent:  %d" % _opp_lines_sent


# --- KO / result -------------------------------------------------------

func _on_player_ko(_final_score: int) -> void:
	Audio.play_sfx("ko")   # you topped out — the defeat sound
	get_tree().root.add_child(ScreenFlash.make(Color(1.0, 0.32, 0.26), 0.4))   # red — you lost (borrow #5)
	_end_duel(false)


func _on_opponent_ko(_final_score: int) -> void:
	Audio.play_sfx("chime")   # VICTORY beat — losing had "ko" but winning was mute (audio-gap audit)
	get_tree().root.add_child(ScreenFlash.make(Color(1.0, 0.86, 0.42), 0.42))   # gold — you won (borrow #5)
	_end_duel(true)


func _end_duel(player_won: bool) -> void:

	if _duel_over:
		return
	_duel_over = true
	# Report the outcome so a Voyage boarding fight can read win/loss on return.
	PlayerState.last_skirmish_won = player_won
	# Battle MEMORY: log the head-to-head against this cast member (skipped for a nameless sparring partner) so
	# they remember the result — drives post-fight banter + chat awareness. See [[npc-battle-memory]].
	if _opponent_profile != null:
		PlayerState.record_battle(_opponent_profile.npc_name, player_won)
	# The LOSER's board floods red (defeat); the winner just freezes (stop).
	if player_won:
		_player_board.stop()
		_opponent_board.defeat()
	else:
		_player_board.defeat()
		_opponent_board.stop()
	var win_quality : int = (_player_board.score() + _lines_sent * LINES_SENT_BONUS
		+ (WIN_BONUS if player_won else 0))
	var mastery : Dictionary = PlayerState.record_puzzle_result("skirmish", win_quality)
	_show_results(player_won, bool(mastery["is_new_best"]))
	if mastery["ranked_up"]:
		add_child(MasteryToast.create(String(mastery["tier_name"])))
	_set_awaiting_dismiss(true)


# --- UI ----------------------------------------------------------------

func _build_ui() -> void:

	var ui : CanvasLayer = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var opp_tint : Color = _opponent_profile.portrait_color if _opponent_profile != null else Color(0.85, 0.52, 0.50, 1.0)
	_you_lines_label = _add_board_header(ui, _player_board, "YOU", Color(0.70, 0.92, 0.74, 1.0), Color(0.95, 0.78, 0.34, 1.0), _player_weapon)
	_opp_lines_label = _add_board_header(ui, _opponent_board, _opponent_name, Color(0.95, 0.74, 0.74, 1.0), opp_tint, _opponent_weapon)
	set_help_text("SKIRMISH — bury your foe in garbage to top them out.\n\n"
		+ "• ←  → :  move the piece\n"
		+ "• ↑ :  rotate\n"
		+ "• ↓  /  SPACE :  soft drop\n\n"
		+ "Clear lines to send GARBAGE to your opponent. Fill their board to the top to win.\n\n"
		+ "Incoming attacks land as grey X-blocks that clog your stack — they can't be cleared until\n"
		+ "they RIPEN into coloured tiles (after a couple of your drops).")


# A PORTRAIT + weapon swatch + name header + a "garbage sent" line above a board. [param tint]
# colours the fighter's avatar (their identity hue); [param weapon] tints the small swatch
# (their equipped weapon, mirroring the boarding header). Returns the sent label.
func _add_board_header(ui: CanvasLayer, board: SkirmishBoard, who: String, color: Color, tint: Color, weapon: String) -> Label:

	var row : HBoxContainer = HBoxContainer.new()
	row.position = board.position + Vector2(0.0, -64.0)
	row.add_theme_constant_override("separation", 8)
	ui.add_child(row)
	var face : Portrait = PORTRAIT_SCENE.instantiate()
	face.custom_minimum_size = Vector2(46.0, 46.0)
	face.setup(who, tint)
	row.add_child(face)
	var wpn : ColorRect = ColorRect.new()      # the weapon shown "on" the avatar
	wpn.custom_minimum_size = Vector2(6.0, 18.0)
	wpn.color = SkirmishWeapon.color_for(weapon)
	row.add_child(wpn)
	var box : VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	row.add_child(box)
	var name_label : Label = Label.new()
	name_label.text = who
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", color)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	name_label.add_theme_constant_override("outline_size", 4)
	box.add_child(name_label)
	var sent : Label = Label.new()
	sent.text = "Attack sent:  0"
	sent.add_theme_font_size_override("font_size", 14)
	sent.add_theme_color_override("font_color", Color(0.74, 0.78, 0.9, 0.95))
	box.add_child(sent)
	return sent


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
	panel.add_theme_stylebox_override("panel", _results_style())
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
		_add_result_label(vbox, "VICTORY!", 44, Color(0.72, 1.0, 0.72, 1.0))
		_add_result_label(vbox, "You buried %s." % _opponent_name, 22, Color(0.95, 0.92, 0.62, 1.0))
	else:
		_add_result_label(vbox, "DEFEATED", 44, Color(0.95, 0.55, 0.55, 1.0))
		_add_result_label(vbox, "%s topped you out." % _opponent_name, 22, Color(0.92, 0.84, 0.6, 1.0))
	_add_result_label(vbox, "Attack sent:  %d" % _lines_sent, 18, Color(0.85, 0.9, 1.0, 1.0))
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


func _results_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.10, 0.16, 0.97)
	s.border_color = Color(0.5, 0.55, 0.82, 1.0)
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.content_margin_left = 48
	s.content_margin_right = 48
	s.content_margin_top = 30
	s.content_margin_bottom = 30
	return s


# The foe you chose at the Spar post's challenge picker (consumed here). Falls
# back to a random cast member if launched without a pick (e.g. a future voyage
# boarding fight). Flavour/name only — the bot plays the same either way.
func _resolve_opponent() -> String:

	var chosen : String = PlayerState.skirmish_opponent
	PlayerState.skirmish_opponent = ""
	if not chosen.is_empty():
		_opponent_profile = load(chosen) as NpcPersonality
	if _opponent_profile == null:
		# Pick-less launch (e.g. a future voyage fight) → a random islander.
		var cast : Array[NpcPersonality] = NpcRegistry.all()
		if not cast.is_empty():
			_opponent_profile = cast[randi() % cast.size()]
	if _opponent_profile != null:
		# The dedicated fists stat — NOT search_depth (card wits), so the fiction holds (Kerr > Godfrey at steel).
		_opponent_skill = clampf(_opponent_profile.skirmish_skill, 0.0, 1.0)
		_opponent_aggression = clampf(_opponent_profile.aggression, 0.0, 1.0)
		var w : String = _opponent_profile.skirmish_weapon
		_opponent_weapon = w if not w.is_empty() else "brawl"
		return _opponent_profile.npc_name
	# No cast at all — fall back to the member defaults (skill/aggression 0.5).
	return "Sparring Partner"


# Live SKIRMISH DUEL state for a chatting foe — situational awareness via the [VersusPuzzleScene] hooks (Troy
# 2026-06-10). Both boards are on-screen, so nothing's hidden: _own_secret_view stays the base's "".
# The asker is the opponent (the only NPC here). NpcBrain folds this in. See [[npc-situational-awareness]].
func _versus_ready() -> bool:
	return _opponent_board != null and _player_board != null


func _public_frame() -> String:

	var lines : PackedStringArray = PackedStringArray()
	lines.append("SKIRMISH — you're in a one-on-one block-stacking DUEL with the traveller right now: clear lines to dump garbage on the other board; whoever tops out first loses. React like a fighter mid-bout (a little trash talk fits).")
	lines.append("You've dumped %d garbage row%s on the traveller; they've dumped %d on you." % [
		_opp_lines_sent, "" if _opp_lines_sent == 1 else "s", _lines_sent])
	return "\n".join(lines)


func _lead_phrase(_asker: String) -> String:

	if _opp_lines_sent > _lines_sent:
		return "You've got the upper hand — piling the pressure on them."
	elif _lines_sent > _opp_lines_sent:
		return "You're on the back foot — they're burying your board faster than you're theirs."
	return "It's neck and neck so far."


func _pressure_phrase(_asker: String) -> String:
	return "The duel's just ended." if _duel_over else ""
