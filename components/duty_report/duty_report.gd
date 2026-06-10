## THE DUTY REPORT — how well each hand performed at their station last leg (the YPP
## "duty report" reskin: https://yppedia.puzzlepirates.com/Duty_report). The crew are
## REAL cast members ([NpcRegistry]); each leg their station is SIMULATED from their
## [member NpcPersonality.duty_skill] (plus per-leg variance, so even an ace has an off
## stretch), while YOUR row is rated from the LIFT you actually banked at the Loft.
##
## Pure logic + the rating ladder; the panel that draws it is [DutyReportPanel].
## Ratings ladder (worst→best), matching YPP: Booched · Poor · Fine · Good · Excellent ·
## Incredible. Static-only (like [NpcRegistry]).
class_name DutyReport
extends RefCounted


const RATINGS : Array[String] = ["Booched", "Poor", "Fine", "Good", "Excellent", "Incredible"]
## Sentinel rating index for a hand who did NOT work a station this leg (you WATCHED the crew sail) — shown as
## "off duty", NOT a rating. Distinguishes "didn't do it" from "did it badly" (Booched). See [method snapshot].
const OFF_DUTY : int = -1
const RATING_COLORS : Array[Color] = [
	Color(0.88, 0.34, 0.30, 1.0),   # Booched — red
	Color(0.95, 0.58, 0.28, 1.0),   # Poor — orange
	Color(0.93, 0.86, 0.42, 1.0),   # Fine — yellow
	Color(0.66, 0.87, 0.48, 1.0),   # Good — lime
	Color(0.42, 0.86, 0.52, 1.0),   # Excellent — green
	Color(0.52, 0.93, 0.96, 1.0),   # Incredible — bright cyan
]

## The AI crew duties, in YPP report order (captain navigates; you man the Loft, shown last
## like YPP's Bilging). Sky-canon keeps the pirate duty names (no water terms to reskin).
const CREW_DUTIES : Array[String] = ["Sailing", "Gunnery", "Carpentry"]
const CAPTAIN_DUTY : String = "Navigating"
const PLAYER_DUTY : String = "The Loft"

## Per-leg performance wobble layered on a crewmate's base skill.
const VARIANCE : float = 0.16

const FALLBACK_SKILL : float = 0.6
const PLAYER_TINT : Color = Color(0.96, 0.82, 0.46, 1.0)


# Map a 0..1 performance score onto the ladder index (0 Booched .. 5 Incredible).
static func rating_index(score: float) -> int:

	if score < 0.12:
		return 0
	if score < 0.30:
		return 1
	if score < 0.50:
		return 2
	if score < 0.70:
		return 3
	if score < 0.88:
		return 4
	return 5


static func rating_name(idx: int) -> String:

	return RATINGS[clampi(idx, 0, RATINGS.size() - 1)]


static func rating_color(idx: int) -> Color:

	return RATING_COLORS[clampi(idx, 0, RATING_COLORS.size() - 1)]


# Build the voyage crew once (on Accept): captain (Navigating) + 3 real cast hands at the
# stations + YOU at the Loft. Each entry: {name, duty, skill, tint, is_player}. Stable for
# the whole pillage so the same faces hold the same posts.
static func build_roster(captain_name: String) -> Array:

	var roster : Array = []
	var cap : NpcPersonality = _personality_by_name(captain_name)
	roster.append({
		"name": captain_name if not captain_name.is_empty() else "Cap'n",
		"duty": CAPTAIN_DUTY,
		"skill": (cap.duty_skill if cap != null else 0.78),
		"tint": (cap.portrait_color if cap != null else Color(0.6, 0.6, 0.72, 1.0)),
		"is_player": false,
	})
	var exclude : Array[NpcPersonality] = []
	if cap != null:
		exclude.append(cap)
	var crew : Array[NpcPersonality] = NpcRegistry.pick_random(CREW_DUTIES.size(), exclude)
	for i in crew.size():
		roster.append({
			"name": crew[i].npc_name,
			"duty": CREW_DUTIES[i] if i < CREW_DUTIES.size() else "Rigging",
			"skill": crew[i].duty_skill,
			"tint": crew[i].portrait_color,
			"is_player": false,
		})
	roster.append({
		"name": "You",
		"duty": PLAYER_DUTY,
		"skill": -1.0,            # n/a — your row is rated from your lift-per-swap performance
		"tint": PLAYER_TINT,
		"is_player": true,
	})
	return roster


# Snapshot this leg's report from the roster: rate the player from `player_score01` (a 0..1
# performance score — lift-per-swap, computed by the caller), sim each crewmate from their
# skill. Each entry: {name, duty, rating_idx, is_player, tint}.
# Build a SELF-CAPTAINED roster: ONLY your own recruited crew aboard (no random cast, no separate AI
# captain — YOU navigate) + YOU at the Loft. `crew_names` is your recruited hands (capped to berths by the
# caller); an EMPTY list means you sail solo (just the player row). Troy 2026-06-10: no crew → no NPCs aboard.
static func build_roster_self(crew_names: Array) -> Array:

	var roster : Array = []
	var n : int = mini(crew_names.size(), CREW_DUTIES.size())   # 3 visible deck posts (Sailing/Gunnery/Carpentry)
	for i in n:
		var p : NpcPersonality = _personality_by_name(String(crew_names[i]))
		roster.append({
			"name": String(crew_names[i]),
			"duty": CREW_DUTIES[i],
			"skill": (p.duty_skill if p != null else FALLBACK_SKILL),
			"tint": (p.portrait_color if p != null else Color(0.6, 0.6, 0.72, 1.0)),
			"is_player": false,
		})
	roster.append({
		"name": "You", "duty": PLAYER_DUTY, "skill": -1.0, "tint": PLAYER_TINT, "is_player": true,
	})
	return roster


static func snapshot(roster: Array, player_score01: float, player_duty: String = "", player_manned: bool = true) -> Array:

	var report : Array = []
	for m in roster:
		var is_player : bool = bool(m.get("is_player", false))
		var idx : int
		if is_player:
			# Off duty (watched) → the OFF_DUTY sentinel, NOT a 0/Booched rating.
			idx = rating_index(clampf(player_score01, 0.0, 1.0)) if player_manned else OFF_DUTY
		elif String(m.get("duty", "")) == "Reserve":
			idx = OFF_DUTY   # aboard but posted to no station this voyage — off duty, not Booched
		else:
			var score : float = clampf(float(m.get("skill", FALLBACK_SKILL)) \
				+ randf_range(-VARIANCE, VARIANCE), 0.0, 1.0)
			idx = rating_index(score)
		report.append({
			"name": String(m.get("name", "")),
			# The player's duty reflects what they actually manned THIS leg (Loft vs Patchworks); fall back to
			# the roster's fixed duty for the AI crew (or if the caller didn't pass one).
			"duty": (player_duty if (is_player and not player_duty.is_empty()) else String(m.get("duty", ""))),
			"rating_idx": idx,
			"is_player": is_player,
			"tint": m.get("tint", Color.WHITE),
		})
	return report


static func _personality_by_name(n: String) -> NpcPersonality:

	for p in NpcRegistry.all():
		if p.npc_name == n:
			return p
	return null
