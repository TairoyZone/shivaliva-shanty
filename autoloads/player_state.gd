## Persistent player state — survives scene changes AND application restarts.
##
## Two flavors of state live here:
##
## Permanent (saved to user://save.cfg, restored on launch):
##   - total_coins           : the gold balance (HUD currency — NOT in the bag)
##   - inventory             : the slot-based backpack (Stardew-style). Holds
##                             stackable items (wood, future ore/planks/etc).
##                             `total_wood` is a convenience read of the wood count.
##   - inventory_capacity    : number of backpack slots (starts at 6, expandable later)
##   - hired_at_workshop     : has the player applied for Godfrey's lumberjacking job?
##   - godfrey_lumber_stock  : accumulated wood the player has delivered to Godfrey
##                             (drives the visible LumberPile + future ship-build gating)
##   - npc_affinity          : per-NPC rapport (name → 0..MAX_AFFINITY)
##   - last_scene            : the scene the player was in when they quit
##   - last_position         : where on that scene they were
##
## Transient (in-memory only — drives the next scene's spawn placement):
##   - pending_spawn_anchor : name of a Marker2D in the next scene to
##                            spawn at (set by a Door or a puzzle table
##                            before scene change)
##   - pending_spawn_position : raw position to spawn at (set on resume
##                              from a saved session)
##
## BaseLocation consumes the transient fields in _ready() — anchor takes
## priority, then position, then falls back to pirate_spawn_position.
extends Node


signal coins_changed(new_total: int)
## Fires whenever the backpack contents change (item added/removed, or
## capacity expanded). UI (the inventory overlay, bag button) listens.
signal inventory_changed
## Fires whenever the player's carried WOOD count specifically changes —
## a convenience signal so wood-aware UI (Workshop drop-off tooltip, the
## bag-button wood-gain feedback) doesn't have to recompute on every
## unrelated inventory change. Carries the new wood total.
signal wood_changed(new_total: int)
## Fires whenever Godfrey's accumulated lumber stock grows (or shrinks
## once ship-building consumes it). Drives the visible LumberPile prop
## inside the Workshop.
signal lumber_stock_changed(new_total: int)
## Mirror of [signal wood_changed] for ore — lets the Forge ore drop-off
## tooltip refresh when the carried ore count changes.
signal ore_changed(new_total: int)
## Mirror of [signal lumber_stock_changed] for Cinder Troy's accumulated
## ore stock. Drives the visible OrePile prop inside the Forge.
signal ore_stock_changed(new_total: int)
## Fires when the player's current onboarding objective MIGHT have changed
## (got hired, bought a ship). The InventoryPanel's Objectives tab listens +
## recomputes via [method current_objective]. (Coin/lumber progress updates ride
## the existing coins_changed / lumber_stock_changed signals.)
signal objective_changed
## Fires when the player buys a spacecraft. The ship-shop modal listens
## to refresh its rows (Buy → Owned).
signal ships_changed
## A trophy was JUST earned for the first time — (id, display_name). The HUD pops a
## [TrophyToast] (the YPP "Ye Received a Trophy!" beat). Detected by [method check_new_trophies].
signal trophy_earned(id: String, trophy_name: String)
signal trophy_claimed(id: String)   # accepted in the Ayo! tab (clears its badge)
## Fires when the player buys a Skirmish weapon. The forge weapon-shop listens
## to refresh its rows (Buy → Owned).
signal weapons_changed
## Fires whenever an NPC's rapport changes. UI (toasts, dialogue tier
## line) listens to surface the gain.
signal affinity_changed(npc_name: String, new_value: int, tier: String)
## Fires when a puzzle's mastery tier increases (a new best crossed a
## threshold). Puzzle result screens listen to pop the "NEW RANK" flourish.
signal mastery_ranked_up(puzzle_id: String, tier_index: int, tier_name: String)

const SAVE_PATH : String = "user://save.cfg"
const SAVE_SECTION : String = "player"
const STARTING_GOLD : int = 0
## The first-ship onboarding goal — mirrors the cheapest spacecraft in
## ship_shop.gd's catalog (the Driftpod). Drives [method current_objective].
const FIRST_SHIP_NAME : String = "Driftpod"
const FIRST_SHIP_GOLD : int = 750
const FIRST_SHIP_LUMBER : int = 0   # MVP: the first ship (Driftpod) is GOLD-ONLY (Troy 2026-06-03)
# Per-class hull caps live in ShipClasses.DEFS (components/ships/ — the single source of truth).
## Max holes the JOBBED pillage ship can take before she founders (someone else's stock hull). A
## SELF-captained run uses your own ship's class cap instead — see voyage_max_holes().
const VOYAGE_MAX_HOLES : int = 4
## A perfect hull starts the Loft at this Stardust (= the Loft's BASELINE, trivially aloft); each
## open hole raises the embark level a touch (a battered hull begins closer to the bite).
const STARDUST_BASE_START : float = 3.0
const STARDUST_START_PER_HOLE : float = 0.6
## A posted SAILING crew member keeps her aloft: each rating point shaves this off the Loft's per-move rise
## (live, floored at RISE_BASE) AND off the embark Stardust start. The reward for crewing a good sailor.
const SAILING_RISE_RELIEF_PER_RATING : float = 0.025
const SAILING_START_RELIEF_PER_RATING : float = 0.2
## Gold paid per wood delivered at the Workshop drop-off. 1:1 is
## intentional — Gem Drop tops out at +10 per match, a clean Lumberjacking
## session yields ~10-30 wood, so 1:1 puts wages in the same earning band
## as parlor games without making chopping trivially better.
const WOOD_TO_GOLD_RATE : float = 1.0
## Gold paid per ore delivered at the Forge drop-off. Ore pays DOUBLE wood
## (2026-05-31): Lumberjacking is open-ended so wood piles up, while Mining
## caps at CHUNK_TARGET per session, making ore the scarcer, harder-won
## (and thematically premium — forge → tech → spacecraft) material. The 2×
## rate rewards the tougher job so it isn't out-earned by easy chopping.
const ORE_TO_GOLD_RATE : float = 2.0
const MAX_AFFINITY : int = 100
## Rapport's floor — NPCs can genuinely HATE a player who earns it (chat offense, spurned duels).
const MIN_AFFINITY : int = -100
## Crew ranks (low → high) the player promotes a recruit through; recruiting needs Confidant rapport.
const CREW_RANKS : Array[String] = ["Deckhand", "Crewmate", "Officer", "First Mate"]
const RECRUIT_MIN_AFFINITY : int = 80

# --- Puzzle mastery (per-puzzle proficiency ladder) --------------------
## Reskin of YPP's per-puzzle "Standing" — but ABSOLUTE + non-decaying +
## alt-proof: your single BEST session score per puzzle (a high-water mark)
## sets your rank. One shared 6-tier ladder, tracked separately per puzzle.
## See [[ypp-template]] / [[roadmap]] (Phase 1).
const MASTERY_TIERS : Array = ["Greenhorn", "Hand", "Adept", "Master", "Ace", "Legend"]
## Per-puzzle config: display name + the best-score needed to REACH each
## tier (index-aligned to MASTERY_TIERS; index 0 = Greenhorn at 0). These
## thresholds are first-pass guesses — TUNE against real session scores.
const MASTERY_PUZZLES : Dictionary = {
	"lumberjacking": {"name": "Lumberjacking", "thresholds": [0, 20, 40, 65, 95, 135]},
	"mining": {"name": "Mining", "thresholds": [0, 20, 40, 65, 95, 135]},
	"gem_drop": {"name": "Gem Drop", "thresholds": [0, 15, 35, 60, 95, 140]},
	"poker": {"name": "Poker", "thresholds": [0, 25, 75, 150, 275, 450]},
	"skirmish": {"name": "Skirmish", "thresholds": [0, 2500, 5500, 10000, 16000, 24000]},
	"loft": {"name": "Lofting", "thresholds": [0, 120, 280, 480, 750, 1100]},
	"patchworks": {"name": "Patchworks", "thresholds": [0, 400, 1200, 2600, 4500, 7000]},
}
## ⭐ SUSTAINED mastery (Troy 2026-06-11): ranks are EARNED over MANY runs, never set by one best session. Each
## run adds "quality" = score ÷ that puzzle's PAR (= its thresholds[3] above, the old single-session "Master"
## score), capped at MASTERY_SESSION_CAP so no single run dominates, ×MASTERY_PAR_POINTS. puzzle_mastery
## ACCUMULATES that. So `thresholds` above now only supplies PAR (the per-puzzle score scale); the RANK ladder
## is shared, in accumulated points: a par run ≈ +25 pts, Master ≈ 14 par runs, Legend ≈ 50.
const MASTERY_RANK_POINTS : Array = [0, 50, 150, 350, 700, 1250]
const MASTERY_PAR_POINTS : float = 25.0   # a par-quality run's points (a 2× run = 50, the cap)
const MASTERY_SESSION_CAP : float = 2.0   # most quality one run can count for — so it can never one-shot a rank

# --- Inventory (Stardew-style slot backpack) -------------------------
## The canonical item id for raw lumber. Future puzzles add more ids
## (ore, planks, …) to [constant ITEM_DEFS]; the inventory is generic.
const ITEM_WOOD : String = "wood"
## The canonical item id for raw ore (mined at the Mine, delivered to
## Cinder Troy at the Forge).
const ITEM_ORE : String = "ore"
## Per-item definitions. max_stack is how many fit in one slot — Troy
## chose a "tight" backpack (small stacks) so space pressure is felt
## early and expansion matters.
const ITEM_DEFS : Dictionary = {
	"wood": {"name": "Wood", "max_stack": 50, "value": 1},   # value = the canonical delivery sale rate (WOOD_TO_GOLD_RATE),
	"ore": {"name": "Ore", "max_stack": 50, "value": 2},     # so NPC barter can never out-pay the dedicated delivery sinks
}
## Fallback stack cap for any item missing from ITEM_DEFS.
const DEFAULT_MAX_STACK : int = 50
## Slots the backpack starts with. Expandable later (buy a bigger
## backpack) via [method expand_inventory]; the value persists.
const INVENTORY_START_CAPACITY : int = 6
## Stardew-style backpack UPGRADES — pay gold to grow the bag, the ONLY way to add inventory space (buying an
## ITEM never expands it). Each tier = a TARGET slot count + its cost; start = INVENTORY_START_CAPACITY (6).
## Only TWO upgrades, ever (Troy 2026-06-11) — 6 → 12 → 18, then maxed. No indefinite growth.
const INVENTORY_BAG_TIERS : Array = [
	{"slots": 12, "cost": 300},
	{"slots": 18, "cost": 900},
]
# Tier thresholds (inclusive lower bound). Used for dialogue gating +
# the eventual hire/crew system — Confidant is the "can recruit" tier.
# Rapport runs NEGATIVE too (Troy 2026-06-10: "NPCs can hate players") — treat them badly enough
# and they sour: Wary → Disliked → Despised. Hate colours CHAT + favours only, never the core earn
# loop (the parlor LAW: affinity gates bonuses, not earning).
const AFFINITY_TIERS : Array = [
	{"min": 80, "name": "Confidant"},
	{"min": 50, "name": "Friend"},
	{"min": 20, "name": "Acquaintance"},
	{"min": 0,  "name": "Stranger"},
	{"min": -24, "name": "Wary"},
	{"min": -59, "name": "Disliked"},
	{"min": -100, "name": "Despised"},
]

# Permanent state — written to disk.
var total_coins : int = STARTING_GOLD :
	set(value):
		if total_coins == value:
			return
		total_coins = value
		coins_changed.emit(total_coins)
		_save()

## Lifetime gold EARNED — monotonic (only ever rises; ignores spending), so
## wealth-milestone trophies stay earn-and-keep. Persisted; bumped in
## [method add_coins].
var lifetime_coins_earned : int = 0

## The backpack: a dense Array of `inventory_capacity` slots. Each slot
## is either {} (empty) or {"id": String, "count": int}. Mutate ONLY via
## [method add_item] / [method remove_item] so signals + persistence fire.
var inventory : Array = []
## Number of backpack slots. Starts at [constant INVENTORY_START_CAPACITY];
## grows via [method expand_inventory]. Persisted.
var inventory_capacity : int = INVENTORY_START_CAPACITY

## Convenience read-only accessor for the carried wood count, so existing
## call sites (Workshop drop-off, HUD) can keep reading `total_wood`.
## Writes go through [method add_item] / [method remove_item].
var total_wood : int :
	get:
		return item_count(ITEM_WOOD)

## Convenience read-only accessor for the carried ore count (mirror of
## [member total_wood]). Writes go through [method add_item] / [method remove_item].
var total_ore : int :
	get:
		return item_count(ITEM_ORE)

