## DevCheats — DEV-ONLY test shortcuts, gated to debug builds (OS.is_debug_build()) so they NEVER fire in a
## release export. Autoload. Keys:
##   F10 — seed a CREW: the whole cast → Confidant rapport + 4 hands hired (Jericho/Sailing, Godfrey/Repair,
##         Kerr/Combat, Mia), so duty-stations + the roster are testable without grinding rapport to 80.
##   F9  — +1000 gold (for fares / poker buy-ins).
##   F8  — open 3 hull holes on the ACTIVE voyage ship (test the Repair seal + the Loft's hole-driven flood);
##         only does anything mid-voyage.
## Built 2026-06-08 to playtest the crew/ship-owning systems.
extends Node


func _unhandled_key_input(event: InputEvent) -> void:

	if not OS.is_debug_build():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F10:
			_seed_crew()
			get_viewport().set_input_as_handled()
		KEY_F9:
			PlayerState.add_coins(1000, "DEV: +1000 gold")
			PlayerState.log_event("DEV (F9): +1000 gold", Color(1, 0.9, 0.5))
			get_viewport().set_input_as_handled()
		KEY_F8:
			if PlayerState.voyage_active:
				PlayerState.add_hole(3)
				PlayerState.log_event("DEV (F8): opened 3 hull holes on the active ship", Color(1, 0.6, 0.5))
			else:
				PlayerState.log_event("DEV (F8): no voyage active — holes only on the pillage ship", Color(0.8, 0.8, 0.8))
			get_viewport().set_input_as_handled()


func _seed_crew() -> void:

	for p in NpcRegistry.all():
		PlayerState.add_affinity(p.npc_name, PlayerState.MAX_AFFINITY)   # → 100 (Confidant): all recruitable
	for who in ["Stormy Jericho", "Cogwise Godfrey", "Flint Kerr", "Spritely Mia"]:
		PlayerState.hire_crew(who)
	PlayerState.log_event(
		"DEV (F10): cast at Confidant + 4 hired — start a voyage, then open Crew Duty on the deck",
		Color(1, 0.9, 0.5))
