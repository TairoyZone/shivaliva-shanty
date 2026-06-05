## THE VOYAGES BOARD — the jobbing notice board ([[pillage-research]]), opened from
## the Skydock's [SkyHelm]. The YPP flow, single-player-adapted: browse AI crews
## seeking a hand (Ship · Crew · Captain · Jobber Cut) → APPLY → a carrier pigeon
## goes out → a JOBBING INVITE comes back → ACCEPT → board that crew's [ShipDeck].
## A pause-tree CanvasLayer that owns its own input — chrome cloned from the other
## modals. The chosen captain/crew ride onto the deck via PlayerState.
class_name VoyagesBoard
extends CanvasLayer


const SHIP_DECK_SCENE : String = "res://levels/ship_deck/ship_deck.tscn"
## Inter-island travel (MVP: Cradle Rock ⇄ Driftspar). A pillage out of your current island
## is bound for the NEAREST OTHER island; LEGS_* = how many stopping points the run takes.
const ISLAND_CRADLE : Dictionary = {"name": "Cradle Rock", "scene": "res://levels/shore/shore.tscn"}
const ISLAND_DRIFTSPAR : Dictionary = {"name": "Driftspar", "scene": "res://levels/frontier_isle/frontier_isle.tscn"}
const LEGS_MIN : int = 2
const LEGS_MAX : int = 4
## Direct paid passage to the nearest island (skips the pillage) — the "fare" alternative to
## jobbing a crew. Cheap: it's just a ride, where pillaging EARNS gold.
const FARE_GOLD : int = 20
## Sky-foes you might MEET en route. A pillage only fights when you ENCOUNTER a ship — most
## stretches are calm sailing — so the encounters are pre-rolled here per offer (~half the
## legs, always at least one) and shown on the deck's voyage chart.
const FOES : Array = ["a sky-brigand sloop", "a marine cutter", "a band of sky-marauders", "a corsair brig"]
const ENCOUNTER_CHANCE : float = 0.5


# Roll which legs hold an encounter: "" = calm, a foe name = a fight. At least one fight
# per voyage (else the run has no boarding at all).
func _roll_encounters(legs: int) -> Array:

	var enc : Array = []
	var any : bool = false
	for i in legs:
		if randf() < ENCOUNTER_CHANCE:
			enc.append(FOES[randi() % FOES.size()])
			any = true
		else:
			enc.append("")
	if not any and legs > 0:
		enc[legs - 1] = FOES[randi() % FOES.size()]
	return enc


# Where ALONG each leg (0..1) the foe is met — a random spot in the MIDDLE stretch, so the swords
# sit between the stops (never on a node) and the boarding fires there. (Rolled for every leg;
# only used on encounter legs.)
func _roll_encounter_positions(legs: int) -> Array:

	var pos : Array = []
	for i in legs:
		pos.append(randf_range(0.28, 0.78))
	return pos


# The nearest OTHER island from where the player launched (the helm stored that in
# voyage_home_scene). MVP pair: on Driftspar → head for Cradle Rock; anywhere else → Driftspar.
func _destination_island() -> Dictionary:

	if PlayerState.voyage_home_scene.find("frontier_isle") != -1:
		return ISLAND_CRADLE
	return ISLAND_DRIFTSPAR

## AI crews currently seeking a hand (single-player flavour; all board the deck).
const CREWS : Array = [
	{"ship": "Enlightened Catfish", "crew": "Scurvy Dogs", "captain": "Stormy Jericho", "cut": 80},
	{"ship": "Drifting Guppy", "crew": "Dark Crusaders", "captain": "Flint Kerr", "cut": 70},
	{"ship": "Haughty Eel", "crew": "Calm Guardians", "captain": "Hollow Ellison", "cut": 75},
]

var _content : VBoxContainer


func _ready() -> void:

	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_tree().paused = true


func _exit_tree() -> void:

	if get_tree() != null:
		get_tree().paused = false


func _build() -> void:

	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel : PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340.0
	panel.offset_top = -250.0
	panel.offset_right = 340.0
	panel.offset_bottom = 250.0
	add_child(panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	panel.add_child(_content)
	_show_list()


# --- The crew list ----------------------------------------------------

func _show_list() -> void:

	_clear_content()
	_content.add_child(_make_title("VOYAGES — PILLAGING WITH A CREW"))
	_content.add_child(_make_caption("Sign on with a crew for FREE — pillage the high skies for a cut of the booty. Or pay fare below for a straight ride."))
	# FREE crew rows lead (no gold needed at zero gold); the paid fare ride sits last as the alternative.
	for crew in CREWS:
		_content.add_child(_make_crew_row(crew))
	_content.add_child(_make_caption("You job a single station and fight the boarding; you can't strand yourself."))
	_content.add_child(_make_fare_row(_destination_island()))
	var back : Button = _make_button("Never mind", Color(0.95, 0.84, 0.56, 1.0))
	back.pressed.connect(_on_cancel)
	_content.add_child(back)


func _make_crew_row(crew: Dictionary) -> PanelContainer:

	var row_panel : PanelContainer = PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", _row_style())
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row_panel.add_child(row)
	var info : Label = Label.new()
	info.text = "%s   ·   %s\nCap'n %s   ·   %d%% jobber cut" % [
		crew["ship"], crew["crew"], crew["captain"], int(crew["cut"])]
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.92, 0.88, 0.74, 1.0))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var apply : Button = _make_button("Apply", Color(0.80, 1.0, 0.66, 1.0))
	apply.pressed.connect(_on_apply.bind(crew))
	row.add_child(apply)
	return row_panel


# --- Apply → carrier pigeon → invite ---------------------------------

