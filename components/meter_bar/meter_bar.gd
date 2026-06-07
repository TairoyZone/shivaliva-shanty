## MeterBar — a reusable labelled status BAR (placeholder-first, scene-per-component so art swaps later).
## Redundant coding = leading ICON + coloured FILL + a right-aligned VALUE caption, so state never rides
## on colour alone (colour-blind safe; the bar is self-labeling, so it needs no long instruction strip).
## The fill TWEENS to new values (animate-everything, see [[animate-everything-principle]]) — never snaps.
## SEGMENTED for small discrete counts (HULL holes), SMOOTH for continuous pools (STARDUST). Reused on the
## ship deck now + droppable into the Loft / Patchworks / future stations later. Call set_value(cur, max).
class_name MeterBar
extends Control

## State palette (migrated from the retired HullGauge so the deck reads identically).
const SOUND : Color = Color(0.58, 0.88, 0.62, 1.0)
const WARN : Color = Color(0.98, 0.82, 0.50, 1.0)
const BAD : Color = Color(1.0, 0.55, 0.50, 1.0)
const STARDUST_CALM : Color = Color(0.50, 0.74, 0.96, 1.0)   # the rising-pool fill when low (calm sky-blue)
const HULL_WOOD : Color = Color(0.46, 0.31, 0.16, 1.0)
const TROUGH_BG : Color = Color(0.07, 0.10, 0.17, 0.92)
const TROUGH_BORDER : Color = Color(0.0, 0.0, 0.0, 0.55)
const TEXT : Color = Color(0.98, 0.96, 0.92, 1.0)
const TEXT_SHADOW : Color = Color(0.0, 0.0, 0.0, 0.9)
const DANGER_TICK_COLOR : Color = Color(1.0, 0.85, 0.40, 0.7)    # the amber WARNING tick line
const HARD_LINE_COLOR : Color = Color(1.0, 0.40, 0.40, 0.95)     # the hard SINK threshold line

const FILL_TIME : float = 0.40   # mirrors the HUD purse's COUNT_DURATION so the deck's juice is unified
const ICON_W : float = 20.0

@export var label_text : String = "HULL"
## 0 = smooth continuous fill; > 0 = N discrete notches (one per unit, e.g. hull holes).
@export var segments : int = 0
## "hull" / "stardust" / "" — the leading glyph drawn at the bar's start, tinted to the state colour.
@export var icon_kind : String = "hull"
## A thin amber WARNING tick at this fraction (0..1); < 0 = none (e.g. Stardust's danger at 0.8).
@export var danger_tick : float = -1.0
## A hard threshold LINE at this fraction (0..1); < 0 = none (e.g. Stardust's sink at 1.0).
@export var hard_line : float = -1.0
## RISING pool (stardust): the fill lerps calm-blue -> red past [member danger_tick] instead of the
## green -> amber -> red ramp a draining health-style bar uses.
@export var rising_palette : bool = false
## Fraction thresholds for the green -> amber -> red ramp (ignored when [member rising_palette]).
@export var warn_frac : float = 0.34
@export var bad_frac : float = 0.66

var _shown : float = 0.0       # the fraction _draw paints (tweens toward _target); never snaps
var _target : float = 0.0
var _caption : String = ""
var _tween : Tween
var _initialized : bool = false   # first set_value snaps (no animate-from-zero on deck re-entry); rest tween


func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_PASS   # PASS so a hover tooltip fires but clicks fall through


