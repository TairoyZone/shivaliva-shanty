## Base for a PUZZLE manned as a VOYAGE STATION during a pillage — the Loft, the Patchworks, and any
## future station. Holds the SHARED leg flow so every station stands on ONE foundation: build + SAIL
## the voyage chart, board on an encounter (snapshot the station's board → Skirmish → restore on
## return), resolve the leg at the node (the duty report), then open the NEXT leg RIGHT HERE — a
## CONTINUOUS crossing: you man ONE station for the whole pillage and the board carries straight
## through (no dismount to the deck). Arrival shows the haul card, a sink the LOST-IN-THE-STARDUST
## card. Subclasses build their own board + HUD, then call
## [method _enter_voyage_station]; they supply the minigame + a few HOOKS (performance, snapshot/restore,
## sink, chart placement, input-lock). See [[voyage-loop-research]] / [[patchworks-spec]] / [[loft-spec]].
class_name VoyageStationScene
extends PuzzleScene


const SKIRMISH_SCENE : String = "res://puzzles/skirmish/skirmish_boarding.tscn"
const SHIP_DECK_SCENE : String = "res://levels/ship_deck/ship_deck.tscn"

## Shared station-HUD chrome so the Loft + Patchworks gauge bars read IDENTICALLY (one source of truth,
## per the inheritance-over-duplication rule). The deck uses the same MeterBar in its own panel layout.
const METER_BAR : PackedScene = preload("res://components/meter_bar/meter_bar.tscn")
const STATION_METER_SIZE : Vector2 = Vector2(208.0, 22.0)   # canonical station gauge size (matches the deck's height)
const STARDUST_SINK : float = 10.0                          # the Stardust full scale (mirrors LoftBoard.SINK_LEVEL)

var _voyage_chart : VoyageChart
var _voyage_busy : bool = false           # a voyage transition (stop/fight/report/sink) underway — fire once
# (this leg's "fight done" flag moved to the canonical PlayerState.pillage_fight_done — shared with the deck)
var _restore_pending : bool = false       # post-fight board restore not done yet — hold leg resolution until it is


# Call from the subclass _ready AFTER it has built its board + HUD, only when PlayerState.voyage_active.
# Builds the chart, then resumes after a fight (pillage_phase==2) or opens a fresh leg (sails the chart).
func _enter_voyage_station() -> void:

	_build_voyage_chart()
	# Refresh UNCONDITIONALLY (matching the old Loft _build_ui): a FRESH leg sails from the node; a
	# post-fight RESUME picks her back up at the PARKED mid-leg position (voyage_ship_t) so she sails ON
	# to the node. Without this the chart renders blank, resets voyage_ship_t, and skips the sail beat.
	if _voyage_chart != null:
		_voyage_chart.refresh_from_state(true)
	if PlayerState.pillage_phase == 2:
		# Back from a boarding → RESTORE the station + sail on to the node, where this fight leg resolves.
		# Mark the fight DONE + restore PENDING synchronously so a stray reached_stop can't re-board or
		# resolve a 0/0 leg before the restore runs; the restore itself is deferred (UI/board built).
		PlayerState.pillage_fight_done = true
		_restore_pending = true
		call_deferred("_resume_after_fight")
	else:
		_setup_fresh_voyage_leg()
		PlayerState.voyage_leg_lift0 = 0
		PlayerState.voyage_leg_swaps0 = 0
		# Zero-distance backstop (mirrors the deck's _begin_sail): if she opens the leg ALREADY at the
		# node (carried voyage_ship_t >= this leg's goal), reached_stop is edge-triggered + won't re-fire,
		# and the endless station has no other end condition → resolve now so she can't dead-lock parked.
		if _voyage_chart != null and not _voyage_chart.needs_sail():
			call_deferred("_on_voyage_reached_stop")


func _build_voyage_chart() -> void:

	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_voyage_chart = VoyageChart.new()
	_voyage_chart_placement(layer)   # the hook calls place_at (which add_child's it) + positions it
	_voyage_chart.reached_stop.connect(_on_voyage_reached_stop)
	_voyage_chart.reached_encounter.connect(_on_voyage_reached_encounter)


# --- Shared station HUD chrome (Loft + Patchworks read identically) ----