## Spacecraft the player has bought from Cogwise Godfrey's ship shop, as
## an Array of ship-id Strings. Vanity ownership for now (the travel/
## sailing arc that uses them is far future); persisted. See
## [method buy_ship] / [method owns_ship].
var owned_ships : Array = []
## Christened names, keyed by ship id ("driftpod" → "Skylark"). Set at purchase (the shipwright's
## christening) or later at the dock. An unchristened ship falls back to her class name. Persisted.
var ship_custom_names : Dictionary = {}
## Which owned ship is ACTIVE — the one berthed at the dock, sailed on a self-captained voyage, and
## whose hull the condition helpers track. "" or a sold id falls back to the first owned. Persisted.
var active_ship : String = ""
## In-game time of day, in minutes since midnight (0..1440). Advanced by the [GameClock] autoload; NPCs read
## it so greetings match the hour. A plain persisted field (no setter — GameClock writes it every frame; the
## normal save cycle + quit persist it). Fresh game starts at 08:00. See game_clock.gd.
var game_minutes : float = 480.0
## The player's chosen name (typed at New Game) — the cast addresses + permanently REMEMBERS it (this is the
## name that doesn't fade from chat history). "" = unnamed (chat falls back to "traveller"). Persisted; set via
## [method set_player_name]. See [NpcBrain.compose_system]. (Troy 2026-06-10.)
var player_name : String = ""

## Persistent per-ship CONDITION, keyed by ship id → {"open_holes": int}. The ACTIVE ship's holes
## drive the Loft's Stardust rise (more holes ⇒ floods faster) + the sink; the Patchworks seals them.
## Round-trips in the save. See [[ship-condition-research]] / [[patchworks-spec]].
var ship_condition : Dictionary = {}

## TRANSIENT: holes on the SHIP YOU'RE CURRENTLY SAILING (the pillage ship — jobbed crew OR your own).
## During a voyage the condition helpers (ship_open_holes / add_hole / close_hole / wreck) operate on
## THIS, not the persisted owned-ship `ship_condition`, so the Loft / the Patchworks station / the sink
## all act on the ship you're actually crewing (YPP-style). Reset when a voyage ends. See [[ship-condition-research]].
var voyage_open_holes : int = 0
## TRANSIENT (not saved): per-leg DUTY-STATION assignments — station key ("Sailing"/"Repair"/"Combat") → the
## recruited crew npc manning it. You man one station live each leg; the crew at the OTHER two are auto-resolved
## by their [CrewSkills] rating. Wiped in [method clear_voyage]. See [[voyage-loop-research]].
var voyage_stations : Dictionary = {}
signal voyage_stations_changed
## TRANSIENT (not saved): true while you're sailing YOUR OWN ship (captained the Driftpod) rather than jobbing
## a crew. Seeds the voyage holes from your ship's persisted condition + writes them BACK on voyage end.
var voyage_self_captained : bool = false
## TRANSIENT (not saved): the display name of the ship this voyage (your owned ship's name when self-captained).
var pillage_ship_name : String = ""
## TRANSIENT (not saved): the OWNED-ship id this self-captained voyage sails ("" on a jobbed run). The
## write-back in clear_voyage targets THIS id — never active_ship_id(), which could in principle drift.
var pillage_ship_id : String = ""
## TRANSIENT (not saved): the hold multiplier scaling this voyage's plunder pool (the class "hold" stat
## on a self-captained run; 1.0 jobbed). Applied in voyage_total_gold so the chart pool shows it live.
var voyage_booty_mult : float = 1.0
## TRANSIENT (not saved): YOUR share of the plunder pool — 1.0 (keep all) when you captain your OWN ship; a
## jobbing crew's advertised cut (0.70–0.80) when you sign on under their captain (he keeps the rest). The
## divvy = pool × duty × this. Set on launch; reset to 1.0 by clear_voyage (audit 2026-06-10 — was dead text).
var pillage_jobber_cut : float = 1.0
## TRANSIENT (not saved): the last line the deck captain spoke — so re-entering the deck in the SAME
## phase doesn't re-announce/re-log the identical line (the deck is a fresh node each re-entry). Reset
## by clear_voyage so a new voyage greets you again. See ship_deck.gd `_say`.
var last_deck_say : String = ""

## The player's Skirmish weapons. You start with just FISTS (brawl); the rest are bought
## at Cinder Troy's forge ([WeaponShop]) → appended here. The EQUIPPED one is the attack
## your boarding/duel sends. Switched in the inventory (the Backpack tab), never mid-fight.
## See [SkirmishWeapon] / [[combat-puzzle-direction]].
var owned_weapons : Array = ["brawl"]
var equipped_weapon : String = "brawl"

## True once the player has signed up at the Hiring Board for Godfrey's
## lumberjacking job. Gates the WoodCuttingSign in the Forest — without
## this flag, the sign tells the player to apply at the Workshop first.
var hired_at_workshop : bool = false :
	set(value):
		if hired_at_workshop == value:
			return
		hired_at_workshop = value
		objective_changed.emit()
		_save()

## True once the player has seen the one-time opening welcome (shown on
## first launch in the shanty). Gates the IntroOverlay so it never repeats.
var has_seen_intro : bool = false :
	set(value):
		if has_seen_intro == value:
			return
		has_seen_intro = value
		_save()

## True once the player has won their first voyage — unlocks ongoing
## access to the frontier isle. Persisted.
var frontier_unlocked : bool = false :
	set(value):
		if frontier_unlocked == value:
			return
		frontier_unlocked = value
		_save()
		check_new_trophies()   # First Voyage trophy

# --- Voyage (transient, in-memory only — drives the Voyage scene flow) ---
## Scene to return to when a voyage ends ("Sail home"); set by the Skydock
## helm before launching the voyage.
var voyage_home_scene : String = ""
## (Removed: voyage_phase — dead orphan from the deleted voyages/voyage.gd; the LIVE phase machine is
## pillage_phase. It was unread/unwritten + unreset, an obvious-name trap. Audit 2026-06-10.)
## The wood yield of the most recent Lumberjacking session (set by
## lumberjacking.gd on commit; robust to a full backpack, unlike a
## carried-wood delta). The Voyage reads it as the boarding-fight result.
var last_lumberjacking_yield : int = 0
## The LIFT banked in the most recent Loft session (set by loft.gd on session
## end). The Voyage reads it as the MAKE-WAY result — it scales the booty and
## seeds the boarding fight (better sailing → an easier board).
var last_loft_lift : int = 0
## Swaps the player spent in that Loft session — with last_loft_lift gives the per-swap RATE
## that drives the duty report (so a short, sharp session still rates well; see [[duty-report]]).
var last_loft_swaps : int = 0
## Did the player win the most recent Skirmish duel? (Set by skirmish_duel.gd on
## end.) The Voyage reads it as the boarding-fight outcome.
var last_skirmish_won : bool = false
## Transient: how much the foe's Skirmish board is pre-buried at the start of a
## voyage boarding fight (the "arrival footing" — derived from last_loft_lift).
## Read + cleared by SkirmishDuel on load; 0 outside a voyage.
var voyage_boarding_seed : int = 0

## The walkable ShipDeck's pillage phase (re-entered after each station/fight
## scene-swap): 0 = just boarded (man the Loft); 1 = back from the Loft (a brigand —
## board them); 2 = back from the boarding fight (take your cut + disembark).
var pillage_phase : int = 0
## CANONICAL "this leg's boarding already fired" flag — set by BOTH the deck (_board_brigand) AND the station
## (_trigger_voyage_skirmish) when a fight starts, read by both before firing/resolving, reset on leg advance.
## ONE source so the deck + station can't disagree and double-fight a leg (audit 2026-06-10).
var pillage_fight_done : bool = false
## The crew the player jobbed onto at the Voyages board (set on Accept) — shown on
## the ShipDeck (captain name + banner). Empty = a generic crew.
var pillage_captain : String = ""
var pillage_crew : String = ""
## The voyage's ROUTE (set on Accept at the Voyages board): the destination name, how many
## STOPPING POINTS (legs) it takes, the current leg (0-based), and a LOG of per-leg job
## reports — drives the ship deck's voyage CHART. Transient; a fresh voyage re-sets them.
var pillage_destination : String = ""
## The ISLAND scene the voyage arrives at on completion (the nearest island). Empty falls
## back to sailing home. Bailing mid-voyage returns home instead.
var pillage_destination_scene : String = ""
var pillage_legs_total : int = 1
var pillage_leg : int = 0
var pillage_log : Array = []   # entries: {leg:int, type:"fight"|"calm", won:bool, lift:int, gold:int}
## One entry PER LEG, pre-rolled on Accept: "" = a calm sailing stretch (no fight),
## a non-empty FOE name (e.g. "a marine cutter") = an ENCOUNTER that triggers the boarding
## Skirmish. So fights happen only when you MEET a ship, never on every stop.
var pillage_encounters : Array = []
## For each encounter leg, WHERE along the leg (0..1) you meet the foe — pre-rolled on Accept so
## the swords sit at a random spot BETWEEN the stops (not pinned to a node) and the fight fires there.
var pillage_encounter_pos : Array = []
## True from boarding a crew (Accept) until you disembark — lets the voyage stations (e.g.
## the Loft) know they're being played AS PART of a pillage, so they can show the chart.
var voyage_active : bool = false
## The voyage chart sloop's live position (0..1 along the whole route). Persisted across the
## deck↔Loft scene swaps so she keeps sailing CONTINUOUSLY instead of snapping back each load.
var voyage_ship_t : float = 0.0
## Snapshot of WHICHEVER voyage station you're manning (the Loft OR the Patchworks), carried across a
## boarding: a fight swaps to the Skirmish scene (freeing the board), so we serialize the station's
## board here + restore it on return. Only ONE station is manned per leg, so one shared key never
## collides. Empty = no snapshot pending (fresh board). See [VoyageStationScene].
var voyage_station_state : Dictionary = {}
## Per-leg measurement baseline: the CUMULATIVE lift + swaps at the current leg's START. The leg's
## duty rating = (current − this) ÷ swaps-this-leg, so each leg's report rates THAT stretch even
## though the board (and its running totals) carry straight across legs + boardings.
var voyage_leg_lift0 : int = 0
var voyage_leg_swaps0 : int = 0
## ⭐ THE SINGLE SOURCE OF TRUTH for WHO IS ABOARD this voyage (built once on Accept / on captain_own_voyage):
## the captain + cast hands at the stations + you at the Loft. Stable for the whole pillage. Entries:
## {name,duty,skill,tint,is_player}. Reflects the REAL crew — your recruited hands when you self-captain (or
## just you, sailing solo), the captain's crew when jobbing (see DutyReport.build_roster / build_roster_self).
## EVERY voyage-crew consumer reads THIS array — the deck (ship_deck `_add_crew`), the DUTY REPORT
## (DutyReport.snapshot → the LAST leg's rated {name,duty,rating_idx,…}), the BOARDING fighters
## (BoardingMelee._voyage_ally_personas), and the NPC chat voyage block. Do NOT invent a separate crew
## roster anywhere — read this one, or solo/crewed/jobbed will drift apart again (Troy 2026-06-10).
var pillage_duty_crew : Array = []
var last_duty_report : Array = []

## --- Voyage payout / footing tuning (shared by the Loft + the ship deck) ---
## Each WON boarding adds a FLAT cut to the plunder POOL; a LOST one grabs a little scrap (so a
## fought leg isn't a flat zero); a CALM leg pays nothing (gold is plunder from a crew, not a toll).
## The WHOLE pool is then scaled at the divvy by your OVERALL duty (voyage_duty_multiplier) — the
## YPP way: your share of the plunder reflects how well you served the crossing. Two separate knobs:
## the per-battle cut is FLAT, the END divvy is performance.
const BATTLE_CUT_WON : int = 60
const BATTLE_CUT_LOST : int = 15
## End-of-voyage divvy multiplier per duty rating tier [Booched, Poor, Fine, Good, Excellent,
## Incredible] — your cut of the whole pool scales with how you flew the Loft across the voyage.
const DUTY_DIVVY_MULT : Array[float] = [0.5, 0.7, 0.9, 1.2, 1.5, 2.0]
## Arrival footing: how much the foe's Skirmish board is pre-buried, from the Loft lift.
const SEED_PER_LIFT_DIV : int = 150
const SEED_CAP : int = 3
## Your DUTY-REPORT rating is a RATE — lift banked per swap — so a short leg still rates by HOW
## WELL you flew, not how long the crew let you puzzle. This is the lift/swap that earns Incredible.
## Calibrated to Troy's real capture (a GOOD leg ≈ 8 lift/swap): at 12 that reads Good/Excellent,
## ~10.6+ earns Incredible, a weak leg Poor, a do-nothing leg Booched.
const DUTY_RATE_FOR_TOP : float = 12.0


