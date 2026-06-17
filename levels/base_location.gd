## Base class for any walkable overworld location (Cradle Rock, tavern,
## future islands). Instantiates the Player and resolves where to spawn
## them in this priority order:
##
##   1. PlayerState.pending_spawn_anchor (string Marker2D name) — set by
##      Door / GemDropTable before they trigger the scene change.
##   2. PlayerState.pending_spawn_position (Vector2) — set by main.gd
##      when resuming from a saved session.
##   3. pirate_spawn_position — the scene's default starting point.
##
## After spawning, the current scene path is saved to PlayerState so the
## player resumes here on next launch.
class_name BaseLocation
extends Node2D

const PLAYER_SCENE : PackedScene = preload("res://player/player.tscn")

## Default mood washes by scene-path keyword (used when [member mood_tint] is left transparent). Subtle —
## tune or override per-scene via the inspector.
const SCENE_MOODS : Dictionary = {
	"mine": Color(0.10, 0.16, 0.40, 0.28),
	"tavern": Color(0.55, 0.32, 0.08, 0.16),
	"forest": Color(0.12, 0.34, 0.18, 0.12),
	"ship_deck": Color(0.18, 0.30, 0.62, 0.14),
	"shanty": Color(0.52, 0.34, 0.14, 0.12),
}

## Outdoor SKY-island locations share ONE procedural Stardust sky + drifting clouds behind them, so every
## open-air scene (the islands AND the ship deck) reads with the SAME background (Troy 2026-06-07: "make the
## background of the ship and the islands the same"). Interiors (tavern, mine, *_interior) stay indoors.
const SKY_LOCATIONS : Array = ["shore", "forest", "frontier_isle", "ship_deck"]
const SKY_FOG_TINT : Color = Color(0.80, 0.84, 0.96, 0.85)   # drifting-cloud colour (shared everywhere)

@export var pirate_spawn_position : Vector2 = Vector2(640, 540)
## (Legacy) scene this location used to load on ESC. ESC is now the
## backpack key — owned + consumed by the [HUD] in the overworld — so
## this is no longer wired to ESC. Kept as an export for a future
## explicit "quit to title" entry point (e.g. a button in the bag /
## pause screen). NOT read anywhere right now.
@export_file("*.tscn") var escape_scene : String = ""

## A colour WASH over this location for mood (alpha = strength); transparent = fall back to the SCENE_MOODS
## keyword default, or none. Set per-scene in the inspector to override. See [MoodTint].
@export var mood_tint : Color = Color(0, 0, 0, 0)

## Sky backdrop: Auto = on for the outdoor [constant SKY_LOCATIONS] (by scene path); Always / Never force it.
@export_enum("Auto", "Always", "Never") var sky_mode : int = 0

var player : Player


# NOTE: no ESC handler here anymore. ESC summons the backpack (handled
# in HUD._unhandled_input, which consumes it), so the old ESC-to-title
# leave was removed to avoid fighting the HUD for the key.


func _ready() -> void:

	# Any walkable location is gameplay → ensure the HUD is shown (the
	# title screen hides it; puzzle scenes hide + restore it themselves).
	if HUD:
		HUD.visible = true
	Audio.play_music_track("overworld")   # the overworld bed (guarded — won't restart between locations)
	_apply_sky()
	_apply_mood()
	_theme_location_banner()   # the scene-title pill follows the central HUD theme (Troy 2026-06-17)
	# Co-op seam: spawn each session player (a loop-of-one in single-player). See [[multiplayer-direction]].
	for id in SessionState.players:
		_spawn_player(int(id))
	var joystick : VirtualJoystick = _build_touch_joystick()
	_build_overworld_camera(joystick)


# Recolor the scene-title banner (each level's .tscn bakes a dark pill + gold label) to the central HUD theme,
# so the overworld title matches the rest of the HUD on whatever scheme is active. One hook, every level.
func _theme_location_banner() -> void:

	var banner : Node = get_node_or_null("UI/LocationBanner")
	if not (banner is PanelContainer):
		return
	var sb : StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Palette.PANEL_BG
	sb.border_color = Palette.BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	UiStyle.glow_shadow(sb)
	(banner as PanelContainer).add_theme_stylebox_override("panel", sb)
	var loc : Node = banner.get_node_or_null("LocationLabel")
	if loc is Label:
		UiStyle.apply_title(loc as Label)
		if not Palette.IS_DARK:
			(loc as Label).add_theme_constant_override("outline_size", 0)   # drop any baked black outline on the light page


