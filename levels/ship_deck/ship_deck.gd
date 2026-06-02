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
const SEED_CAP : int = 3

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
const HELM_G : Vector2 = Vector2(4.0, 3.2)     # captain + the "board" point
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


# Iso projection, centred so the deck middle sits on the world origin.
func _iso(gx: float, gy: float) -> Vector2:

	return Vector2(
		(gx - gy) * TILE_W * 0.5 - float(GW - GH) * TILE_W * 0.25,
		(gx + gy) * TILE_H * 0.5 - float(GW + GH) * TILE_H * 0.25)


func _ready() -> void:

	pirate_spawn_position = _iso(SPAWN_G.x, SPAWN_G.y)
	super._ready()                 # spawns the Player under YSortNode2D (normal camera)
	_add_hull_collision()
	_add_crew()
	_build_ui()
	_setup_phase()
	queue_redraw()


# --- Pillage phase ----------------------------------------------------

func _setup_phase() -> void:

	match PlayerState.pillage_phase:
		1:
			_say("Brigand off the bow! To arms — get to the helm and board 'em!")
		2:
			_resolve_boarding()
		_:
			_say("Welcome aboard, hand! Man the Loft yonder — keep her aloft as we make way.")


func _resolve_boarding() -> void:

	if PlayerState.last_skirmish_won:
		@warning_ignore("integer_division")
		var bonus : int = clampi(PlayerState.last_loft_lift / BOOTY_PER_LIFT_DIV, 0, BOOTY_LIFT_BONUS_CAP)
		var cut : int = BOOTY_BASE + bonus
		PlayerState.add_coins(cut)
		PlayerState.frontier_unlocked = true
		_say("We sent 'em running! Yer cut o' the booty: %d gold. Take the plank when ye're ready." % cut)
	else:
		_say("They slipped our grapple and ran... no booty this run. Take the plank and we'll limp home.")


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
		"board":
			_board_brigand()
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
	match PlayerState.pillage_phase:
		1:
			return [["board", _iso(HELM_G.x, HELM_G.y)], plank]
		2:
			return [plank]
		_:
			return [["loft", _iso(LOFT_G.x, LOFT_G.y)], plank]


func _action_label(id: String) -> String:

	match id:
		"loft":
			return "Man the Loft"
		"board":
			return "Board the brigand!"
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

	PlayerState.pillage_phase = 0
	var home : String = PlayerState.voyage_home_scene
	if home.is_empty():
		home = FALLBACK_HOME
	get_tree().change_scene_to_file(home)


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


func _say(line: String) -> void:

	if _captain_label != null:
		_captain_label.text = "Cap'n %s:  \"%s\"" % [_captain_name(), line]


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
	# Glow the ONE station this phase needs (its job is read by the glow, not a tag).
	_draw_glow(_active_world_pos())
	# Clean station props (no labels): playable Loft + helm + the flavour props + plank.
	_draw_prop(_iso(LOFT_G.x, LOFT_G.y), "loft")
	_draw_prop(_iso(HELM_G.x, HELM_G.y), "navigation")
	for st in FLAVOUR_STATIONS:
		_draw_prop(_iso(st[0].x, st[0].y), st[1])
	_draw_plank(_iso(PLANK_G.x, PLANK_G.y))
	# (Crew are real Npc instances added in _add_crew — not drawn here.)


# World position of the station active this phase (the one that glows).
func _active_world_pos() -> Vector2:

	match PlayerState.pillage_phase:
		1:
			return _iso(HELM_G.x, HELM_G.y)
		2:
			return _iso(PLANK_G.x, PLANK_G.y)
		_:
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


# Crew = real [Npc] instances (reuse the overworld character + dialogue), placed
# clear of the functional stations so their E-to-talk doesn't clash. Captain Jericho
# (the recruiter) + a couple of swabbies for the crewed-ship feel.
func _add_crew() -> void:

	var ysort : Node = find_child("YSortNode2D", false, false)
	if ysort == null:
		ysort = self
	_add_npc(ysort, _captain_name(), _iso(6.0, 4.0), Color(0.5, 0.5, 0.62, 1.0),
		["Ahoy! Welcome aboard, hand.", "Keep the Loft singing and we'll make way.",
		"When a brigand swings in, get to the helm and board 'em!"])
	_add_npc(ysort, "Deckhand", _iso(1.6, 9.5), Color(0.46, 0.52, 0.6, 1.0),
		["Aye, just keepin' busy.", "Mind the Stardust don't catch us nappin'."])
	_add_npc(ysort, "Deckhand", _iso(6.2, 13.0), Color(0.52, 0.5, 0.46, 1.0),
		["Ahoy.", "Mind the cannons, aye?"])


func _add_npc(parent: Node, who: String, pos: Vector2, tint: Color, lines: Array[String]) -> void:

	var npc : Npc = NPC_SCENE.instantiate()
	npc.npc_name = who
	npc.portrait_color = tint
	npc.dialog_lines = lines
	npc.position = pos
	parent.add_child(npc)