# Resolve one voyage leg (shared by the Loft cockpit and the ship deck): bank the cut, snapshot
# the duty report (your row rated on lift-per-swap), log the leg, and advance / mark arrival.
# Returns {arrived:bool, cut:int, outcome_line:String}.
func resolve_voyage_leg(is_fight: bool, won: bool, lift: int, swaps: int, mastery_id: String = "loft", mastery_score: int = -1, player_manned: bool = true) -> Dictionary:

	# If the player WATCHED this leg (never manned a station — the deck-side resolve), they did NO duty: zero
	# their lift/swaps so the report reads "off duty" (not Booched) and the overall duty isn't skewed by stale
	# carry-over from a leg they DID man. (Troy 2026-06-09: "booched" with no job taken.)
	if not player_manned:
		lift = 0
		swaps = 0
	# Gold = your CUT OF THE PLUNDER from DEFEATING a crew (pirates / marines), the YPP way — NOT
	# a payout for reaching a waypoint. A calm stretch is just sailing: no fight, no plunder. Each
	# fight adds a FLAT cut to the POOL (pillage_log); the WHOLE pool is then scaled by your overall
	# duty at the divvy (voyage_final_cut / cash_out_voyage) — performance lives at the END, not here.
	var cut : int = 0
	if is_fight:
		cut = BATTLE_CUT_WON if won else BATTLE_CUT_LOST
		# Enemy fire opens hull HOLES this fight — a loss takes more than a win. Persists on the active
		# ship + drives the Loft's Stardust rise on later legs (more holes ⇒ floods faster). [[ship-condition-research]]
		add_hole(2 if not won else 1)

	# A posted REPAIR hand seals holes you didn't patch BY HAND this leg — skipped when you manned the Patchworks
	# live (mastery_id=="patchworks"), whose block-blast already closed holes (no double-dip). Lands BEFORE the
	# next leg's _push_effective_rise reads the hole count, so the relief bites immediately. r3-4 seals 1, r5 → 2.
	if mastery_id != "patchworks":
		var repair_rating : int = voyage_station_skill("Repair")
		var sealed : int = (2 if repair_rating >= 5 else (1 if repair_rating >= 3 else 0))
		if sealed > 0:
			close_hole(sealed)
			log_event("%s patched %d hole%s below decks" % [
				voyage_station_npc("Repair"), sealed, "" if sealed == 1 else "s"], Color(0.7, 0.95, 0.8))

	# This leg's duty rating is a RATE — lift banked per swap THIS stretch (the caller passes the
	# per-leg delta on a continuous crossing). Both lift + swaps are logged so the end divvy can
	# rate the WHOLE voyage (voyage_duty_score01).
	var score01 : float = clampf((float(lift) / maxf(1.0, float(swaps))) / DUTY_RATE_FOR_TOP, 0.0, 1.0)
	if not pillage_duty_crew.is_empty():
		var player_duty : String = "The Patchworks" if mastery_id == "patchworks" else DutyReport.PLAYER_DUTY
		last_duty_report = DutyReport.snapshot(pillage_duty_crew, score01, player_duty, player_manned)
	# A leg feeds its STATION's high-water-mark mastery (Loft legs → Lofting by lift; Patchworks legs →
	# Patchworks by board score). Defaults to Lofting/lift. Silent — no mid-voyage toast.
	record_puzzle_result(mastery_id, mastery_score if mastery_score >= 0 else lift)
	pillage_log.append({"leg": pillage_leg, "type": ("fight" if is_fight else "calm"),
		"won": won, "lift": lift, "swaps": swaps, "gold": cut})

	# Live event feed: the plunder this fight (the pool grows — your cut is the end divvy) + any hull
	# holes the enemy opened, or a calm stretch. The booty itself pays out at voyage's end, pooled.
	if is_fight:
		log_event("Plundered %d booty — pool now %d" % [cut, voyage_total_gold()], Color(0.85, 1.0, 0.7))
		# The pillage ship took hull damage this fight (voyage_open_holes) — narrate it.
		var holed : int = 2 if not won else 1
		log_event("Enemy fire opened %d hole%s in the hull" % [holed, "" if holed == 1 else "s"], Color(1.0, 0.6, 0.5))
	else:
		log_event("A calm stretch — no plunder, but she's aloft", Color(0.78, 0.85, 0.95))

	var outcome : String
	if is_fight:
		outcome = ("We took 'em — %d gold to the hold!" % cut) if won \
			else ("They broke off — %d gold from the scrap." % cut)
	else:
		outcome = "Clear skies — a fair stretch. No plunder, but she's aloft and on course."

	var arrived : bool = pillage_leg >= pillage_legs_total - 1
	if arrived:
		frontier_unlocked = true
	else:
		pillage_leg += 1
		pillage_phase = 0
		pillage_fight_done = false   # next leg starts fresh — its boarding hasn't fired yet
	return {"arrived": arrived, "cut": cut, "outcome_line": outcome}


# The boarding footing seed from a Loft lift (capped). Set into voyage_boarding_seed before a fight.
func voyage_seed_from_lift(lift: int) -> int:

	@warning_ignore("integer_division")
	var base : int = clampi(lift / SEED_PER_LIFT_DIV, 0, SEED_CAP)
	# A posted COMBAT hand sharpens arrival footing — each rating point above 3 pre-buries the foe one more
	# clump (r4 → +1, r5 → +2), past the usual lift cap. Consumed in boarding_melee / skirmish_duel footing.
	var combat : int = maxi(0, voyage_station_skill("Combat") - 3)
	return clampi(base + combat, 0, SEED_CAP + 2)


# The pooled plunder logged across the voyage so far — the sum of the per-battle cuts BEFORE the
# duty divvy (the chart's "Haul" + the haul card's pool line).
func voyage_total_gold() -> int:

	var t : int = 0
	for r in pillage_log:
		t += int(r.get("gold", 0))
	# The class "hold" stat: a bigger hull carries home a bigger pool (×1.0 jobbed / Driftpod,
	# ×1.3 Cloud Cutter, ×1.6 Sky Galleon). Applied here so the chart's live pool shows it too.
	return roundi(float(t) * voyage_booty_mult)


# The OVERALL duty score (0..1) across the WHOLE voyage so far — total lift per total swap, the
# same rate the per-leg report uses but summed end-to-end. Drives the divvy multiplier.
func voyage_duty_score01() -> float:

	var lift_sum : int = 0
	var swap_sum : int = 0
	for r in pillage_log:
		lift_sum += int(r.get("lift", 0))
		swap_sum += int(r.get("swaps", 0))
	if swap_sum <= 0:
		return 0.0
	return clampf((float(lift_sum) / float(swap_sum)) / DUTY_RATE_FOR_TOP, 0.0, 1.0)


# The voyage's overall duty RATING index (0 Booched .. 5 Incredible) — for the haul card. Returns the OFF_DUTY
# sentinel if you manned NO station the whole run (a passenger, not a botcher — watched legs record 0/0 swaps).
func voyage_duty_rating_index() -> int:

	var swap_sum : int = 0
	for r in pillage_log:
		swap_sum += int(r.get("swaps", 0))
	if swap_sum <= 0:
		return DutyReport.OFF_DUTY
	return DutyReport.rating_index(voyage_duty_score01())


# The divvy multiplier your overall duty earns (×0.5 Booched .. ×2.0 Incredible). A pure passenger (manned
# nothing) gets a fair PAR cut (×1.0) — no duty bonus, but not the Booched penalty either.
func voyage_duty_multiplier() -> float:

	var idx : int = voyage_duty_rating_index()
	if idx == DutyReport.OFF_DUTY:
		return 1.0
	return DUTY_DIVVY_MULT[clampi(idx, 0, DUTY_DIVVY_MULT.size() - 1)]


# Your FINAL cut: the whole pooled plunder scaled by your overall duty multiplier — the YPP divvy
# (a flat pool from the battles, then your share reflecting how well you flew the whole crossing).
func voyage_final_cut() -> int:

	return roundi(float(voyage_total_gold()) * voyage_duty_multiplier() * pillage_jobber_cut)


# Pay out your FINAL cut — the pooled booty scaled by your overall duty (YPP-style, paid at voyage's
# end, not per stop). Returns the total paid. Call ONCE before clear_voyage on disembark.
func cash_out_voyage() -> int:

	var total : int = voyage_final_cut()
	if total > 0:
		add_coins(total, "Voyage's cut  (×%.1f duty)" % voyage_duty_multiplier())
	return total


## Gold toll to be towed home + dry-docked after a sinking (on top of forfeiting the whole booty pool).
const SINK_REPAIR_TOLL : int = 80

## The ship SANK on a fight leg — LOST IN THE STARDUST. Forfeit the un-cashed booty pool (we DON'T
## cash out), charge a gold TOW toll, and WRECK her (max holes) — she limps home and must be mended at
## the Patchworks before sailing again. The owned-ship DEED is KEPT (earn-and-keep).
## Returns {forfeited, toll, home} so the Loft can show the loss + relocate. See [[ship-condition-research]].
func sink_voyage() -> Dictionary:

	var forfeited : int = voyage_final_cut()   # the cut you WOULD have banked — now lost in the Stardust
	var toll : int = mini(SINK_REPAIR_TOLL, total_coins)   # can't drive the purse negative
	if toll > 0:
		add_coins(-toll, "Towed home from the Stardust")
	wreck_active_ship()   # she arrives home WRECKED (max holes) — mend her at the Patchworks before sailing again
	log_event("LOST IN THE STARDUST — she went under", Color(1.0, 0.5, 0.5))
	var home : String = voyage_home_scene if not voyage_home_scene.is_empty() else "res://levels/shore/shore.tscn"
	clear_voyage()   # forfeits the pool (no cash-out); the wreck PERSISTS (no auto-mend)
	return {"forfeited": forfeited, "toll": toll, "home": home}


# Wipe all transient voyage/pillage scaffolding — called when a voyage ENDS (disembark, whether
# arrived or bailed) or a straight fare is taken, so nothing stale bleeds into the next run.
func clear_voyage() -> void:

	# A SELF-CAPTAINED run writes its final hull state BACK to your owned ship's persisted condition (so the
	# Driftpod actually accrues + keeps the damage you took, and the port Patchworks has something to mend).
	# Done FIRST, while voyage_open_holes still holds the run's final holes (a sink already maxed it via wreck).
	if voyage_self_captained:
		# Write to the ship that SAILED (pillage_ship_id), not active_ship_id() — identical today (the
		# dock refuses swaps mid-voyage), but correct by construction. Falls back for safety.
		var sid : String = pillage_ship_id if not pillage_ship_id.is_empty() else active_ship_id()
		if not sid.is_empty():
			var cond : Dictionary = ship_condition.get(sid, {})
			cond["open_holes"] = clampi(voyage_open_holes, 0, ship_max_holes(sid))
			ship_condition[sid] = cond
			_save()
	voyage_self_captained = false
	pillage_ship_name = ""
	pillage_ship_id = ""
	voyage_booty_mult = 1.0
	pillage_jobber_cut = 1.0
	voyage_active = false
	voyage_ship_t = 0.0
	pillage_phase = 0
	pillage_leg = 0
	pillage_fight_done = false
	pillage_legs_total = 1
	pillage_log = []
	pillage_encounters = []
	pillage_destination = ""
	pillage_destination_scene = ""
	pillage_captain = ""
	pillage_crew = ""
	pillage_duty_crew = []
	last_duty_report = []
	pillage_encounter_pos = []
	voyage_station_state = {}
	voyage_leg_lift0 = 0
	voyage_leg_swaps0 = 0
	voyage_boarding_seed = 0   # don't bleed a stale footing seed into the next (maybe friendly) Skirmish
	last_loft_lift = 0         # AND its upstream source — else a WATCHED encounter leg seeds boarding footing
	last_loft_swaps = 0        # from a PRIOR voyage's Loft run (audit 2026-06-10). Watched = no duty = no footing.
	voyage_open_holes = 0      # the pillage SHIP's holes are transient — the next voyage's ship starts fresh
	voyage_stations = {}       # drop stale crew assignments (a dismissed hand mustn't bleed into the next run)
	last_deck_say = ""         # so the next voyage's captain greets you again instead of staying silent
	# The voyage stations set puzzle_return_scene to the ship deck so a station returns there. Once the voyage
	# ENDS it must be cleared, or it leaks: a puzzle launched later (e.g. poker from the Inn) would read the
	# stale deck path on Leave and warp the player back into the (now-over) voyage. (Troy 2026-06-09 bug.)
	puzzle_return_scene = ""
	# (Your OWNED ship's persisted condition (`ship_condition`) is separate + survives, repaired at the
	# Skydock's Patchworks post. The in-voyage Patchworks station mends the CURRENT pillage ship.)
	# A boarding melee still in flight (you stepped away, never rejoined, then bailed) is abandoned too.
	BoardingMelee.clear()

## Transient: the chosen Skirmish-duel opponent's NPC resource path. Set by the
## Spar post's challenge picker; consumed (and cleared) by SkirmishDuel on load.
var skirmish_opponent : String = ""

# --- Tournament (transient — drives the TournamentScene bracket flow) ---
## True while the player is in a tournament bracket.
var tournament_active : bool = false
## The 3 rival NPC profile paths in the bracket (the player is the 4th seed).
var tournament_field : Array = []
## 1 = semifinal, 2 = final.
var tournament_round : int = 1
## Gold prize pool the champion takes.
var tournament_pot : int = 0
## True while a bracket match is being played, so the TournamentScene knows
## to score the result when it loads again.
var tournament_awaiting : bool = false
## How the player's bracket run currently stands.
enum TournamentOutcome { IN_PROGRESS, CHAMPION, KNOCKED_OUT }
## Current outcome of the player's run. See [enum TournamentOutcome].
var tournament_outcome : TournamentOutcome = TournamentOutcome.IN_PROGRESS
## The other finalist's profile path — the winner of the parallel semifinal,
## decided once the player wins their semi; becomes the final opponent.
var tournament_finalist : String = ""
## Scene to return to when the tournament ends (the Inn).
var tournament_home : String = ""
## Result of the most recent Gem Drop match — set by GemDropScene on exit,
## read by the TournamentScene to advance the bracket.
var last_gem_drop_won : bool = false

## Accumulated wood the player has delivered to Cogwise Godfrey. Survives
## drop-offs (it's HIS stock, separate from the player's [member total_wood]).
## Drives the visible LumberPile in the Workshop + future ship-build gating.
var godfrey_lumber_stock : int = 0 :
	set(value):
		var clamped : int = max(0, value)
		if godfrey_lumber_stock == clamped:
			return
		godfrey_lumber_stock = clamped
		lumber_stock_changed.emit(godfrey_lumber_stock)
		_save()