## A status MeterBar sized for a station's centre gauge bar (cool, art-swappable). Caller sets its
## rising_palette / danger ticks / call-site refresh.
func _make_station_meter(label_text: String, icon: String) -> MeterBar:

	var m : MeterBar = METER_BAR.instantiate() as MeterBar
	m.custom_minimum_size = STATION_METER_SIZE
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m.label_text = label_text
	m.icon_kind = icon
	return m


## Wrap a label in the cool station "pill" (navy trough + sky-blue frame) — the BANKED/SWAPS/SCORE chips.
func _make_station_pill(label: Label) -> PanelContainer:

	var panel : PanelContainer = PanelContainer.new()
	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Palette.PANEL_TROUGH
	s.border_color = Palette.SKY_FRAME
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	panel.add_theme_stylebox_override("panel", s)
	panel.custom_minimum_size = Vector2(150.0, 0.0)
	panel.add_child(label)
	return panel


## Refresh a HULL MeterBar from the ACTIVE ship's open holes (one lit notch per hole; green→amber→red).
## Shared by the Loft + Patchworks so the ship's condition reads the same at either station.
func _refresh_hull_meter(bar: MeterBar) -> void:

	if bar == null:
		return
	var holes : int = PlayerState.ship_open_holes()
	var maxh : int = maxi(PlayerState.voyage_max_holes(), 1)
	bar.segments = maxh
	bar.set_value(float(holes), float(maxh))
	bar.set_caption("sound" if holes <= 0 else ("%d hole%s" % [holes, "" if holes == 1 else "s"]))


# --- The shared leg flow ----------------------------------------------

# The sloop made this leg's NODE — resolve the leg over the board + post the duty report. A calm leg
# just reports; a fight leg reports with the boarding outcome folded in. A fight leg that reached the
# node WITHOUT meeting the foe boards 'em now.
func _on_voyage_reached_stop() -> void:

	if _restore_pending:
		return   # post-fight restore not done — _resume_after_fight will drive the resolve
	var perf : Dictionary = _leg_performance()
	if _is_voyage_fight_leg():
		if PlayerState.pillage_fight_done:
			_resolve_and_report(true, PlayerState.last_skirmish_won, int(perf["lift"]), int(perf["swaps"]))
		else:
			_trigger_voyage_skirmish()
	else:
		_resolve_and_report(false, true, int(perf["lift"]), int(perf["swaps"]))


# The sloop reached this leg's swords (the mid-leg spot) — board 'em right there.
func _on_voyage_reached_encounter() -> void:

	if _is_voyage_fight_leg() and not PlayerState.pillage_fight_done:
		_trigger_voyage_skirmish()


func _is_voyage_fight_leg() -> bool:

	var enc : Array = PlayerState.pillage_encounters
	var i : int = PlayerState.pillage_leg
	return i >= 0 and i < enc.size() and String(enc[i]) != ""


# Back from a boarding → RESTORE the station's board (continue) and sail on to the node, where this
# fight leg resolves with the remembered outcome. No re-deal, no re-fight.
func _resume_after_fight() -> void:

	if not is_inside_tree():
		return
	if not PlayerState.voyage_station_state.is_empty():
		_restore_voyage_state(PlayerState.voyage_station_state)
		PlayerState.voyage_station_state = {}
	if _voyage_chart != null:
		_voyage_chart.mark_encounter_fired()   # don't let the resumed chart re-signal this fought leg
	_restore_pending = false
	_voyage_busy = false
	_disarm_sink()   # the fight's done — sailing on to the resolve node can't sink her
	# If the boarding fired AT the node (the swords-missed fallback), the chart is already at its goal
	# and reached_stop won't re-fire — resolve the leg right now (mirrors the deck's zero-distance guard).
	if _voyage_chart != null and not _voyage_chart.needs_sail():
		_on_voyage_reached_stop()


# Resolve the leg via the shared PlayerState logic + show the DUTY REPORT over the board. On dismiss:
# back to the deck for the next station, or the haul card on arrival.
func _resolve_and_report(is_fight: bool, won: bool, lift: int, swaps: int) -> void:

	if _voyage_busy:
		return
	_voyage_busy = true
	if _voyage_chart != null:
		_voyage_chart.snap_to_goal()   # she's at the node — pin her there for the report
	var m : Dictionary = _leg_mastery()
	var r : Dictionary = PlayerState.resolve_voyage_leg(is_fight, won, lift, swaps, String(m["id"]), int(m["score"]))
	var panel : DutyReportPanel = DutyReportPanel.create(PlayerState.last_duty_report)
	panel.closed.connect(_on_report_closed.bind(bool(r["arrived"])))
	add_child(panel)


