## THE SHIP DECK — the walkable hub of a JOBBING pillage ([[pillage-research]]). You
## signed onto a crew at the Skydock; now you're aboard their ISOMETRIC SKYship, adrift
## in the high sky (NOT the sea — this world floats). The crew is AI/flavour; YOU work
## the one playable station — the **[[loft-spec]] LOFT** (keeps her aloft). The captain
## drives the pillage:
##   board → MAN THE LOFT → "brigand off the bow!" → BOARD (the Skirmish duel) → take
##   your CUT → DISEMBARK.
##
## Normal overworld camera (rides the Player). Iso-styled + ship-shaped so it walks right.
## Self-contained interactions (no per-station Interactable scenes): a left-CLICK mans the nearest active
## station (E opens the backpack now). Phase off [member PlayerState.pillage_phase], re-entered after each
## station/fight scene-swap. ⚠️ Procedural PLACEHOLDER art — real skyship sprites later.
@tool   # paints the procedural deck in the EDITOR (Troy: "i wanna see it") — runtime wiring is guarded off
class_name ShipDeck
extends BaseLocation


const LOFT_SCENE : String = "res://puzzles/loft/loft.tscn"
const PATCHWORKS_SCENE : String = "res://puzzles/patchworks/patchworks_scene.tscn"
## Boarding the brigand = the crew-vs-crew [SkirmishBoarding] team fight (you + AI
## mates vs the brigand crew). The 1v1 skirmish_duel stays the Spar's friendly match.
const SKIRMISH_SCENE : String = "res://puzzles/skirmish/skirmish_boarding.tscn"
const SELF_SCENE : String = "res://levels/ship_deck/ship_deck.tscn"
const FALLBACK_HOME : String = "res://levels/shore/shore.tscn"
## Where to land after a pillage makes port — the Skydock door anchor in the destination island, so you
## step off ON THE DOCKS, not the island's default spawn. Islands lacking it fall back to their default.
const DOCK_ANCHOR : String = "SkydockDoor"
## Crew are REAL [Npc] instances (reuse the overworld character), not drawn figures.
const NPC_SCENE : PackedScene = preload("res://components/npc/npc.tscn")
# Voyage payout / footing tuning now lives on PlayerState (shared with the Loft cockpit):
# resolve_voyage_leg(), voyage_seed_from_lift(), voyage_total_gold().

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
const PATCHWORKS_G : Vector2 = Vector2(5.4, 10.6)  # the playable hull-repair station (the Patchworks)
const HELM_G : Vector2 = Vector2(4.0, 3.2)     # captain's post + the navigation prop
const PLANK_G : Vector2 = Vector2(4.0, 15.2)   # the gangplank (disembark)
const SPAWN_G : Vector2 = Vector2(4.0, 13.0)