## True once the player has signed up at the Forge Hiring Board for Cinder
## Troy's mining job. Gates the MiningSign in the Mine.
var hired_at_forge : bool = false :
	set(value):
		if hired_at_forge == value:
			return
		hired_at_forge = value
		objective_changed.emit()
		_save()

## Accumulated ore the player has delivered to Cinder Troy (his stock,
## separate from the player's [member total_ore]). Drives the visible
## OrePile in the Forge + future smithing gating. Mirrors godfrey_lumber_stock.
var cinder_ore_stock : int = 0 :
	set(value):
		var clamped : int = max(0, value)
		if cinder_ore_stock == clamped:
			return
		cinder_ore_stock = clamped
		ore_stock_changed.emit(cinder_ore_stock)
		_save()

## Per-NPC rapport. Keyed by the NPC's full name ("Hearty Brian").
## Persisted to disk. Read via [method get_affinity] / [method affinity_tier].
var npc_affinity : Dictionary = {}

## Per-NPC lifetime favour count (name → times the player has done a small
## favour for them). Persisted. Bumped via [method record_favor]; drives
## "you've helped me N times" warmth + is the hook for future favour
## milestones. See [[parlor-social-system]].
var npc_favor_done : Dictionary = {}

## Your CREW — npc_name → rank INDEX into [constant CREW_RANKS]. Persisted; the foundation for the hire/rank
## system (the NPC profile recruits + ranks them). You may only recruit a CONFIDANT (rapport ≥
## [constant RECRUIT_MIN_AFFINITY]), per [constant AFFINITY_TIERS]' design note.
var crew : Dictionary = {}
signal crew_changed

## Favours the player has ACCEPTED but not yet turned in (name → {item,
## amount}). Persisted. Surfaced in the Objectives log via
## [method current_quests]; added ONLY by an explicit
## [method accept_favor] (never on a mere offer) and removed by
## [method complete_favor] on turn-in, so a favour never lingers as "done".
var active_favors : Dictionary = {}

## NPC-issued Skirmish CHALLENGES the player hasn't answered yet (npc names). Filed when a chat AI drops the
## [[DUEL]] marker (an argument / bravado / the player goading them); shown in the Ayo! tab → Accept (launch the
## duel) / Reject (dismiss). Persisted. See [[ayo-tidings-inbox]].
var pending_challenges : Array = []
signal challenges_changed

## Head-to-head Skirmish RECORD per NPC, the player's perspective: npc_name -> {wins, losses} (wins = times the
## PLAYER beat that NPC; losses = times that NPC beat the player). Persisted — battle MEMORY so the cast knows
## the score (fed into chat context so an NPC never denies a defeat it actually suffered + the NPC profile shows
## the tally). Mutate ONLY via [method record_battle]. See [[npc-battle-memory]].
var npc_battle_record : Dictionary = {}
## Max chat turns kept PER NPC (a cost + save-size guard — the last ~8 exchanges).
const NPC_CHAT_LOG_CAP : int = 16
## Persistent per-NPC CHAT HISTORY — {npc_name: Array[{role, content}]} — so a cast member REMEMBERS past
## conversations across scene changes AND a full reload (Troy 2026-06-10). Bounded to the last NPC_CHAT_LOG_CAP
## turns; stage-direction openings aren't stored. Read via [method npc_chat_history]; written by [NpcBrain].
var npc_chat_log : Dictionary = {}
## One-shot record of the MOST RECENT duel — {npc, player_won} — set on duel end, NOT persisted (transient,
## lives in the autoload across the scene cut back to the overworld). Drives the post-fight banter bubble + a
## "this was just now" freshness note in chat. Overwritten by the next duel; cleared on New Game.
var recent_duel : Dictionary = {}
signal battle_record_changed

## Lifetime tournaments won (champion count). Persisted — an earn-only
## achievement stat. Bumped via [method record_tournament_win].
var tournaments_won : int = 0

## Per-puzzle BEST session score (high-water mark), keyed by puzzle id
## (see [constant MASTERY_PUZZLES]). Drives the mastery tier. Persisted.
## Mutate only via [method record_puzzle_result].
var puzzle_mastery : Dictionary = {}
## Trophy ids the player has already been NOTIFIED of (so each toasts ONCE). Seeded with
## currently-earned trophies on load so existing ones never re-toast; persisted.
var trophies_seen : Array = []
## Trophies the player has ACCEPTED in the Ayo! tab. Earned-but-unclaimed = the Ayo! badge. Persisted.
var trophies_claimed : Array = []

var last_scene : String = ""
var last_position : Vector2 = Vector2.ZERO

# Transient spawn intent — consumed by the next BaseLocation._ready().
## When a PuzzleScene should return somewhere OTHER than last_scene on
## exit (e.g. a Voyage launches Lumberjacking as a boarding fight and wants
## it back). Transient; PuzzleScene._return_to_launching_scene prefers +
## clears it. Keeps last_scene pointing at a real resumable location.
var puzzle_return_scene : String = ""

# --- Parlor lobby (transient, in-memory only) -------------------------
## Resource paths of the NPC profiles the [ParlorBrowser] seated for the parlor
## game about to launch. The parlor scene loads these so its opponents
## match the faces the player just watched fill the table. Consumed
## (cleared) by [method consume_lobby_setup] on the scene's _ready.
var lobby_seated_paths : Array = []
## True when the player chose a FREE table — no buy-in, no gold won or
## lost, just rapport. The parlor scene reads this to suppress every gold
## change while still granting affinity. Consumed with the above.
var free_table : bool = false
## Per-table config the browser chose (poker: {structure, min_bet, seats, turn_time}; empty for
## simple games like Gem Drop). The poker scene reads it via [method consume_lobby_setup]. Transient.
var lobby_table_config : Dictionary = {}
## The table seated last time (any parlor game), kept in-memory so the
## next lobby can EXCLUDE those faces and avoid back-to-back repeats. Not
## consumed — it's the cross-session memory, reset only on a game restart.
var last_lobby_seated_paths : Array = []

var pending_spawn_anchor : String = ""
var pending_spawn_position : Vector2 = Vector2.ZERO
var _has_pending_position : bool = false

## Guard: suppresses [method _save] while [method _load] is assigning
## fields. Without it, the property setters (which each call _save) would
## write the file mid-load — persisting still-default npc_affinity /
## last_scene / last_position over the very data being read back, losing
## it on a later crash. Also lets [method clear_save] reset many fields
## with a single final write instead of one per field.
var _suppress_save : bool = false


func _ready() -> void:

	_init_inventory()
	_load()


func _notification(what: int) -> void:

	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_session()


## Emitted for the running EVENT LOG (the [EventFeed] overlay): a one-line record of something
## noteworthy — a coin change with its reason, a plunder, a hull hole. A tint colour comes with it.
signal event_logged(text: String, color: Color)


## Push a line to the event feed (the always-on log overlay). Gold-neutral tint by default.
func log_event(text: String, color: Color = Color(1.0, 0.92, 0.55)) -> void:

	event_logged.emit(text, color)


## Credit (or debit, if negative) gold. Pass a `reason` to ALSO log it to the event feed
## ("+60  Plundered the foe") — omit it for the noisy per-match trickles (the purse animation suffices).
func add_coins(amount: int, reason: String = "") -> void:

	# Track lifetime earnings (monotonic) BEFORE the total_coins setter fires
	# _save(), so the new lifetime value lands in the same write.
	if amount > 0:
		lifetime_coins_earned += amount
		Audio.play_sfx("coin")   # the gold-earned chime (first audio call site — more to come)
	total_coins = maxi(0, total_coins + amount)   # gold NEVER goes negative — you can't spend what you lack
	check_new_trophies()   # Full Purse + a periodic sweep for any newly-earned trophy
	if not reason.is_empty() and amount != 0:
		log_event("%s%d  %s" % ["+" if amount >= 0 else "", amount, reason],
			Color(0.55, 1.0, 0.55) if amount >= 0 else Color(1.0, 0.55, 0.55))


# --- Inventory ---------------------------------------------------------

# Fill the backpack with `inventory_capacity` empty slots. Called once
# in _ready before _load (which may overwrite it with saved contents).
func _init_inventory() -> void:

	inventory = []
	for _i in inventory_capacity:
		inventory.append({})


func _max_stack(item_id: String) -> int:

	if is_weapon(item_id):
		return 1   # weapons don't stack — each is its own slot
	var def : Dictionary = ITEM_DEFS.get(item_id, {})
	return int(def.get("max_stack", DEFAULT_MAX_STACK))


## The gold value of one unit of an item — drives NPC barter (what they'll pay) + future shoppes.
func item_value(item_id: String) -> int:

	return int((ITEM_DEFS.get(item_id, {}) as Dictionary).get("value", 1))


## Total count of [param item_id] across every slot.
func item_count(item_id: String) -> int:

	var total : int = 0
	for slot in inventory:
		if not slot.is_empty() and slot["id"] == item_id:
			total += int(slot["count"])
	return total


## How many MORE of [param item_id] the backpack can hold right now —
## remaining room in existing partial stacks plus empty slots × max_stack.
func space_for(item_id: String) -> int:

	var cap : int = _max_stack(item_id)
	var room : int = 0
	for slot in inventory:
		if slot.is_empty():
			room += cap
		elif slot["id"] == item_id:
			room += maxi(0, cap - int(slot["count"]))
	return room


## True if every slot is occupied (no empties). Note: a non-full bag may
## still reject an item if its matching stacks are all maxed — use
## [method space_for] for an exact "can this fit" check.
func is_inventory_full() -> bool:

	for slot in inventory:
		if slot.is_empty():
			return false
	return true


## Add [param count] of [param item_id]. Tops up existing partial stacks
## first, then fills empty slots, each capped at the item's max_stack.
## Returns the OVERFLOW — the amount that did NOT fit (0 = all stored).
## The caller decides what to do with overflow (warn, drop, etc.).
func add_item(item_id: String, count: int) -> int:

	if count <= 0:
		return maxi(0, count)
	var cap : int = _max_stack(item_id)
	var remaining : int = count
	# Pass 1: top up existing partial stacks of this item.
	for slot in inventory:
		if remaining <= 0:
			break
		if not slot.is_empty() and slot["id"] == item_id and int(slot["count"]) < cap:
			var add : int = mini(remaining, cap - int(slot["count"]))
			slot["count"] = int(slot["count"]) + add
			remaining -= add
	# Pass 2: fill empty slots with fresh stacks.
	for i in inventory.size():
		if remaining <= 0:
			break
		if inventory[i].is_empty():
			var add : int = mini(remaining, cap)
			inventory[i] = {"id": item_id, "count": add}
			remaining -= add
	if remaining != count:
		_on_inventory_mutated(item_id)
		Audio.play_sfx("thunk")   # something landed in the backpack — central, covers wood/ore/all items
		var iname : String = String((ITEM_DEFS.get(item_id, {}) as Dictionary).get("name", item_id.capitalize()))
		log_event("+%d %s" % [count - remaining, iname], Color(0.78, 0.92, 0.7))
	return remaining


## Remove up to [param count] of [param item_id]. Returns the amount
## actually removed (may be less if the bag held fewer). Empties any slot
## that hits zero.
func remove_item(item_id: String, count: int) -> int:

	if count <= 0:
		return 0
	var remaining : int = count
	for i in inventory.size():
		if remaining <= 0:
			break
		var slot : Dictionary = inventory[i]
		if slot.is_empty() or slot["id"] != item_id:
			continue
		var take : int = mini(remaining, int(slot["count"]))
		var left : int = int(slot["count"]) - take
		inventory[i] = {} if left <= 0 else {"id": item_id, "count": left}
		remaining -= take
	var removed : int = count - remaining
	if removed > 0:
		_on_inventory_mutated(item_id)
	return removed


## Drag-drop core (Minecraft/Stardew arrange): move [param amount] (-1 = the whole stack) of the item in slot
## [param from] onto slot [param to]. EMPTY target → place it there; the SAME item → merge up to its stack cap
## (any leftover stays in `from`); a DIFFERENT item → SWAP the two slots (whole-stack moves only — you can't
## drop a partial split onto another item). Bounds-checked; no-ops on a junk/no-op move. Emits inventory_changed.
func move_inventory(from: int, to: int, amount: int = -1) -> void:

	if from == to or from < 0 or to < 0 or from >= inventory.size() or to >= inventory.size():
		return
	var src : Dictionary = inventory[from]
	if src.is_empty():
		return
	var src_id : String = String(src["id"])
	var src_n : int = int(src["count"])
	var move_n : int = src_n if amount < 0 else clampi(amount, 1, src_n)
	var dst : Dictionary = inventory[to]
	if dst.is_empty():
		inventory[to] = {"id": src_id, "count": move_n}
		inventory[from] = {} if src_n - move_n <= 0 else {"id": src_id, "count": src_n - move_n}
	elif String(dst["id"]) == src_id:
		var merged : int = mini(move_n, maxi(0, _max_stack(src_id) - int(dst["count"])))
		if merged <= 0:
			return   # target stack already full of this item — nothing moved
		inventory[to] = {"id": src_id, "count": int(dst["count"]) + merged}
		inventory[from] = {} if src_n - merged <= 0 else {"id": src_id, "count": src_n - merged}
	else:
		if amount >= 0 and move_n != src_n:
			return   # can't drop a PARTIAL stack onto a different item — only a full-stack swap
		inventory[from] = dst
		inventory[to] = src
	inventory_changed.emit()


