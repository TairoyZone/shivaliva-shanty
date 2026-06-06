## SpeechBubble — a single line of speech that floats above an NPC and fades (the YPP chat-bubble model,
## see [[Official:Communications]]) — replaces the old dialogue box for casual "Talk". Add it to the NPC:
##   SpeechBubble.say(npc, "This island is so peaceful...")
## A child of the NPC, so it rides their position; outlined for readability; self-fades + frees. A future
## chat box can render the same lines into a log. Placeholder-first. See [[godot-borrow-todo]].
class_name SpeechBubble
extends Node2D

const WIDTH : float = 230.0

var _text : String = ""


static func say(npc: Node2D, text: String, y: float = -118.0) -> void:

	if npc == null or text.is_empty():
		return
	var b : SpeechBubble = SpeechBubble.new()
	b._text = text
	b.position = Vector2(0.0, y)
	npc.add_child(b)


func _ready() -> void:

	z_index = 100
	var label : Label = Label.new()
	label.text = _text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.99, 0.97, 0.9, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.06, 0.95))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size = Vector2(WIDTH, 0.0)
	label.position = Vector2(-WIDTH * 0.5, 0.0)   # centre it over the NPC
	add_child(label)
	# Pop in, hold, fade, free (the bubble breathes — like a real chat line).
	scale = Vector2(0.6, 0.6)
	var tw : Tween = create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.6)
	tw.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(queue_free)
