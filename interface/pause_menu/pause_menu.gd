## PauseMenu — ESC in the walkable world opens this: it PAUSES the game and offers Resume / Options /
## Quit to Title (the Options + Quit moved here OUT of the backpack, Troy 2026-06-07). Mirrors the
## JournalPanel modal pattern: a PROCESS_MODE_ALWAYS CanvasLayer that pauses the tree and owns its own
## ESC-to-resume, added to the root via PauseMenu.open(host) (won't stack). Built procedurally
## (placeholder-first). The HUD drives opening; closing whatever's already open takes priority over it.
class_name PauseMenu
extends Modal

const GROUP : StringName = &"pause_menu"
const GOLD : Color = Color(0.96, 0.86, 0.5, 1.0)


## Open the pause menu (added to the tree root + pauses). No-op if one is already showing.
static func open(host: Node) -> void:

	if host == null or host.get_tree() == null:
		return
	if host.get_tree().get_first_node_in_group(GROUP) != null:
		return
	host.get_tree().root.add_child(PauseMenu.new())


# --- Modal config -----------------------------------------------------

func _modal_layer() -> int:
	return 80   # above the HUD (10) + chat (12), below the OptionsPanel (90) it can open

func _modal_group() -> StringName:
	return GROUP

func _modal_size() -> Vector2:
	return Vector2(380.0, 340.0)

func _modal_content_separation() -> int:
	return 14

func _modal_dim_alpha() -> float:
	return 0.6

func _modal_esc_to_close() -> bool:
	return false   # PauseMenu handles ESC itself (_unhandled_input) so the Options panel can stack over it

func _modal_panel_style() -> StyleBoxFlat:
	return _panel_style()


func _build_content() -> void:

	var title : Label = Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	var spacer : Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 8.0)
	_content.add_child(spacer)

	_content.add_child(_make_button("Resume", Color(0.86, 0.94, 0.82, 1.0), Color(0.16, 0.22, 0.14, 0.94),
		Color(0.46, 0.66, 0.36, 1.0), _close))
	_content.add_child(_make_button("Options", Color(0.80, 0.86, 0.96, 1.0), Color(0.14, 0.13, 0.20, 0.94),
		Color(0.40, 0.42, 0.58, 1.0), func() -> void: OptionsPanel.open(self)))
	_content.add_child(_make_button("Quit to Title", Color(0.92, 0.72, 0.52, 1.0), Color(0.20, 0.12, 0.07, 0.94),
		Color(0.55, 0.38, 0.18, 1.0), _on_quit_to_title))

	var hint : Label = Label.new()
	hint.text = "Esc to resume"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.8, 0.68, 0.42, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(hint)


func _make_button(text: String, fg: Color, bg: Color, border: Color, action: Callable) -> Button:

	var b : Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	b.add_theme_constant_override("outline_size", 3)
	# 3-state styling so the button responds to hover/press (was normal-only — inert, no affordance).
	for state in ["normal", "hover", "pressed"]:
		var s : StyleBoxFlat = StyleBoxFlat.new()
		var sb : Color = bg
		if state == "hover":
			sb = bg.lightened(0.10)
		elif state == "pressed":
			sb = bg.darkened(0.12)
		s.bg_color = sb
		s.border_color = border
		s.set_border_width_all(2)
		s.set_corner_radius_all(8)   # the modal-button family radius (options/voyages/shoppe/favor all 8)
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 9
		s.content_margin_bottom = 9
		b.add_theme_stylebox_override(state, s)
	b.pressed.connect(action)
	return b


func _panel_style() -> StyleBoxFlat:

	var s : StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.11, 0.06, 0.98)
	s.border_color = Palette.BRASS_FRAME   # the ONE brass source of truth (was a hand-typed duplicate)
	s.set_border_width_all(3)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(26)
	return s


func _unhandled_input(event: InputEvent) -> void:

	if event.is_action_pressed("ui_cancel"):
		# If the Options sub-panel is up over us, let it be (it closes via its own button/dim) — don't
		# half-close the stack.
		if get_tree() != null and get_tree().get_first_node_in_group(&"options_panel") != null:
			return
		_close()
		var vp : Viewport = get_viewport()
		if vp != null:
			vp.set_input_as_handled()


# Return to the title — PlayerState autosaves on every change + records last_scene, so main.tscn resumes
# the player here on next launch. clear_voyage() drops any in-flight pillage (transient, not saved).
# This modal lives under the tree ROOT (see open()), so a scene change does NOT free it — we must drop it
# ourselves or it strands on top of the title. _was_paused is forced false so _exit_tree can't re-pause the
# title we're heading to.
func _on_quit_to_title() -> void:

	if get_tree() == null:
		return
	PlayerState.clear_voyage()
	_was_paused = false
	get_tree().paused = false
	queue_free()   # root-parented → the scene swap won't reap it; remove it so it can't linger over the title
	get_tree().change_scene_to_file("res://main.tscn")