## Grow the backpack by [param extra] slots (the future "buy a bigger
## backpack" upgrade). Persists.
func expand_inventory(extra: int) -> void:

	if extra <= 0:
		return
	inventory_capacity += extra
	for _i in extra:
		inventory.append({})
	inventory_changed.emit()
	_save()


## The next backpack upgrade ({slots, cost}), or {} if the bag is fully upgraded.
func next_bag_upgrade() -> Dictionary:

	for tier in INVENTORY_BAG_TIERS:
		if int(tier["slots"]) > inventory_capacity:
			return tier
	return {}


## Buy the next backpack upgrade if one's available AND affordable — spends gold, grows the bag. true on
## success. The ONLY path that adds inventory space (an item purchase must FIT existing slots, never expand).
func buy_bag_upgrade() -> bool:

	var tier : Dictionary = next_bag_upgrade()
	if tier.is_empty() or total_coins < int(tier["cost"]):
		return false
	add_coins(-int(tier["cost"]), "Bigger backpack")
	expand_inventory(int(tier["slots"]) - inventory_capacity)
	return true


# Fire the change signals + persist after any add/remove. Emits the
# specific wood_changed too when wood was the item touched.
func _on_inventory_mutated(item_id: String) -> void:

	inventory_changed.emit()
	if item_id == ITEM_WOOD:
		wood_changed.emit(item_count(ITEM_WOOD))
	elif item_id == ITEM_ORE:
		ore_changed.emit(item_count(ITEM_ORE))
	_save()


# --- Wood / lumberjacking ----------------------------------------------

## Credit the player with wood from a Lumberjacking session. Returns the
## OVERFLOW (wood that didn't fit in the backpack) so the caller can warn
## the player their bag was too full to hold the whole haul.
func add_wood(amount: int) -> int:

	if amount <= 0:
		return 0
	return add_item(ITEM_WOOD, amount)


## Player drops `amount` of carried wood at Godfrey's Workshop. Wood
## moves from the backpack into Godfrey's stock, and the player is paid
## gold at the [member WOOD_TO_GOLD_RATE]. Caller passes a
## reasonable amount (typically [member total_wood] for a full drop-off).
## Returns the gold actually paid, so the UI can show a clean toast.
func deliver_wood(amount: int) -> int:

	var removed : int = remove_item(ITEM_WOOD, amount)
	if removed <= 0:
		return 0
	godfrey_lumber_stock += removed
	var payout : int = int(round(removed * WOOD_TO_GOLD_RATE))
	add_coins(payout, "Lumber delivered")
	return payout


# --- Ore / mining ------------------------------------------------------

## Credit the player with ore from a Mining session. Returns the OVERFLOW
## (ore that didn't fit in the backpack). Mirror of [method add_wood].
func add_ore(amount: int) -> int:

	if amount <= 0:
		return 0
	return add_item(ITEM_ORE, amount)


## Player drops `amount` of carried ore at Cinder Troy's Forge: it moves
## from the backpack into his stock and the player is paid gold at
## [constant ORE_TO_GOLD_RATE]. Returns the gold paid. Mirror of
## [method deliver_wood].
func deliver_ore(amount: int) -> int:

	var removed : int = remove_item(ITEM_ORE, amount)
	if removed <= 0:
		return 0
	cinder_ore_stock += removed
	var payout : int = int(round(removed * ORE_TO_GOLD_RATE))
	add_coins(payout, "Ore delivered")
	return payout


# --- Ships (Godfrey's ship shop) ---------------------------------------

## Does the player already own [param ship_id]?
func owns_ship(ship_id: String) -> bool:

	return owned_ships.has(ship_id)


## True if the player owns ANY spacecraft — gates the Skydock voyage helm.
func has_ship() -> bool:

	return not owned_ships.is_empty()


## Can the player afford + is eligible to buy [param ship_id]? GOLD ONLY (the single earned
## currency, earn-and-keep), and must not already own it.
func can_buy_ship(ship_id: String, gold_cost: int) -> bool:

	if owns_ship(ship_id):
		return false
	return total_coins >= gold_cost


## Buy [param ship_id]: spends gold only. Returns true on success. No-ops if unaffordable or
## already owned.
func buy_ship(ship_id: String, gold_cost: int) -> bool:

	if not can_buy_ship(ship_id, gold_cost):
		return false
	add_coins(-gold_cost, "Bought the %s" % ShipClasses.display(ship_id))
	owned_ships.append(ship_id)
	if active_ship.is_empty() or not owned_ships.has(active_ship):
		active_ship = ship_id   # your first hull berths as the active ship; later buys swap at the dock
	ships_changed.emit()
	objective_changed.emit()
	_save()
	return true


# --- Ship condition (holes → Stardust; the sinkable-ship coupling) -----
# See [[ship-condition-research]]. Holes are persistent hull damage on the ACTIVE ship; combat opens
# them (fight legs), the Patchworks seals them, and they drive how fast the Loft's Stardust floods in.

## The ship a voyage uses right now: the chosen ACTIVE ship, falling back to the first owned
## (covers old saves + a just-sold active). "" if none owned.
func active_ship_id() -> String:

	if not active_ship.is_empty() and owned_ships.has(active_ship):
		return active_ship
	return String(owned_ships[0]) if not owned_ships.is_empty() else ""


## The display name for a ship id — her CHRISTENED name when she has one, else the class name
## from ShipClasses (e.g. "driftpod" → "Skylark" or "Driftpod").
func ship_name(ship_id: String) -> String:

	var custom : String = String(ship_custom_names.get(ship_id, ""))
	return custom if not custom.is_empty() else ShipClasses.display(ship_id)


## The display name of your active owned ship — "" if none owned.
func active_ship_name() -> String:

	var id : String = active_ship_id()
	return ship_name(id) if not id.is_empty() else ""


## Christen (or re-christen) an owned ship. Empty/whitespace clears back to the class name.
func christen_ship(ship_id: String, new_name: String) -> void:

	if not owns_ship(ship_id):
		return
	var trimmed : String = new_name.strip_edges().left(24)
	if trimmed.is_empty():
		ship_custom_names.erase(ship_id)
	else:
		ship_custom_names[ship_id] = trimmed
	ships_changed.emit()
	_save()


## Make an owned ship the ACTIVE one (the dock berth swap). No-op mid-voyage — the hull
## write-back targets the ship that sailed, so the fleet can't be juggled under a live run.
func set_active_ship(ship_id: String) -> void:

	if voyage_active or not owns_ship(ship_id) or ship_id == active_ship_id():
		return
	active_ship = ship_id
	ships_changed.emit()
	_save()


## Sell an owned ship back to the shipwright for ShipClasses.sell_price (half the catalog price).
## Her condition + christened name go with her. Refuses mid-voyage. Returns the gold refunded, -1 on refusal.
func sell_ship(ship_id: String) -> int:

	if voyage_active or not owns_ship(ship_id):
		return -1
	var price : int = ShipClasses.sell_price(ship_id)
	var sold_name : String = ship_name(ship_id)
	owned_ships.erase(ship_id)
	ship_condition.erase(ship_id)
	ship_custom_names.erase(ship_id)
	if active_ship == ship_id:
		active_ship = String(owned_ships[0]) if not owned_ships.is_empty() else ""
	add_coins(price, "Sold the %s" % sold_name)
	ships_changed.emit()
	objective_changed.emit()
	_save()
	return price


# --- Captain your OWN ship (a self-captained voyage) ------------------
# Route length is CLASS-driven now (ShipClasses legs_min/legs_max — a skiff hops, a galleon ranges).
const SELF_VOYAGE_FOES : Array = ["a sky-brigand sloop", "a marine cutter", "a band of sky-marauders", "a corsair brig"]
const SELF_VOYAGE_ENCOUNTER_CHANCE : float = 0.5

## Set up a SELF-CAPTAINED voyage on your owned ship, bound for the nearest OTHER island (from
## [member voyage_home_scene]). Rolls the route + seeds the hull from your ship's persisted condition + marks
## it self-captained (so the holes write BACK on arrival). Returns the ship-deck scene path to change to (the
## caller sets voyage_home_scene first + does the scene change), or "" if you own no ship. Shared by the
## Voyages board's "Captain the Driftpod" row AND the moored-ship Board prop.
func captain_own_voyage() -> String:

	if not has_ship():
		return ""
	var to_cradle : bool = voyage_home_scene.find("frontier_isle") != -1
	var dest_name : String = "Cradle Rock" if to_cradle else "Driftspar"
	var dest_scene : String = "res://levels/shore/shore.tscn" if to_cradle else "res://levels/frontier_isle/frontier_isle.tscn"
	var sid : String = active_ship_id()
	var def : Dictionary = ShipClasses.get_def(sid)
	var legs_min : int = int(def.get("legs_min", 2))
	var legs_max : int = int(def.get("legs_max", 4))
	var legs : int = legs_min + randi() % maxi(legs_max - legs_min + 1, 1)
	var enc : Array = []
	var pos : Array = []
	var any_fight : bool = false
	for _i in legs:
		if randf() < SELF_VOYAGE_ENCOUNTER_CHANCE:
			enc.append(SELF_VOYAGE_FOES[randi() % SELF_VOYAGE_FOES.size()])
			any_fight = true
		else:
			enc.append("")
		pos.append(randf_range(0.28, 0.78))
	if not any_fight and legs > 0:
		enc[legs - 1] = SELF_VOYAGE_FOES[randi() % SELF_VOYAGE_FOES.size()]
	# Aboard = YOUR recruited crew, capped to the ship's berths — NOT random cast. None recruited → you sail
	# SOLO (Troy 2026-06-10: no crew means no NPCs aboard your own ship). Your first hand is the speaking
	# MATE; with no crew there's no mate (the deck voice becomes your own log — see ship_deck._say).
	var aboard : Array = crew.keys()
	var berths : int = ShipClasses.crew_slots(sid)
	if aboard.size() > berths:
		aboard = aboard.slice(0, berths)
	var mate : String = String(aboard[0]) if not aboard.is_empty() else ""
	var start_holes : int = ship_holes_of(active_ship_id())   # the canonical owned-ship condition directly (not
	# the dual-source ship_open_holes() helper), so the seed is right even if prior transient state were live.
	pillage_captain = mate
	pillage_crew = "your crew"
	pillage_ship_name = active_ship_name()
	pillage_ship_id = sid                                  # the hull that sails is the hull written back
	voyage_booty_mult = ShipClasses.booty_mult(sid)        # the class hold scales the whole pool
	pillage_jobber_cut = 1.0                                # YOUR ship → you keep the whole cut
	voyage_self_captained = true
	pillage_destination = dest_name
	pillage_destination_scene = dest_scene
	pillage_legs_total = legs
	pillage_encounters = enc
	pillage_encounter_pos = pos
	pillage_leg = 0
	pillage_log = []
	pillage_phase = 0
	voyage_active = true
	voyage_ship_t = 0.0
	voyage_open_holes = start_holes
	voyage_station_state = {}
	BoardingMelee.clear()
	pillage_duty_crew = DutyReport.build_roster_self(aboard)   # only YOUR crew aboard (or just you, solo)
	sync_voyage_stations_from_roster()   # auto-post them to stations + relabel duties (ONE source of truth)
	last_duty_report = []
	return "res://levels/ship_deck/ship_deck.tscn"


## Max hull holes for a ship id (its sink ceiling + Patchworks cap) — the class "hull" stat.
func ship_max_holes(ship_id: String) -> int:

	return ShipClasses.max_holes(ship_id)


## The CURRENT voyage's hull cap: your own ship's class hull when self-captained, the stock
## jobbed-ship cap otherwise. The Loft's sink bar + the hull gauge + the wreck all key off this.
func voyage_max_holes() -> int:

	if voyage_self_captained and not pillage_ship_id.is_empty():
		return ShipClasses.max_holes(pillage_ship_id)
	return VOYAGE_MAX_HOLES


## Open holes on a SPECIFIC owned ship's persisted condition (the dock berth lists every hull).
func ship_holes_of(ship_id: String) -> int:

	return int((ship_condition.get(ship_id, {}) as Dictionary).get("open_holes", 0))


## Open holes on the ACTIVE ship (0 with no ship / no damage yet).
func ship_open_holes() -> int:

	if voyage_active:
		return voyage_open_holes   # the pillage ship you're crewing
	var id : String = active_ship_id()
	if id.is_empty():
		return 0
	return int((ship_condition.get(id, {}) as Dictionary).get("open_holes", 0))


## Add `n` holes to the active ship (clamped to its max). Persisted. Combat calls this on fight legs.
func add_hole(n: int = 1) -> void:

	_set_open_holes(ship_open_holes() + n)


## Seal `n` holes on the active ship (clamped to 0). Persisted. The Patchworks calls this.
func close_hole(n: int = 1) -> void:

	var before : int = ship_open_holes()
	_set_open_holes(before - n)
	var sealed : int = before - ship_open_holes()
	if sealed > 0:
		log_event("Sealed %d hull hole%s" % [sealed, "" if sealed == 1 else "s"], Color(0.7, 0.9, 0.78))