## Flavour (AI-manned) props: [grid_cell, kind]. Clean, unlabeled, well-spaced — pure
## decoration so the deck reads as a crewed ship without piling up text.
const FLAVOUR_STATIONS : Array = [
	[Vector2(6.0, 8.6), "sailing"],
	[Vector2(2.0, 11.4), "gunnery"],
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
## Extra wood/sail tones for the aesthetic pass (procedural, no imported art).
const HULL_SIDE_DARK : Color = Color(0.27, 0.17, 0.08, 1.0)   # lower hull, in shadow (2-tone depth)
const DECK_INSET : Color = Color(0.57, 0.41, 0.23, 1.0)       # the inset deck-border ring + post caps
const PLANK_HILITE : Color = Color(1.0, 1.0, 1.0, 0.05)       # faint grain highlight beside each seam
const SAIL : Color = Color(0.88, 0.85, 0.76, 0.94)            # canvas sail
const SAIL_SHADE : Color = Color(0.73, 0.69, 0.59, 0.94)      # the sail's lee-side fold
const SHADOW : Color = Color(0.0, 0.0, 0.0, 0.18)             # soft ground shadow under props
const RIGGING : Color = Color(0.20, 0.14, 0.08, 0.7)          # mast stays/rigging lines

var _active : String = ""
var _hull_label : Label          # HULL condition readout (the ship you're crewing) — top-right
var _prompt : Label
var _captain_label : Label
var _chart : VoyageChart         # the drawn voyage progress ribbon
var _crossing : bool = false     # the ship is sailing between stops — stations locked, watch her make way
var _report_btn : Button         # Duty Report button — hidden mid-boarding (its panel pauses the live melee)


# Iso projection, centred so the deck middle sits on the world origin.
func _iso(gx: float, gy: float) -> Vector2:

	return Vector2(
		(gx - gy) * TILE_W * 0.5 - float(GW - GH) * TILE_W * 0.25,
		(gx + gy) * TILE_H * 0.5 - float(GW + GH) * TILE_H * 0.25)


func _ready() -> void:

	# @tool: in the EDITOR just paint the ship so its look is visible while editing — skip all the runtime
	# spawn / crew / UI / voyage wiring (autoloads + the Player don't exist at edit time).
	if Engine.is_editor_hint():
		queue_redraw()
		return
	# The deck is the hub every station/fight/report returns to — never inherit a stuck pause from a
	# panel that ran on the way here, or the player can't move/man and the chart won't sail. Self-heal.
	if get_tree() != null:
		get_tree().paused = false
	pirate_spawn_position = _iso(SPAWN_G.x, SPAWN_G.y)
	_seed_demo_route_if_unset()
	super._ready()                 # spawns the Player under YSortNode2D (normal camera)
	# A LIVING procedural sky behind the deck — twinkling Stardust starfield (borrow #3) replaces the old
	# flat SKY fill. Low CanvasLayer, behind the ship; SKY stays the flat fallback if the shader is stripped.
	var sky : SkyBackdrop = SkyBackdrop.new()
	sky.fallback_color = SKY
	add_child(sky)
	add_child(DriftFog.make(Color(0.80, 0.84, 0.96, 0.85)))   # drifting cloud wisps between the stars + the deck
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
	PlayerState.pillage_encounter_pos = [0.5, 0.55, 0.5]
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

	# The Duty Report panel PAUSES the tree, which would freeze the live background melee — hide the button
	# while a boarding's in progress (you can read it again once the leg's banked).
	if _report_btn != null:
		_report_btn.visible = not BoardingMelee.has_active()
	_update_hull_label()   # refresh the HULL readout (holes change as legs resolve)
	if _arrived():
		# Voyage's end. Also guards a redundant re-load so the last leg is never re-banked.
		_say("%s dead ahead — voyage's end! Your cut: %d gold. Take the plank to make port." % [
			_destination(), PlayerState.voyage_final_cut()])
		_refresh_chart(false)
		return
	if BoardingMelee.has_active():
		# You stepped away from a boarding — it's still being decided (or just was). Get back in the fight;
		# no station is mountable mid-boarding.
		if BoardingMelee.is_resolved():
			_say("The boarding's decided, hand — get to the helm to see how yer crew fared.")
		else:
			_say("The boarding still rages — get to the helm and rejoin the fight!")
		# Show her PARKED AT THE SWORDS (where the boarding fired), not snapped back to the node. Refresh
		# with sailing=true so her position reads straight from voyage_ship_t (sailing=false would clamp it
		# back to the node) — then freeze so she holds there instead of sailing on.
		_refresh_chart(true)
		if _chart != null:
			_chart.freeze()
		return
	match PlayerState.pillage_phase:
		1:
			_say("Underway toward %s — man the LOFT or the PATCHWORKS to crew her, or watch her make way." % _destination())
			_begin_sail()
		2:
			_say("Back to the crossing toward %s — man a station, or watch her make way." % _destination())
			_begin_sail()
		_:
			# Holding at the node: the captain waits for your WORD to set sail (you set sail first, THEN
			# crew her on the way — manning a station no longer casts off).
			if PlayerState.pillage_leg <= 0:
				_say("Welcome aboard, hand! Give the word at the HELM when you're ready to set sail for %s." % _destination())
			else:
				_say("Holding at the waypoint — give the word at the HELM to set sail on toward %s." % _destination())
			_refresh_chart(false)


# Start (or resume) the crossing: the chart sails toward the next node at crew pace. If she's
# somehow already there (zero-distance), resolve the stop straight away.
func _begin_sail() -> void:

	_crossing = true
	_refresh_chart(true)
	# Already at the stop (she made it during your Loft session)? Fire the event now.
	if _chart != null and not _chart.needs_sail():
		_on_chart_reached_stop()


# The sloop MADE THE NEXT STOP (a league point) — whether you were here or working the Loft.
# A fight stop boards first (after a "Sail ho!" beat, so it never teleports); then the leg
# resolves (fight booty or calm salvage) and the DUTY REPORT posts here, YPP-style.
# The sloop reached this leg's swords (the random mid-leg spot) — board 'em.
func _on_chart_reached_encounter() -> void:

	if not _crossing or PlayerState.pillage_phase != 1 or not _is_encounter_leg(PlayerState.pillage_leg):
		return
	_crossing = false
	await _deck_board_now()


func _on_chart_reached_stop() -> void:

	if not _crossing:
		return
	_crossing = false
	# Fallback: an unfought encounter leg reached the node (the mid-leg swords didn't fire) → board.
	if _is_encounter_leg(PlayerState.pillage_leg) and PlayerState.pillage_phase == 1:
		await _deck_board_now()
		return
	# Calm stop, or back from the boarding → resolve the leg + post the duty report here.
	if _is_encounter_leg(PlayerState.pillage_leg):
		_resolve_boarding()
	else:
		_resolve_calm()
	_refresh_chart(false)   # update done/haul
	# Post the leg's report; on dismiss she SAILS ON to the next leg (set-sail-once — the deck keeps
	# crewing the whole route without another captain prompt), or holds at the isle on arrival.
	if not PlayerState.last_duty_report.is_empty():
		var panel : DutyReportPanel = DutyReportPanel.create(PlayerState.last_duty_report)
		panel.closed.connect(_on_leg_report_closed)
		add_child(panel)
	else:
		_on_leg_report_closed()


# A leg's duty report was dismissed → carry on the crossing (no re-set-sail), or hold at the destination.
func _on_leg_report_closed() -> void:

	if not _arrived():
		PlayerState.pillage_phase = 1
	_setup_phase()   # arrived → "take the plank"; else → "underway" + sail on
	queue_redraw()


# The "Sail ho!" cry + a held beat, then swap to the Skirmish (so the boarding never teleports).
func _deck_board_now() -> void:

	if _chart != null:
		_chart.freeze()
	_say("Sail ho — %s off the bow! Grapples away, hands — board 'em!" % _foe_name(PlayerState.pillage_leg))
	await get_tree().create_timer(1.1).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return   # bailed (or left) during the cry
	_board_brigand()


# Resolve a leg via the SHARED PlayerState logic (so the deck + the Loft cockpit never diverge),
# then say the outcome. (Normally the Loft cockpit drives the crossing; this is the deck-side
# path for when you're on the deck — e.g. you bailed the Loft mid-crossing.)
func _resolve_boarding() -> void:

	_after_resolve(PlayerState.resolve_voyage_leg(true, PlayerState.last_skirmish_won,
		PlayerState.last_loft_lift, PlayerState.last_loft_swaps))


func _resolve_calm() -> void:

	_after_resolve(PlayerState.resolve_voyage_leg(false, true,
		PlayerState.last_loft_lift, PlayerState.last_loft_swaps))


func _after_resolve(r: Dictionary) -> void:

	if bool(r["arrived"]):
		_say("%s  %s dead ahead — voyage's end! Your cut: %d gold. Take the plank to make port." % [
			String(r["outcome_line"]), _destination(), PlayerState.voyage_final_cut()])
	else:
		_say("%s  Waypoint made — man the Loft for the next stretch toward %s." % [
			String(r["outcome_line"]), _destination()])


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

	if Engine.is_editor_hint() or player == null:
		return
	_active = _nearest_active_station()
	if _prompt != null:
		_prompt.visible = not _active.is_empty()
		if not _active.is_empty():
			_prompt.text = "[Click]  %s" % _action_label(_active)


func _unhandled_input(event: InputEvent) -> void:

	if Engine.is_editor_hint():
		return
	# A left-CLICK mans the nearest active station (E opens the backpack now — Troy: click-based world).
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _active.is_empty():
		return
	if Overlay.is_active or (HUD != null and HUD.is_inventory_open()) or ChatBox.is_typing():
		return
	get_viewport().set_input_as_handled()
	match _active:
		"set_sail":
			_set_sail()
		"loft":
			_man_loft()
		"patchworks":
			_man_patchworks()
		"rejoin":
			_rejoin_boarding()
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
	if BoardingMelee.has_active():
		# Mid-boarding: no station is mountable (the LOCKED rule) — only rejoin the fight (or walk the plank).
		return [["rejoin", _iso(HELM_G.x, HELM_G.y)], plank]
	match PlayerState.pillage_phase:
		1, 2:
			# Underway — man a station ANY time (or just watch her make way); the plank's always there.
			return [["loft", _iso(LOFT_G.x, LOFT_G.y)],
				["patchworks", _iso(PATCHWORKS_G.x, PATCHWORKS_G.y)], plank]
		_:
			# Holding at the node — give the word at the helm to set sail (no station until she's underway).
			return [["set_sail", _iso(HELM_G.x, HELM_G.y)], plank]


func _action_label(id: String) -> String:

	match id:
		"set_sail":
			return "Set sail!"
		"loft":
			return "Man the Loft"
		"patchworks":
			return "Man the Patchworks" if PlayerState.ship_open_holes() > 0 else "Mend at the Patchworks"
		"rejoin":
			return "Rejoin the boarding"
		"plank":
			return "Disembark"
	return ""


# Give the captain the word at the helm — she casts off and sails the route on her OWN from here (the
# DECK drives the crossing). You man stations as she goes; you don't re-set-sail at each node, she
# carries on (set-sail-once). The boardings + duty reports fire as she sails.
func _set_sail() -> void:

	PlayerState.pillage_phase = 1
	_setup_phase()   # → "underway" + _begin_sail
	queue_redraw()   # the glow shifts from the helm to the Loft


func _man_loft() -> void:

	PlayerState.last_loft_lift = 0
	PlayerState.last_loft_swaps = 0   # reset the lift/swaps PAIR together (the rate's denominator)
	PlayerState.pillage_phase = 1
	PlayerState.puzzle_return_scene = SELF_SCENE
	get_tree().change_scene_to_file(LOFT_SCENE)


# Man the PATCHWORKS — the YPP-carpentry reskin, a CORE voyage station. Manning it FLIES A LEG (the crew
# sails the Loft at a steady baseline while YOU mend the hull — ~3 cleared lines seal a hole), so it
# sails + resolves + returns to the deck exactly like the Loft (pillage_phase=1, the same machinery via
# VoyageStationScene). Holes carry on the ship, so a patch leg lowers the next Loft leg's flood.
func _man_patchworks() -> void:

	PlayerState.last_loft_lift = 0
	PlayerState.last_loft_swaps = 0   # reset the lift/swaps PAIR (the rate's denominator), like _man_loft
	PlayerState.pillage_phase = 1
	PlayerState.puzzle_return_scene = SELF_SCENE
	get_tree().change_scene_to_file(PATCHWORKS_SCENE)


func _board_brigand() -> void:

	PlayerState.last_skirmish_won = false
	PlayerState.pillage_phase = 2
	PlayerState.voyage_boarding_seed = PlayerState.voyage_seed_from_lift(PlayerState.last_loft_lift)
	PlayerState.skirmish_opponent = ""
	PlayerState.puzzle_return_scene = SELF_SCENE
	get_tree().change_scene_to_file(SKIRMISH_SCENE)


# Back into the live melee (it kept fighting while you were here on the deck). The boarding RE-ATTACHES to
# the still-running — or already-finished — sim; puzzle_return_scene is untouched, so dismissing it banks
# the leg the usual way (the station or the deck reads last_skirmish_won).
func _rejoin_boarding() -> void:

	get_tree().change_scene_to_file(SKIRMISH_SCENE)


func _disembark() -> void:

	# Voyage's END (the whole route run) → the booty DIVVY card (the pool × your overall duty), THEN step
	# ashore on its close — the same payoff the in-station arrival shows (the deck is the usual arrival now,
	# so it can't skip the ceremony). Bailing mid-voyage → straight home, no plunder card.
	if _arrived() and not PlayerState.pillage_destination_scene.is_empty():
		var card : VoyageHaulCard = VoyageHaulCard.create(PlayerState.pillage_destination)
		card.closed.connect(_on_haul_card_closed)
		add_child(card)
		return
	_finish_voyage(PlayerState.voyage_home_scene)


func _on_haul_card_closed() -> void:

	_finish_voyage(PlayerState.pillage_destination_scene)


# Pay out the pooled booty (you keep what you plundered), wipe the voyage scaffolding, and step off.
func _finish_voyage(target: String) -> void:

	if target.is_empty():
		target = PlayerState.voyage_home_scene
	if target.is_empty():
		target = FALLBACK_HOME
	# Land ON THE DOCKS (the Skydock) in the destination, not its default spawn (Troy 2026-06-07).
	PlayerState.request_spawn_at_anchor(DOCK_ANCHOR)
	PlayerState.cash_out_voyage()
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
	# [Click] prompt bottom-centre). Populated by _setup_phase → _refresh_chart right after this.
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
	_report_btn = report_btn

	# HULL condition readout (top-right) — the ship you're crewing. Mirrors the Loft's HULL pill.
	_hull_label = Label.new()
	_hull_label.add_theme_font_size_override("font_size", 17)
	_hull_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_hull_label.add_theme_constant_override("outline_size", 3)
	_hull_label.anchor_left = 1.0
	_hull_label.anchor_right = 1.0
	_hull_label.offset_left = -210.0
	_hull_label.offset_right = -16.0
	_hull_label.offset_top = 18.0
	_hull_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hull_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hull_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hull_label)
	_update_hull_label()


