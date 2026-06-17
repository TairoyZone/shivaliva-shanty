## PauseMenu — ESC in the walkable world opens this: it PAUSES the game and offers Resume / Options /
## Quit to Title (the Options + Quit moved here OUT of the backpack, Troy 2026-06-07). Mirrors the
## JournalPanel modal pattern: a PROCESS_MODE_ALWAYS CanvasLayer that pauses the tree and owns its own
## ESC-to-resume, added to the root via PauseMenu.open(host) (won't stack). Built procedurally
## (placeholder-first). The HUD drives opening; closing whatever's already open takes priority over it.
class_name PauseMenu
extends Modal

const GROUP : StringName = &"pause_menu"


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


func _build_content() -> void:

	var title : Label = Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 32)
	UiStyle.apply_title(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)

	var spacer : Control = Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 8.0)
	_content.add_child(spacer)

	_content.add_child(_make_button("Resume", Palette.POSITIVE, _close))
	_content.add_child(_make_button("Options", Palette.ACCENT, func() -> void: OptionsPanel.open(self)))
	_content.add_child(_make_button("Save & Quit", Palette.DANGER, _on_quit_to_title))

	var hint : Label = Label.new()
	hint.text = "Tap Resume to continue" if TouchEnv.is_touch() else "Esc to resume"
	hint.add_theme_font_size_override("font_size", 14)
	UiStyle.apply_muted(hint)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(hint)


func _make_button(text: String, fg: Color, action: Callable) -> Button:

	var b : Button = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	UiStyle.style_button(b, fg)   # themed 3-state states + label color + ink outline (one call)
	b.pressed.connect(action)
	return b


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
	PlayerState.save_session()   # explicit write so "Save & Quit" is literally true (autosave already covers it)
	_was_paused = false
	get_tree().paused = false
	queue_free()   # root-parented → the scene swap won't reap it; remove it so it can't linger over the title
	get_tree().change_scene_to_file("res://main.tscn")
