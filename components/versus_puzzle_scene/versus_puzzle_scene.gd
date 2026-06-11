## VersusPuzzleScene — the base for any mini-game with a chat-able AI OPPONENT (poker, Gem Drop, Skirmish
## duels). It bundles the two situational foundations every versus game should INHERIT, so a new game gets
## them by extending this and filling a few small hooks, never by re-wiring:
##
##   1. SITUATIONAL AWARENESS — a default `npc_chat_context(asker)` that emits the STANDARD shape
##      (public frame → pre-computed lead → the asker's OWN secret view only → pressure → mood note).
##      HIDDEN-INFO-SAFE BY CONSTRUCTION: only `_own_secret_view` ever reads hidden state, and the
##      assembler only ever calls it with the ASKER's own name — a rival's secret has no path out.
##   2. TALK-INFLUENCE seam — `mood_bias(name)` / `tick_opponent_mood(name)` + the `_apply_opponent_mood(name)`
##      hook a game overrides to fold the mood into its own AI. No-ops until the NpcMood autoload ships.
##
## Override ONLY the hooks you need; all default to safe empties. SOLO puzzles keep extending PuzzleScene.
## See the "New VERSUS puzzle" recipe in CLAUDE.md. Reference subclasses: gem_drop (open, simplest),
## skirmish_duel (open, 1v1), poker_scene (hidden hole cards + multi-seat — the richest).
class_name VersusPuzzleScene
extends PuzzleScene


# ── Situational awareness ───────────────────────────────────────────────────────────────────────────────
# The ONE assembler. NpcBrain.compose_system duck-types this (has_method + passes the chatting NPC's own
# name as `asker`). Concrete games fill the hooks below — they must NOT re-implement this method.
func npc_chat_context(asker: String) -> String:

	if not _versus_ready():
		return ""
	var parts : PackedStringArray = PackedStringArray()
	for part in [_public_frame(), _lead_phrase(asker), _own_secret_view(asker), _pressure_phrase(asker), _active_mood_note(asker)]:
		if not String(part).is_empty():
			parts.append(String(part))
	return "\n".join(parts)


## True once this game's board(s) are live enough to describe. Override to gate (e.g. `_board != null`).
func _versus_ready() -> bool:
	return true


## The PUBLIC, mutually-visible frame (header / board / scores / stacks). Takes NO asker — it structurally
## cannot leak a secret. NEVER put hidden state here.
func _public_frame() -> String:
	return ""


## One pre-computed, PLAIN-WORDS lead line (who's ahead, by how much). The chat model can't be trusted to
## compare numbers, so state it outright. (asker is passed for symmetry; 1v1 games may ignore it.)
func _lead_phrase(_asker: String) -> String:
	return ""


## THE hidden-info hook: the asker's OWN private view ONLY (e.g. their hole cards). Return "" for OPEN
## boards — empty is first-class and the section is simply omitted. This is the ONLY hook that may read
## hidden state, and the assembler only ever calls it with the asker's own name.
func _own_secret_view(_asker: String) -> String:
	return ""


## One pre-computed PRESSURE / recent-action line (who's under the gun, what just happened).
func _pressure_phrase(_asker: String) -> String:
	return ""


## An active-mood note for the chatting opponent, so their banter matches what the player just did to them
## (2nd person — the prompt addresses the NPC as "you"). "" when no mood is live.
func _active_mood_note(asker: String) -> String:
	match NpcMood.current_kind(asker):
		NpcMood.TILT:
			return "(The traveller's needling has gotten under your skin — you're playing rattled and loose right now.)"
		NpcMood.FIRED_UP:
			return "(The traveller's got your blood up — you're feeling bold and aggressive right now.)"
		NpcMood.COWED:
			return "(The traveller's gotten in your head — you're playing cautious and tight right now.)"
	return ""


# ── Talk-influence seam (no-ops until the NpcMood autoload ships) ────────────────────────────────────────
# The shared accessor every concrete AI reads. Sign convention: + = rattled (toward blunder/looser),
# − = confident / steely. 0 when there's no live mood. Read it on the MAIN thread (it lazily clears expiries).
func mood_bias(name: String) -> float:
	return NpcMood.bias(name)


## Tick the opponent's mood once, at the AI decision point (ages it one step toward neutral).
func tick_opponent_mood(name: String) -> void:
	NpcMood.tick(name)


## Per-game AI-biasing hook: override to fold `mood_bias(name)` into your own AI knobs, and CALL it at your
## AI decision point (per active opponent for multi-seat games). The default just ticks (a no-op today).
func _apply_opponent_mood(name: String) -> void:
	tick_opponent_mood(name)
