## THE VOYAGE CHART — the YPP-style pillage progress ribbon shown on the [ShipDeck].
## A drawn route: your HOME isle on the left, the DESTINATION island on the right,
## waypoint nodes between, and a little SLOOP that sails along the line — animating its
## hop forward each time a stop is cleared ([[animate-everything-principle]]). Legs that
## hold an ENCOUNTER carry a crossed-swords mark (green = beat 'em, orange = they fled,
## faint = still ahead). Placeholder-first procedural _draw() art — no labels-as-chrome,
## the only text is the destination name + the stop/haul tallies.
class_name VoyageChart
extends Control


const TRACK_DIM : Color = Color(0.34, 0.42, 0.60, 0.85)
const TRACK_LIT : Color = Color(0.62, 0.82, 1.0, 1.0)
const WAYPOINT : Color = Color(0.66, 0.74, 0.88, 1.0)
const ISLE : Color = Color(0.42, 0.70, 0.40, 1.0)
const ISLE_PEAK : Color = Color(0.56, 0.82, 0.52, 1.0)
const ISLE_EDGE : Color = Color(0.22, 0.42, 0.22, 1.0)
## The HOME isle you set out from — a cooler, muted green (it's behind you now).
const HOME_ISLE : Color = Color(0.50, 0.58, 0.50, 1.0)
const HOME_PEAK : Color = Color(0.62, 0.70, 0.60, 1.0)
const HULL_C : Color = Color(0.52, 0.34, 0.16, 1.0)
const HULL_EDGE : Color = Color(0.30, 0.19, 0.09, 1.0)
const SAIL_C : Color = Color(0.96, 0.94, 0.86, 1.0)
const MAST_C : Color = Color(0.30, 0.19, 0.09, 1.0)
const SWORD_PEND : Color = Color(0.60, 0.66, 0.78, 0.85)
const SWORD_WON : Color = Color(0.55, 0.95, 0.58, 1.0)
const SWORD_LOST : Color = Color(1.0, 0.74, 0.50, 1.0)
const TEXT_DEST : Color = Color(0.88, 0.94, 1.0, 1.0)
const TEXT_STOP : Color = Color(0.92, 0.90, 0.70, 1.0)
const TEXT_HAUL : Color = Color(0.98, 0.86, 0.46, 1.0)

const LM : float = 24.0          # left/right track margins
const RM : float = 26.0
const TRACK_Y : float = 62.0

var _dest : String = ""
var _total : int = 1
var _done : int = 0
var _log : Array = []
var _encounters : Array = []
var _haul : int = 0

signal reached_stop        # the sloop arrived at a route node (a league point) — show the report
signal reached_encounter   # the sloop reached an encounter leg's swords — time to board / fight

var _ship_t : float = 0.0        # current sloop position, 0..1 along the track
var _goal_t : float = 0.0        # the node she's sailing toward — she STOPS here
var _inited : bool = false       # resume the position from PlayerState on the first feed
var _bob : float = 0.0           # bob phase (gentle sway on the wind)
var _sail_speed : float = 0.05   # track-fraction/sec — set ENTIRELY by the crew's sailing skill
var _enc_fired : bool = false    # this crossing's encounter mark already signalled (fire once)
var _bg : StyleBoxFlat           # self-drawn panel backing (so any scene can drop us in bare)

const SIZE : Vector2 = Vector2(326.0, 116.0)
## She STOPS at each node and only sails BETWEEN them; the pace is set by how good the crew are
## (their average duty_skill) — a top crew crosses a leg fast, no/poor crew the slowest.
const SAIL_SECS_SLOW : float = 7.0   # seconds to cross one leg with no / poor crew
const SAIL_SECS_FAST : float = 2.8   # …with a top crew
const BOB_RATE : float = 2.4
const BOB_AMP : float = 2.5


func _ready() -> void:

	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_bg = StyleBoxFlat.new()
	_bg.bg_color = Color(0.07, 0.10, 0.17, 0.92)
	_bg.border_color = Color(0.50, 0.62, 0.85, 0.92)
	_bg.set_border_width_all(2)
	_bg.set_corner_radius_all(10)
	# Repaint when the layout resolves our size (matches the codebase's other size-dependent
	# _draw Controls) — avoids a degenerate first frame at size (0,0).
	resized.connect(queue_redraw)


# Pin to a screen corner on a CanvasLayer (no wrapping panel needed — we draw our own bg).
func place_at(parent: CanvasLayer, top: bool) -> void:

	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0 if top else 1.0
	anchor_bottom = 0.0 if top else 1.0
	offset_left = 16.0
	offset_right = 16.0 + SIZE.x
	offset_top = 16.0 if top else -(16.0 + SIZE.y)
	offset_bottom = (16.0 + SIZE.y) if top else -16.0
	parent.add_child(self)