func _say(line: String) -> void:

	if _captain_label != null:
		_captain_label.text = "Cap'n %s:  \"%s\"" % [_captain_name(), line]


# The HULL condition readout (the ship you're crewing) — green SOUND → amber → red, mirroring the Loft.
func _update_hull_label() -> void:

	if _hull_label == null:
		return
	var holes : int = PlayerState.ship_open_holes()
	if holes <= 0:
		_hull_label.text = "HULL  SOUND"
		_hull_label.add_theme_color_override("font_color", Color(0.7, 0.95, 0.75, 1.0))
	else:
		_hull_label.text = "HULL  %d hole%s" % [holes, "" if holes == 1 else "s"]
		_hull_label.add_theme_color_override("font_color",
			Color(0.98, 0.82, 0.5) if holes <= 2 else Color(1.0, 0.55, 0.5))


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
# NO floating labels anywhere — the only text is the captain banner + the [Click] prompt
# (both fixed UI). The ONE station you need this phase GLOWS so it reads without a tag.

func _draw() -> void:

	# The sky is now the procedural SkyBackdrop (added in _ready) on a low CanvasLayer — no flat fill here.
	var deck : PackedVector2Array = PackedVector2Array()
	for g in OUTLINE:
		deck.append(_iso(g.x, g.y))
	# Hull depth — a 2-TONE side (upper lit, lower in shadow) so she reads as a solid wooden hull.
	var down : Vector2 = Vector2(0.0, HULL_H)
	var mid : Vector2 = Vector2(0.0, HULL_H * 0.42)
	for i in deck.size():
		var a : Vector2 = deck[i]
		var b : Vector2 = deck[(i + 1) % deck.size()]
		draw_colored_polygon(PackedVector2Array([a, b, b + mid, a + mid]), HULL_SIDE)
		draw_colored_polygon(PackedVector2Array([a + mid, b + mid, b + down, a + down]), HULL_SIDE_DARK)
	draw_colored_polygon(deck, DECK)
	# An inset plank-ring just inside the rail — gives the deck a framed, finished edge.
	var inset : PackedVector2Array = _inset_outline(0.5)
	draw_polyline(inset + PackedVector2Array([inset[0]]), DECK_INSET, 3.0)
	# Planking: denser fore-aft seams (each with a faint grain highlight) + a few cross-seams.
	for gy in range(2, GH, 2):
		draw_line(_iso(0.5, float(gy)), _iso(float(GW) - 0.5, float(gy)), PLANK_LINE, 2.0)
		draw_line(_iso(0.5, float(gy) + 0.07), _iso(float(GW) - 0.5, float(gy) + 0.07), PLANK_HILITE, 1.0)
	for gx in [2.0, 4.0, 6.0]:
		draw_line(_iso(gx, 2.0), _iso(gx, float(GH) - 2.0), PLANK_LINE, 1.0)
	# Gunwale rail + upright posts along it.
	draw_polyline(deck + PackedVector2Array([deck[0]]), RAIL, 5.0)
	_draw_rail_posts(deck)
	# Masts + a few rail cannons (clean, evenly spaced, no labels).
	_draw_mast(_iso(4.0, 6.0))
	_draw_mast(_iso(4.0, 11.0))
	for gy in [4.5, 8.0, 11.5]:
		_draw_cannon(_iso(0.7, gy))
		_draw_cannon(_iso(float(GW) - 0.7, gy))
	_draw_chest(_iso(5.4, 5.4))
	# Glow the action this phase needs (runtime only — reads voyage / PlayerState state absent at edit time).
	if not Engine.is_editor_hint():
		_draw_glow(_active_world_pos())
		# A second halo on the Patchworks when the hull's holed (man it to mend) — not at the set-sail node
		# or mid-boarding (where the only glow is the helm).
		if not _arrived() and not BoardingMelee.has_active() and PlayerState.pillage_phase != 0 \
				and PlayerState.ship_open_holes() > 0:
			_draw_glow(_iso(PATCHWORKS_G.x, PATCHWORKS_G.y))
	# Clean station props (no labels): playable Loft + helm + the flavour props + plank.
	_draw_prop(_iso(LOFT_G.x, LOFT_G.y), "loft")
	_draw_prop(_iso(PATCHWORKS_G.x, PATCHWORKS_G.y), "patchworks")
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
	if BoardingMelee.has_active():
		return _iso(HELM_G.x, HELM_G.y)   # rejoin the boarding from the helm
	if PlayerState.pillage_phase == 0:
		return _iso(HELM_G.x, HELM_G.y)   # holding at the node — set sail at the helm
	return _iso(LOFT_G.x, LOFT_G.y)       # underway — man the Loft


