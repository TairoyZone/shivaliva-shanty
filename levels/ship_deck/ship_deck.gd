## THE SHIP DECK — the walkable hub of a JOBBING pillage ([[pillage-research]]). You
## signed onto a crew at the Skydock; now you're aboard their ISOMETRIC SKYship, adrift
## in the high sky (NOT the sea — this world floats). The crew is AI/flavour; YOU work
## the one playable station — the **[[loft-spec]] LOFT** (keeps her aloft). The captain
## drives the pillage:
##   board → MAN THE LOFT → "brigand off the bow!" → BOARD (the Skirmish duel) → take
##   your CUT → DISEMBARK.
##
## Normal overworld camera (rides the Player). Iso-styled + ship-shaped so it walks right.
## Self-contained interactions (no per-station Interactable scenes): only the playable
## Loft takes E. Phase off [member PlayerState.pillage_phase], re-entered after each
## station/fight scene-swap. ⚠️ Procedural PLACEHOLDER art — real skyship sprites later.
class_name ShipDeck
extends BaseLocation


const LOFT_SCENE : String = "res://puzzles/loft/loft.tscn"
## Boarding the brigand = the crew-vs-crew [SkirmishBoarding] team fight (you + AI
## mates vs the brigand crew). The 1v1 skirmish_duel stays the Spar's friendly match.
const SKIRMISH_SCENE : String = "res://puzzles/skirmish/skirmish_boarding.tscn"
const SELF_SCENE : String = "res://levels/ship_deck/ship_deck.tscn"
const FALLBACK_HOME : String = "res://levels/shore/shore.tscn"
## Crew are REAL [Npc] instances (reuse the overworld character), not drawn figures.
const NPC_SCENE : PackedScene = preload("res://components/npc/npc.tscn")

const BOOTY_BASE : int = 40
const BOOTY_PER_LIFT_DIV : int = 6
const BOOTY_LIFT_BONUS_CAP : int = 100
const SEED_PER_LIFT_DIV : int = 150
## A LOST run still limps home with a small consolation cut (scaled to Loft lift) so a voyage
## is never a total zero — a first-timer never feels the whole run was wasted.
const BOOTY_LOSS_DIV : int = 14
const BOOTY_LOSS_CAP : int = 24
const SEED_CAP : int = 3
## A CALM stretch (no ship met) pays only modest SALVAGE, scaled to how well you flew the
## Loft — so calm legs still reward good sailing, but a fight is worth far more.
const SALVAGE_PER_LIFT_DIV : int = 10
const SALVAGE_MIN : int = 8
const SALVAGE_CAP : int = 40

## Iso deck grid (tiles) + tile size (2:1, matching the iso Player). Big, so the
## Player is a small figure on a roomy deck (stations don't overlap).
const GW : int = 8
const GH : int = 18
const TILE_W : float = 112.0
const TILE_H : float = 56.0
const HULL_H : float = 78.0
const INTERACT_RANGE : float = 95.0

## Functional station grid cells (well spread out).
const LOFT_G : Vector2 = Vector2(2.6, 7.0)     # the playable Loft
const HELM_G : Vector2 = Vector2(4.0, 3.2)     # captain's post + the navigation prop
const PLANK_G : Vector2 = Vector2(4.0, 15.2)   # the gangplank (disembark)
const SPAWN_G : Vector2 = Vector2(4.0, 13.0)

## Flavour (AI-manned) props: [grid_cell, kind]. Clean, unlabeled, well-spaced — pure
## decoration so the deck reads as a crewed ship without piling up text.
const FLAVOUR_STATIONS : Array = [
	[Vector2(6.0, 8.6), "sailing"],
	[Vector2(2.0, 11.4), "gunnery"],
	[Vector2(6.0, 12.4), "carpentry"],
]
## Ship hull outline in grid coords (pointed bow at high gy, flat stern at low gy).
const OUTLINE : Array = [
	Vector2(2.0, 1.0), Vector2(6.0, 1.0),
	Vector2(8.0, 3.0), Vector2(8.0, 12.5),
	Vector2(6.4, 15.5), Vector2(4.0, 18.0),
	Vector2(1.6, 15.5), Vector2(0.0, 12.5),
	Vector2(0.0, 3.0),
]

