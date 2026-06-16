## DayNight — a drop-in procedural day/night cycle for the OUTDOOR overworld. `add_child(DayNight.new())`
## (BaseLocation does it for the SKY_LOCATIONS, over the stardust SkyBackdrop). Driven by the GameClock's
## PlayerState.game_minutes (a 30-real-minute day), it makes the hour PHYSICALLY readable in the overworld:
##   • a CanvasModulate tints the whole WORLD — bright midday → warm dusk → deep-blue night → cool dawn;
##   • a DAY-SKY gradient lies over the stardust starfield and FADES OUT at night so the stars show through;
##   • a SUN arcs across by day and a MOON by night (the "directional" cue — you watch them rise + set).
## Process-always so time keeps flowing through a pause (matches GameClock). Placeholder-first — tune the
## colour stops + arc. See [[sky-canon]].
class_name DayNight
extends Node2D

# --- Layering (relative to the existing sky stack) -------------------
const SKY_GRADIENT_LAYER : int = -9   # over the stardust sky (-10), behind the drift clouds (-5)
const CELESTIAL_LAYER : int = -3      # in front of the clouds, BEHIND the world (0) — the far sky

# --- Sun clock (minutes of the 24h day) ------------------------------
const SUNRISE_MIN : float = 390.0     # ~6:30 rise
const SUNSET_MIN : float = 1110.0     # ~18:30 set
const NOON_MIN : float = 750.0        # 12:30 peak

# --- Palette (placeholder-first; tune freely) ------------------------
const WORLD_DAY : Color = Color(1.0, 0.99, 0.96)      # CanvasModulate multiply — neutral-bright midday
const WORLD_NIGHT : Color = Color(0.34, 0.40, 0.62)   # deep blue night (dark but still playable)
const WORLD_WARM : Color = Color(1.0, 0.74, 0.55)     # golden-hour warmth
const SKY_DAY_TOP : Color = Color(0.36, 0.58, 0.88)
const SKY_DAY_BOT : Color = Color(0.66, 0.82, 0.96)
const SKY_WARM_TOP : Color = Color(0.93, 0.55, 0.40)
const SKY_WARM_BOT : Color = Color(0.99, 0.80, 0.54)
const NIGHT_DIM : Color = Color(0.05, 0.06, 0.16)     # laid over the clouds/sky at night

var _world_mod : CanvasModulate
var _gradient : _SkyGradient
var _celestial : _Celestial


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS   # time + visuals keep moving through a paused tree (like GameClock)
	_world_mod = CanvasModulate.new()
	add_child(_world_mod)   # lives in the scene canvas (layer 0) → tints the whole world

	var grad_layer : CanvasLayer = CanvasLayer.new()
	grad_layer.layer = SKY_GRADIENT_LAYER
	add_child(grad_layer)
	_gradient = _SkyGradient.new()
	grad_layer.add_child(_gradient)

	var cel_layer : CanvasLayer = CanvasLayer.new()
	cel_layer.layer = CELESTIAL_LAYER
	add_child(cel_layer)
	_celestial = _Celestial.new()
	cel_layer.add_child(_celestial)

	_fit()
	get_viewport().size_changed.connect(_fit)
	_update()


# Cover the whole viewport (Controls under a CanvasLayer have no anchor parent — size them explicitly).
func _fit() -> void:

	var vp : Vector2 = get_viewport().get_visible_rect().size
	_gradient.vp = vp
	_celestial.vp = vp
	_gradient.queue_redraw()
	_celestial.queue_redraw()


func _process(_delta: float) -> void:

	_update()


