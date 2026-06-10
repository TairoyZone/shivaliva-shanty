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

signal reached_stop        # the sloop arrived at the next node — the deck/Loft handles the event there
signal reached_encounter   # the sloop reached this leg's swords (a random mid-leg spot) — board 'em

var _enc_fired : bool = false    # this crossing's encounter mark already signalled (fire once)
var _ship_t : float = 0.0        # current sloop position, 0..1 along the track
var _goal_t : float = 0.0        # the node she's sailing toward — she STOPS here
var _inited : bool = false       # resume the position from PlayerState on the first feed
var _bob : float = 0.0           # bob phase (gentle sway on the wind)
var _sail_speed : float = 0.05   # track-fraction/sec — set ENTIRELY by the crew's sailing skill
var _bg : StyleBoxFlat           # self-drawn panel backing (so any scene can drop us in bare)

const SIZE : Vector2 = Vector2(326.0, 116.0)
const COLLAPSED_H : float = 30.0   # the thin one-line strip height when collapsed (hover to expand)
const EXPAND_TIME : float = 0.22

var _collapsible : bool = false    # deck chart only: a thin top strip that expands DOWN on hover
var _collapsed : bool = true
var _h_tween : Tween
## She sails CONTINUOUSLY while you work the station (deck + Loft charts share voyage_ship_t, so
## the progress is identical on both screens), STOPPING at each node where the event fires. Pace
## is how good the crew are (avg duty_skill) — slow enough to fill a puzzle session per leg.
const SAIL_SECS_SLOW : float = 36.0   # seconds to cross one leg with no / poor crew
const SAIL_SECS_FAST : float = 18.0   # …with a top crew
const BOB_RATE : float = 2.4
const BOB_AMP : float = 2.5


func _ready() -> void:

	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_bg = StyleBoxFlat.new()
	_bg.bg_color = Palette.PANEL_TROUGH   # the deck's cool-HUD family (shared w/ the MeterBar troughs)
	_bg.border_color = Palette.SKY_FRAME
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


# Deck variant: a THIN top-CENTRE strip (dest + stop + pool) that expands DOWN into the full route on
# hover, then collapses again — keeps the busy bottom-left clear (chat + feed live there). Troy 2026-06-07.
func place_collapsed_top(parent: CanvasLayer) -> void:

	_collapsible = true
	_collapsed = true
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -SIZE.x * 0.5
	offset_right = SIZE.x * 0.5
	offset_top = 14.0
	offset_bottom = 14.0 + COLLAPSED_H
	parent.add_child(self)
	# _ready (run on add_child) sets custom_minimum_size = SIZE (116 tall) AND mouse_filter = IGNORE — override
	# BOTH here, AFTER add_child: clear the min-size so the offsets + the tween control the height, and set the
	# filter to STOP so the strip actually CATCHES the click to toggle open/folded. (Setting STOP *before*
	# add_child silently lost — _ready's IGNORE clobbered it, so the chart could never expand. The bug.)
	custom_minimum_size = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_STOP   # CLICK the strip to toggle open/folded — it STAYS as you leave it


# CLICK the strip to TOGGLE it open/folded — it stays that way until you click again (Troy 2026-06-07:
# a persistent toggle, not hover-to-peek). mouse_filter is STOP so the click lands here (and is consumed,
# so it never also mans a deck station underneath).
func _gui_input(event: InputEvent) -> void:

	if not _collapsible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_collapsed = not _collapsed
		_tween_height((14.0 + COLLAPSED_H) if _collapsed else (14.0 + SIZE.y))
		accept_event()