## Drive the bar to [param current] out of [param maximum] — the ONLY call site hook each refresh.
## Animates the fill over [constant FILL_TIME]; a re-entry to the same value is a no-op (no reflash).
func set_value(current: float, maximum: float) -> void:

	var frac : float = 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
	if _initialized and is_equal_approx(frac, _target):
		return
	_target = frac
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# First value SNAPS (so re-entering the deck doesn't animate-from-zero each time); every change after
	# that TWEENS, so the player SEES holes open / stardust rise.
	if not _initialized:
		_initialized = true
		_shown = frac
		queue_redraw()
		return
	_tween = create_tween()
	_tween.tween_method(_set_shown, _shown, _target, FILL_TIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## The right-aligned value text ("sound" / "2 holes" / "rising").
func set_caption(text: String) -> void:

	if text == _caption:
		return
	_caption = text
	queue_redraw()


func _set_shown(v: float) -> void:

	_shown = v
	queue_redraw()


# The fill colour at the current shown fraction.
func _state_color() -> Color:

	if rising_palette:
		var dt : float = danger_tick if danger_tick >= 0.0 else 0.75
		var t : float = 0.0 if _shown <= dt else clampf((_shown - dt) / maxf(1.0 - dt, 0.01), 0.0, 1.0)
		return STARDUST_CALM.lerp(BAD, t)
	if _shown >= bad_frac - 0.001:
		return BAD
	if _shown >= warn_frac - 0.001:
		return WARN
	return SOUND


func _draw() -> void:

	var h : float = size.y
	var track_x : float = ICON_W + 4.0
	var track_w : float = size.x - track_x
	if track_w <= 0.0:
		return
	var col : Color = _state_color()
	# Trough (a dark rounded panel so the bar reads over the wood deck + the twinkling sky).
	var trough : StyleBoxFlat = StyleBoxFlat.new()
	trough.bg_color = TROUGH_BG
	trough.set_corner_radius_all(6)
	trough.border_color = TROUGH_BORDER
	trough.set_border_width_all(1)
	trough.draw(get_canvas_item(), Rect2(track_x, 1.0, track_w, h - 2.0))
	# Fill — snapped to whole notches when segmented (so HULL reads as countable lit notches).
	var fill_frac : float = _shown
	if segments > 0:
		fill_frac = clampf(round(_shown * segments) / float(segments), 0.0, 1.0)
	if fill_frac > 0.001:
		var fill : StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = col
		fill.set_corner_radius_all(5)
		var fw : float = maxf(track_w * fill_frac - 2.0, 3.0)
		fill.draw(get_canvas_item(), Rect2(track_x + 1.0, 2.0, fw, h - 4.0))
	# Segment dividers carve the continuous fill into notches.
	if segments > 1:
		for i in range(1, segments):
			var x : float = track_x + track_w * (float(i) / float(segments))
			draw_line(Vector2(x, 3.0), Vector2(x, h - 3.0), TROUGH_BG, 1.5)
	# Danger tick + hard threshold line. CLAMPED inside the track so a fraction at 1.0 (the SINK line —
	# the single most critical tick) isn't half-eaten by the rounded frame / clip edge: at frac 1.0 the
	# raw x lands on size.x, so ~1px renders outside the control + the rest hides under the corner.
	if danger_tick >= 0.0:
		var dx : float = clampf(track_x + track_w * danger_tick, track_x + 1.0, track_x + track_w - 2.0)
		draw_line(Vector2(dx, 2.0), Vector2(dx, h - 2.0), DANGER_TICK_COLOR, 1.5)
	if hard_line >= 0.0:
		var hx : float = clampf(track_x + track_w * hard_line, track_x + 1.0, track_x + track_w - 2.0)
		draw_line(Vector2(hx, 1.0), Vector2(hx, h - 1.0), HARD_LINE_COLOR, 2.0)
	# Leading icon (tinted to state, so the glyph ALSO carries the colour cue).
	_draw_icon(Vector2(ICON_W * 0.5, h * 0.5), col)
	# Label (left) + value caption (right), each with a 1px shadow for contrast over the fill.
	var font : Font = get_theme_default_font()
	if font != null:
		var fs : int = 12
		var ty : float = h * 0.5 + float(fs) * 0.36
		_draw_text(font, Vector2(track_x + 7.0, ty), label_text, fs)
		if not _caption.is_empty():
			var cw : float = font.get_string_size(_caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
			_draw_text(font, Vector2(track_x + track_w - cw - 7.0, ty), _caption, fs)


func _draw_text(font: Font, pos: Vector2, text: String, fs: int) -> void:

	draw_string(font, pos + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT_SHADOW)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT)


# Procedural placeholder glyphs (a Sprite child would supersede these later — art-swap, no code change).
func _draw_icon(c: Vector2, col: Color) -> void:

	match icon_kind:
		"hull":
			var hull : PackedVector2Array = PackedVector2Array([
				c + Vector2(-7.0, -4.0), c + Vector2(7.0, -4.0), c + Vector2(4.0, 5.0), c + Vector2(-4.0, 5.0)])
			draw_colored_polygon(hull, HULL_WOOD)
			draw_polyline(hull + PackedVector2Array([hull[0]]), col, 1.4)
		"stardust":
			draw_line(c + Vector2(0.0, -7.0), c + Vector2(0.0, 7.0), col, 1.6)
			draw_line(c + Vector2(-6.0, 0.0), c + Vector2(6.0, 0.0), col, 1.6)
			draw_line(c + Vector2(-4.0, -4.0), c + Vector2(4.0, 4.0), Color(col.r, col.g, col.b, 0.6), 1.2)
			draw_line(c + Vector2(-4.0, 4.0), c + Vector2(4.0, -4.0), Color(col.r, col.g, col.b, 0.6), 1.2)
			draw_circle(c, 1.8, col)
		_:
			pass