const DECK : Color = Color(0.64, 0.47, 0.27, 1.0)
const DECK_DARK : Color = Color(0.46, 0.31, 0.16, 1.0)
const PLANK_LINE : Color = Color(0.0, 0.0, 0.0, 0.13)
const HULL_SIDE : Color = Color(0.38, 0.25, 0.12, 1.0)
const RAIL : Color = Color(0.30, 0.19, 0.09, 1.0)
## The open sky the ship floats in (NOT sea — a high twilight blue).
const SKY : Color = Color(0.34, 0.50, 0.72, 1.0)
const STATION_BG : Color = Color(0.18, 0.25, 0.38, 0.92)
const STATION_LIVE : Color = Color(0.66, 0.90, 1.0, 1.0)
const STATION_IDLE : Color = Color(0.60, 0.64, 0.76, 1.0)

var _active : String = ""
var _prompt : Label
var _captain_label : Label
var _chart : VoyageChart         # the drawn voyage progress ribbon
var _crossing : bool = false     # the ship is sailing between stops — stations locked, watch her make way


# Iso projection, centred so the deck middle sits on the world origin.
func _iso(gx: float, gy: float) -> Vector2:

	return Vector2(
		(gx - gy) * TILE_W * 0.5 - float(GW - GH) * TILE_W * 0.25,
		(gx + gy) * TILE_H * 0.5 - float(GW + GH) * TILE_H * 0.25)


func _ready() -> void:

	pirate_spawn_position = _iso(SPAWN_G.x, SPAWN_G.y)
	_seed_demo_route_if_unset()
	super._ready()                 # spawns the Player under YSortNode2D (normal camera)
	_add_hull_collision()
	_add_crew()
	_build_ui()
	_setup_phase()
	queue_redraw()


# Entered standalone (running ship_deck.tscn directly, with no route laid in at the
# Voyages board)? Lay in a representative demo route so the chart + encounters still
# show their real selves. A real jobbed voyage always arrives with legs_total >= 2.
func _seed_demo_route_if_unset() -> void:

	if PlayerState.pillage_legs_total > 1 or not PlayerState.pillage_destination.is_empty() \
			or not PlayerState.pillage_log.is_empty():
		return
	PlayerState.pillage_destination = "Driftspar"
	PlayerState.pillage_destination_scene = "res://levels/frontier_isle/frontier_isle.tscn"
	PlayerState.pillage_legs_total = 3
	PlayerState.pillage_leg = 0
	PlayerState.pillage_log = []
	PlayerState.pillage_encounters = ["", "a marine cutter", ""]
	PlayerState.voyage_active = true
	PlayerState.voyage_ship_t = 0.0
	PlayerState.pillage_duty_crew = DutyReport.build_roster(_captain_name())
	PlayerState.last_duty_report = []


# --- Pillage phase ----------------------------------------------------

# The voyage now PLAYS OUT ON THE CHART: at a node you man the Loft (your duty), then the ship
# SAILS the leg at the crew's pace — fires the boarding when she reaches the swords, and the
# duty report when she makes the next node. Phase 0 = at a node; 1 = crossing; 2 = crossing
# after the boarding (resume to the node).
func _setup_phase() -> void:

	if _arrived():
		# Voyage's end. Also guards a redundant re-load so the last leg is never re-banked.
		_say("%s dead ahead — voyage's end! Total haul: %d gold. Take the plank to make port." % [
			_destination(), _voyage_total_gold()])
		_refresh_chart(false)
		return
	match PlayerState.pillage_phase:
		1:
			_say("Underway toward %s — hold fast, hand." % _destination())
			_begin_sail()
		2:
			_say("Back to the crossing — making way toward %s." % _destination())
			_begin_sail()
		_:
			if PlayerState.pillage_leg <= 0:
				_say("Welcome aboard, hand! Man the Loft, then we make for %s." % _destination())
			else:
				_say("Waypoint made — man the Loft for the next stretch toward %s." % _destination())
			_refresh_chart(false)


# Start (or resume) the crossing: the chart sails toward the next node at crew pace. If she's
# somehow already there (zero-distance), resolve the stop straight away.
func _begin_sail() -> void:

	_crossing = true
	_refresh_chart(true)
	if _chart != null and not _chart.needs_sail():
		# Degenerate zero-distance crossing: we still owe the boarding on an encounter leg.
		if PlayerState.pillage_phase == 1 and _is_encounter_leg(PlayerState.pillage_leg):
			_on_chart_reached_encounter()
		else:
			_on_chart_reached_stop()


