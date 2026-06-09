## Central lookup for the 8 named [NpcPersonality] profiles that make
## up the [[cradle-rock-cast]]. Mini-games use [method pick_random] to
## select opponents at the start of each session — so two poker hands
## in a row never share the same three NPCs unless RNG repeats.
##
## Adding a new NPC: drop a new .tres in [code]components/npc/profiles/[/code]
## and append its path to [const PROFILE_PATHS]. Both poker and gem
## drop automatically pick it up.
class_name NpcRegistry
extends RefCounted


const PROFILE_PATHS : Array[String] = [
	"res://components/npc/profiles/hearty_brian.tres",
	"res://components/npc/profiles/stormy_jericho.tres",
	"res://components/npc/profiles/flint_kerr.tres",
	"res://components/npc/profiles/cinder_troy.tres",
	"res://components/npc/profiles/cogwise_godfrey.tres",
	"res://components/npc/profiles/spritely_mia.tres",
	"res://components/npc/profiles/mossy_jade.tres",
	"res://components/npc/profiles/hollow_ellison.tres",
	"res://components/npc/profiles/merry_geneva.tres",
]


## Returns every cast member's [NpcPersonality] in registry order.
static func all() -> Array[NpcPersonality]:

	var out : Array[NpcPersonality] = []
	for path in PROFILE_PATHS:
		var profile : NpcPersonality = load(path) as NpcPersonality
		if profile != null:
			out.append(profile)
	return out


## Find a cast member's [NpcPersonality] by display name (e.g. "Flint Kerr"). Null if no match. Used to
## resolve a stored challenge name back to its profile (for the Ayo! duel launch) without a scene reference.
static func by_name(npc_name: String) -> NpcPersonality:

	for profile in all():
		if profile.npc_name == npc_name:
			return profile
	return null


## Returns [param count] randomly-picked profiles, optionally
## [param exclude]-ing any already-chosen ones. Used by the poker
## scene to seat three random opponents and by the gem-drop scene to
## pick one. Result order is randomized so seat assignment is also
## random.
static func pick_random(count: int, exclude: Array[NpcPersonality] = []) -> Array[NpcPersonality]:

	var pool : Array[NpcPersonality] = []
	for profile in all():
		if profile in exclude:
			continue
		pool.append(profile)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))


## Convenience for scenes that just want one. Equivalent to
## [code]pick_random(1, exclude).front()[/code].
static func pick_one(exclude: Array[NpcPersonality] = []) -> NpcPersonality:

	var picks : Array[NpcPersonality] = pick_random(1, exclude)
	if picks.is_empty():
		return null
	return picks[0]


## Affinity-weighted lobby fill. Walks the cast in shuffled order and, for
## each candidate, rolls a join chance that scales with the player's
## rapport: a Confidant turns up ~90% of the time, a Stranger ~25%. Fills
## up to [param count] seats. [param affinity_of] is a
## [code]Callable(name: String) -> int[/code] (pass
## [code]PlayerState.get_affinity[/code]); [param exclude] keeps the same
## faces from recurring back-to-back, same as [method pick_random].
##
## LIVELINESS GUARANTEE: if too few NPCs roll in, the table is topped up
## with the friendliest remaining faces — affinity biases the ODDS, never
## collapses the pool, and a parlor game is NEVER left short a seat (so a
## zero-rapport, day-one player always gets a full, lively table).
static func pick_for_lobby(count: int, affinity_of: Callable, exclude: Array[NpcPersonality] = []) -> Array[NpcPersonality]:

	var pool : Array[NpcPersonality] = []
	for profile in all():
		if profile in exclude:
			continue
		pool.append(profile)
	pool.shuffle()
	var chosen : Array[NpcPersonality] = []
	for profile in pool:
		if chosen.size() >= count:
			break
		var aff : int = int(affinity_of.call(profile.npc_name))
		var p_join : float = clampf(0.25 + float(aff) / 100.0 * 0.65, 0.25, 0.90)
		if randf() <= p_join:
			chosen.append(profile)
	# Top up with the friendliest faces that didn't roll in, so the table
	# is always full.
	if chosen.size() < count:
		var rest : Array[NpcPersonality] = []
		for profile in pool:
			if not (profile in chosen):
				rest.append(profile)
		rest.sort_custom(func(a: NpcPersonality, b: NpcPersonality) -> bool:
			return int(affinity_of.call(a.npc_name)) > int(affinity_of.call(b.npc_name)))
		for profile in rest:
			if chosen.size() >= count:
				break
			chosen.append(profile)
	return chosen


## Load NPC profiles from a list of resource-path strings (round-trips with
## [member NpcPersonality.resource_path]). Used by the parlor scenes (seating from the lobby
## handoff) AND the parlor browser (exclude lists). Skips unloadable paths. (Relocated here from
## the retired LobbyModal so both live games keep working.)
static func profiles_from_paths(paths: Array) -> Array[NpcPersonality]:

	var out : Array[NpcPersonality] = []
	for p in paths:
		var prof : NpcPersonality = load(String(p)) as NpcPersonality
		if prof != null:
			out.append(prof)
	return out


## A DERIVED per-game parlor STANDING for an NPC, as a mastery-tier index (0 Greenhorn .. 5 Legend).
## NPCs store no real rating, so this synthesizes one from their AI knobs — letting a table row show
## a rank YPP-style ("Master Cutepo"). Deterministic per NPC + game (stable across browser opens);
## pure flavor, never persisted. [param game_id] = "poker" / "gem_drop".
static func parlor_tier(profile: NpcPersonality, game_id: String) -> int:

	if profile == null:
		return 0
	var strength : float
	if game_id == "gem_drop":
		var depth01 : float = float(profile.search_depth - 1) / 4.0   # search_depth 1..5 -> 0..1
		strength = 0.60 * depth01 + 0.25 * profile.perception + 0.15 * profile.aggression
	else:   # poker (and any future card game)
		strength = 0.50 * profile.perception + 0.30 * profile.pfr_target + 0.20 * profile.aggression
	return clampi(int(round(clampf(strength, 0.0, 1.0) * 5.0)), 0, 5)