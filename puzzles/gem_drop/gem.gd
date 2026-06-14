## A gem game piece for Gem Drop. Falls through the funnel, bounces off
## paddle switches, lands in scoring slots.
##
## Visual: drawn PROCEDURALLY (no imported art) per the placeholder-first
## house rule. A struck-coin face with a beveled rim, an up-left key-light
## sheen, and an embossed center pip. The human's coins are warm topaz
## gold; the rival's are ruby red, so the two sides read apart at a glance
## (and echo the board's cool->hot scoring ramp). This REPLACES the old
## lifted GDQuest spritesheet, which also caused the gem-drop spin jitter
## on mobile.
##
## ## Spin & rest
##
## A falling coin spins edge-on (an x-squash driven by [member _spin_phase]),
## and carries a soft two-disc halo. A RESTING coin freezes flat and stops
## processing entirely. Resting coins accumulate over a round (up to the 16
## scoring slots), so freezing them is the perf win that killed the jitter.
##
## Multi-gem stacks render as a single coin plus an `xN` label above. The
## Board manages stacking via the [member size] property.
@tool
class_name Gem
extends Node2D


const RADIUS : float = 14.0
## Half the visible coin height in scene units. The Board reads this to
## land resting coins pixel-flush on the pad surface.
const VISUAL_HALF_HEIGHT : float = 12.0
## Radius of the drawn coin face (slightly inside [const RADIUS] so the
## physics circle has a hair of margin over the visual).
const FACE_RADIUS : float = 12.0
const FALL_SPEED : float = 280.0  # px/sec — read by the Board's _process
const STACK_LABEL_OFFSET : float = -28.0
## Radians/sec the falling coin's edge-on spin advances.
const SPIN_SPEED : float = 6.0

const HUMAN : int = 0
const AI : int = 1

## Coin FACE colors per owner. Human = warm topaz; rival = ruby — instant
## side identity. The lit-disc and rim shades are derived from these.
const HUMAN_FACE : Color = Palette.GEM_TOPAZ
const AI_FACE : Color = Palette.GEM_RUBY_LIGHT


# State managed by the Board.
var next_switch_row : int = 0
## A coin only needs to SPIN (and redraw) while it's FALLING. On rest it
## freezes flat and stops processing — a yard of always-animating coins was
## the gem-drop jitter on mobile (Troy 2026-06-13, the mobile perf pass).
var resting : bool = false :
	set(value):
		if resting == value:
			return
		resting = value
		set_process(not value)   # resting coins do no per-frame work
		queue_redraw()
var owner_player : int = HUMAN :
	set(value):
		owner_player = value
		_apply_tint()
var size : int = 1 :
	set(value):
		size = value
		queue_redraw()

# --- Derived per-owner draw colors (set by _apply_tint) ------------------
var _face : Color = HUMAN_FACE
var _face_lit : Color = HUMAN_FACE.lightened(0.40)
var _rim : Color = HUMAN_FACE.darkened(0.45)
## Phase of the edge-on spin; advanced while falling, staggered per coin so
## a freshly-spawned row doesn't pulse in unison.
var _spin_phase : float = 0.0


func _ready() -> void:

	_apply_tint()
	_spin_phase = randf() * TAU   # desync the row
	set_process(not resting)
	queue_redraw()


func _process(delta: float) -> void:

	# Only ever runs while falling (the resting setter calls set_process(false)).
	_spin_phase += SPIN_SPEED * delta
	queue_redraw()


func _apply_tint() -> void:

	var base : Color = HUMAN_FACE if owner_player == HUMAN else AI_FACE
	_face = base
	_face_lit = base.lightened(0.42)
	_rim = base.darkened(0.45)
	queue_redraw()


func _draw() -> void:

	# A falling coin shows its spin as a horizontal squash (the face tips
	# edge-on as _spin_phase sweeps); a resting coin sits flat (sx = 1).
	# Floor the squash so the coin never fully vanishes at the edge-on frame.
	var sx : float = 1.0
	if not resting:
		sx = maxf(0.20, absf(cos(_spin_phase)))
		# Soft two-disc halo behind a falling coin (drawn first, faint).
		var halo : Color = Color(_face.r, _face.g, _face.b, 0.16)
		draw_circle(Vector2.ZERO, FACE_RADIUS + 5.0, halo)
		draw_circle(Vector2.ZERO, FACE_RADIUS + 2.5, Color(_face.r, _face.g, _face.b, 0.22))

	# Squash subsequent coin-body draws on the x axis to fake the spin.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, 1.0))
	# Dark separation ring so the coin always reads, even when a topaz coin
	# rests on a brass paddle (gold-on-gold would otherwise blend).
	draw_circle(Vector2.ZERO, FACE_RADIUS + 1.0, Palette.SKY_VOID)
	# Body + an up-left lit disc for volume.
	draw_circle(Vector2.ZERO, FACE_RADIUS, _face)
	draw_circle(Vector2(-2.0, -2.6), FACE_RADIUS * 0.62, _face_lit)
	# Beveled rim.
	draw_arc(Vector2.ZERO, FACE_RADIUS, 0.0, TAU, 28, _rim, 2.0)
	# Two specular sheen arcs over the upper-left (one key light, matches
	# the board + paddle highlight language).
	draw_arc(Vector2.ZERO, FACE_RADIUS - 2.0, PI * 0.92, PI * 1.45, 10, Palette.BRASS_BRIGHT, 1.6)
	draw_arc(Vector2.ZERO, FACE_RADIUS - 5.0, PI * 1.02, PI * 1.34, 8, Palette.BRASS_BRIGHT, 1.0)
	# Embossed center pip.
	draw_circle(Vector2.ZERO, 2.4, _rim)
	draw_circle(Vector2(-0.7, -0.7), 1.1, Palette.GOLD_GLOW)
	# Reset the transform so the stack label is never squashed.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if size <= 1:
		return
	var font : Font = ThemeDB.fallback_font
	var label : String = "x%d" % size
	var w : float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
	var pos : Vector2 = Vector2(-w * 0.5, STACK_LABEL_OFFSET)
	draw_string(font, pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Palette.SKY_VOID)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Palette.GOLD_TEXT)