func _on_report_closed(arrived: bool) -> void:

	if arrived:
		# Voyage's end → the booty DIVVY (pool × your overall duty), then step ashore.
		var card : VoyageHaulCard = VoyageHaulCard.create(PlayerState.pillage_destination)
		card.closed.connect(_on_haul_card_closed)
		add_child(card)
	else:
		# CONTINUOUS crossing — the next leg opens RIGHT HERE over the same board (no dismount to the deck,
		# no dead stop): you man ONE station for the whole pillage. The board + its state carry straight
		# through; we just open a fresh measurement window and sail the chart on.
		_begin_next_leg()


# Open the NEXT leg in place (continuous): the board + its state carry through; reset the per-leg
# measurement baseline + re-arm the station (via the hook), then sail the chart on toward the next node.
func _begin_next_leg() -> void:

	PlayerState.pillage_fight_done = false
	_open_next_leg()
	if _voyage_chart != null:
		_voyage_chart.refresh_from_state(true)
	_voyage_busy = false


# The Stardust took her on a fight leg — LOST IN THE STARDUST (only a station that _voyage_can_sink can
# reach this). Apply the consequence, show the card, then limp home on dismiss.
func _on_voyage_sunk() -> void:

	_voyage_busy = true   # OWN the transition — block any concurrent reached_stop / boarding from firing too
	var r : Dictionary = PlayerState.sink_voyage()
	var card : VoyageSinkCard = VoyageSinkCard.create(int(r["forfeited"]), int(r["toll"]))
	card.closed.connect(_on_sunk_card_closed.bind(String(r["home"])))
	add_child(card)


func _on_sunk_card_closed(home: String) -> void:

	if get_tree() != null:
		get_tree().change_scene_to_file(home)


func _on_haul_card_closed() -> void:

	var dest : String = PlayerState.pillage_destination_scene
	# Land ON THE DOCKS (the Skydock) in the destination, not its default spawn (mirrors ShipDeck).
	PlayerState.request_spawn_at_anchor("SkydockDoor")
	PlayerState.cash_out_voyage()   # pay the pooled booty as one cut
	PlayerState.clear_voyage()
	if dest.is_empty():
		dest = SHIP_DECK_SCENE
	get_tree().change_scene_to_file(dest)


# The Leave button → step off the station back onto the STILL-SAILING deck (the deck drives the crossing
# now), so you can man a station again, re-take the helm, or just watch her make way — WITHOUT stopping or
# rewinding her. The phase stays 1 (underway); only this station session ends, so drop its board snapshot.
# Standalone (non-voyage) → the base PuzzleScene. Subclasses that override this MUST call super().
func _return_to_launching_scene() -> void:

	if PlayerState.voyage_active:
		if _voyage_busy:
			return
		_voyage_busy = true
		var perf : Dictionary = _leg_performance()
		PlayerState.last_loft_lift = int(perf["lift"])
		PlayerState.last_loft_swaps = int(perf["swaps"])
		PlayerState.voyage_station_state = {}
		get_tree().change_scene_to_file(SHIP_DECK_SCENE)
		return
	super._return_to_launching_scene()