# A soft accent halo marking the active station (no text needed).
func _draw_glow(pos: Vector2) -> void:

	var c : Color = STATION_LIVE
	draw_circle(pos + Vector2(0.0, 4.0), 42.0, Color(c.r, c.g, c.b, 0.13))
	draw_arc(pos + Vector2(0.0, 4.0), 38.0, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.85), 2.5)


# The hull outline pulled IN toward the deck centre by [param amount] grid units (the inset rail ring).
func _inset_outline(amount: float) -> PackedVector2Array:

	var center : Vector2 = Vector2(float(GW) * 0.5, float(GH) * 0.5)
	var pts : PackedVector2Array = PackedVector2Array()
	for g in OUTLINE:
		var dir : Vector2 = (center - g).normalized()
		pts.append(_iso(g.x + dir.x * amount, g.y + dir.y * amount))
	return pts


# Short upright railing posts at each hull vertex + each edge midpoint — a simple gunwale.
func _draw_rail_posts(deck: PackedVector2Array) -> void:

	for i in deck.size():
		var a : Vector2 = deck[i]
		var b : Vector2 = deck[(i + 1) % deck.size()]
		for t in [0.0, 0.5]:
			var p : Vector2 = a.lerp(b, t)
			draw_line(p, p + Vector2(0.0, -10.0), RAIL, 3.0)
			draw_circle(p + Vector2(0.0, -10.0), 2.0, DECK_INSET)


