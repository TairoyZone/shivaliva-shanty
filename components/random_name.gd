## RandomName — rolls sky-pirate character names for the New Game dice button, and validates a chosen name.
## Names follow the cast's "Adjective Name" convention (see [[cradle-rock-cast]]) and stay sky-flavoured (no
## water terms — see [[sky-canon]]). The 24×30 space gives ~700 combos, so an UNUSED name is almost always one
## roll away. Caller passes the live TAKEN set: the NPC cast now; once online/co-op lands, the server's
## registered player names fold into that same set so global uniqueness is enforced through one path.
## Static helper, no instances.
class_name RandomName
extends Object


const ADJECTIVES : Array[String] = [
	"Stormy", "Cinder", "Brass", "Gilded", "Restless", "Windward", "Lucky", "Bold", "Iron", "Copper",
	"Starlit", "Drifting", "Bright", "Wandering", "Cloudless", "Dawnlit", "Roving", "Quick", "Grizzled",
	"Dusty", "Brave", "Wily", "Amber", "Rusty",
]
const NAMES : Array[String] = [
	"Wren", "Pike", "Hollis", "Sable", "Roan", "Marlowe", "Quill", "Bryony", "Fitz", "Rook",
	"Cass", "Lark", "Vesper", "Bram", "Sorrel", "Reed", "Gale", "Hawke", "Finch", "Mabel",
	"Otis", "Pearl", "Dorian", "Esme", "Cleo", "Jonas", "Rory", "Tamsin", "Wynn", "Linnet",
]


## A random "Adjective Name" that is NOT in `taken` (case-insensitive). Retries a few times; on the rare
## all-collide run it returns a combo anyway (better a tiny dupe chance than a hang).
static func roll(taken: Array) -> String:

	var taken_lc : Dictionary = _lower_set(taken)
	for _i in 40:
		var candidate : String = String(ADJECTIVES.pick_random()) + " " + String(NAMES.pick_random())
		if not taken_lc.has(candidate.to_lower()):
			return candidate
	return String(ADJECTIVES.pick_random()) + " " + String(NAMES.pick_random())


## True if `name` is a usable choice: non-empty after trimming AND not already in `taken` (case-insensitive).
static func is_available(name: String, taken: Array) -> bool:

	var trimmed : String = name.strip_edges()
	if trimmed.is_empty():
		return false
	return not _lower_set(taken).has(trimmed.to_lower())


static func _lower_set(taken: Array) -> Dictionary:

	var out : Dictionary = {}
	for t in taken:
		out[String(t).strip_edges().to_lower()] = true
	return out