# Pull the live route straight from PlayerState. `sailing` = she's CROSSING a leg now (sails
# toward the NEXT node); else she HOLDS at the current node. Pace comes from the crew's skill.
func refresh_from_state(sailing: bool) -> void:

	var dest : String = PlayerState.pillage_destination if not PlayerState.pillage_destination.is_empty() else "the lanes"
	var haul : int = 0
	for r in PlayerState.pillage_log:
		haul += int(r.get("gold", 0))
	_sail_speed = _crew_sail_speed()
	set_route(dest, PlayerState.pillage_legs_total, PlayerState.pillage_log.size(),
		PlayerState.pillage_log, PlayerState.pillage_encounters, haul, sailing)


# Ship PACE = how good the crew are: the higher their average duty_skill, the faster she
# crosses a leg. No crew at all → the slowest pace. (The player's Loft does NOT affect speed.)
func _crew_sail_speed() -> float:

	var legs : int = maxi(1, PlayerState.pillage_legs_total)
	var sum : float = 0.0
	var n : int = 0
	for m in PlayerState.pillage_duty_crew:
		# Pace = the SAILING HANDS only — skip you, and skip the captain (he navigates, not sails).
		if bool(m.get("is_player", false)) or String(m.get("duty", "")) == DutyReport.CAPTAIN_DUTY:
			continue
		sum += float(m.get("skill", 0.0))
		n += 1
	var avg : float = (sum / float(n)) if n > 0 else 0.0
	var secs : float = lerpf(SAIL_SECS_SLOW, SAIL_SECS_FAST, clampf(avg, 0.0, 1.0))
	return (1.0 / float(legs)) / maxf(secs, 0.5)   # track-fraction/sec to cross one leg in `secs`


# Feed the live route. She sails toward _goal_t in _process at the crew's pace, STOPPING at the
# node; en route she signals reached_encounter (at an encounter leg's swords) and reached_stop.
func set_route(dest: String, total: int, done: int, leg_log: Array, encounters: Array,
		haul: int, sailing: bool = false) -> void:

	_dest = dest
	_total = maxi(1, total)
	_done = done
	_log = leg_log
	_encounters = encounters
	_haul = haul
	if done >= _total:
		_goal_t = 1.0                                                  # arrived — up to the isle
	elif sailing:
		_goal_t = clampf((float(done) + 1.0) / float(_total), 0.0, 1.0)  # crossing → the NEXT node
	else:
		_goal_t = clampf(float(done) / float(_total), 0.0, 1.0)          # holding AT this node
	if not _inited:
		_ship_t = clampf(PlayerState.voyage_ship_t, 0.0, _goal_t)
		_inited = true
	_enc_fired = false   # re-arm the encounter mark for this feed
	queue_redraw()


# Sail toward the goal at the crew's pace; fire reached_encounter at the swords and reached_stop
# at the node. A gentle bob keeps her alive even while holding at a stop.
func _process(delta: float) -> void:

	if _ship_t != _goal_t:
		var prev : float = _ship_t
		_ship_t = move_toward(_ship_t, _goal_t, _sail_speed * delta)
		PlayerState.voyage_ship_t = _ship_t   # carry the position across scene swaps
		if not _enc_fired and _is_encounter(_done):
			var mid : float = (float(_done) + 0.5) / float(_total)
			if prev < mid and _ship_t >= mid:
				_enc_fired = true
				reached_encounter.emit()
		if _ship_t == _goal_t:
			reached_stop.emit()
	_bob += delta
	queue_redraw()


# Has she still got track to cover before her goal? (The deck uses this to know whether a
# crossing will actually animate, so a zero-distance "sail" still triggers the stop logic.)
func needs_sail() -> bool:

	return not is_equal_approx(_ship_t, _goal_t)


# Hold her exactly where she is (e.g. parked at the swords while the boarding cry plays).
func freeze() -> void:

	_goal_t = _ship_t


# This leg's logged report (or {} if not run yet).
func _report(leg_i: int) -> Dictionary:

	for r in _log:
		if int(r.get("leg", -1)) == leg_i:
			return r
	return {}


func _node_x(i: int) -> float:

	var span : float = size.x - LM - RM
	return LM + span * float(i) / float(_total)


