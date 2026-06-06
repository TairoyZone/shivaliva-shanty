## ClearBurst — a one-shot puff of shards at a cleared cell (a gem shatters / ore cracks / a line blasts).
## Uses CPUParticles2D so it's rock-solid on our GL Compatibility target (no GPU-particle caveats). Self-
## freeing. Spawn it where a piece clears — CAPTURE the position as a primitive BEFORE the piece frees
## (the await-after-free gotcha):
##   var p : Vector2 = stone.position
##   var b : ClearBurst = ClearBurst.make(tint); b.position = p; add_child(b)
## Placeholder-first; a tiny procedural white square is the shard, tinted per call. See [[godot-borrow-todo]]
## / [[await-after-free-gotcha]] / [[animate-everything-principle]].
class_name ClearBurst
extends CPUParticles2D

var _tint : Color = Color.WHITE
var _amount : int = 12
var _power : float = 1.0


static func make(tint: Color, amount: int = 12, power: float = 1.0) -> ClearBurst:

	var b : ClearBurst = ClearBurst.new()
	b._tint = tint
	b._amount = amount
	b._power = power
	return b


func _ready() -> void:

	# A tiny white square stands in for a shard — tinted by `color`, scaled + spun per particle.
	var img : Image = Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	texture = ImageTexture.create_from_image(img)

	one_shot = true
	explosiveness = 1.0          # all at once = a burst, not a stream
	amount = maxi(1, _amount)
	lifetime = 0.55
	direction = Vector2(0.0, -1.0)
	spread = 180.0               # fly every direction
	gravity = Vector2(0.0, 520.0)   # shards fall
	initial_velocity_min = 80.0 * _power
	initial_velocity_max = 230.0 * _power
	angular_velocity_min = -320.0
	angular_velocity_max = 320.0
	scale_amount_min = 0.5
	scale_amount_max = 1.3
	damping_min = 30.0
	damping_max = 70.0
	color = _tint
	var ramp : Gradient = Gradient.new()
	ramp.set_color(0, Color(_tint.r, _tint.g, _tint.b, 1.0))
	ramp.set_color(1, Color(_tint.r, _tint.g, _tint.b, 0.0))   # fade out over the lifetime
	color_ramp = ramp

	emitting = true
	# Self-free once the burst has played out.
	var t : Tween = create_tween()
	t.tween_interval(lifetime + 0.25)
	t.tween_callback(queue_free)