# The sloop reached this leg's swords on the chart — board 'em (only on the first pass; the
# post-fight resume is phase 2, which this ignores). Cry the alarm and hold her at the swords
# for a beat BEFORE the Skirmish loads, so the boarding never reads as a teleport.
func _on_chart_reached_encounter() -> void:

	if PlayerState.pillage_phase != 1 or not _is_encounter_leg(PlayerState.pillage_leg):
		return
	if _chart != null:
		_chart.freeze()
	_say("Sail ho — %s off the bow! Grapples away, hands — board 'em!" % _foe_name(PlayerState.pillage_leg))
	await get_tree().create_timer(1.1).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return   # bailed (or left) during the cry
	_board_brigand()


# The sloop made the next node (a league point) — resolve the leg (fight booty or calm salvage)
# and post the DUTY REPORT here, the way YPP shows it at every league point.
func _on_chart_reached_stop() -> void:

	if not _crossing:
		return
	_crossing = false
	if _is_encounter_leg(PlayerState.pillage_leg):
		_resolve_boarding()
	else:
		_resolve_calm()
	_refresh_chart(false)   # update done/haul + hold at the node
	if not PlayerState.last_duty_report.is_empty():
		_show_duty_report()


# Back from the boarding Skirmish on an encounter leg → tally booty + report it.
func _resolve_boarding() -> void:

	var won : bool = PlayerState.last_skirmish_won
	var lift : int = PlayerState.last_loft_lift
	var cut : int = 0
	if won:
		@warning_ignore("integer_division")
		var bonus : int = clampi(lift / BOOTY_PER_LIFT_DIV, 0, BOOTY_LIFT_BONUS_CAP)
		cut = BOOTY_BASE + bonus
	else:
		@warning_ignore("integer_division")
		cut = clampi(lift / BOOTY_LOSS_DIV, 0, BOOTY_LOSS_CAP)
	if cut > 0:
		PlayerState.add_coins(cut)
	var line : String = ("We sent 'em running — %d gold for the cut!" % cut) if won \
		else ("They slipped our grapple — %d gold salvaged." % cut)
	_finish_leg({"leg": PlayerState.pillage_leg, "type": "fight", "won": won, "lift": lift, "gold": cut}, line)


# A calm stretch (no ship met) — bank modest salvage scaled to how well the Loft was flown.
func _resolve_calm() -> void:

	var lift : int = PlayerState.last_loft_lift
	@warning_ignore("integer_division")
	var cut : int = clampi(lift / SALVAGE_PER_LIFT_DIV, SALVAGE_MIN, SALVAGE_CAP)
	if cut > 0:
		PlayerState.add_coins(cut)
	_finish_leg({"leg": PlayerState.pillage_leg, "type": "calm", "won": true, "lift": lift, "gold": cut},
		"Clear skies — a fair stretch. %d gold in salvage." % cut)


# Log this stop's report (drives the chart), then either sail on to the next leg or, if this
# was the last stop, arrive at the destination island (a completed voyage → First Voyage).
func _finish_leg(entry: Dictionary, outcome_line: String) -> void:

	PlayerState.pillage_log.append(entry)
	# Log this leg's DUTY REPORT — your Loft rating (from lift) + each hand's simmed station.
	if not PlayerState.pillage_duty_crew.is_empty():
		PlayerState.last_duty_report = DutyReport.snapshot(PlayerState.pillage_duty_crew, int(entry.get("lift", 0)))
	if PlayerState.pillage_leg >= PlayerState.pillage_legs_total - 1:
		PlayerState.frontier_unlocked = true
		_say("%s  %s dead ahead — voyage's end! Total haul: %d gold. Take the plank to make port." % [
			outcome_line, _destination(), _voyage_total_gold()])
	else:
		PlayerState.pillage_leg += 1
		PlayerState.pillage_phase = 0
		_say("%s  Waypoint made — man the Loft for the next stretch toward %s." % [outcome_line, _destination()])


