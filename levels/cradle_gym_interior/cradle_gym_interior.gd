## Interior of the CRADLE GYM — the island's Skirmish training hall (renamed from Mossy Jade's old
## healer's hut, Troy 2026-06-16). Hollow Ellison (master) + Mossy Jade (healer) work here; a Spar sign
## launches a practice bout. Shared behavior (player spawn, return-spawn anchoring) lives in
## [BaseLocation]; the door back to Cradle Rock + the props are in the scene file.
class_name CradleGymInterior
extends BaseLocation


func _ready() -> void:

	super._ready()
	_resolve_ladder_return()
	_maybe_play_intro()


# THE GYM-MASTER INTRO — a one-time, Pokémon-professor-style cinematic the FIRST time you set foot in the gym:
# Hollow Ellison welcomes you (the typewriter dialogue) then has you choose your fighting STYLE (the power type),
# and closes with a line. Gated on gym_intro_seen so it plays exactly once.
func _maybe_play_intro() -> void:

	if PlayerState.gym_intro_seen:
		return
	PlayerState.gym_intro_seen = true   # set up front so it's one-time even if they back out
	PlayerState._save()
	await get_tree().create_timer(0.5).timeout   # let the scene settle + the player land before the cinematic
	if not is_inside_tree():
		return
	Overlay.show_dialog("Hollow Ellison", [
		"So. A new face wanders into my gym.",
		"Everyone who climbs my ladder fights their own way — the brawler's fists, the swordsman's edge, the marksman's aim... and stranger paths still.",
		"Before you spar a single soul here, you'll need to know YOURS.",
		"Tell me, traveller — what kind of fighter are you?",
	], _open_intro_picker)


func _open_intro_picker() -> void:

	if not is_inside_tree():
		return
	var picker : PowerTypePicker = PowerTypePicker.new()
	picker.chosen.connect(_on_intro_chosen)
	add_child(picker)   # cancelling the picker self-cleans (you can choose later at the Spar sign)


func _on_intro_chosen(weapon_id: String) -> void:

	PlayerState.choose_power_type(weapon_id)
	# The picker sets _handing_off (it normally chains to the ladder); the intro doesn't, so un-pause ourselves.
	if get_tree() != null:
		get_tree().paused = false
	Overlay.show_dialog("Hollow Ellison", [
		"%s. A fine path — wear it well." % SkirmishWeapon.power_type_name(weapon_id),
		"Climb my ladder when you reckon you're ready to prove it.",
	])


# On return from a gym-ladder bout, record a WIN — it unlocks the next rung (and clearing the top earns the
# Gym Champion trophy). A loss leaves the rung standing; the ladder is friendly, so just try again.
func _resolve_ladder_return() -> void:

	var who : String = PlayerState.gym_ladder_pending
	if who.is_empty():
		return
	PlayerState.gym_ladder_pending = ""
	if PlayerState.last_skirmish_won and PlayerState.ladder_mark_beaten(who):
		if PlayerState.ladder_complete():
			PlayerState.log_event("You've topped the Cradle Gym ladder — Gym Champion!", Color(1.0, 0.86, 0.4))
		else:
			PlayerState.log_event("%s bested — the next rung opens." % _given_name(who), Color(0.7, 0.95, 0.6))


func _given_name(full: String) -> String:

	var parts : PackedStringArray = full.split(" ")
	return parts[parts.size() - 1] if parts.size() > 0 else full