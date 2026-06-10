## OpponentChat — makes a versus-puzzle's AI opponent CHAT-REACHABLE, the way a poker seat is (the
## situational-awareness hook beyond poker; Troy 2026-06-10: "wire the NPC brain on every puzzle"). Drop it
## as a child of the PuzzleScene and call setup(persona): it joins the "npc" group so the chat box's scope
## menu AND RoomChat's ambient pool find it, and open_chat() routes a private AI conversation through the chat
## bar. The SCENE supplies the live game state via its own npc_chat_context(npc_name) (NpcBrain folds it in).
## Position it where replies should float (e.g. over the opponent's score panel); the chat LOG carries the
## conversation regardless. Reusable by Gem Drop, the Skirmish duel — any 1-v-1 puzzle.
class_name OpponentChat
extends Node2D


var _persona : NpcPersonality = null
var _fallback : Array = []
var npc_name : String = ""   # read by the chat scope menu + RoomChat (they duck-type "npc_name" in node)


## Register [param persona] as the chattable opponent. [param fallback] are canned lines used if an AI request
## fails (optional). No-op on a null persona.
func setup(persona: NpcPersonality, fallback: Array = []) -> void:

	if persona == null:
		return
	_persona = persona
	_fallback = fallback
	npc_name = persona.npc_name
	if not is_in_group("npc"):
		add_to_group("npc")


## Open a private AI conversation with this opponent — the chat box's scope menu + RoomChat call this.
func open_chat() -> void:

	if _persona != null:
		ChatBox.start_private_chat(_persona, self, _fallback)