# Recompute every tint + the sun/moon arc from the current in-game minute.
func _update() -> void:

	var m : float = PlayerState.game_minutes
	var alt : float = cos((m - NOON_MIN) / GameClock.DAY_MINUTES * TAU)   # sun altitude: +1 noon … -1 midnight
	var day_f : float = clampf((alt + 0.04) / 0.42, 0.0, 1.0)             # 1 when the sun's well up, 0 below horizon
	var warm_f : float = clampf(1.0 - absf(alt) / 0.20, 0.0, 1.0)         # golden-hour band near the horizon

	# World multiply tint: night → day, then warmed through the golden hours.
	_world_mod.color = WORLD_NIGHT.lerp(WORLD_DAY, day_f).lerp(WORLD_WARM, warm_f * 0.6)

	# Day-sky gradient over the stardust — alpha fades to 0 at night so the stars read through.
	var top : Color = SKY_DAY_TOP.lerp(SKY_WARM_TOP, warm_f)
	var bot : Color = SKY_DAY_BOT.lerp(SKY_WARM_BOT, warm_f)
	var sky_a : float = maxf(day_f, warm_f * 0.85)
	top.a = sky_a
	bot.a = sky_a
	_gradient.top = top
	_gradient.bot = bot
	_gradient.queue_redraw()

	# Night dim over the clouds + the sun (day) / moon (night) discs on the far sky.
	var dim : Color = NIGHT_DIM
	dim.a = clampf(1.0 - day_f - warm_f * 0.7, 0.0, 1.0) * 0.55
	_celestial.dim = dim

	var sun_prog : float = clampf((m - SUNRISE_MIN) / (SUNSET_MIN - SUNRISE_MIN), 0.0, 1.0)
	_celestial.sun_pos = Vector2(lerpf(0.16, 0.84, sun_prog) * _celestial.vp.x,
		(0.60 - clampf(alt, 0.0, 1.0) * 0.48) * _celestial.vp.y)
	_celestial.sun_a = clampf((alt + 0.10) / 0.14, 0.0, 1.0)

	var moon_alt : float = -alt
	var night_m : float = fposmod(m - SUNSET_MIN, GameClock.DAY_MINUTES)   # minutes since sunset
	var night_len : float = GameClock.DAY_MINUTES - (SUNSET_MIN - SUNRISE_MIN)
	var moon_prog : float = clampf(night_m / night_len, 0.0, 1.0)
	_celestial.moon_pos = Vector2(lerpf(0.16, 0.84, moon_prog) * _celestial.vp.x,
		(0.60 - clampf(moon_alt, 0.0, 1.0) * 0.48) * _celestial.vp.y)
	_celestial.moon_a = clampf((moon_alt + 0.10) / 0.14, 0.0, 1.0)
	_celestial.queue_redraw()


# --- The two procedural sky drawers (own CanvasLayers; fed by _update) ----

# A vertical day-sky gradient quad — alpha 0 at night so the stardust starfield shows through.
class _SkyGradient extends Node2D:

	var vp : Vector2 = Vector2.ZERO
	var top : Color = Color(0, 0, 0, 0)
	var bot : Color = Color(0, 0, 0, 0)

	func _draw() -> void:
		if vp == Vector2.ZERO or (top.a <= 0.003 and bot.a <= 0.003):
			return
		var pts : PackedVector2Array = PackedVector2Array([
			Vector2(0, 0), Vector2(vp.x, 0), Vector2(vp.x, vp.y), Vector2(0, vp.y)])
		var cols : PackedColorArray = PackedColorArray([top, top, bot, bot])
		draw_polygon(pts, cols)


# The night dim wash over the clouds + a glowing sun / moon disc on the far sky.
class _Celestial extends Node2D:

	var vp : Vector2 = Vector2.ZERO
	var dim : Color = Color(0, 0, 0, 0)
	var sun_pos : Vector2 = Vector2.ZERO
	var sun_a : float = 0.0
	var moon_pos : Vector2 = Vector2.ZERO
	var moon_a : float = 0.0

	func _draw() -> void:
		if vp == Vector2.ZERO:
			return
		if dim.a > 0.003:
			draw_rect(Rect2(Vector2.ZERO, vp), dim)
		if sun_a > 0.01:
			for i in 4:
				draw_circle(sun_pos, 28.0 + float(i) * 18.0, Color(1.0, 0.84, 0.42, 0.09 * sun_a))
			draw_circle(sun_pos, 26.0, Color(1.0, 0.90, 0.55, sun_a))
			draw_circle(sun_pos, 18.0, Color(1.0, 0.97, 0.80, sun_a))
		if moon_a > 0.01:
			for i in 4:
				draw_circle(moon_pos, 24.0 + float(i) * 14.0, Color(0.78, 0.84, 0.99, 0.07 * moon_a))
			draw_circle(moon_pos, 21.0, Color(0.86, 0.89, 0.99, moon_a))
			draw_circle(moon_pos + Vector2(-7, -5), 4.5, Color(0.74, 0.78, 0.92, moon_a * 0.7))
			draw_circle(moon_pos + Vector2(6, 4), 3.5, Color(0.74, 0.78, 0.92, moon_a * 0.6))
			draw_circle(moon_pos + Vector2(3, -8), 2.8, Color(0.74, 0.78, 0.92, moon_a * 0.6))
