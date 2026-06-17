## CLOCK WIDGET — a persistent Stardew-style in-game clock for the overworld HUD. A compact brass pill with a
## day/night ARC (a sun travels it by day, a moon presides by night — matching the [DayNight] cycle) and the
## time ("7:10 AM") + the time-of-day phase. Reads the [GameClock] (PlayerState.game_minutes) live so the
## player can always check the hour. Process-always (ticks through a pause, like the clock). Placeholder-first.
class_name ClockWidget
extends Control

const W : float = 212.0   # wide enough for the longest phase ("The Dead Of Night") so text never bleeds the pill
const H : float = 64.0
const TEXT_X : float = 70.0   # left edge of the time + phase text (clears the arc)
const ARC_C : Vector2 = Vector2(36.0, 44.0)   # arc centre (left side of the pill)
const ARC_R : float = 26.0

# Pill chrome + text route through the swappable HUD theme (Palette tokens, read at build time so a scheme
# swap retunes the clock too). The day/night ARC art (sun gold, moon pale, dim track) stays fixed — it's a
# drawn indicator, not chrome.
const ARC_TRACK : Color = Color(0.55, 0.45, 0.28, 0.7)
# The sun/moon must CONTRAST the pill. On a DARK pill the old bright gold sun + pale moon read fine; on the
# LIGHT pill they vanished (light-on-light), so use a deep amber sun + a dark slate moon there (Troy 2026-06-17).
var SUN : Color :
	get: return Color(1.0, 0.86, 0.4, 1.0) if Palette.IS_DARK else Color(0.84, 0.50, 0.10, 1.0)
var MOON : Color :
	get: return Color(0.86, 0.89, 0.99, 1.0) if Palette.IS_DARK else Color(0.22, 0.28, 0.50, 1.0)

# Sun clock (mirrors DayNight): rises ~6:30, sets ~18:30, peaks 12:30.
const SUNRISE : float = 390.0
const SUNSET : float = 1110.0

var _panel_style : StyleBoxFlat
var _bg : Color = Palette.PANEL_BG   # the pill backing — also painted over the moon to cut its crescent
var _time_label : Label
var _phase_label : Label
var _last_min : int = -1


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bg = Palette.PANEL_BG
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = _bg
	_panel_style.border_color = Palette.BORDER
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(12)

	# Both labels are width-bounded + clipped to the pill's inner width, so a long string (e.g. "The Dead Of
	# Night") can never bleed past the pill background — it stays inside the text column.
	var text_w : float = W - TEXT_X - 8.0

	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 21)
	_time_label.add_theme_color_override("font_color", Palette.TEXT_PRIMARY)
	# Light schemes (dark text on a light pill) drop the heavy black outline; dark schemes keep it crisp.
	if Palette.IS_DARK:
		_time_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_time_label.add_theme_constant_override("outline_size", 4)
	_time_label.position = Vector2(TEXT_X, 9.0)
	_time_label.size = Vector2(text_w, 26.0)
	_time_label.clip_text = true
	add_child(_time_label)

	_phase_label = Label.new()
	_phase_label.add_theme_font_size_override("font_size", 12)
	_phase_label.add_theme_color_override("font_color", Palette.TEXT_MUTED)
	_phase_label.position = Vector2(TEXT_X, 37.0)
	_phase_label.size = Vector2(text_w, 18.0)
	_phase_label.clip_text = true
	add_child(_phase_label)

	_refresh(true)
	call_deferred("_refresh", true)   # re-fit once the HUD has set our right-edge offset


func _process(_delta: float) -> void:
	_refresh(false)


func _refresh(force: bool) -> void:

	var m : int = int(PlayerState.game_minutes)
	if not force and m == _last_min:
		return
	_last_min = m
	_time_label.text = GameClock.time_string()
	_phase_label.text = GameClock.phase().capitalize()
	_fit_width()
	queue_redraw()


# Shrink the pill to FIT its current text (right-anchored, grows left) so there's no dead space after a short
# phase like "Midday" — the longest ("The Dead Of Night") still fits (Troy 2026-06-17).
func _fit_width() -> void:

	var font : Font = get_theme_default_font()
	if font == null:
		return
	var tw : float = font.get_string_size(_time_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 21).x
	var pw : float = font.get_string_size(_phase_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x
	var w : float = clampf(TEXT_X + maxf(tw, pw) + 16.0, 150.0, 240.0)
	if absf(w - size.x) < 1.0:
		return
	offset_left = offset_right - w   # keep the right edge fixed
	var col_w : float = w - TEXT_X - 8.0
	_time_label.size.x = col_w
	_phase_label.size.x = col_w


func _draw() -> void:

	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))

	var m : float = PlayerState.game_minutes
	var is_day : bool = m >= SUNRISE and m <= SUNSET
	# Daytime arc track (the sun's path); dim at night.
	draw_arc(ARC_C, ARC_R, PI, TAU, 28, ARC_TRACK if is_day else ARC_TRACK.darkened(0.3), 2.5)

	if is_day:
		# Sun travels left (dawn) → top (noon) → right (dusk) along the arc.
		var p : float = clampf((m - SUNRISE) / (SUNSET - SUNRISE), 0.0, 1.0)
		var ang : float = PI * (1.0 + p)
		var pos : Vector2 = ARC_C + ARC_R * Vector2(cos(ang), sin(ang))
		for i in 8:
			var ray : float = (TAU / 8.0) * float(i)
			draw_line(pos + Vector2(cos(ray), sin(ray)) * 7.0, pos + Vector2(cos(ray), sin(ray)) * 11.0, SUN, 1.5)
		draw_circle(pos, 6.0, SUN)
		draw_circle(pos, 3.5, Color(1.0, 0.97, 0.82, 1.0))
	else:
		# Night — a moon presides at the crown of the (dim) arc, with a crescent bite + a couple of stars.
		var moon : Vector2 = ARC_C + Vector2(0.0, -ARC_R)
		draw_circle(moon, 6.5, MOON)
		draw_circle(moon + Vector2(2.5, -1.5), 5.0, _bg)   # crescent shadow (the pill bg, cuts the crescent)
		draw_circle(ARC_C + Vector2(-18.0, -8.0), 1.2, MOON)
		draw_circle(ARC_C + Vector2(16.0, -12.0), 1.0, MOON)
		draw_circle(ARC_C + Vector2(10.0, 2.0), 1.1, MOON)
