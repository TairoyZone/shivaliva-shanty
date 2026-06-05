## Single source of truth for the parlor POKER table config — the stake ladder, the three bet
## structures, and everything DERIVED from a "min bet" (blinds + buy-in range), à la Puzzle Pirates.
## Shared by the browser's Create dialog, the table prop, the poker scene, the board engine, and the
## AI so they never disagree on the rules. Pure static helpers. See [[parlor-social-system]].
class_name PokerConfig
extends RefCounted


## The three betting formats. NO_LIMIT is the engine's native mode (the board is already no-limit).
enum BetStructure { FIXED_LIMIT, POT_LIMIT, NO_LIMIT }

## The stake ladder, as MIN-BET values (in gold). Everything else derives from these:
##   buy-in range = 10× .. 100× min-bet   ·   blinds = 0.5× / 1× min-bet.
## So: min-bet 2 → buy-in 20–200, blinds 1/2;  20 → 200–2000, 10/20;  200 → 2000–20000, 100/200.
const STAKE_MIN_BETS : Array[int] = [2, 20, 200]
const SEAT_MIN : int = 2
const SEAT_MAX : int = 10
const TURN_TIMES : Array[int] = [10, 20, 30]
const DEFAULT_TURN_TIME : int = 20
## House cut taken off each CONTESTED pot before payout (a gold sink). 0 on free tables.
const RAKE_FRACTION : float = 0.05


static func structure_name(s: int) -> String:

	match s:
		BetStructure.FIXED_LIMIT:
			return "Fixed Limit"
		BetStructure.POT_LIMIT:
			return "Pot Limit"
		_:
			return "No Limit"


static func small_blind(min_bet: int) -> int:

	@warning_ignore("integer_division")
	return maxi(1, min_bet / 2)


static func big_blind(min_bet: int) -> int:

	return min_bet


static func buy_in_min(min_bet: int) -> int:

	return min_bet * 10


static func buy_in_max(min_bet: int) -> int:

	return min_bet * 100


## A fresh default table config (No Limit, lowest stake, a 6-seat table). buy_in is 0 until the
## player picks one at the buy-in dialog.
static func make_default() -> Dictionary:

	return {
		"structure": BetStructure.NO_LIMIT,
		"min_bet": STAKE_MIN_BETS[0],
		"seats": 6,
		"turn_time": DEFAULT_TURN_TIME,
		"buy_in": 0,
	}


## Coerce/repair a (possibly partial) config dict to a full, valid one.
static func normalize(cfg: Dictionary) -> Dictionary:

	var mb : int = int(cfg.get("min_bet", STAKE_MIN_BETS[0]))
	if not (mb in STAKE_MIN_BETS):
		mb = STAKE_MIN_BETS[0]
	return {
		"structure": clampi(int(cfg.get("structure", BetStructure.NO_LIMIT)), 0, 2),
		"min_bet": mb,
		"seats": clampi(int(cfg.get("seats", 6)), SEAT_MIN, SEAT_MAX),
		"turn_time": int(cfg.get("turn_time", DEFAULT_TURN_TIME)),
		"buy_in": int(cfg.get("buy_in", 0)),
	}


## A one-line stake/structure label for a browser row or the table felt.
static func describe(cfg: Dictionary) -> String:

	var mb : int = int(cfg.get("min_bet", STAKE_MIN_BETS[0]))
	return "%d %s  ·  blinds %d/%d  ·  buy-in %d–%dg" % [
		mb, structure_name(int(cfg.get("structure", BetStructure.NO_LIMIT))),
		small_blind(mb), big_blind(mb), buy_in_min(mb), buy_in_max(mb)]
