## A brief "READY? → GO!" lead-in for the versus boards. The instant a Skirmish scene loads it PAUSES
## the tree (freezing both boards + their AI the same frame the pieces spawn), flashes the controls so
## a first-timer isn't dropped into falling blocks blind, then UNPAUSES on GO! and fades out.
##
## Usage: `add_child(ReadyOverlay.new())` at the END of the match scene's _ready (after the boards are
## built). Self-frees. Belt-and-suspenders: it also unpauses in _exit_tree so it can never leak a pause.
class_name ReadyOverlay
extends CanvasLayer


## How long READY? holds (the boards stay frozen this whole time), then GO! + unfreeze.
const HOLD : float = 0.95
const FADE : float = 0.32

var _root : Control
var _title : Label


func _ready() -> void:

	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS   # run + animate while the tree is paused
	_build()
	if get_tree() != null:
		get_tree().paused = true
	_run()


func _build() -> void:

	var vp : Vector2 = get_viewport().get_visible_rect().size
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP   # swallow clicks during the beat
	_root.pivot_offset = vp * 0.5
	add_child(_root)

	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	_title = Label.new()
	_title.text = "READY?"
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_color_override("font_color", Color(0.99, 0.88, 0.42, 1.0))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_title.add_theme_constant_override("outline_size", 8)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size = Vector2(vp.x, 80.0)
	_title.position = Vector2(0.0, vp.y * 0.40 - 40.0)
	_root.add_child(_title)

	var hint : Label = Label.new()
	hint.text = "←  →   move        ↑   rotate        ↓ / Space   drop"
	hint.add_theme_font_size_override("font_size", 24)
	hint.add_theme_color_override("font_color", Color(0.90, 0.86, 0.72, 1.0))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("outline_size", 5)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(vp.x, 40.0)
	hint.position = Vector2(0.0, vp.y * 0.40 + 40.0)
	_root.add_child(hint)

	# A small pop-in so it doesn't just appear.
	_root.scale = Vector2(0.9, 0.9)
	var pop : Tween = create_tween()
	pop.tween_property(_root, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _run() -> void:

	await get_tree().create_timer(HOLD).timeout   # a process-always timer ticks while paused
	if not is_instance_valid(self):
		return
	if _title != null:
		_title.text = "GO!"
		_title.add_theme_color_override("font_color", Color(0.62, 1.0, 0.52, 1.0))
	if get_tree() != null:
		get_tree().paused = false   # unfreeze — the match begins
	var tw : Tween = create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(_root, "modulate:a", 0.0, FADE)
	tw.tween_callback(queue_free)


# Safety: if this overlay is ever freed without finishing (e.g. a scene change mid-beat), make sure the
# pause it set can't ride on into the next scene.
func _exit_tree() -> void:

	if get_tree() != null:
		get_tree().paused = false
