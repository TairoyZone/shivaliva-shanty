## SpeechBubble — a single line of speech that floats above a character inside a rounded bg BUBBLE
## (YPP-style, see [[chatbox-comms-reference]]) and fades. Add it: SpeechBubble.say(node, "Hello!").
## Used by NPC Talk + the player's chat. A child of the node, so it rides their position; the bubble
## sizes to the text (snug for short lines, wraps long ones); self-fades + frees. Placeholder-first.
class_name SpeechBubble
extends Node2D

const MAX_WIDTH : float = 250.0
const FONT_SIZE : int = 17

var _text : String = ""


static func say(npc: Node2D, text: String, y: float = -118.0) -> SpeechBubble:

	if npc == null or text.is_empty():
		return null
	# A node can override the default float height (e.g. the poker SEAT's origin is its
	# panel CENTRE, not an NPC's feet, so its bubble sits just above the panel).
	var custom : Variant = npc.get("bubble_y")
	if custom != null:
		y = float(custom)
	var b : SpeechBubble = SpeechBubble.new()
	b._text = text
	b.position = Vector2(0.0, y)
	npc.add_child(b)
	return b


func _ready() -> void:

	z_index = 100
	# Bigger + wider on touch — the 17px bubble reads tiny on a phone (Troy 2026-06-13).
	var fs : int = 25 if TouchEnv.is_touch() else FONT_SIZE
	var maxw : float = 330.0 if TouchEnv.is_touch() else MAX_WIDTH
	var label : Label = Label.new()
	label.text = _text
	label.add_theme_font_size_override("font_size", fs)
	label.add_theme_color_override("font_color", Color(0.99, 0.97, 0.9, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.06, 0.9))
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Size to the text, up to a max — short lines get a snug bubble, long ones wrap.
	var font : Font = label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var natural : float = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	label.custom_minimum_size = Vector2(minf(natural + 2.0, maxw), 0.0)

	var pill : PanelContainer = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _bubble_style())
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(label)
	add_child(pill)

	# Centre the bubble above the anchor once it's laid out (its size depends on the text). Hidden for the
	# one layout frame so it never flashes at the wrong spot.
	scale = Vector2(0.6, 0.6)
	modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(self) or not is_instance_valid(pill):
		return
	pill.position = Vector2(-pill.size.x * 0.5, -pill.size.y)
	modulate.a = 1.0
	# Pop in, hold, fade, free. The hold scales with the line LENGTH so longer (chattier AI) replies stay up
	# long enough to read, while one-liners still clear quickly.
	var hold : float = clampf(_text.length() * 0.05, 3.0, 9.0)
	var tw : Tween = create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(queue_free)


# Rounded dark bubble behind the line, matching the recent-log pills — reads over a busy world.
func _bubble_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.09, 0.13, 0.88)
	s.border_color = Color(0.62, 0.46, 0.20, 0.55)
	s.set_border_width_all(1)
	s.set_corner_radius_all(9)
	s.content_margin_left = 11.0
	s.content_margin_right = 11.0
	s.content_margin_top = 5.0
	s.content_margin_bottom = 5.0
	return s