## Wreck the active ship — set it to MAX holes (the sink consequence). Persisted.
func wreck_active_ship() -> void:

	if voyage_active:
		_set_open_holes(voyage_max_holes())
		return
	var id : String = active_ship_id()
	if not id.is_empty():
		_set_open_holes(ship_max_holes(id))


## The Stardust level the Loft should START at for the active ship: a perfect hull starts at the
## baseline (trivially aloft); a battered hull starts higher (closer to the bite). Read on embark.
func ship_stardust_start() -> float:

	var relief : float = SAILING_START_RELIEF_PER_RATING * float(voyage_station_skill("Sailing"))
	return maxf(1.0, STARDUST_BASE_START + float(ship_open_holes()) * STARDUST_START_PER_HOLE - relief)


# Write the active ship's open-hole count (clamped 0..max), then persist.
func _set_open_holes(value: int) -> void:

	if voyage_active:
		voyage_open_holes = clampi(value, 0, voyage_max_holes())   # the pillage ship (transient, not saved)
		return
	var id : String = active_ship_id()
	if id.is_empty():
		return
	var cond : Dictionary = ship_condition.get(id, {})
	cond["open_holes"] = clampi(value, 0, ship_max_holes(id))
	ship_condition[id] = cond
	_save()


# --- Skirmish weapons --------------------------------------------------

## Equip a Skirmish weapon you OWN (no-op if unowned). What your boarding/duel attacks
## use. Switched here (the inventory) only, never mid-fight. Persisted.
func equip_weapon(weapon_id: String) -> void:

	if not owns_weapon(weapon_id):
		return
	equipped_weapon = weapon_id
	weapons_changed.emit()
	inventory_changed.emit()   # the backpack re-highlights the equipped weapon item
	_save()


## True if the player has this weapon — bare fists (DEFAULT_WEAPON) are always available; otherwise it's the
## equipped one or a weapon ITEM sitting in the bag (weapons are items now — ONE class with everything else).
func owns_weapon(weapon_id: String) -> bool:

	if weapon_id == SkirmishWeapon.DEFAULT_WEAPON or equipped_weapon == weapon_id:
		return true
	return _inventory_has(weapon_id)


## True if a non-empty slot holds [param item_id].
func _inventory_has(item_id: String) -> bool:

	for slot in inventory:
		if slot is Dictionary and not slot.is_empty() and String(slot["id"]) == item_id:
			return true
	return false


## True if [param item_id] is a real (buyable) weapon — drives the weapon icon, the 1-per-slot stack cap, and
## double-click-to-equip. Bare fists (DEFAULT_WEAPON) is NOT a carried item.
func is_weapon(item_id: String) -> bool:

	return item_id != SkirmishWeapon.DEFAULT_WEAPON and SkirmishWeapon.DESCRIPTIONS.has(item_id)


## True if [param weapon_id] is unowned, affordable, AND there's bag room (a weapon is an item now; a purchase
## never grows the bag — buy a bigger backpack first).
func can_buy_weapon(weapon_id: String, gold_cost: int) -> bool:

	return not owns_weapon(weapon_id) and total_coins >= gold_cost and space_for(weapon_id) >= 1


## Buy a weapon at the forge: spend gold, drop it into the BAG as an item (then double-click to equip). Returns
## true on success. No-op if already owned, unaffordable, or the bag is full.
func buy_weapon(weapon_id: String, gold_cost: int) -> bool:

	if not can_buy_weapon(weapon_id, gold_cost):
		return false
	add_coins(-gold_cost, "Bought the %s" % weapon_id.capitalize())
	add_item(weapon_id, 1)
	weapons_changed.emit()
	return true


# --- Onboarding objective ----------------------------------------------

## The player's current driving goal, as {text, done}. Derived purely from
## existing progress flags so it auto-updates — no separate quest state.
## Drives the objective readout. The arc: get hired → earn gold (puzzle-work /
## jobbing voyages) → buy your first spacecraft (gold only).
func current_objective() -> Dictionary:

	if not owned_ships.is_empty():
		return {
			"text": "You earned your first spacecraft! More of the skies to come.",
			"done": true}
	if total_coins >= FIRST_SHIP_GOLD:
		return {
			"text": "Buy your first ship — the %s — at the Workshop ship desk." % FIRST_SHIP_NAME,
			"done": false}
	# The headline MVP loop: sign onto a jobbing VOYAGE at the Skydock helm — no ship of
	# your own needed. A few good voyages bank the gold for your first hull.
	return {
		"text": "Sail a jobbing voyage — take the helm at the SKYDOCK (no ship needed).   Toward your first ship:  %d / %d gold" % [
			mini(total_coins, FIRST_SHIP_GOLD), FIRST_SHIP_GOLD],
		"done": false}


## The player's quest log, as an ordered Array of {title, detail, done}.
## Derived purely from progress flags (no stored quest state), so quests
## tick themselves done. Drives the user panel's Objectives tab. Add entries here as the
## game grows; keep the first-ship line as the spine for now.
func current_quests() -> Array:

	var quests : Array = []
	quests.append({
		"title": "Find Honest Work",
		"detail": ("Cradle Rock's folk pay gold for puzzle-work. Apply for a job "
			+ "at Cogwise Godfrey's Workshop (lumber) or Cinder Troy's Forge (ore)."),
		"done": hired_at_workshop or hired_at_forge,
	})
	var ship_done : bool = not owned_ships.is_empty()
	var ship_detail : String
	if ship_done:
		ship_detail = "Done — you fly your own %s now. More of the skies to come." % FIRST_SHIP_NAME
	else:
		ship_detail = ("Earn %d gold — a few good voyages at the Skydock will do it — then "
			+ "buy a %s at the Workshop ship desk.\n\nProgress:  %d / %d gold") % [
			FIRST_SHIP_GOLD, FIRST_SHIP_NAME,
			mini(total_coins, FIRST_SHIP_GOLD), FIRST_SHIP_GOLD]
	quests.append({
		"title": "A Ship of Your Own",
		"detail": ship_detail,
		"done": ship_done,
	})
	# Accepted favours — small side-quests the player chose to take on. They
	# carry done=false (a favour is never shown as "done": turning it in
	# erases it via complete_favor, so it simply drops off the log).
	for fav_name in active_favors:
		if not (active_favors[fav_name] is Dictionary):
			continue
		var fav : Dictionary = active_favors[fav_name]
		var fav_item : String = String(fav.get("item", ""))
		var fav_amount : int = int(fav.get("amount", 0))
		var have : int = item_count(fav_item)
		var detail : String
		if have >= fav_amount:
			detail = "Ready! Bring %d %s back to %s." % [fav_amount, fav_item, fav_name]
		else:
			detail = "Bring %d %s to %s.   (You have %d.)" % [fav_amount, fav_item, fav_name, have]
		quests.append({
			"title": "A favour for %s" % fav_name,
			"detail": detail,
			"done": false,
		})
	return quests


## True if any quest is still open (drives the journal button's "!" badge).
func has_active_quests() -> bool:

	for quest in current_quests():
		if not quest["done"]:
			return true
	return false


# --- Rapport / affinity ------------------------------------------------

## Current rapport with [param npc_name] (0 if never interacted).
func get_affinity(npc_name: String) -> int:

	return int(npc_affinity.get(npc_name, 0))


## Tier name for the current rapport level — "Stranger" → "Acquaintance"
## → "Friend" → "Confidant".
func affinity_tier(npc_name: String) -> String:

	var value : int = get_affinity(npc_name)
	for tier in AFFINITY_TIERS:
		if value >= tier["min"]:
			return tier["name"]
	return "Stranger"


## Raise (or lower) rapport with an NPC, clamped to [MIN_AFFINITY, MAX_AFFINITY] — rapport can go
## NEGATIVE (an NPC genuinely soured on the player). Emits [signal affinity_changed] + persists when
## the value actually moves. No-ops on empty name or zero delta.
func add_affinity(npc_name: String, amount: int) -> void:

	if npc_name.is_empty() or amount == 0:
		return
	var old_val : int = get_affinity(npc_name)
	var new_val : int = clampi(old_val + amount, MIN_AFFINITY, MAX_AFFINITY)
	if new_val == old_val:
		return
	npc_affinity[npc_name] = new_val
	affinity_changed.emit(npc_name, new_val, affinity_tier(npc_name))
	_save()


## The saved chat history with [param npc_name] (a deep copy) — what they remember of past conversations.
## Empty for an NPC you've never chatted with. See [NpcBrain.enter_chat].
func npc_chat_history(npc_name: String) -> Array:

	var entries : Array = npc_chat_log.get(npc_name, [])
	return entries.duplicate(true)


## Persist the chat history with [param npc_name] (bounded to the last NPC_CHAT_LOG_CAP turns). Called by
## [NpcBrain] after each reply so the conversation survives scene changes + reloads.
func save_npc_chat(npc_name: String, messages: Array) -> void:

	if npc_name.is_empty():
		return
	var trimmed : Array = messages
	if trimmed.size() > NPC_CHAT_LOG_CAP:
		trimmed = trimmed.slice(trimmed.size() - NPC_CHAT_LOG_CAP)
	npc_chat_log[npc_name] = trimmed.duplicate(true)
	_save()


## Set + persist the player's name (typed at New Game). Trimmed + capped at 20 chars.
func set_player_name(new_name: String) -> void:

	player_name = new_name.strip_edges().left(20)
	_save()


# --- Crew (hire + ranks) — the foundation for "start a crew" ------------

## Can the player recruit this NPC? Only a CONFIDANT (the design's "can recruit" tier). NOTE: this gates the
## moment of HIRE only — a crew member stays aboard even if rapport later dips (earn-and-keep, no decay).
func can_recruit(npc_name: String) -> bool:

	return get_affinity(npc_name) >= RECRUIT_MIN_AFFINITY


func is_in_crew(npc_name: String) -> bool:

	return crew.has(npc_name)


## The crew member's rank name, or "" if they're not in your crew.
func crew_rank(npc_name: String) -> String:

	if not crew.has(npc_name):
		return ""
	return CREW_RANKS[clampi(int(crew[npc_name]), 0, CREW_RANKS.size() - 1)]


func crew_size() -> int:

	return crew.size()


## Recruit an NPC (joins at the lowest rank). No-ops unless they're recruitable + not already aboard.
func hire_crew(npc_name: String) -> bool:

	if npc_name.is_empty() or crew.has(npc_name) or not can_recruit(npc_name):
		return false
	crew[npc_name] = 0
	crew_changed.emit()
	_save()
	return true


func dismiss_crew(npc_name: String) -> void:

	if crew.erase(npc_name):
		for k in voyage_stations.keys():   # a dismissed hand can't keep a station post
			if String(voyage_stations[k]) == npc_name:
				voyage_stations.erase(k)
		crew_changed.emit()
		voyage_stations_changed.emit()
		_save()


## Promote (+1) / demote (-1) a crew member, clamped to the rank ladder. Returns the new rank name.
func cycle_crew_rank(npc_name: String, dir: int) -> String:

	if not crew.has(npc_name):
		return ""
	crew[npc_name] = clampi(int(crew[npc_name]) + dir, 0, CREW_RANKS.size() - 1)
	crew_changed.emit()
	_save()
	return crew_rank(npc_name)


# --- Voyage duty-stations (assign crew to a station; their skill carries it) ---

## How many of YOUR crew this voyage's ship can berth (the class "crew slots" stat on a self-captained
## run — a Driftpod posts 1 hand, the Sky Galleon all stations). Outside a class-bound run, no cap.
func voyage_crew_berths() -> int:

	if voyage_self_captained and not pillage_ship_id.is_empty():
		return ShipClasses.crew_slots(pillage_ship_id)
	return CrewSkills.STATIONS.size()


## Assign [param npc_name] (or "" to clear) to a voyage station ("Sailing"/"Repair"/"Combat"). Only a recruited
## crew member may man a station, no one mans two (assigning moves them), and the ship's class caps how many
## hands she BERTHS in total. Transient (not saved).
func set_voyage_station(station: String, npc_name: String) -> void:

	if not (station in CrewSkills.STATIONS):
		return
	if npc_name.is_empty():
		voyage_stations.erase(station)
	else:
		if not is_in_crew(npc_name):
			return
		# A MOVE (already posted somewhere) never raises the count; a fresh posting must fit the berths.
		var already_posted : bool = voyage_stations.values().has(npc_name)
		if not already_posted and voyage_station_npc(station).is_empty() \
				and voyage_stations.size() >= voyage_crew_berths():
			return
		for k in voyage_stations.keys():
			if String(voyage_stations[k]) == npc_name and k != station:
				voyage_stations.erase(k)
		voyage_stations[station] = npc_name
	_relabel_roster_from_stations()   # keep the deck/report/chat duties in step with the new posting
	voyage_stations_changed.emit()


## The crew member manning [param station], or "" if unmanned.
func voyage_station_npc(station: String) -> String:

	return String(voyage_stations.get(station, ""))


## Which station [param npc_name] is posted to this voyage ("" if none) — the reverse of [method voyage_station_npc].
func voyage_station_of(npc_name: String) -> String:

	for station in voyage_stations:
		if String(voyage_stations[station]) == npc_name:
			return station
	return ""