func _tween_height(target_bottom: float) -> void:

	if _h_tween != null and _h_tween.is_valid():
		_h_tween.kill()
	_h_tween = create_tween()
	_h_tween.tween_property(self, "offset_bottom", target_bottom, EXPAND_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# (No parallel repaint driver needed — _process queue_redraw()s every frame while we're in the tree.)


# Pull the live route straight from PlayerState. `sailing` = she's CROSSING a leg now (sails
# toward the NEXT node); else she HOLDS at the current node. Pace comes from the crew's skill.
func refresh_from_state(sailing: bool) -> void:

	var dest : String = PlayerState.pillage_destination if not PlayerState.pillage_destination.is_empty() else "the lanes"
	# The CANONICAL pool (includes the class hold mult). Don't re-sum pillage_log raw here — that omitted
	# voyage_booty_mult, so the chart undersold a galleon's pool the whole crossing (audit 2026-06-10).
	var haul : int = PlayerState.voyage_total_gold()
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
# next node and signalling reached_stop there (the deck/Loft decides report-or-fight).
func set_route(dest: String, total: int, done: int, leg_log: Array, encounters: Array,
		haul: int, sailing: bool = false) -> void:

	_dest = dest
	_total = maxi(1, total)
	_done = done
	_log = leg_log
	_encounters = encounters
	_haul = haul
	# Where she's bound RIGHT NOW: holding at the current node, or sailing to the NEXT node (the
	# stop). Whatever waits at that stop — a report or a fight — fires there when she arrives.
	if done >= _total:
		_goal_t = 1.0                                                     # arrived — up to the isle
	elif sailing:
		_goal_t = clampf((float(done) + 1.0) / float(_total), 0.0, 1.0)   # crossing → the next stop
	else:
		_goal_t = clampf(float(done) / float(_total), 0.0, 1.0)           # holding AT this node
	if not _inited:
		_ship_t = clampf(PlayerState.voyage_ship_t, 0.0, _goal_t)
		_inited = true
	_enc_fired = false   # re-arm this crossing's encounter mark
	queue_redraw()


# Sail toward the goal at the crew's pace; fire reached_stop when she makes the node. A gentle
# bob keeps her alive even while holding at a stop.
func _process(delta: float) -> void:

	if not is_equal_approx(_ship_t, _goal_t):
		var prev : float = _ship_t
		_ship_t = move_toward(_ship_t, _goal_t, _sail_speed * delta)
		if is_equal_approx(_ship_t, _goal_t):
			_ship_t = _goal_t   # snap so reached_stop + needs_sail() never disagree on arrival
		PlayerState.voyage_ship_t = _ship_t   # carry the position across scene swaps (deck↔Loft sync)
		# Crossed this leg's swords (the random mid-leg fight spot)? Board 'em.
		if not _enc_fired and _is_encounter(_done):
			var ft : float = _fight_t(_done)
			if prev < ft and _ship_t >= ft:
				_enc_fired = true
				reached_encounter.emit()
		if _ship_t == _goal_t:
			reached_stop.emit()               # reached the stop — the deck/Loft fires its event
	_bob += delta
	queue_redraw()


# Has she still got track to cover before her goal? (The deck uses this to know whether a
# crossing will actually animate, so a zero-distance "sail" still triggers the stop logic.)
func needs_sail() -> bool:

	return not is_equal_approx(_ship_t, _goal_t)


# The stop she's bound for (0..1). The Loft snaps her here when you finish your station early.
func goal_t() -> float:

	return _goal_t


# Hold her exactly where she is (e.g. parked at the swords while the boarding cry plays).
func freeze() -> void:

	_goal_t = _ship_t


# Park her exactly AT the node she's bound for — used when a station FINISHES EARLY (the leg ends
# now), so the persisting chart doesn't carry a short-of-the-node position into the next leg.
func snap_to_goal() -> void:

	_ship_t = _goal_t
	PlayerState.voyage_ship_t = _ship_t
	queue_redraw()


# Mark THIS leg's encounter as already met (a post-fight chart re-armed it in refresh_from_state) —
# so the resumed crossing never re-signals a foe you've already boarded. Next leg re-arms it.
func mark_encounter_fired() -> void:

	_enc_fired = true


# This leg's logged report (or {} if not run yet).
func _report(leg_i: int) -> Dictionary:

	for r in _log:
		if int(r.get("leg", -1)) == leg_i:
			return r
	return {}


func _node_x(i: int) -> float:

	var span : float = size.x - LM - RM
	return LM + span * float(i) / float(_total)


func _pos_x(t: float) -> float:

	return LM + (size.x - LM - RM) * t


# Where along the WHOLE track (0..1) this leg's swords / fight sits — the pre-rolled random
# mid-leg spot (default mid-leg if unrolled). Same value drawn + crossed, so they always agree.
func _fight_t(leg: int) -> float:

	var pos : Array = PlayerState.pillage_encounter_pos
	var frac : float = 0.5
	if leg >= 0 and leg < pos.size():
		frac = clampf(float(pos[leg]), 0.06, 0.94)
	return clampf((float(leg) + frac) / float(_total), 0.0, 1.0)


func _draw() -> void:

	if size.x < LM + RM + 8.0:
		return   # not laid out yet — skip a degenerate (negative-span) frame
	if _bg != null:
		draw_style_box(_bg, Rect2(Vector2.ZERO, size))
	var font : Font = get_theme_default_font()
	# Collapsed deck strip: one line (dest left, stop + pool right, a ▾ expand hint). Hover shows the route.
	if _collapsible and _collapsed:
		if font != null:
			var arrived0 : bool = _done >= _total
			var stop0 : String = "Arrived!" if arrived0 else "Stop %d/%d" % [mini(_done + 1, _total), _total]
			var right0 : String = "%s   ·   Pool %dg   ▾" % [stop0, _haul]
			# Draw the right block first, then CLAMP the left dest to the space left over so a long
			# destination name clips instead of colliding with the stop/pool. Both at 14 / one baseline
			# (was 14 vs 13 on two y's, reading as two mismatched fragments on one line).
			draw_string(font, Vector2(0.0, 20.0), right0,
				HORIZONTAL_ALIGNMENT_RIGHT, size.x - RM + 8.0, 14, TEXT_STOP)
			var rw : float = font.get_string_size(right0, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
			var left_max : float = maxf((size.x - RM + 8.0) - rw - (LM - 6.0) - 12.0, 24.0)
			draw_string(font, Vector2(LM - 6.0, 20.0), "Bound for %s" % _dest,
				HORIZONTAL_ALIGNMENT_LEFT, left_max, 14, TEXT_DEST)
		return
	var x0 : float = LM
	var ship_x : float = LM + (size.x - LM - RM) * _ship_t

	# Header: where we're bound. Size 14 to MATCH the collapsed strip's header — so the same "Bound for"
	# text doesn't resize when the chart toggles open. A ▴ at the right = "click to fold" (the deck strip).
	if font != null:
		draw_string(font, Vector2(LM - 6.0, 22.0), "Bound for %s" % _dest,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT_DEST)
		if _collapsible:
			draw_string(font, Vector2(0.0, 22.0), "▴", HORIZONTAL_ALIGNMENT_RIGHT, size.x - RM + 8.0, 14, TEXT_STOP)

	# The route track — dim ahead, bright behind the sloop.
	draw_line(Vector2(x0, TRACK_Y), Vector2(size.x - RM, TRACK_Y), TRACK_DIM, 4.0)
	draw_line(Vector2(x0, TRACK_Y), Vector2(ship_x, TRACK_Y), TRACK_LIT, 4.0)

	# Encounter marks (crossed swords) at the random MID-LEG spot where the foe is met (between
	# the stops, never pinned to a node) — the sloop boards 'em when she reaches the mark.
	for i in _total:
		if not _is_encounter(i):
			continue
		var col : Color = SWORD_PEND
		var rep : Dictionary = _report(i)
		if not rep.is_empty():
			col = SWORD_WON if bool(rep.get("won", false)) else SWORD_LOST
		_draw_swords(Vector2(_pos_x(_fight_t(i)), TRACK_Y - 16.0), col)   # clear of the island/dot below

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
		var haul_txt : String = "Pool: %d gold" % _haul   # the PRE-divvy plunder pool (your cut scales by duty at the end)
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
