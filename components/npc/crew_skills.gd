## CrewSkills — what each NPC is GOOD at, so the player can decide WHO to recruit (and, later, who to put on
## which voyage station). Ratings 1–5 across the crew-relevant skills. Data-driven + shared by the NPC profile
## (the "why hire them" Abilities readout) and the crew roster. Built 2026-06-08; the foundation for crew
## duty-stations (a high-Sailing crew member at the Loft, a high-Repair one at the Patchworks, …).
class_name CrewSkills
extends RefCounted


## The crew skills, in display order. Map onto the game's stations/loops: Combat = Skirmish/boarding,
## Sailing = the Loft, Repair = the Patchworks, Cards = Poker/Gem Drop, Craft = gathering + their trade.
const SKILLS : Array[String] = ["Combat", "Sailing", "Repair", "Cards", "Craft"]

## The three skills that are VOYAGE DUTY STATIONS — the player assigns a crew member to each, and that hand's
## rating carries the station they aren't manning (Sailing→Loft, Repair→Patchworks, Combat→boarding).
const STATIONS : Array[String] = ["Sailing", "Repair", "Combat"]

## Which puzzle/leg-job each station maps to, for UI labels.
const STATION_POST : Dictionary = {"Sailing": "the Loft", "Repair": "the Patchworks", "Combat": "boarding"}

## Per-NPC ratings (1–5). Tuned so every cast member has a distinct reason to hire them (Jericho the ace
## sailor, Godfrey the fixer, Geneva the card sharp, Kerr the fighter-smith, …).
const ABILITIES : Dictionary = {
	"Flint Kerr":      {"Combat": 5, "Sailing": 2, "Repair": 3, "Cards": 2, "Craft": 5},
	"Cinder Troy":     {"Combat": 3, "Sailing": 2, "Repair": 4, "Cards": 2, "Craft": 5},
	"Hearty Brian":    {"Combat": 2, "Sailing": 2, "Repair": 2, "Cards": 4, "Craft": 2},
	"Merry Geneva":    {"Combat": 2, "Sailing": 2, "Repair": 2, "Cards": 5, "Craft": 2},
	"Spritely Mia":    {"Combat": 2, "Sailing": 3, "Repair": 3, "Cards": 3, "Craft": 4},
	"Mossy Jade":      {"Combat": 2, "Sailing": 2, "Repair": 3, "Cards": 2, "Craft": 4},
	"Cogwise Godfrey": {"Combat": 2, "Sailing": 3, "Repair": 5, "Cards": 3, "Craft": 5},
	"Stormy Jericho":  {"Combat": 4, "Sailing": 5, "Repair": 4, "Cards": 2, "Craft": 3},
	"Hollow Ellison":  {"Combat": 3, "Sailing": 3, "Repair": 2, "Cards": 4, "Craft": 2},
}


static func skills_for(npc_name: String) -> Dictionary:

	return ABILITIES.get(npc_name, {})


static func rating(npc_name: String, skill: String) -> int:

	return int((ABILITIES.get(npc_name, {}) as Dictionary).get(skill, 0))


## The NPC's single best skill (name) — for a one-line roster summary. "" if no data.
static func top_skill(npc_name: String) -> String:

	var best : String = ""
	var best_r : int = 0
	for s in SKILLS:
		var r : int = rating(npc_name, s)
		if r > best_r:
			best_r = r
			best = s
	return best


## A compact star string for a 1–5 rating, e.g. ★★★★☆.
static func stars(rating_val: int) -> String:

	var n : int = clampi(rating_val, 0, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)


## The player-facing TITLE for a 1–5 skill — named ranks instead of a star string (Troy 2026-06-11: titles read
## as character, stars read as filler). Mirrors the spar picker's Novice/Regular/Expert tone.
static func tier_name(rating_val: int) -> String:

	match clampi(rating_val, 0, 5):
		1: return "Novice"
		2: return "Fair"
		3: return "Capable"
		4: return "Skilled"
		5: return "Master"
	return "—"