# Met the foe mid-leg → park at the swords, SNAPSHOT the station's board (to carry across the boarding),
# then board 'em. The Skirmish returns to a fresh station (_resume_after_fight restores + sails on to the
# node, where the leg resolves). The footing is seeded from THIS leg's form so far.
func _trigger_voyage_skirmish() -> void:

	if _voyage_busy:
		return
	_voyage_busy = true
	if _voyage_chart != null:
		_voyage_chart.freeze()   # PARK her at the swords — don't sail on to the node
	_lock_station_input(true)    # no stray input during the cry / before we snapshot
	# A "Sail ho!" beat so the boarding never reads as a teleport (animate-everything).
	var cry : Tween = _flash_alarm("Sail ho!   Board 'em!")
	# Let any in-flight cascade settle so we snapshot a STABLE board. Cap the wait so a stuck resolve
	# can't hang the cry.
	var guard : int = 0
	while _station_is_resolving() and guard < 120:
		await get_tree().process_frame
		if not is_instance_valid(self) or not is_inside_tree():
			return
		guard += 1
	# A cascade that settled during the wait may have SUNK her → _on_voyage_sunk already cleared the
	# voyage and owns the transition. Abort the boarding so we don't double-fire a scene change.
	if not PlayerState.voyage_active:
		return
	PlayerState.voyage_station_state = _snapshot_voyage_state()
	# Footing = how well you flew INTO the fight (this leg's form so far); banked for the deck path too.
	var perf : Dictionary = _leg_performance()
	PlayerState.last_loft_lift = int(perf["lift"])
	PlayerState.last_loft_swaps = int(perf["swaps"])
	PlayerState.last_skirmish_won = false
	PlayerState.voyage_boarding_seed = PlayerState.voyage_seed_from_lift(int(perf["lift"]))
	PlayerState.skirmish_opponent = ""
	PlayerState.pillage_phase = 2
	PlayerState.pillage_fight_done = true   # the STATION fired this leg's boarding — the deck won't re-board it
	PlayerState.puzzle_return_scene = _self_scene()
	# Swap right as the cry ENDS — never cut it off (fast resolve) nor leave a dead locked frame after it.
	if cry != null and cry.is_valid():
		await cry.finished
	if not is_instance_valid(self) or not is_inside_tree() or not PlayerState.voyage_active:
		return
	get_tree().change_scene_to_file(SKIRMISH_SCENE)


# A big centred cry over the board (the boarding alarm). Returns its Tween so the caller can await it.
func _flash_alarm(text: String) -> Tween:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", Color(1.0, 0.52, 0.40, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(640.0, 110.0)
	var vp : Vector2 = get_viewport().get_visible_rect().size
	label.position = Vector2(vp.x * 0.5 - 320.0, vp.y * 0.34)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.6, 0.6)
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	layer.add_child(label)
	var tw : Tween = create_tween()
	tw.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.5)
	tw.chain().tween_property(label, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(layer.queue_free)
	return tw


# --- Hooks (subclasses override) --------------------------------------

## Open a fresh leg (the chart then sails). Default: nothing extra (the base already reset the leg
## baselines). The Loft seeds Stardust + arms can-sink here.
func _setup_fresh_voyage_leg() -> void:
	pass

## This leg's performance → {"lift": int, "swaps": int} — rates the duty report + seeds the boarding
## footing. The Loft returns its real lift/swaps; the Patchworks a steady baseline (the crew flew while
## you patched). `swaps` MUST be >= 1 (it's a divisor in resolve_voyage_leg / voyage_seed_from_lift).
func _leg_performance() -> Dictionary:
	return {"lift": 0, "swaps": 1}

## The station's mastery for this leg → {"id": String, "score": int}. Default: Lofting, rated by the
## leg's lift (score -1 = use the lift). The Patchworks records its own ("patchworks", board score).
func _leg_mastery() -> Dictionary:
	return {"id": "loft", "score": -1}

## Open the next leg of a CONTINUOUS crossing: reset the per-leg measurement baseline + re-arm the
## station for the new leg (the board CARRIES across legs). Loft: re-baseline lift/swaps + re-arm sink +
## re-push the hole rise. Patchworks: re-baseline its score. Override per station.
func _open_next_leg() -> void:
	pass

## Snapshot the station's board to carry across a boarding (default: nothing).
func _snapshot_voyage_state() -> Dictionary:
	return {}

func _restore_voyage_state(_state: Dictionary) -> void:
	pass

## Drop any "can sink" arming when a fight ends (default no-op; the Loft clears its board flag).
func _disarm_sink() -> void:
	pass

## Position [member _voyage_chart] on the given CanvasLayer (default: top-left). Must call place_at
## (which add_child's the chart).
func _voyage_chart_placement(layer: CanvasLayer) -> void:
	_voyage_chart.place_at(layer, true)

## The scene to return to after a boarding (each subclass's own .tscn).
func _self_scene() -> String:
	return ""

## Lock the station's input during the boarding cry (default no-op).
func _lock_station_input(_on: bool) -> void:
	pass

## Is the station's board still resolving a cascade (so we wait before snapshotting)? Default false.
func _station_is_resolving() -> bool:
	return false
