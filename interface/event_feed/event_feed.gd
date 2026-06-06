## THE EVENT FEED — a small always-on log overlay (YPP-chat-style) on the lower-left. Listens to
## [PlayerState.event_logged] and streams recent one-line events — plunder + your pool, coin in/out
## with its reason, hull holes — each lingering then fading. Unlike the hideable HUD this is autoloaded
## and shows EVERYWHERE, so you watch the booty land live DURING the voyage's Loft + boarding (where
## the HUD is hidden). Idle = empty = invisible (no clutter in non-voyage puzzles). See [[voyage-loop-research]].
extends CanvasLayer


## Lines shown at once before the oldest is dropped.
const MAX_LINES : int = 6
## Seconds a line holds at full opacity before it fades out.
const LINGER : float = 5.0
const FADE : float = 1.2

var _box : VBoxContainer


func _ready() -> void:

	layer = 15   # above gameplay + the hidden HUD (10), below the Leave button / modals (20+)
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep lines fading even under a tree-pausing modal (the sink card)
	_box = VBoxContainer.new()
	# Anchor to the BOTTOM-LEFT corner and grow toward BEGIN so new lines stack UPWARD and the log
	# tucks into the lower-left like a proper chat feed (was an un-anchored VBox floating mid-left).
	_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_left = 18.0
	_box.offset_bottom = -52.0   # sit above the chat bar, which lives at the very bottom
	_box.add_theme_constant_override("separation", 3)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	PlayerState.event_logged.connect(_on_event_logged)


func _on_event_logged(text: String, color: Color) -> void:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(l)
	# Drop the oldest line(s) past the cap — remove_child is immediate (queue_free is deferred, so a
	# count-based loop on it would spin); the dropped label's bound tween auto-kills with it.
	while _box.get_child_count() > MAX_LINES:
		var oldest : Node = _box.get_child(0)
		_box.remove_child(oldest)
		oldest.queue_free()
	# Linger, then fade + free. Tween is bound to the LABEL (l.create_tween) so it dies with the line.
	var tw : Tween = l.create_tween()
	tw.tween_interval(LINGER)
	tw.tween_property(l, "modulate:a", 0.0, FADE)
	tw.tween_callback(l.queue_free)
