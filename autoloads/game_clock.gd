## GameClock — a lightweight in-game clock (Troy 2026-06-10: the NPCs always thought it was evening). Time
## advances in REAL time while you play; a full in-game DAY passes in REAL_SECONDS_PER_DAY. The single source
## of truth is PlayerState.game_minutes (a plain persisted float — written by the normal save cycle + on quit),
## so the hour survives scene changes AND reloads. NPCs fold prompt_line() into their chat prompt so greetings
## match the time of day. No heavy sim — one advancing float + a phase-change signal. Autoloaded AFTER PlayerState.
extends Node


signal phase_changed(phase: String)

const REAL_SECONDS_PER_DAY : float = 1800.0   # 30 real minutes = one in-game day
const DAY_MINUTES : float = 1440.0            # 24 × 60

var _last_phase : String = ""


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS   # keep time flowing even while a modal pauses the tree
	_last_phase = phase()


func _process(delta: float) -> void:

	var per_real : float = DAY_MINUTES / REAL_SECONDS_PER_DAY   # in-game minutes per real second
	PlayerState.game_minutes = fposmod(PlayerState.game_minutes + delta * per_real, DAY_MINUTES)
	var p : String = phase()
	if p != _last_phase:
		_last_phase = p
		phase_changed.emit(p)


func hour() -> int:

	return int(PlayerState.game_minutes / 60.0) % 24


func minute() -> int:

	return int(PlayerState.game_minutes) % 60


## A descriptive time-of-day bucket the NPCs speak to.
func phase() -> String:

	var h : int = hour()
	if h < 5:
		return "the dead of night"
	if h < 8:
		return "early morning"
	if h < 11:
		return "mid-morning"
	if h < 13:
		return "midday"
	if h < 17:
		return "afternoon"
	if h < 20:
		return "evening"
	if h < 22:
		return "nightfall"
	return "late night"


func is_night() -> bool:

	var h : int = hour()
	return h < 5 or h >= 20


## A compact 12-hour clock readout for the HUD clock widget ("7:10 AM").
func time_string() -> String:

	var h : int = hour()
	var period : String = "AM" if h < 12 else "PM"
	@warning_ignore("integer_division")
	var h12 : int = h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, minute(), period]


## A natural 12-hour readout ("about 3 in the afternoon").
func clock_phrase() -> String:

	var h : int = hour()
	var period : String = "in the morning"
	if h >= 12 and h < 17:
		period = "in the afternoon"
	elif h >= 17 and h < 21:
		period = "in the evening"
	elif h >= 21 or h < 5:
		period = "at night"
	var h12 : int = h % 12
	if h12 == 0:
		h12 = 12
	return "about %d %s" % [h12, period]


## The clause NpcBrain folds into the system prompt so greetings match the hour (fixes "always evening").
func prompt_line() -> String:

	return ("TIME OF DAY: Right now it is %s on the island (%s). Greet and speak to THIS time of day — it is "
		+ "NOT always evening. Match the hour naturally (a morning hello, a midday word, a late-night remark), "
		+ "and don't force the time into every line.") % [phase(), clock_phrase()]