func _voyage_total_gold() -> int:

	var t : int = 0
	for r in PlayerState.pillage_log:
		t += int(r.get("gold", 0))
	return t


# The whole route is run — the destination island is reached; only the plank remains.
func _arrived() -> bool:

	return PlayerState.pillage_log.size() >= PlayerState.pillage_legs_total


func _destination() -> String:

	return PlayerState.pillage_destination if not PlayerState.pillage_destination.is_empty() else "the lanes"


# Does this leg hold an encounter (a ship to board)? "" in the pre-rolled list = calm sailing.
func _is_encounter_leg(leg_i: int) -> bool:

	var enc : Array = PlayerState.pillage_encounters
	if leg_i >= 0 and leg_i < enc.size():
		return String(enc[leg_i]) != ""
	return false   # no roll (shouldn't happen on a real voyage) → treat as calm


func _foe_name(leg_i: int) -> String:

	var enc : Array = PlayerState.pillage_encounters
	if leg_i >= 0 and leg_i < enc.size() and String(enc[leg_i]) != "":
		return String(enc[leg_i])
	return "a sky-brigand"


# --- Interactions (self-contained: proximity + E) --------------------

func _process(_delta: float) -> void:

	if player == null:
		return
	_active = _nearest_active_station()
	if _prompt != null:
		_prompt.visible = not _active.is_empty()
		if not _active.is_empty():
			_prompt.text = "[E]  %s" % _action_label(_active)


func _unhandled_input(event: InputEvent) -> void:

	if not event.is_action_pressed("interact") or _active.is_empty():
		return
	if Overlay.is_active or (HUD != null and HUD.is_inventory_open()):
		return
	get_viewport().set_input_as_handled()
	match _active:
		"loft":
			_man_loft()
		"plank":
			_disembark()


func _nearest_active_station() -> String:

	var here : Vector2 = player.global_position
	var best : String = ""
	var best_d : float = INTERACT_RANGE * INTERACT_RANGE
	for s in _stations_for_phase():
		var d : float = here.distance_squared_to(s[1])
		if d <= best_d:
			best_d = d
			best = s[0]
	return best


func _stations_for_phase() -> Array:

	# The plank (disembark) is ALWAYS available — you can leave the ship any time.
	var plank : Array = ["plank", _iso(PLANK_G.x, PLANK_G.y)]
	if _arrived():
		return [plank]   # voyage's end — the plank is all that's left
	match PlayerState.pillage_phase:
		1, 2:
			return [plank]   # crossing — watch her make way (the boarding fires itself at the swords)
		_:
			return [["loft", _iso(LOFT_G.x, LOFT_G.y)], plank]


func _action_label(id: String) -> String:

	match id:
		"loft":
			return "Man the Loft"
		"plank":
			return "Disembark"
	return ""


func _man_loft() -> void:

	PlayerState.last_loft_lift = 0
	PlayerState.pillage_phase = 1
	PlayerState.puzzle_return_scene = SELF_SCENE
	get_tree().change_scene_to_file(LOFT_SCENE)


func _board_brigand() -> void:

	PlayerState.last_skirmish_won = false
	PlayerState.pillage_phase = 2
	@warning_ignore("integer_division")
	var boarding_seed : int = clampi(PlayerState.last_loft_lift / SEED_PER_LIFT_DIV, 0, SEED_CAP)
	PlayerState.voyage_boarding_seed = boarding_seed
	PlayerState.skirmish_opponent = ""
	PlayerState.puzzle_return_scene = SELF_SCENE
	get_tree().change_scene_to_file(SKIRMISH_SCENE)


func _disembark() -> void:

	# Finished the route → step off at the DESTINATION island; bailed mid-voyage → back home.
	var arrived : bool = _arrived()
	var target : String = ""
	if arrived and not PlayerState.pillage_destination_scene.is_empty():
		target = PlayerState.pillage_destination_scene
	else:
		target = PlayerState.voyage_home_scene
	if target.is_empty():
		target = FALLBACK_HOME
	# Voyage's over either way — wipe the scaffolding so nothing stale carries to the next run.
	PlayerState.clear_voyage()
	get_tree().change_scene_to_file(target)


# --- UI (captain line + the E prompt) --------------------------------