# A grounding base + soft shadow under a deck prop, so it sits ON the deck instead of floating.
func _draw_pedestal(pos: Vector2) -> void:

	draw_circle(pos + Vector2(0.0, 9.0), 20.0, SHADOW)
	draw_circle(pos + Vector2(0.0, 5.0), 16.0, DECK_DARK)
	draw_arc(pos + Vector2(0.0, 5.0), 16.0, 0.0, TAU, 20, DECK_INSET, 1.5)


# A clean station prop by kind — no labels.
func _draw_prop(pos: Vector2, kind: String) -> void:

	if kind != "gunnery":
		_draw_pedestal(pos)   # a grounding base + shadow under the bench/console props (the cannon has its own)
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
		"patchworks":
			# A repair workbench with a half-planked hull panel on top (echoes the Skydock post).
			draw_rect(Rect2(pos.x - 18.0, pos.y - 6.0, 36.0, 7.0), Color(0.50, 0.34, 0.18, 1.0))
			draw_line(pos + Vector2(-13.0, -2.0), pos + Vector2(-6.0, 14.0), DECK_DARK, 3.0)
			draw_line(pos + Vector2(13.0, -2.0), pos + Vector2(6.0, 14.0), DECK_DARK, 3.0)
			var ppr : Rect2 = Rect2(pos.x - 13.0, pos.y - 24.0, 26.0, 16.0)
			draw_rect(ppr, Color(0.10, 0.09, 0.18, 1.0))
			draw_rect(Rect2(ppr.position.x, ppr.position.y, 26.0, 5.0), Color(0.62, 0.46, 0.27, 1.0))
			draw_rect(Rect2(ppr.position.x, ppr.position.y + 10.0, 26.0, 5.0), Color(0.62, 0.46, 0.27, 1.0))
			draw_rect(ppr, STATION_IDLE, false, 1.5)
		"carpentry":
			draw_rect(Rect2(pos.x - 16.0, pos.y - 8.0, 32.0, 6.0), Color(0.55, 0.40, 0.22, 1.0))
			draw_line(pos + Vector2(-12.0, -4.0), pos + Vector2(-4.0, 12.0), DECK_DARK, 3.0)
			draw_line(pos + Vector2(12.0, -4.0), pos + Vector2(4.0, 12.0), DECK_DARK, 3.0)


