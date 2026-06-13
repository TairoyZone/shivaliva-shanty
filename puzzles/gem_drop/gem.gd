## A gem game piece for Gem Drop. Falls through the funnel, bounces off
## paddle switches, lands in scoring slots.
##
## Visual: GDQuest CC-BY 4.0 pixel-art gem from
## `learn_2d_gamedev_godot_4/M14.side_scroller_levels_solutions/assets/gem/`
## — a 5-frame spritesheet of a yellow diamond rotating around its
## vertical axis. Played as a looping AnimatedSprite2D animation at
## 10 fps with nearest-neighbor filtering (crisp pixels).
##
## Color identity: the texture is naturally yellow, used as-is for the
## human player. The AI's gem is the same sprite with a ruby modulate.
##
## Multi-gem stacks render as a single sprite plus an `xN` label drawn
## above. The Board manages stacking via the `size` property.
@tool
class_name Gem
extends Node2D


const RADIUS : float = 14.0
## Half the visible sprite height in scene units (12 px native × 2 scale =
## 24 px displayed → 12 px half). The Board reads this to land resting
## gems pixel-flush on the pad surface.
const VISUAL_HALF_HEIGHT : float = 12.0
const FALL_SPEED : float = 280.0  # px/sec — read by the Board's _process
const STACK_LABEL_OFFSET : float = -28.0

const HUMAN : int = 0
const AI : int = 1

const HUMAN_TINT : Color = Color(1.0, 1.0, 1.0, 1.0)   # sprite as-is (yellow → topaz)
const AI_TINT : Color = Color(1.0, 0.30, 0.30, 1.0)    # red modulate over yellow → ruby
const STACK_LABEL_COLOR : Color = Palette.WOOD_PIVOT

@onready var _sprite : AnimatedSprite2D = %AnimatedSprite2D

# State managed by the Board.
var next_switch_row : int = 0
## A coin only needs to SPIN while it's falling. Resting coins accumulate over a round (up to the 16 scoring
## slots), and a yard of continuously-animating AnimatedSprite2D was the gem-drop jitter on mobile — so freeze the
## spin on rest, resume it if the coin is launched back into play (Troy 2026-06-13, the mobile perf pass).
var resting : bool = false :
	set(value):
		if resting == value:
			return
		resting = value
		if is_instance_valid(_sprite):
			if value:
				_sprite.stop()
			else:
				_sprite.play(&"spin")
var owner_player : int = HUMAN :
	set(value):
		owner_player = value
		_apply_tint()
var size : int = 1 :
	set(value):
		size = value
		queue_redraw()


func _ready() -> void:

	_apply_tint()
	if _sprite == null:
		return
	if resting:
		_sprite.stop()   # honour a resting state set before the sprite existed (no needless spin)
		return
	# Stagger frame so a row of freshly-spawned gems doesn't all spin in
	# unison.
	if _sprite.sprite_frames:
		var frame_count : int = _sprite.sprite_frames.get_frame_count(&"spin")
		if frame_count > 0:
			_sprite.frame = randi() % frame_count


func _apply_tint() -> void:

	if _sprite == null:
		_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if _sprite == null:
			return
	_sprite.modulate = HUMAN_TINT if owner_player == HUMAN else AI_TINT


func _draw() -> void:

	if size <= 1:
		return
	var font : Font = ThemeDB.fallback_font
	var label : String = "x%d" % size
	var w : float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14).x
	draw_string(font, Vector2(-w * 0.5, STACK_LABEL_OFFSET), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, STACK_LABEL_COLOR)
