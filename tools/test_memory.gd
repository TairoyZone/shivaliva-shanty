## DEV-ONLY: verify the shared social memory — record a gym win, SAVE+RELOAD (persistence), then confirm it
## reaches a DIFFERENT NPC's (Ellison's) prompt as cross-NPC awareness. Deterministic; no LLM call.
extends Node

func _ready() -> void:
	call_deferred("_go")

func _go() -> void:
	var fails := 0
	PlayerState.player_name = "Bulldog"
	PlayerState.recent_happenings = []
	# Simulate: the player bests Jade at the gym (this is exactly what ladder_mark_beaten now records).
	PlayerState.note_happening("Bulldog bested Mossy Jade in a friendly bout at the Cradle Gym.", "cradle_gym_interior")

	# ROUND-TRIP: persist, wipe in-memory, reload from disk — proves it survives a quit/reload.
	PlayerState._save()
	PlayerState.recent_happenings = []
	PlayerState._load()
	var survived : bool = false
	for e in PlayerState.recent_happenings:
		if "bested Mossy Jade" in String(e.get("text", "")):
			survived = true
	print("RELOAD survived: ", survived, " | entries=", PlayerState.recent_happenings.size())
	if not survived: fails += 1

	# CROSS-NPC: compose Ellison's prompt — he must now be aware of the Jade bout he never witnessed.
	var ellison : NpcPersonality = load("res://components/npc/profiles/hollow_ellison.tres")
	var sys : String = NpcBrain.compose_system(ellison, true)
	var aware : bool = "bested Mossy Jade" in sys
	var framed : bool = "AROUND THE ISLAND LATELY" in sys
	print("ELLISON aware of Jade bout: ", aware, " | hearsay-framed: ", framed)
	if not aware: fails += 1
	if not framed: fails += 1

	# MULTI-ISLAND: a Driftspar event reads as "word from afar" to a Cradle Rock NPC, but "here" to a Driftspar NPC.
	PlayerState.note_happening("Bulldog charted a new reef off Driftspar.", "frontier_isle")
	var afar_for_cradle : bool = "(word from afar) Bulldog charted a new reef" in NpcBrain.compose_system(ellison, true)
	var dpar : NpcPersonality = NpcPersonality.new()
	dpar.npc_name = "Test Driftspar"
	dpar.island = "driftspar"
	var sys3 : String = NpcBrain.compose_system(dpar, true)
	var here_for_dpar : bool = ("Bulldog charted a new reef" in sys3) and not ("(word from afar) Bulldog charted a new reef" in sys3)
	print("AFAR for Cradle NPC: ", afar_for_cradle, " | HERE for Driftspar NPC: ", here_for_dpar)
	if not afar_for_cradle: fails += 1
	if not here_for_dpar: fails += 1

	# CAP: never exceeds HAPPENINGS_CAP no matter how many fire.
	for i in range(40):
		PlayerState.note_happening("filler event %d." % i, "shore")
	print("CAP held: ", PlayerState.recent_happenings.size(), " <= ", PlayerState.HAPPENINGS_CAP)
	if PlayerState.recent_happenings.size() > PlayerState.HAPPENINGS_CAP: fails += 1

	print("MEMORY TEST: %s (%d fail)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit()