## ⭐ ONE crew system (audit 2026-06-10): auto-post the aboard crew to the 3 mechanical STATIONS (the best-rated
## hand per station) AND relabel the roster's duties + per-station skill to match — so what you SEE on deck /
## in the duty report / in chat IS what actually WORKS the leg, on JOBBED runs too (they used to give zero
## mechanical benefit). Called on every voyage launch; CrewDutyPanel re-posts re-sync via the relabel.
func sync_voyage_stations_from_roster() -> void:

	voyage_stations = {}
	var pool : Array = []
	for e in pillage_duty_crew:
		if e is Dictionary and not bool(e.get("is_player", false)) and String(e.get("duty", "")) != DutyReport.CAPTAIN_DUTY:
			pool.append(String(e.get("name", "")))
	for station in CrewSkills.STATIONS:
		if pool.is_empty():
			break
		var best : String = ""
		var best_r : int = -1
		for nm in pool:
			var r : int = CrewSkills.rating(String(nm), station)
			if r > best_r:
				best_r = r
				best = String(nm)
		if not best.is_empty():
			voyage_stations[station] = best
			pool.erase(best)
	_relabel_roster_from_stations()


# Relabel each non-player, non-captain roster entry's DUTY + per-station SKILL from voyage_stations, so the
# deck / duty report / chat describe the crew at the stations they actually work (Reserve = aboard, unposted).
func _relabel_roster_from_stations() -> void:

	for e in pillage_duty_crew:
		if not (e is Dictionary) or bool(e.get("is_player", false)) or String(e.get("duty", "")) == DutyReport.CAPTAIN_DUTY:
			continue
		var nm : String = String(e.get("name", ""))
		var station : String = voyage_station_of(nm)
		e["duty"] = station if not station.is_empty() else "Reserve"
		e["skill"] = (float(CrewSkills.rating(nm, station)) / 5.0) if not station.is_empty() else 0.0


## The skill rating (1–5) carrying [param station] this voyage — 0 if unmanned or the assigned hand is no
## longer in your crew (a dismissed-but-still-assigned name doesn't keep helping).
func voyage_station_skill(station: String) -> int:

	var who : String = voyage_station_npc(station)
	if who.is_empty() or not is_in_crew(who):
		return 0
	return CrewSkills.rating(who, station)


## The per-move Loft rise RELIEF from a posted Sailing hand (0 if none). Subtracted in loft.gd _push_effective_rise.
func sailing_rise_relief() -> float:

	return SAILING_RISE_RELIEF_PER_RATING * float(voyage_station_skill("Sailing"))


## Record that the player completed a favour for [param npc_name]. Bumps
## the lifetime count, persists, and returns the new total (for the
## "you've helped me N times" thank-you). Rapport itself is granted
## separately via [method add_affinity] so the two stay independently tunable.
func record_favor(npc_name: String) -> int:

	if npc_name.is_empty():
		return int(npc_favor_done.get(npc_name, 0))
	var count : int = int(npc_favor_done.get(npc_name, 0)) + 1
	npc_favor_done[npc_name] = count
	_save()
	return count


## Accept an offered favour — adds it to [member active_favors] so it shows
## in the Objectives log. Idempotent. ONLY the player's explicit "accept"
## calls this (a mere offer must not). Emits [signal objective_changed].
func accept_favor(npc_name: String, item_id: String, amount: int) -> void:

	if npc_name.is_empty() or active_favors.has(npc_name):
		return
	active_favors[npc_name] = {"item": item_id, "amount": amount}
	objective_changed.emit()
	_save()


## Turn in / clear an accepted favour — removes it from the Objectives log
## so it disappears the moment it's done. No-op if it was never tracked
## (e.g. handed over on the spot without accepting). Emits [signal objective_changed].
func complete_favor(npc_name: String) -> void:

	if not active_favors.has(npc_name):
		return
	active_favors.erase(npc_name)
	objective_changed.emit()
	_save()


## True if [param npc_name]'s favour is currently on the player's
## objectives (accepted, not yet turned in).
func has_active_favor(npc_name: String) -> bool:

	return active_favors.has(npc_name)


## Atomically turn in a favour: spend the items, grant the rapport, clear it
## from the objectives log, and bump the lifetime count — batched into a
## SINGLE save instead of one write per step. Returns the new lifetime
## count. The caller must have already verified the player holds [param amount].
func turn_in_favor(npc_name: String, item_id: String, amount: int, affinity: int) -> int:

	_suppress_save = true
	remove_item(item_id, amount)
	add_affinity(npc_name, affinity)
	complete_favor(npc_name)
	var count : int = record_favor(npc_name)
	_suppress_save = false
	_save()
	return count


## Atomically run a completed trade with an NPC: hand over the player's offered items (+ an optional gold
## gift), receive the NPC's gold, and gain rapport — batched into ONE save. SELF-VALIDATING: bails with no
## mutation (returns false) if the player can't cover the offer, so it's safe even unpaused (co-op later).
## (Player↔player trades reuse this per side.)
func execute_trade(give_items: Dictionary, give_gold: int, get_gold: int, npc_name: String, rapport: int) -> bool:

	for id in give_items:
		if item_count(String(id)) < int(give_items[id]):
			return false
	if give_gold > total_coins:
		return false
	_suppress_save = true
	for id in give_items:
		remove_item(String(id), int(give_items[id]))
	if give_gold > 0:
		add_coins(-give_gold, "Trade gift")
	if get_gold > 0:
		add_coins(get_gold, "Trade with %s" % npc_name)
	if rapport > 0 and not npc_name.is_empty():
		add_affinity(npc_name, rapport)
	_suppress_save = false
	_save()
	return true


# --- Tournament flow ---------------------------------------------------

## Begin a tournament: seed the 3-rival bracket, stash the pot + the scene
## to return to. Transient — a tournament doesn't survive a quit.
func start_tournament(field: Array, pot: int, home: String) -> void:

	tournament_active = true
	tournament_field = field.duplicate()
	tournament_round = 1
	tournament_pot = pot
	tournament_awaiting = false
	tournament_outcome = TournamentOutcome.IN_PROGRESS
	tournament_finalist = ""
	tournament_home = home


## Clear all tournament state (on leaving the bracket).
func end_tournament() -> void:

	tournament_active = false
	tournament_field = []
	tournament_round = 1
	tournament_pot = 0
	tournament_awaiting = false
	tournament_outcome = TournamentOutcome.IN_PROGRESS
	tournament_finalist = ""


## The player's current bracket opponent path — semifinal = the first seed,
## final = the other finalist.
func tournament_opponent() -> String:

	if tournament_round >= 2:
		return tournament_finalist
	if tournament_field.is_empty():
		return ""
	return String(tournament_field[0])


## Record a tournament championship — the earn-only win count. Persisted.
func record_tournament_win() -> void:

	tournaments_won += 1
	_save()


## Overall popularity = the summed rapport across the whole cast. A pure
## DERIVED read — never stored, never decays (honours earn-and-keep), so
## it can't be farmed or lost and is alt-proof. Used only as participation
## flavour; never surfaced as a raw number or tied to a reward.
func reputation() -> int:

	var total : int = 0
	for value in npc_affinity.values():
		total += int(value)
	return total


## One-shot read of the [ParlorBrowser]'s choices for the parlor scene that is loading. Returns
## {"seated_paths": Array, "free": bool, "table_config": Dictionary} and RESETS all three transients
## so a later non-lobby launch can't inherit stale settings.
func consume_lobby_setup() -> Dictionary:

	var setup : Dictionary = {
		"seated_paths": lobby_seated_paths.duplicate(),
		"free": free_table,
		"table_config": lobby_table_config.duplicate(true),
	}
	lobby_seated_paths = []
	free_table = false
	lobby_table_config = {}
	return setup


# --- Puzzle mastery ----------------------------------------------------

## Record a finished puzzle session's score. Updates the per-puzzle BEST
## (high-water mark) and, if that crossed into a new tier, emits
## [signal mastery_ranked_up]. Returns {best, tier_index, tier_name,
## is_new_best, ranked_up} so the result screen can show the right flourish.
func record_puzzle_result(puzzle_id: String, score: int) -> Dictionary:

	if not MASTERY_PUZZLES.has(puzzle_id):
		return {"best": 0, "tier_index": 0, "tier_name": MASTERY_TIERS[0],
			"is_new_best": false, "ranked_up": false}
	# SUSTAINED: add this run's (capped) quality to the accumulated total, then read the rank off the shared
	# points ladder — so it climbs over many runs and one great run can't jump it.
	var gain : float = clampf(float(score) / _mastery_par(puzzle_id), 0.0, MASTERY_SESSION_CAP) * MASTERY_PAR_POINTS
	var old_points : float = float(puzzle_mastery.get(puzzle_id, 0.0))
	var old_tier : int = _mastery_tier_index_points(old_points)
	var new_points : float = old_points + gain
	if gain > 0.0:
		puzzle_mastery[puzzle_id] = new_points
		_save()
	var new_tier : int = _mastery_tier_index_points(new_points)
	var ranked_up : bool = new_tier > old_tier
	if ranked_up:
		Audio.play_sfx("powerup")   # the rank-up fanfare (borrowed GDQuest lib — richer than the synth chime)
		mastery_ranked_up.emit(puzzle_id, new_tier, MASTERY_TIERS[new_tier])
		var pname : String = String((MASTERY_PUZZLES.get(puzzle_id, {}) as Dictionary).get("name", puzzle_id))
		log_event("Ranked up: %s — %s" % [pname, MASTERY_TIERS[new_tier]], Color(0.98, 0.86, 0.5))
	check_new_trophies()
	return {"best": roundi(new_points), "tier_index": new_tier, "tier_name": MASTERY_TIERS[new_tier],
		"is_new_best": gain > 0.0, "ranked_up": ranked_up}


## Detect trophies that JUST became earned (vs trophies_seen) + announce each via
## [signal trophy_earned] (the HUD pops a [TrophyToast]). Idempotent — a trophy fires once.
## Called from the mutators that can unlock one (mastery, coins, the frontier flag). add_coins
## being frequent also makes this a periodic sweep that catches affinity/tournament trophies.
func check_new_trophies() -> void:

	# Never fire mid-load/reset (setters call this before trophies_seen is read back) — the
	# load-time _seed_trophies_seen handles existing trophies silently.
	if _suppress_save:
		return
	var changed : bool = false
	for t in Trophies.ALL:
		var id : String = String(t["id"])
		if Trophies.is_earned(id) and not trophies_seen.has(id):
			trophies_seen.append(id)
			changed = true
			trophy_earned.emit(id, String(t["name"]))
	if changed:
		_save()


## Earned trophies the player hasn't yet ACCEPTED in the Ayo! tab (drives its badge count).
func unclaimed_trophy_ids() -> Array:

	var out : Array = []
	for t in Trophies.ALL:
		var id : String = String(t["id"])
		if Trophies.is_earned(id) and not trophies_claimed.has(id):
			out.append(id)
	return out


## Accept a trophy in the Ayo! tab — marks it claimed (clears it from the badge), persists, and fires
## [signal trophy_claimed]. No-op if already claimed or not actually earned.
func claim_trophy(id: String) -> void:

	if trophies_claimed.has(id) or not Trophies.is_earned(id):
		return
	trophies_claimed.append(id)
	_save()
	trophy_claimed.emit(id)


## Has the player got pending NPC duel challenges waiting in Ayo!?
func has_challenges() -> bool:

	return not pending_challenges.is_empty()


## File a Skirmish challenge from [param npc_name] (deduped). Drives the Ayo! tab + its badge.
func add_challenge(npc_name: String) -> void:

	if npc_name.is_empty() or pending_challenges.has(npc_name):
		return
	pending_challenges.append(npc_name)
	challenges_changed.emit()
	_save()


## Clear a challenge (on Accept or Reject).
func clear_challenge(npc_name: String) -> void:

	if pending_challenges.has(npc_name):
		pending_challenges.erase(npc_name)
		challenges_changed.emit()
		_save()


## Record the outcome of a Skirmish duel against [param npc_name] (player's perspective: [param player_won] =
## the player beat this NPC). Bumps the persisted head-to-head tally + stamps [member recent_duel] so the NPC
## delivers post-fight banter and the chat AI knows the fresh result. No-op for a nameless sparring partner.
func record_battle(npc_name: String, player_won: bool) -> void:

	if npc_name.is_empty():
		return
	var rec : Dictionary = npc_battle_record.get(npc_name, {"wins": 0, "losses": 0})
	if player_won:
		rec["wins"] = int(rec.get("wins", 0)) + 1
	else:
		rec["losses"] = int(rec.get("losses", 0)) + 1
	npc_battle_record[npc_name] = rec
	# Stamp with a monotonic tick so chat can tell "just now" from "a while ago" (freshness decays). Not
	# persisted, so the tick is always same-session-valid (recent_duel is blank on a fresh boot).
	recent_duel = {"npc": npc_name, "player_won": player_won, "ts": Time.get_ticks_msec()}
	battle_record_changed.emit()
	_save()


## The head-to-head duel tally with [param npc_name], the player's perspective: {wins, losses} (wins = the
## player's wins over this NPC). Always returns both keys (0 if never fought). Read by chat + the NPC profile.
func battle_record(npc_name: String) -> Dictionary:

	var rec : Dictionary = npc_battle_record.get(npc_name, {})
	return {"wins": int(rec.get("wins", 0)), "losses": int(rec.get("losses", 0))}