func _on_apply(crew: Dictionary) -> void:

	_clear_content()
	_content.add_child(_make_title("APPLICATION SENT"))
	_content.add_child(_make_caption(
		"A carrier pigeon has been dispatched with yer application to '%s'..." % crew["crew"]))
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(self):
		return
	_show_invite(crew)


func _show_invite(crew: Dictionary) -> void:

	_clear_content()
	# CREWS is a const → its dicts are READ-ONLY. Roll this offer's route onto a MUTABLE copy
	# (which then carries through Accept), so we never write into the const entry.
	crew = crew.duplicate(true)
	if not crew.has("destination"):
		var dest : Dictionary = _destination_island()
		crew["destination"] = dest["name"]
		crew["dest_scene"] = dest["scene"]
		crew["legs"] = LEGS_MIN + randi() % (LEGS_MAX - LEGS_MIN + 1)
		crew["encounters"] = _roll_encounters(int(crew["legs"]))
		crew["encounter_pos"] = _roll_encounter_positions(int(crew["legs"]))
	var fights : int = 0
	for e in crew["encounters"]:
		if String(e) != "":
			fights += 1
	_content.add_child(_make_title("JOBBING INVITE"))
	_content.add_child(_make_caption(
		"%s has offered ye a temporary jobbing position with '%s' aboard the %s — a run to %s (%d stops, ~%d likely scrap%s) for a %d%% cut of the booty." % [
		crew["captain"], crew["crew"], crew["ship"], String(crew["destination"]),
		int(crew["legs"]), fights, "" if fights == 1 else "s", int(crew["cut"])]))
	var accept : Button = _make_button("Accept — board the ship", Color(0.80, 1.0, 0.66, 1.0))
	accept.pressed.connect(_on_accept.bind(crew))
	_content.add_child(accept)
	var decline : Button = _make_button("Decline", Color(0.95, 0.84, 0.56, 1.0))
	decline.pressed.connect(_show_list)
	_content.add_child(decline)


func _on_accept(crew: Dictionary) -> void:

	PlayerState.pillage_captain = String(crew["captain"])
	PlayerState.pillage_crew = String(crew["crew"])
	# Lay in the route: a fresh voyage starts at leg 0 with an empty job log, bound for the
	# nearest island (where the player disembarks on arrival).
	PlayerState.pillage_destination = String(crew.get("destination", "Driftspar"))
	PlayerState.pillage_destination_scene = String(crew.get("dest_scene", ""))
	PlayerState.pillage_legs_total = int(crew.get("legs", 3))
	PlayerState.pillage_encounters = crew.get("encounters", [])
	PlayerState.pillage_encounter_pos = crew.get("encounter_pos", [])
	PlayerState.pillage_leg = 0
	PlayerState.pillage_log = []
	PlayerState.pillage_phase = 0
	PlayerState.voyage_active = true
	PlayerState.voyage_ship_t = 0.0   # a fresh voyage sets out from the home isle
	# Lay in the crew for the duty report: this captain + real cast hands at the stations.
	PlayerState.pillage_duty_crew = DutyReport.build_roster(String(crew["captain"]))
	PlayerState.last_duty_report = []
	if get_tree() != null:
		get_tree().paused = false
	get_tree().change_scene_to_file(SHIP_DECK_SCENE)


# --- Fare: direct paid passage (no pillage) --------------------------

func _make_fare_row(dest: Dictionary) -> PanelContainer:

	var row_panel : PanelContainer = PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", _row_style())
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row_panel.add_child(row)
	var info : Label = Label.new()
	info.text = "Buy fare — a straight ride to %s, no pillaging.   %d gold" % [String(dest["name"]), FARE_GOLD]
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 1.0))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var can_afford : bool = PlayerState.total_coins >= FARE_GOLD
	var fare : Button = _make_button("Pay fare" if can_afford else "Need %d gold" % FARE_GOLD,
		Color(0.80, 1.0, 0.66, 1.0) if can_afford else Color(0.72, 0.72, 0.76, 1.0))
	fare.disabled = not can_afford
	if can_afford:
		fare.pressed.connect(_on_fare.bind(dest))
	row.add_child(fare)
	return row_panel


func _on_fare(dest: Dictionary) -> void:

	if PlayerState.total_coins < FARE_GOLD:
		return
	PlayerState.add_coins(-FARE_GOLD, "Straight-fare ride")
	PlayerState.clear_voyage()   # a straight ride — no pillage state on the far side
	if get_tree() != null:
		get_tree().paused = false
	get_tree().change_scene_to_file(String(dest["scene"]))


func _on_cancel() -> void:

	if get_tree() != null:
		get_tree().paused = false
	queue_free()


# --- Chrome (cloned from the other modals) ---------------------------

func _clear_content() -> void:

	for child in _content.get_children():
		child.queue_free()


func _make_title(text: String) -> Label:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_caption(text: String) -> Label:

	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.74, 0.80, 0.92, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(620.0, 0.0)
	return label


func _panel_style() -> StyleBoxFlat:

	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.11, 0.06, 0.96)
	style.border_color = Color(0.78, 0.58, 0.24, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(28)
	return style


func _row_style() -> StyleBoxFlat:

	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.14, 0.08, 0.92)
	style.border_color = Color(0.5, 0.4, 0.22, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	return style


func _make_button(text: String, font_color: Color) -> Button:

	var btn : Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 3)
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.24, 0.16, 0.09, 0.95)
		if state == "hover":
			bg = bg.lightened(0.10)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		s.bg_color = bg
		s.border_color = Color(0.78, 0.58, 0.24, 1.0)
		s.set_border_width_all(2)
		s.set_corner_radius_all(8)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 7
		s.content_margin_bottom = 7
		btn.add_theme_stylebox_override(state, s)
	return btn
