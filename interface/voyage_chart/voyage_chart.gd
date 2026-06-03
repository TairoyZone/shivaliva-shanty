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
var _ship_t : float = 0.0        # current sloop position, 0..1 along the track
var _goal_t : float = 0.0        # where she's sailing toward right now (continuous creep)
var _inited : bool = false       # snap to the start stop on the first feed, then creep
var _bob : float = 0.0           # bob phase (gentle real-time sway on the wind)
var _bg : StyleBoxFlat           # self-drawn panel backing (so any scene can drop us in bare)

const SIZE : Vector2 = Vector2(326.0, 116.0)
## Real-time sailing: the sloop steadily creeps toward ~80% of the CURRENT leg (so you always
## SEE her making way while you work), and clearing a stop nudges the goal a leg further on.
const CREEP_SPEED : float = 0.05     # track-fraction per second
const CREEP_FRAC : float = 0.8       # how far into the working leg she sails before the stop
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


# Pull the live route straight from PlayerState (so callers don't duplicate the read).
func refresh_from_state(animate: bool) -> void:

	var dest : String = PlayerState.pillage_destination if not PlayerState.pillage_destination.is_empty() else "the lanes"
	var haul : int = 0
	for r in PlayerState.pillage_log:
		haul += int(r.get("gold", 0))
	set_route(dest, PlayerState.pillage_legs_total, PlayerState.pillage_log.size(),
		PlayerState.pillage_log, PlayerState.pillage_encounters, haul, animate)


# Feed the live route. The sloop SAILS toward her goal continuously (see _process); a cleared
# stop just moves the goal a leg onward, so she keeps making way rather than teleporting.
# (`animate` is vestigial now that motion is continuous — kept for the call sites.)
func set_route(dest: String, total: int, done: int, leg_log: Array, encounters: Array,
		haul: int, _animate: bool = false) -> void:

	_dest = dest
	_total = maxi(1, total)
	_done = done
	_log = leg_log
	_encounters = encounters
	_haul = haul
	if done >= _total:
		_goal_t = 1.0                                              # arrived — sail up to the isle
	else:
		_goal_t = clampf((float(done) + CREEP_FRAC) / float(_total), 0.0, 1.0)
	if not _inited:
		# Resume exactly where the sloop was on the last screen (capped only so she can't
		# overshoot the goal), so deck↔Loft swaps stay continuous AND a just-cleared stop lets
		# her sail smoothly THROUGH the node rather than snapping onto it.
		_ship_t = clampf(PlayerState.voyage_ship_t, 0.0, _goal_t)
		_inited = true
	queue_redraw()


# Sail toward the goal every frame + bob on the wind — the "real-time" motion.
func _process(delta: float) -> void:

	_ship_t = move_toward(_ship_t, _goal_t, CREEP_SPEED * delta)
	PlayerState.voyage_ship_t = _ship_t   # carry the position across scene swaps
	_bob += delta
	queue_redraw()


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