## Mark all CURRENTLY-earned trophies as already-seen WITHOUT announcing — called once on
## load so existing trophies (or a pre-system save) never spam toasts; only live earns notify.
func _seed_trophies_seen() -> void:

	for t in Trophies.ALL:
		var id : String = String(t["id"])
		if Trophies.is_earned(id) and not trophies_seen.has(id):
			trophies_seen.append(id)


## The player's accumulated mastery POINTS for a puzzle, rounded (0 if never played). Climbs every run.
func mastery_best(puzzle_id: String) -> int:

	return roundi(float(puzzle_mastery.get(puzzle_id, 0.0)))


## {index, name} of a puzzle's current mastery tier.
func mastery_tier(puzzle_id: String) -> Dictionary:

	var idx : int = _mastery_tier_index_points(float(puzzle_mastery.get(puzzle_id, 0.0)))
	return {"index": idx, "name": MASTERY_TIERS[idx]}


# That puzzle's PAR — the score a single "strong" run makes (its old single-session Master threshold) = 1.0 quality.
func _mastery_par(puzzle_id: String) -> float:

	var t : Array = (MASTERY_PUZZLES.get(puzzle_id, {}) as Dictionary).get("thresholds", [0, 0, 0, 1])
	return maxf(1.0, float(t[mini(3, t.size() - 1)]))


# Highest rank index whose ACCUMULATED-points threshold has been reached.
func _mastery_tier_index_points(points: float) -> int:

	var idx : int = 0
	for i in MASTERY_RANK_POINTS.size():
		if points >= float(MASTERY_RANK_POINTS[i]):
			idx = i
		else:
			break
	return idx


# Called by Door / GemDropTable before they change_scene_to_file.
# BaseLocation.consume_anchor() drains this in the next scene's _ready.
func request_spawn_at_anchor(anchor_name: String) -> void:

	pending_spawn_anchor = anchor_name


func consume_anchor() -> String:

	var anchor : String = pending_spawn_anchor
	pending_spawn_anchor = ""
	return anchor


# Set by resume-from-save logic on launch. BaseLocation reads it once.
func request_spawn_at_position(pos: Vector2) -> void:

	pending_spawn_position = pos
	_has_pending_position = true


func consume_position() -> Variant:

	if not _has_pending_position:
		return null
	_has_pending_position = false
	var pos : Vector2 = pending_spawn_position
	pending_spawn_position = Vector2.ZERO
	return pos


# Returns true if user://save.cfg has a restorable scene + position
# (i.e. the player has played before and we can resume them).
func has_resumable_session() -> bool:

	return not last_scene.is_empty()


# Writes current scene path + player's world position to disk. Called on
# game close (NOTIFICATION_WM_CLOSE_REQUEST) and could also be called
# manually after meaningful checkpoints if we want to harden against crashes.
func save_session() -> void:

	var tree : SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		_save()
		return
	var current_scene : Node = tree.current_scene
	var scene_path : String = current_scene.scene_file_path
	# Only save scene+position if a Player is present (skip puzzle/title
	# scenes — they have no player, so there's nothing to anchor to).
	var players : Array = tree.get_nodes_in_group("player")
	if scene_path.is_empty() or players.is_empty():
		_save()
		return
	last_scene = scene_path
	last_position = (players[0] as Node2D).global_position
	_save()


# Clear the save file and reset state. Useful for a "New Game" button.
# Resets fields under the save-suppress guard so the New Game wipe writes
# the file exactly once (via the final _save) instead of once per setter.
func clear_save() -> void:

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_suppress_save = true
	total_coins = STARTING_GOLD
	lifetime_coins_earned = 0
	hired_at_workshop = false
	godfrey_lumber_stock = 0
	hired_at_forge = false
	cinder_ore_stock = 0
	has_seen_intro = false
	frontier_unlocked = false
	puzzle_mastery = {}
	trophies_seen = []
	trophies_claimed = []
	owned_ships = []
	ship_condition = {}
	ship_custom_names = {}
	active_ship = ""
	game_minutes = 480.0   # a fresh game wakes at 08:00
	player_name = ""       # named at the New Game prompt
	owned_weapons = ["brawl"]
	equipped_weapon = "brawl"
	npc_affinity = {}
	npc_favor_done = {}
	crew = {}
	active_favors = {}
	pending_challenges = []
	npc_battle_record = {}
	npc_chat_log = {}
	recent_duel = {}
	tournaments_won = 0
	last_scene = ""
	last_position = Vector2.ZERO
	inventory_capacity = INVENTORY_START_CAPACITY
	_init_inventory()
	_suppress_save = false
	inventory_changed.emit()
	wood_changed.emit(0)
	ore_changed.emit(0)
	ore_stock_changed.emit(0)
	ships_changed.emit()
	objective_changed.emit()
	clear_voyage()   # a New Game wipes any in-flight pillage too (the voyage fields are transient + unsaved)
	_save()


func _save() -> void:

	# Guarded so loads / batch resets don't write the file mid-update
	# (see [member _suppress_save]).
	if _suppress_save:
		return
	var config : ConfigFile = ConfigFile.new()
	config.set_value(SAVE_SECTION, "total_coins", total_coins)
	config.set_value(SAVE_SECTION, "lifetime_coins_earned", lifetime_coins_earned)
	config.set_value(SAVE_SECTION, "inventory", inventory)
	config.set_value(SAVE_SECTION, "inventory_capacity", inventory_capacity)
	config.set_value(SAVE_SECTION, "hired_at_workshop", hired_at_workshop)
	config.set_value(SAVE_SECTION, "godfrey_lumber_stock", godfrey_lumber_stock)
	config.set_value(SAVE_SECTION, "hired_at_forge", hired_at_forge)
	config.set_value(SAVE_SECTION, "cinder_ore_stock", cinder_ore_stock)
	config.set_value(SAVE_SECTION, "has_seen_intro", has_seen_intro)
	config.set_value(SAVE_SECTION, "frontier_unlocked", frontier_unlocked)
	config.set_value(SAVE_SECTION, "puzzle_mastery", puzzle_mastery)
	config.set_value(SAVE_SECTION, "mastery_model", "sustained_v1")
	config.set_value(SAVE_SECTION, "trophies_seen", trophies_seen)
	config.set_value(SAVE_SECTION, "trophies_claimed", trophies_claimed)
	config.set_value(SAVE_SECTION, "owned_ships", owned_ships)
	config.set_value(SAVE_SECTION, "ship_condition", ship_condition)
	config.set_value(SAVE_SECTION, "ship_custom_names", ship_custom_names)
	config.set_value(SAVE_SECTION, "active_ship", active_ship)
	config.set_value(SAVE_SECTION, "game_minutes", game_minutes)
	config.set_value(SAVE_SECTION, "player_name", player_name)
	config.set_value(SAVE_SECTION, "owned_weapons", owned_weapons)
	config.set_value(SAVE_SECTION, "equipped_weapon", equipped_weapon)
	config.set_value(SAVE_SECTION, "weapons_model", "items_v1")
	config.set_value(SAVE_SECTION, "npc_affinity", npc_affinity)
	config.set_value(SAVE_SECTION, "npc_favor_done", npc_favor_done)
	config.set_value(SAVE_SECTION, "crew", crew)
	config.set_value(SAVE_SECTION, "active_favors", active_favors)
	config.set_value(SAVE_SECTION, "pending_challenges", pending_challenges)
	config.set_value(SAVE_SECTION, "npc_battle_record", npc_battle_record)
	config.set_value(SAVE_SECTION, "npc_chat_log", npc_chat_log)
	config.set_value(SAVE_SECTION, "tournaments_won", tournaments_won)
	config.set_value(SAVE_SECTION, "last_scene", last_scene)
	config.set_value(SAVE_SECTION, "last_position_x", last_position.x)
	config.set_value(SAVE_SECTION, "last_position_y", last_position.y)
	config.save(SAVE_PATH)


func _load() -> void:

	var config : ConfigFile = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	# Suppress per-field saves while we assign — the property setters each
	# call _save(), which (before this guard) wrote the file before
	# npc_affinity/last_scene/last_position were read back, blanking them
	# on disk. Audited 2026-05-29.
	_suppress_save = true
	total_coins = int(config.get_value(SAVE_SECTION, "total_coins", STARTING_GOLD))
	# Backfill old saves (pre-trophy) with their current balance as lifetime.
	lifetime_coins_earned = int(config.get_value(SAVE_SECTION, "lifetime_coins_earned", total_coins))
	hired_at_workshop = bool(config.get_value(SAVE_SECTION, "hired_at_workshop", false))
	godfrey_lumber_stock = int(config.get_value(SAVE_SECTION, "godfrey_lumber_stock", 0))
	hired_at_forge = bool(config.get_value(SAVE_SECTION, "hired_at_forge", false))
	cinder_ore_stock = int(config.get_value(SAVE_SECTION, "cinder_ore_stock", 0))
	has_seen_intro = bool(config.get_value(SAVE_SECTION, "has_seen_intro", false))
	frontier_unlocked = bool(config.get_value(SAVE_SECTION, "frontier_unlocked", false))
	puzzle_mastery = config.get_value(SAVE_SECTION, "puzzle_mastery", {})
	# Sustained-mastery migration (2026-06-11): old saves stored best-SCORES here, not accumulated points —
	# reset once so ranks are re-earned under the new model.
	if String(config.get_value(SAVE_SECTION, "mastery_model", "")) != "sustained_v1":
		puzzle_mastery = {}
	trophies_seen = config.get_value(SAVE_SECTION, "trophies_seen", [])
	trophies_claimed = config.get_value(SAVE_SECTION, "trophies_claimed", [])
	owned_ships = config.get_value(SAVE_SECTION, "owned_ships", [])
	ship_condition = config.get_value(SAVE_SECTION, "ship_condition", {})
	ship_custom_names = config.get_value(SAVE_SECTION, "ship_custom_names", {})
	active_ship = String(config.get_value(SAVE_SECTION, "active_ship", ""))
	game_minutes = float(config.get_value(SAVE_SECTION, "game_minutes", 480.0))
	player_name = String(config.get_value(SAVE_SECTION, "player_name", ""))
	owned_weapons = config.get_value(SAVE_SECTION, "owned_weapons", ["brawl"])
	equipped_weapon = String(config.get_value(SAVE_SECTION, "equipped_weapon", "brawl"))
	npc_affinity = config.get_value(SAVE_SECTION, "npc_affinity", {})
	npc_favor_done = config.get_value(SAVE_SECTION, "npc_favor_done", {})
	crew = config.get_value(SAVE_SECTION, "crew", {})
	active_favors = config.get_value(SAVE_SECTION, "active_favors", {})
	pending_challenges = config.get_value(SAVE_SECTION, "pending_challenges", [])
	npc_battle_record = config.get_value(SAVE_SECTION, "npc_battle_record", {})
	npc_chat_log = config.get_value(SAVE_SECTION, "npc_chat_log", {})
	tournaments_won = int(config.get_value(SAVE_SECTION, "tournaments_won", 0))
	last_scene = String(config.get_value(SAVE_SECTION, "last_scene", ""))
	last_position = Vector2(
		float(config.get_value(SAVE_SECTION, "last_position_x", 0.0)),
		float(config.get_value(SAVE_SECTION, "last_position_y", 0.0)),
	)
	inventory_capacity = int(config.get_value(SAVE_SECTION, "inventory_capacity", INVENTORY_START_CAPACITY))
	_load_inventory(config)
	# Weapons-are-items migration (2026-06-11): fold the old owned_weapons list into the bag as items (the
	# equipped one too — equipped_weapon still just flags it). Direct slot insert to skip add_item's sfx/log.
	if String(config.get_value(SAVE_SECTION, "weapons_model", "")) != "items_v1":
		for wid in owned_weapons:
			var w : String = String(wid)
			if w == SkirmishWeapon.DEFAULT_WEAPON or _inventory_has(w):
				continue
			for i in inventory.size():
				if (inventory[i] as Dictionary).is_empty():
					inventory[i] = {"id": w, "count": 1}
					break
		owned_weapons = [SkirmishWeapon.DEFAULT_WEAPON]
	_suppress_save = false
	# Mark already-earned trophies as seen so loading never spam-toasts; only live earns notify.
	_seed_trophies_seen()


# Restore the backpack from the save file. Rebuilds a clean
# inventory_capacity-length slot array, copying saved slots in. Migrates
# legacy saves that stored a flat `total_wood` int (pre-inventory) by
# seeding that much wood into the fresh backpack.
func _load_inventory(config: ConfigFile) -> void:

	_init_inventory()
	# New-format save: an "inventory" key exists (even if the bag was
	# empty). has_section_key distinguishes it from a legacy/fresh save
	# AND avoids get_value's "null default = error" footgun.
	if config.has_section_key(SAVE_SECTION, "inventory"):
		var saved : Variant = config.get_value(SAVE_SECTION, "inventory", [])
		if saved is Array:
			for i in mini(saved.size(), inventory.size()):
				var slot : Variant = saved[i]
				if slot is Dictionary and not slot.is_empty() and slot.has("id") and slot.has("count"):
					inventory[i] = {"id": String(slot["id"]), "count": int(slot["count"])}
		return
	# Legacy migration: pre-inventory saves carried a flat total_wood int.
	var legacy_wood : int = int(config.get_value(SAVE_SECTION, "total_wood", 0))
	if legacy_wood > 0:
		add_item(ITEM_WOOD, legacy_wood)