## Spawn the player for [param id] + parent it under the iso Y-sort root (falls back to self for legacy
## top-down scenes). The LOCAL player resolves its spawn from the scene-transition handoff + becomes
## [member player]; this loop body is what co-op fans out over when netcode lands.
func _spawn_player(id: int) -> void:

	var p : Player = PLAYER_SCENE.instantiate()
	p.peer_id = id
	# Parent inside YSortNode2D when present so the iso character y-sorts against tiles + buildings; falls
	# back to self for legacy / top-down scenes without one.
	var y_sort_root : Node = find_child("YSortNode2D", false, false)
	if y_sort_root != null:
		y_sort_root.add_child(p)
	else:
		add_child(p)
	if id == SessionState.LOCAL_ID:
		player = p
		p.global_position = _resolve_spawn_position()
		# Record where the local player landed so a quit-now resume restores them here.
		PlayerState.last_scene = scene_file_path
		PlayerState.last_position = p.global_position


# On touch, the overworld camera is driven by the OverworldCamera state-machine rig (Troy 2026-06-14): it FOLLOWS
# the player dead-centre by default (the camera is a child Camera2D), a one-finger swipe OUTSIDE the joystick zone
# PEEKS around (up to 50% of the screen, easing back on release) and works even while moving, and a 2-finger pinch
# ZOOMS — but never while moving. The rig is fed the [param joystick] so it knows the move-finger's zone and can
# never confuse it for a look-swipe. Gated on TouchEnv; desktop never sees it. One wiring point covers every
# walkable scene AND the ship deck. See [[touch-input-foundation]].
func _build_overworld_camera(joystick: VirtualJoystick) -> void:

	if not TouchEnv.is_touch() or player == null:
		return
	var cam : Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var rig : OverworldCamera = OverworldCamera.new()
	rig.setup(cam, joystick)
	add_child(rig)


# On a touch device, a virtual stick drives overworld movement (the world is action-based — Input.get_vector on
# move_* — not tap-to-walk). Its own CanvasLayer (layer 5) so it floats over the world but under the HUD/panels.
# Gated on TouchEnv, so the desktop build never sees it. See [[touch-input-foundation]].
func _build_touch_joystick() -> VirtualJoystick:

	if not TouchEnv.is_touch():
		return null
	var layer : CanvasLayer = CanvasLayer.new()
	layer.layer = 5
	layer.name = "TouchJoystickLayer"
	add_child(layer)
	var js : VirtualJoystick = VirtualJoystick.new()
	layer.add_child(js)
	return js


## Add the shared procedural Stardust SKY + drifting clouds behind an OUTDOOR location, so the islands +
## the ship deck share ONE background. Gated by [method _wants_sky]; sits on low CanvasLayers (sky -10,
## clouds -5), fixed in screen space — a distant sky, not parented to the camera.
func _apply_sky() -> void:

	if not _wants_sky():
		return
	add_child(SkyBackdrop.new())
	# DriftFog is a SECOND full-screen animated fragment shader on top of the sky — drop it on touch/web, where
	# two full-viewport procedural passes tax a phone GPU (Troy 2026-06-13, the mobile perf pass). Desktop keeps it.
	if not TouchEnv.is_touch():
		add_child(DriftFog.make(SKY_FOG_TINT))
	# The day/night cycle — tints the world + shifts the sky (sun by day, moon + stardust by night), driven by
	# the GameClock so you can physically read the hour outdoors. Added last so its world CanvasModulate wins.
	add_child(DayNight.new())


func _wants_sky() -> bool:

	if sky_mode == 1:
		return true    # Always
	if sky_mode == 2:
		return false   # Never (interiors)
	for key in SKY_LOCATIONS:
		if scene_file_path.contains(key):
			return true
	return false


## Add a [MoodTint] colour wash if this location has a mood — an explicit [member mood_tint], else a
## SCENE_MOODS keyword match on the scene path. Tints the world only (sits below the HUD/UI).
func _apply_mood() -> void:

	var tint : Color = mood_tint
	if tint.a <= 0.0:
		for key in SCENE_MOODS:
			if scene_file_path.contains(key):
				tint = SCENE_MOODS[key]
				break
	if tint.a > 0.0:
		add_child(MoodTint.make(tint))


func _resolve_spawn_position() -> Vector2:

	var anchor_name : String = PlayerState.consume_anchor()
	if not anchor_name.is_empty():
		var anchor : Node = find_child(anchor_name, true, false)
		if anchor is Node2D:
			# Each spawn-target component (Door, GemDropTable, …)
			# carries its own @export var spawn_offset so the spawn point
			# lives next to the thing it belongs to. Apply it if present.
			var base : Vector2 = (anchor as Node2D).global_position
			var offset_value : Variant = anchor.get("spawn_offset")
			if offset_value is Vector2:
				return base + (offset_value as Vector2)
			return base
	var resumed_pos : Variant = PlayerState.consume_position()
	if resumed_pos != null:
		return resumed_pos
	return pirate_spawn_position
