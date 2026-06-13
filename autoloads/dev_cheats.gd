## DevCheats — DEV-ONLY test commands, run via SLASH-COMMANDS typed in the chat box (the "Say something…" bar).
## Gated to debug builds: the ChatBox only routes a leading "/" here when OS.is_debug_build(), so they vanish
## from a release export. Commands:
##   /crew       — seed a CREW: the whole cast → Confidant rapport + 4 hired (Jericho/Sailing, Godfrey/Repair,
##                 Kerr/Combat, Mia), so the crew/duty-stations systems are testable without grinding rapport.
##   /gold [n]   — +n gold (default 1000), for fares / poker buy-ins.
##   /skills     — max EVERY puzzle's mastery to Legend (the top tier), so the voyage/pillage is testable
##                 without grinding. Pairs with /crew + /gold for a fully-kitted pillage run.
##   /holes [n]  — open n hull holes on the ACTIVE ship (the voyage ship mid-run, else your owned ship; default 3).
##   /mend       — fully mend the active ship (seal all holes).
##   /wreck      — wreck the active ship (max holes) — to feel the holed Loft / set up a sink.
##   /help       — list the commands.
## (Function-key cheats were dropped — F8/F9 etc. collide with Godot's editor shortcuts.) Built 2026-06-08.
extends Node


func run_command(text: String) -> void:

	var parts : PackedStringArray = text.strip_edges().split(" ", false)
	if parts.is_empty():
		return
	var cmd : String = String(parts[0]).to_lower()
	var arg : int = 0
	if parts.size() > 1 and String(parts[1]).is_valid_int():
		arg = int(parts[1])
	match cmd:
		"/crew":
			_seed_crew()
		"/gold":
			var amt : int = arg if arg > 0 else 1000
			PlayerState.add_coins(amt, "DEV: +%d gold" % amt)
			_note("+%d gold" % amt)
		"/skills":
			PlayerState.dev_max_all_mastery()
			_note("all puzzle skills maxed to Legend — reopen Profile to see it")
		"/holes":
			var n : int = arg if arg > 0 else 3
			PlayerState.add_hole(n)
			_note("opened %d hull hole%s on the active ship" % [n, "" if n == 1 else "s"])
		"/mend":
			PlayerState.close_hole(99)
			_note("mended the hull — all holes sealed")
		"/wreck":
			PlayerState.wreck_active_ship()
			_note("WRECKED the active ship — max holes")
		"/help", "/?", "/commands":
			_note("/crew · /gold [n] · /skills · /holes [n] · /mend · /wreck")
		_:
			_note("unknown command '%s' — try /help" % cmd)


func _seed_crew() -> void:

	for p in NpcRegistry.all():
		# SET to max, not add — add_affinity is relative, so a soured NPC (now possible, rapport < 0) would
		# land below the recruit threshold and hire_crew would silently no-op. Lift everyone TO Confidant.
		PlayerState.add_affinity(p.npc_name, PlayerState.MAX_AFFINITY - PlayerState.get_affinity(p.npc_name))
	for who in ["Stormy Jericho", "Cogwise Godfrey", "Flint Kerr", "Spritely Mia"]:
		PlayerState.hire_crew(who)
	_note("cast at Confidant + 4 hired — start a voyage, then open Crew Duty on the deck")


func _note(msg: String) -> void:

	PlayerState.log_event("DEV: %s" % msg, Color(1.0, 0.9, 0.5))