func _build_ui() -> void:

	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 6
	add_child(layer)

	var banner : PanelContainer = PanelContainer.new()
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(12)
	banner.add_theme_stylebox_override("panel", s)
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_top = 18.0
	banner.offset_left = -380.0
	banner.offset_right = 380.0
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(banner)
	_captain_label = Label.new()
	_captain_label.add_theme_font_size_override("font_size", 19)
	_captain_label.add_theme_color_override("font_color", Color(0.98, 0.90, 0.62, 1.0))
	_captain_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_captain_label.add_theme_constant_override("outline_size", 3)
	_captain_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_captain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_captain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(_captain_label)

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color(0.80, 1.0, 0.66, 1.0))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 4)
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_top = -78.0
	_prompt.offset_left = -240.0
	_prompt.offset_right = 240.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	layer.add_child(_prompt)

	# Voyage CHART (self-contained, BOTTOM-LEFT — clear of the captain banner up top and the
	# [E] prompt bottom-centre). Populated by _setup_phase → _refresh_chart right after this.
	_chart = VoyageChart.new()
	_chart.place_at(layer, false)
	_chart.reached_stop.connect(_on_chart_reached_stop)
	_chart.reached_encounter.connect(_on_chart_reached_encounter)

	# DUTY REPORT button (top-left — how the crew fared last leg, YPP-style).
	var report_btn : Button = Button.new()
	report_btn.text = "Duty Report"
	report_btn.add_theme_font_size_override("font_size", 16)
	report_btn.anchor_left = 0.0
	report_btn.anchor_top = 0.0
	report_btn.offset_left = 16.0
	report_btn.offset_top = 16.0
	report_btn.offset_right = 176.0
	report_btn.offset_bottom = 52.0
	report_btn.pressed.connect(_open_duty_report)
	layer.add_child(report_btn)


func _say(line: String) -> void:

	if _captain_label != null:
		_captain_label.text = "Cap'n %s:  \"%s\"" % [_captain_name(), line]


# Open the YPP-style duty report (last leg's per-hand ratings) — one at a time.
func _open_duty_report() -> void:

	_show_duty_report()


func _show_duty_report() -> void:

	if get_tree().get_first_node_in_group("duty_report") != null:
		return   # already showing — don't stack panels
	add_child(DutyReportPanel.create(PlayerState.last_duty_report))


# Feed the live route into the drawn chart. `sailing` = she's crossing a leg now (sails toward
# the next node, crew-paced); false = hold at the current node.
func _refresh_chart(sailing: bool) -> void:

	if _chart == null:
		return
	_chart.refresh_from_state(sailing)


# The captain you jobbed onto at the [VoyagesBoard] (falls back to Jericho when
# the deck is entered without a board — e.g. captaining your own ship later).
func _captain_name() -> String:

	if not PlayerState.pillage_captain.is_empty():
		return PlayerState.pillage_captain
	return "Stormy Jericho"


# --- Hull collision (fences the player to the SHIP outline) ----------

# A hollow collision wall running along the ship's drawn outline (build_mode =
# SEGMENTS), so the player is contained on the actual ship shape — not a box around
# it. (The player's collision radius keeps their feet a touch inside the rail.)
func _add_hull_collision() -> void:

	var body : StaticBody2D = StaticBody2D.new()
	body.collision_layer = 2     # Walls — the Player masks this
	body.collision_mask = 0
	var poly : CollisionPolygon2D = CollisionPolygon2D.new()
	poly.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	var pts : PackedVector2Array = PackedVector2Array()
	for g in OUTLINE:
		pts.append(_iso(g.x, g.y))
	poly.polygon = pts
	body.add_child(poly)
	add_child(body)


# --- Procedural ISO ship (clean, stylized placeholder) ---------------
# NO floating labels anywhere — the only text is the captain banner + the [E] prompt
# (both fixed UI). The ONE station you need this phase GLOWS so it reads without a tag.