func _draw_mast(pos: Vector2) -> void:

	# A mast: base ring, a pole up-screen, a cross-yard, and a billowed canvas sail + rigging stays.
	draw_circle(pos + Vector2(0.0, 6.0), 14.0, SHADOW)
	draw_circle(pos, 8.0, DECK_DARK)
	var top : Vector2 = pos + Vector2(0.0, -86.0)
	draw_line(pos, top, DECK_DARK, 6.0)
	draw_line(pos, top, Color(0.42, 0.28, 0.14, 1.0), 3.0)
	var yard_y : float = top.y + 16.0
	var yl : Vector2 = Vector2(pos.x - 32.0, yard_y)
	var yr : Vector2 = Vector2(pos.x + 32.0, yard_y)
	draw_line(yl, yr, DECK_DARK, 4.0)
	# Sail — hangs from the yard, billowing to a sagged bottom edge (lee-side fold shaded).
	var bl : Vector2 = Vector2(pos.x - 27.0, pos.y - 30.0)
	var br : Vector2 = Vector2(pos.x + 27.0, pos.y - 30.0)
	var belly : Vector2 = Vector2(pos.x, pos.y - 20.0)
	draw_colored_polygon(PackedVector2Array([yl, yr, br, belly, bl]), SAIL)
	draw_colored_polygon(PackedVector2Array([yr, br, belly]), SAIL_SHADE)
	draw_line(yl, pos + Vector2(-16.0, 2.0), RIGGING, 1.0)
	draw_line(yr, pos + Vector2(16.0, 2.0), RIGGING, 1.0)


