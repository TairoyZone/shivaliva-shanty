## ShipClasses — THE single source of truth for the three ship classes (Troy locked the "full spread"
## 2026-06-10): every stat traces to the catalog blurb — "one-seat skiff" → berths, "room for cargo" →
## hold, "built for long voyages" → route legs. The shop, PlayerState, the dock, the deck and the chat
## brain ALL read from here so the classes can never drift apart again (the old SHIP_NAMES id mismatch).
## ids ("driftpod"/"cloudcutter"/"skygalleon") persist in owned_ships — keep them stable forever.
class_name ShipClasses


const DEFS : Dictionary = {
	"driftpod": {
		"display": "Driftpod",
		"gold": 750,
		"blurb": "A one-seat skiff for short hops between nearby rocks.",
		"max_holes": 4,      # hull — the sink bar (reach it on a fight leg and she's lost)
		"crew_slots": 1,     # berths — how many of YOUR crew you can post to stations aboard
		"legs_min": 2,       # route length rolled for a self-captained voyage…
		"legs_max": 3,
		"booty_mult": 1.0,   # hold — scales the whole plunder pool on a self-captained run
		"moor_scale": 0.62,  # the berthed hull's visual size at the dock (× the prop's ship_scale)
		"masts": 1,
		"cannon_rows": [8.0],                      # deck dressing — rail-gun pairs along the hull
	},
	"cloudcutter": {
		"display": "Cloud Cutter",
		"gold": 3000,
		"blurb": "A nimble cutter — room for a small crew and some cargo.",
		"max_holes": 6,
		"crew_slots": 2,
		"legs_min": 2,
		"legs_max": 4,
		"booty_mult": 1.3,
		"moor_scale": 1.0,
		"masts": 2,
		"cannon_rows": [4.5, 8.0, 11.5],
	},
	"skygalleon": {
		"display": "Sky Galleon",
		"gold": 10000,
		"blurb": "A great hull built for long voyages across the void.",
		"max_holes": 9,
		"crew_slots": 4,
		"legs_min": 4,
		"legs_max": 6,
		"booty_mult": 1.6,
		"moor_scale": 1.32,
		"masts": 3,
		"cannon_rows": [3.0, 5.5, 8.0, 10.5, 13.0],
	},
}

## Selling back to the shipwright returns this fraction of the catalog price (earn-and-keep
## friendly: a sale is liquidity, not a punishment — but the shipwright takes his margin).
const SELL_FRACTION : float = 0.5

## Christening suggestions — the "random name" button cycles these (sky-canon flavored).
const NAME_IDEAS : Array = [
	"Skylark", "Stardust Queen", "Cloudchaser", "Morning Glory", "Windrunner",
	"The Wanderer", "Drifting Star", "Old Faithful", "Comet's Tail", "The Lucky Gull",
]


static func get_def(ship_id: String) -> Dictionary:

	return DEFS.get(ship_id, {})


static func display(ship_id: String) -> String:

	return String(get_def(ship_id).get("display", ship_id.capitalize()))


static func max_holes(ship_id: String) -> int:

	return int(get_def(ship_id).get("max_holes", 4))


static func crew_slots(ship_id: String) -> int:

	return int(get_def(ship_id).get("crew_slots", 1))


static func booty_mult(ship_id: String) -> float:

	return float(get_def(ship_id).get("booty_mult", 1.0))


static func gold_cost(ship_id: String) -> int:

	return int(get_def(ship_id).get("gold", 0))


static func sell_price(ship_id: String) -> int:

	return int(round(float(gold_cost(ship_id)) * SELL_FRACTION))


## The one-line stat strip shown on shop rows / the dock — sells WHY a bigger hull costs more.
static func stat_line(ship_id: String) -> String:

	var d : Dictionary = get_def(ship_id)
	if d.is_empty():
		return ""
	return "Hull %d  ·  %d crew berth%s  ·  %d–%d leg routes  ·  hold ×%.1f" % [
		int(d["max_holes"]), int(d["crew_slots"]), "" if int(d["crew_slots"]) == 1 else "s",
		int(d["legs_min"]), int(d["legs_max"]), float(d["booty_mult"])]