func _draw() -> void:

	draw_rect(Rect2(-2000.0, -2000.0, 4000.0, 4000.0), SKY)
	var deck : PackedVector2Array = PackedVector2Array()
	for g in OUTLINE:
		deck.append(_iso(g.x, g.y))
	# Hull depth (one clean tone; back walls hidden by the deck drawn over them).
	var down : Vector2 = Vector2(0.0, HULL_H)
	for i in deck.size():
		var a : Vector2 = deck[i]
		var b : Vector2 = deck[(i + 1) % deck.size()]
		draw_colored_polygon(PackedVector2Array([a, b, b + down, a + down]), HULL_SIDE)
	draw_colored_polygon(deck, DECK)
	# A few subtle plank lines for texture.
	for gy in range(3, GH - 1, 3):
		draw_line(_iso(0.5, float(gy)), _iso(float(GW) - 0.5, float(gy)), PLANK_LINE, 2.0)
	draw_polyline(deck + PackedVector2Array([deck[0]]), RAIL, 5.0)
	# Masts + a few rail cannons (clean, evenly spaced, no labels).
	_draw_mast(_iso(4.0, 6.0))
	_draw_mast(_iso(4.0, 11.0))
	for gy in [4.5, 8.0, 11.5]:
		_draw_cannon(_iso(0.7, gy))
		_draw_cannon(_iso(float(GW) - 0.7, gy))
	_draw_chest(_iso(5.4, 5.4))
	# Glow the ONE station this phase needs (its job is read by the glow, not a tag). While
	# crossing there's nothing to man — you just watch her make way — so no glow.
	if not _crossing:
		_draw_glow(_active_world_pos())
	# Clean station props (no labels): playable Loft + helm + the flavour props + plank.
	_draw_prop(_iso(LOFT_G.x, LOFT_G.y), "loft")
	_draw_prop(_iso(HELM_G.x, HELM_G.y), "navigation")
	for st in FLAVOUR_STATIONS:
		_draw_prop(_iso(st[0].x, st[0].y), st[1])
	_draw_plank(_iso(PLANK_G.x, PLANK_G.y))
	# (Crew are real Npc instances added in _add_crew — not drawn here.)


# World position of the station active this phase (the one that glows). Only used outside a
# crossing: at a node it's the Loft (your duty); on arrival it's the plank.
func _active_world_pos() -> Vector2:

	if _arrived():
		return _iso(PLANK_G.x, PLANK_G.y)
	return _iso(LOFT_G.x, LOFT_G.y)


# A soft accent halo marking the active station (no text needed).
func _draw_glow(pos: Vector2) -> void:

	var c : Color = STATION_LIVE
	draw_circle(pos + Vector2(0.0, 4.0), 42.0, Color(c.r, c.g, c.b, 0.13))
	draw_arc(pos + Vector2(0.0, 4.0), 38.0, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.85), 2.5)


# A clean station prop by kind — no labels.
func _draw_prop(pos: Vector2, kind: String) -> void:

	match kind:
		"loft":
			# A breath-stone on a pedestal — sing it alight to keep her aloft.
			draw_rect(Rect2(pos.x - 12.0, pos.y - 4.0, 24.0, 12.0), DECK_DARK)
			draw_rect(Rect2(pos.x - 12.0, pos.y - 4.0, 24.0, 12.0), STATION_LIVE, false, 2.0)
			var stone : PackedVector2Array = PackedVector2Array([
				pos + Vector2(0.0, -30.0), pos + Vector2(10.0, -17.0),
				pos + Vector2(0.0, -4.0), pos + Vector2(-10.0, -17.0)])
			draw_colored_polygon(stone, Color(STATION_LIVE.r, STATION_LIVE.g, STATION_LIVE.b, 0.45))
			draw_polyline(PackedVector2Array([stone[0], stone[1], stone[2], stone[3], stone[0]]),
				STATION_LIVE, 2.0)
		"navigation":
			draw_arc(pos, 16.0, 0.0, TAU, 24, RAIL, 4.0)
			draw_circle(pos, 5.0, Color(0.82, 0.66, 0.30, 1.0))
			for i in 6:
				var a : float = TAU * i / 6.0
				var d : Vector2 = Vector2(cos(a), sin(a))
				draw_line(pos + d * 12.0, pos + d * 20.0, DECK_DARK, 2.5)
		"sailing":
			draw_arc(pos, 15.0, 0.0, TAU, 24, Color(0.78, 0.68, 0.44, 1.0), 4.0)
			draw_arc(pos, 9.0, 0.0, TAU, 20, Color(0.70, 0.60, 0.38, 1.0), 4.0)
		"gunnery":
			_draw_cannon(pos)
		"carpentry":
			draw_rect(Rect2(pos.x - 16.0, pos.y - 8.0, 32.0, 6.0), Color(0.55, 0.40, 0.22, 1.0))
			draw_line(pos + Vector2(-12.0, -4.0), pos + Vector2(-4.0, 12.0), DECK_DARK, 3.0)
			draw_line(pos + Vector2(12.0, -4.0), pos + Vector2(4.0, 12.0), DECK_DARK, 3.0)


