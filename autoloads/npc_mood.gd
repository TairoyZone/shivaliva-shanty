## NpcMood — the TRANSIENT per-NPC "table mood" behind the talk-moves-the-game system. The player's chat can
## rattle (TILT), intimidate (COWED), or hype (FIRED_UP) a versus opponent; a small DECAYING mood then biases
## that NPC's next few AI decisions a CAPPED amount (an edge, never a win button — the NPC can always refuse).
##
## ONE mood per NPC works across ALL versus games (poker / Gem Drop / Skirmish) unchanged — only each game's
## `_apply_opponent_mood` adapter reads it differently (via [VersusPuzzleScene].mood_bias). The chat side
## sets it through [NpcBrain] (the [[TILT]]/[[COWED]]/[[FIRED_UP]] tag + keyword fallback).
##
## NOT saved — purely in-match (mirrors PlayerState.recent_duel). Cleared on New Game + on leaving a puzzle.
## See [[talk-moves-the-game-spec]] + [[ai-npc-chat-hook]].
extends Node

enum { NEUTRAL, TILT, COWED, FIRED_UP }

const MOOD_TURNS : int = 4          # how many of the NPC's own decisions a fresh mood colors before it fades
const NUDGE_STEP : float = 0.42     # diminishing-returns step toward a full mood (5 taunts ≈ 2, never a spike)
const TICK_DECAY : float = 0.15     # level eased toward 0 each consumed decision
const STALE_MS : int = 90000        # wall-clock backstop — a mood older than this is dead (player walked off)
const COOLDOWN_MS : int = 1500      # ignore a repeat SAME-kind nudge within this window (anti chat-burst spam)

# npc_name -> { kind:int, level:float [0..1], turns_left:int, set_ms:int }
var _mood : Dictionary = {}


## Push a mood onto an NPC. Diminishing returns toward a cap; a CONTRADICTING kind bleeds the old one toward
## neutral first (you can't be cowed AND fired-up at once); a rapid same-kind repeat is ignored (anti-spam).
func nudge(npc_name: String, kind: int) -> void:

	if npc_name.is_empty() or kind == NEUTRAL:
		return
	var now : int = Time.get_ticks_msec()
	var m : Dictionary = _mood.get(npc_name, {})
	if not m.is_empty() and int(m.get("kind", NEUTRAL)) == kind and now - int(m.get("set_ms", 0)) < COOLDOWN_MS:
		return
	var cur_kind : int = int(m.get("kind", NEUTRAL))
	var level : float = float(m.get("level", 0.0))
	if cur_kind != NEUTRAL and cur_kind != kind:
		level -= NUDGE_STEP                       # contradicting mood — spend the old one down first
		if level <= 0.0:
			cur_kind = kind
			level = NUDGE_STEP
	else:
		cur_kind = kind
		level = level + (1.0 - level) * NUDGE_STEP
	_mood[npc_name] = {"kind": cur_kind, "level": clampf(level, 0.0, 1.0), "turns_left": MOOD_TURNS, "set_ms": now}


## The deliberate-move path (a future "Needle / Read / Steady" button row). Same store, synchronous, no LLM.
## Returns true if it landed (a real kind on a real NPC).
func play_move(npc_name: String, kind: int) -> bool:
	nudge(npc_name, kind)
	return not npc_name.is_empty() and kind != NEUTRAL


## The ONE signed scalar every adapter reads. + = rattled / looser / bolder, − = confident / tighter. 0 when
## there's no live mood. Lazily clears an expired entry (turns spent or gone stale on the wall clock).
func bias(npc_name: String) -> float:

	var m : Dictionary = _mood.get(npc_name, {})
	if m.is_empty():
		return 0.0
	if int(m.get("turns_left", 0)) <= 0 or Time.get_ticks_msec() - int(m.get("set_ms", 0)) > STALE_MS:
		_mood.erase(npc_name)
		return 0.0
	var level : float = float(m.get("level", 0.0))
	return -level if int(m.get("kind", NEUTRAL)) == COWED else level


## One AI decision consumed → age the mood (turn-based decay). Call once per decision at the AI chokepoint.
func tick(npc_name: String) -> void:

	var m : Dictionary = _mood.get(npc_name, {})
	if m.is_empty():
		return
	m["turns_left"] = int(m["turns_left"]) - 1
	m["level"] = float(m["level"]) * (1.0 - TICK_DECAY)
	if int(m["turns_left"]) <= 0 or float(m["level"]) < 0.02:
		_mood.erase(npc_name)
	else:
		_mood[npc_name] = m


## The live mood kind for display/flavour (NEUTRAL once expired). Used by _active_mood_note.
func current_kind(npc_name: String) -> int:
	if is_zero_approx(bias(npc_name)):
		return NEUTRAL
	return int(_mood.get(npc_name, {}).get("kind", NEUTRAL))


func clear(npc_name: String) -> void:
	_mood.erase(npc_name)


func clear_all() -> void:
	_mood.clear()
