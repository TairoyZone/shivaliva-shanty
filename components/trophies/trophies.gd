## Earn-only / permanent trophies for the player's Profile page. Each trophy
## is DERIVED LIVE from existing [PlayerState] (no separate unlock-event system
## or save data) and reads only MONOTONIC state — high-water-mark mastery, the
## lifetime-coins counter, won-counts, unlocked flags, non-decaying affinity —
## so a trophy can never un-earn. Honours earn-and-keep ([[community-research]],
## [[ypp-template]]). The [ProfileView] renders [constant ALL] and asks
## [method is_earned] per trophy. See [[profile-standings-tab]].
class_name Trophies
extends RefCounted


## Mastery tier index a per-puzzle trophy requires (Master — MASTERY_TIERS[3]).
const MASTERY_TROPHY_TIER : int = 3
## Lifetime gold for the Full Purse trophy (≈ the first ship a few times over).
const FULL_PURSE_GOLD : int = 1000
## Per-cast-member rapport needed for Friend of the Inn (the "Friend" tier).
const INN_FRIEND_AFFINITY : int = 50

## The registry: id, display name, one-line description. Earned state is NOT
## stored here — it's computed by [method is_earned] from live PlayerState.
const ALL : Array = [
	{"id": "master_lumberjack", "name": "Master Lumberjack", "desc": "Reach Master rank at Lumberjacking."},
	{"id": "deep_digger", "name": "Deep Digger", "desc": "Reach Master rank at Mining."},
	{"id": "gemcutter", "name": "Gemcutter", "desc": "Reach Master rank at Gem Drop."},
	{"id": "card_shark", "name": "Card Shark", "desc": "Reach Master rank at Poker."},
	{"id": "skirmisher", "name": "Skirmisher", "desc": "Reach Master rank at Skirmish."},
	{"id": "first_voyage", "name": "First Voyage", "desc": "Complete your maiden voyage."},
	{"id": "tournament_champ", "name": "Tournament Champion", "desc": "Win a Gem Drop tournament."},
	{"id": "full_purse", "name": "Full Purse", "desc": "Earn 1,000 gold across your career."},
	{"id": "friend_of_inn", "name": "Friend of the Inn", "desc": "Befriend the whole cast of Cradle Rock."},
	{"id": "sweetheart", "name": "Sweetheart", "desc": "Win an islander's heart and become sweethearts."},
]


## Is the trophy with this id currently earned? Pure read of live state.
static func is_earned(id: String) -> bool:

	match id:
		"master_lumberjack":
			return _mastered("lumberjacking")
		"deep_digger":
			return _mastered("mining")
		"gemcutter":
			return _mastered("gem_drop")
		"card_shark":
			return _mastered("poker")
		"skirmisher":
			return _mastered("skirmish")
		"first_voyage":
			return PlayerState.frontier_unlocked
		"tournament_champ":
			return PlayerState.tournaments_won >= 1
		"full_purse":
			return PlayerState.lifetime_coins_earned >= FULL_PURSE_GOLD
		"friend_of_inn":
			return _all_cast_friended()
		"sweetheart":
			return PlayerState.has_been_sweetheart
	return false


## How many of [constant ALL] are earned right now.
static func earned_count() -> int:

	var n : int = 0
	for t in ALL:
		if is_earned(String(t["id"])):
			n += 1
	return n


# True once the puzzle's high-water-mark mastery has reached Master+.
static func _mastered(puzzle_id: String) -> bool:

	return int(PlayerState.mastery_tier(puzzle_id)["index"]) >= MASTERY_TROPHY_TIER


# True once EVERY cast member is at the Friend rapport tier or higher.
static func _all_cast_friended() -> bool:

	var cast : Array[NpcPersonality] = NpcRegistry.all()
	if cast.is_empty():
		return false
	for profile in cast:
		if PlayerState.get_affinity(profile.npc_name) < INN_FRIEND_AFFINITY:
			return false
	return true