func _draw_mast(pos: Vector2) -> void:

	draw_circle(pos, 15.0, DECK_DARK)
	draw_circle(pos, 9.0, DECK)


func _draw_cannon(pos: Vector2) -> void:

	draw_rect(Rect2(pos.x - 9.0, pos.y - 6.0, 20.0, 12.0), Color(0.20, 0.21, 0.24, 1.0))
	draw_circle(pos + Vector2(-7.0, 4.0), 4.0, Color(0.12, 0.13, 0.15, 1.0))


func _draw_plank(pos: Vector2) -> void:

	var quad : PackedVector2Array = PackedVector2Array([
		pos + Vector2(-20.0, -8.0), pos + Vector2(20.0, 0.0),
		pos + Vector2(34.0, 46.0), pos + Vector2(-10.0, 40.0)])
	draw_colored_polygon(quad, Color(0.48, 0.32, 0.16, 1.0))
	draw_polyline(quad + PackedVector2Array([quad[0]]), Color(0.30, 0.19, 0.09, 1.0), 2.0)


func _draw_chest(pos: Vector2) -> void:

	draw_rect(Rect2(pos.x - 16.0, pos.y - 11.0, 32.0, 22.0), Color(0.46, 0.30, 0.14, 1.0))
	draw_rect(Rect2(pos.x - 16.0, pos.y - 11.0, 32.0, 22.0), Color(0.90, 0.74, 0.34, 1.0), false, 2.0)


# Crew = real [Npc] instances drawn from the DUTY-REPORT roster, so the hands you SEE on the
# deck are the very ones rated each leg. Each stands at their station, clear of the functional
# interact points (Loft / helm-board / plank) so their E-to-talk doesn't clash. You man the Loft.
func _add_crew() -> void:

	var ysort : Node = find_child("YSortNode2D", false, false)
	if ysort == null:
		ysort = self
	if PlayerState.pillage_duty_crew.is_empty():
		PlayerState.pillage_duty_crew = DutyReport.build_roster(_captain_name())
	for m in PlayerState.pillage_duty_crew:
		if bool(m.get("is_player", false)):
			continue
		var duty : String = String(m.get("duty", ""))
		_add_npc(ysort, String(m.get("name", "Hand")), _duty_station_pos(duty),
			m.get("tint", Color(0.5, 0.5, 0.62, 1.0)), _duty_lines(duty))


# Where each duty's hand stands (kept off the Loft / helm-board / plank interact points).
func _duty_station_pos(duty: String) -> Vector2:

	match duty:
		"Navigating":
			return _iso(6.4, 4.2)   # a touch off the helm/board point so E never clashes
		"Sailing":
			return _iso(6.9, 8.6)
		"Gunnery":
			return _iso(1.2, 11.4)
		"Carpentry":
			return _iso(6.9, 12.4)
	return _iso(3.0, 6.0)


func _duty_lines(duty: String) -> Array[String]:

	match duty:
		"Navigating":
			return ["Ahoy! Welcome aboard, hand.", "Keep the Loft singing and we'll make way.",
				"When a ship swings in, get to the helm and board 'em!"]
		"Sailing":
			return ["Trimmin' the sails to catch the drift.", "Mind the Stardust don't catch us nappin'."]
		"Gunnery":
			return ["Cannons loaded, powder dry.", "Point me at a brigand, aye?"]
		"Carpentry":
			return ["Patchin' her up where she creaks.", "She'll hold. Mostly."]
	return ["Ahoy.", "Just keepin' busy."]


func _add_npc(parent: Node, who: String, pos: Vector2, tint: Color, lines: Array[String]) -> void:

	var npc : Npc = NPC_SCENE.instantiate()
	npc.npc_name = who
	npc.portrait_color = tint
	npc.dialog_lines = lines
	npc.position = pos
	parent.add_child(npc)