## RomanceVowModal — the deterministic Sweetheart VOW (Troy's "Sweethearts"). The one irreversible romance beat
## is a clean PLAYER CONFIRM, NEVER an AI call — so a stray [[SMITTEN]] tag can never marry you, and the whole
## thing works with the proxy offline. Opened from an NPC's radial "Propose" once you're Smitten + Confidant.
## Monogamous: if you already have a Sweetheart, confirming leaves them. On yes → PlayerState.become_sweetheart.
## Extends the shared [Modal] (dim + centred panel + ESC + pop-in).
class_name RomanceVowModal
extends Modal


const GROUP : StringName = &"romance_vow"

var _npc_name : String = ""
var _npc_color : Color = Color(0.78, 0.5, 0.66, 1.0)
var _done : bool = false


static func open(host: Node, npc_name: String, color: Color) -> void:

	if host == null or host.get_tree() == null or npc_name.is_empty():
		return
	if host.get_tree().get_first_node_in_group(GROUP) != null:
		return
	var m : RomanceVowModal = RomanceVowModal.new()
	m._npc_name = npc_name
	m._npc_color = color
	host.get_tree().root.add_child(m)


func _modal_group() -> StringName:
	return GROUP

func _modal_size() -> Vector2:
	return Vector2(460.0, 300.0)


func _build_content() -> void:

	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_render_prompt()


func _render_prompt() -> void:

	for c in _content.get_children():
		c.queue_free()
	_add_title("Sweethearts?")
	var msg : String = "Give your heart to %s — and ask for theirs?" % _npc_name
	var existing : String = PlayerState.current_sweetheart()
	if existing != "" and existing != _npc_name:
		msg += "\n\nYou'd be leaving %s for them." % existing
	_add_body(msg)
	var row : HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	var yes : Button = _make_button("Aye — be mine", Color(1.0, 0.72, 0.82))
	yes.pressed.connect(_on_yes)
	row.add_child(yes)
	var no : Button = _make_button("Not yet", Color(0.86, 0.86, 0.86))
	no.pressed.connect(_close)
	row.add_child(no)
	_content.add_child(row)


func _on_yes() -> void:

	if _done:
		return
	# become_sweetheart now leaves any existing Sweetheart ATOMICALLY (only once the vow gate passes), so a
	# failed vow can never strand the player single — no pre-emptive break_up here.
	if not PlayerState.become_sweetheart(_npc_name):
		_render_prompt()   # rapport slipped below the vow gate between opening + confirming — bail gracefully
		return
	_done = true
	_show_result()


func _show_result() -> void:

	for c in _content.get_children():
		c.queue_free()
	_add_title("Sweethearts")
	_add_body("You and %s are sweethearts now.\nThey'll greet you with an open heart from here on." % _npc_name)
	var row : HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ok : Button = _make_button("Done", _npc_color.lightened(0.4))
	ok.pressed.connect(_close)
	row.add_child(ok)
	_content.add_child(row)
	# A small celebratory beat (animate-everything) — a drawn heart that swells in between title + text.
	# SIZE_SHRINK_CENTER is load-bearing: in a VBox a bare Control expands to FULL WIDTH, and the heart drew
	# as two giant lobes swallowing the modal (caught by the screenshot harness 2026-06-11).
	var heart : RomanceHeart = RomanceHeart.new()
	heart.color = Color(1.0, 0.45, 0.6, 1.0)
	heart.custom_minimum_size = Vector2(64, 64)
	heart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	heart.scale = Vector2(0.2, 0.2)
	heart.pivot_offset = Vector2(32, 32)
	_content.add_child(heart)
	_content.move_child(heart, 1)
	var t : Tween = create_tween()
	t.tween_property(heart, "scale", Vector2(1.15, 1.15), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(heart, "scale", Vector2.ONE, 0.14)


# --- small build helpers ----------------------------------------------

func _add_title(text: String) -> void:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", Color(1.0, 0.74, 0.82, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(l)


func _add_body(text: String) -> void:

	var l : Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(0.94, 0.88, 0.78, 1.0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(380.0, 0.0)
	_content.add_child(l)


func _make_button(text: String, font_color: Color) -> Button:

	var b : Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", font_color)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 2)
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var bg : Color = Color(0.26, 0.12, 0.18, 0.96)
		if state == "hover":
			bg = bg.lightened(0.12)
		elif state == "pressed":
			bg = bg.darkened(0.12)
		s.bg_color = bg
		s.border_color = Color(0.86, 0.5, 0.62, 1.0)
		s.set_border_width_all(2)
		s.set_corner_radius_all(8)
		s.content_margin_left = 14
		s.content_margin_right = 14
		s.content_margin_top = 7
		s.content_margin_bottom = 7
		b.add_theme_stylebox_override(state, s)
	return b


## A tiny procedural heart (placeholder-first — no art asset): two lobe circles + a triangle for the point.
class RomanceHeart extends Control:

	var color : Color = Color(1.0, 0.45, 0.6, 1.0)

	func _draw() -> void:
		# Measure off the SMALLER dimension so the heart stays a heart whatever box it lands in.
		var d : float = minf(size.x, size.y)
		var cx : float = size.x * 0.5
		var r : float = d * 0.27
		var ly : float = d * 0.30            # lobe centre height
		draw_circle(Vector2(cx - r, ly), r, color)   # left lobe
		draw_circle(Vector2(cx + r, ly), r, color)   # right lobe
		# Bottom point: a triangle from just below the lobes' outer tangents down to the tip.
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - r * 1.96, ly + r * 0.2),
			Vector2(cx + r * 1.96, ly + r * 0.2),
			Vector2(cx, d * 0.95)]), color)
