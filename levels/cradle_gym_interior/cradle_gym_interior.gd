## Interior of the CRADLE GYM — the island's Skirmish training hall (renamed from Mossy Jade's old
## healer's hut, Troy 2026-06-16). Hollow Ellison (master) + Mossy Jade (healer) work here; a Spar sign
## launches a practice bout. Shared behavior (player spawn, return-spawn anchoring) lives in
## [BaseLocation]; the door back to Cradle Rock + the props are in the scene file.
class_name CradleGymInterior
extends BaseLocation


func _ready() -> void:

	super._ready()
	_resolve_ladder_return()


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