func _draw() -> void:

	if size.x < LM + RM + 8.0:
		return   # not laid out yet — skip a degenerate (negative-span) frame
	if _bg != null:
		draw_style_box(_bg, Rect2(Vector2.ZERO, size))
	var font : Font = get_theme_default_font()
	var x0 : float = LM
	var ship_x : float = LM + (size.x - LM - RM) * _ship_t

	# Header: where we're bound.
	if font != null:
		draw_string(font, Vector2(LM - 6.0, 22.0), "Bound for %s" % _dest,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_DEST)

	# The route track — dim ahead, bright behind the sloop.
	draw_line(Vector2(x0, TRACK_Y), Vector2(size.x - RM, TRACK_Y), TRACK_DIM, 4.0)
	draw_line(Vector2(x0, TRACK_Y), Vector2(ship_x, TRACK_Y), TRACK_LIT, 4.0)

	# Per-leg encounter marks (crossed swords) at each leg's midpoint above the line.
	for i in _total:
		var enc : bool = _is_encounter(i)
		if not enc:
			continue
		var mx : float = (_node_x(i) + _node_x(i + 1)) * 0.5
		var col : Color = SWORD_PEND
		var rep : Dictionary = _report(i)
		if not rep.is_empty():
			col = SWORD_WON if bool(rep.get("won", false)) else SWORD_LOST
		_draw_swords(Vector2(mx, TRACK_Y - 16.0), col)

	# Nodes: HOME isle (left, muted) · waypoint dots · DESTINATION isle (right, vivid).
	_draw_island(Vector2(_node_x(0), TRACK_Y), HOME_ISLE, HOME_PEAK)
	for i in range(1, _total):
		draw_circle(Vector2(_node_x(i), TRACK_Y), 4.0, WAYPOINT)
	_draw_island(Vector2(_node_x(_total), TRACK_Y), ISLE, ISLE_PEAK)

	# The sloop, sailing the line + a gentle bob on the wind (drawn last so she rides on top).
	var bob_y : float = sin(_bob * BOB_RATE) * BOB_AMP
	_draw_ship(Vector2(ship_x, TRACK_Y + bob_y))

	# Footer: stop tally (left) + haul (right).
	if font != null:
		var arrived : bool = _done >= _total
		var stop_txt : String = "Arrived!" if arrived \
			else "Stop %d of %d" % [mini(_done + 1, _total), _total]
		draw_string(font, Vector2(LM - 6.0, size.y - 8.0), stop_txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT_STOP)
		var haul_txt : String = "Haul: %d gold" % _haul
		draw_string(font, Vector2(0.0, size.y - 8.0), haul_txt,
			HORIZONTAL_ALIGNMENT_RIGHT, size.x - RM + 8.0, 14, TEXT_HAUL)


func _is_encounter(leg_i: int) -> bool:

	if leg_i >= 0 and leg_i < _encounters.size():
		return String(_encounters[leg_i]) != ""
	return false


func _draw_swords(c: Vector2, col: Color) -> void:

	# Two CROSSED SWORDS — blades crossing, hilts (pommel + guard) at the lower ends — so it
	# reads as "a fight on this leg", not a plain X.
	draw_line(c + Vector2(-5.0, 6.0), c + Vector2(5.0, -6.0), col, 2.0)    # blade ↗
	draw_line(c + Vector2(5.0, 6.0), c + Vector2(-5.0, -6.0), col, 2.0)    # blade ↖
	draw_line(c + Vector2(-7.0, 3.5), c + Vector2(-2.5, 5.5), col, 1.6)    # left crossguard
	draw_line(c + Vector2(7.0, 3.5), c + Vector2(2.5, 5.5), col, 1.6)      # right crossguard
	draw_circle(c + Vector2(-5.0, 6.0), 1.7, col)                          # left pommel
	draw_circle(c + Vector2(5.0, 6.0), 1.7, col)                           # right pommel


func _draw_island(c: Vector2, base: Color, peak_col: Color) -> void:

	# A little landmass with a peak — both ends of the route are islands (home + destination).
	draw_circle(c + Vector2(0.0, 3.0), 11.0, base)
	draw_arc(c + Vector2(0.0, 3.0), 11.0, 0.0, TAU, 24, ISLE_EDGE, 1.6)
	var peak : PackedVector2Array = PackedVector2Array([
		c + Vector2(-7.0, 1.0), c + Vector2(0.0, -13.0), c + Vector2(7.0, 1.0)])
	draw_colored_polygon(peak, peak_col)
	draw_polyline(peak, ISLE_EDGE, 1.4)


func _draw_ship(c: Vector2) -> void:

	# Hull (a small boat), a mast, and a sail bellied toward travel (rightward).
	var hull : PackedVector2Array = PackedVector2Array([
		c + Vector2(-11.0, 1.0), c + Vector2(11.0, 1.0),
		c + Vector2(7.0, 9.0), c + Vector2(-7.0, 9.0)])
	draw_colored_polygon(hull, HULL_C)
	draw_polyline(hull + PackedVector2Array([hull[0]]), HULL_EDGE, 1.4)
	draw_line(c + Vector2(0.0, 1.0), c + Vector2(0.0, -13.0), MAST_C, 2.0)
	var sail : PackedVector2Array = PackedVector2Array([
		c + Vector2(1.0, -12.0), c + Vector2(11.0, -1.0), c + Vector2(1.0, -1.0)])
	draw_colored_polygon(sail, SAIL_C)
	draw_polyline(sail + PackedVector2Array([sail[0]]), HULL_EDGE, 1.0)