func _draw_cannon(pos: Vector2) -> void:

	draw_circle(pos + Vector2(0.0, 7.0), 10.0, SHADOW)
	draw_rect(Rect2(pos.x - 9.0, pos.y - 6.0, 22.0, 11.0), Color(0.20, 0.21, 0.24, 1.0))   # barrel
	draw_rect(Rect2(pos.x + 9.0, pos.y - 4.0, 6.0, 7.0), Color(0.10, 0.11, 0.13, 1.0))     # muzzle
	draw_circle(pos + Vector2(-5.0, 6.0), 4.0, Color(0.30, 0.20, 0.10, 1.0))               # carriage wheels
	draw_circle(pos + Vector2(7.0, 6.0), 4.0, Color(0.30, 0.20, 0.10, 1.0))


func _draw_plank(pos: Vector2) -> void:

	var quad : PackedVector2Array = PackedVector2Array([
		pos + Vector2(-20.0, -8.0), pos + Vector2(20.0, 0.0),
		pos + Vector2(34.0, 46.0), pos + Vector2(-10.0, 40.0)])
	draw_colored_polygon(quad, Color(0.48, 0.32, 0.16, 1.0))
	draw_polyline(quad + PackedVector2Array([quad[0]]), Color(0.30, 0.19, 0.09, 1.0), 2.0)


func _draw_chest(pos: Vector2) -> void:

	draw_circle(pos + Vector2(0.0, 12.0), 18.0, SHADOW)
	draw_rect(Rect2(pos.x - 16.0, pos.y - 4.0, 32.0, 15.0), Color(0.46, 0.30, 0.14, 1.0))   # box
	draw_rect(Rect2(pos.x - 16.0, pos.y - 11.0, 32.0, 8.0), Color(0.55, 0.37, 0.18, 1.0))   # lid
	draw_rect(Rect2(pos.x - 16.0, pos.y - 11.0, 32.0, 22.0), Color(0.90, 0.74, 0.34, 1.0), false, 2.0)
	draw_rect(Rect2(pos.x - 3.0, pos.y - 6.0, 6.0, 7.0), Color(0.93, 0.79, 0.40, 1.0))      # clasp


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
