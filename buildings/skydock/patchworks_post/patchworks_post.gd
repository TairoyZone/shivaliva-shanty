## THE PATCHWORKS POST — a hull-repair workbench at the Skydock. Press E to play the Patchworks and
## MEND your ship's holes (every ~3 cleared lines seals one; see [PatchworksScene]). Gated on owning a
## ship; the tooltip reports the live hull state. Inherits the proximity / tooltip / scene-change wiring
## from [Puzzle]; this owns the workbench visual + the hull-aware tooltip. The PORT-repair half of the
## sinkable-ship loop (the in-voyage deck-hybrid station comes later). See [[ship-condition-research]] / [[patchworks-spec]].
@tool
class_name PatchworksPost
extends Puzzle


const COLOR_LEG : Color = Color(0.30, 0.20, 0.11, 1.0)
const COLOR_TOP : Color = Color(0.46, 0.32, 0.18, 1.0)
const COLOR_TOP_EDGE : Color = Color(0.24, 0.16, 0.08, 1.0)
const COLOR_PLANK : Color = Color(0.62, 0.46, 0.27, 1.0)
const COLOR_PLANK_EDGE : Color = Color(0.40, 0.28, 0.15, 1.0)
const COLOR_BREACH : Color = Color(0.10, 0.09, 0.18, 1.0)
const COLOR_NAIL : Color = Color(0.80, 0.82, 0.86, 1.0)
const COLOR_MALLET_HEAD : Color = Color(0.52, 0.36, 0.20, 1.0)
const COLOR_MALLET_HANDLE : Color = Color(0.66, 0.50, 0.30, 1.0)


func interact() -> void:

	if Engine.is_editor_hint():
		return
	if not PlayerState.has_ship():
		return   # the tooltip explains — no ship to mend yet
	if puzzle_scene.is_empty():
		return
	PlayerState.request_spawn_at_anchor(name)
	get_tree().change_scene_to_file(puzzle_scene)


func _refresh_tooltip_text() -> void:

	if _tooltip == null:
		return
	if not PlayerState.has_ship():
		_tooltip.text = "Get a ship first"
		_tooltip.modulate = Color(0.98, 0.62, 0.42, 1.0)
		return
	var holes : int = PlayerState.ship_open_holes()
	if holes <= 0:
		_tooltip.text = "Mend the Hull — she's sound  [Click]"
		_tooltip.modulate = Color(0.72, 0.95, 0.76, 1.0)
	else:
		_tooltip.text = "Mend the Hull — %d hole%s  [Click]" % [holes, "" if holes == 1 else "s"]
		_tooltip.modulate = Color(0.98, 0.78, 0.50, 1.0)


func _draw() -> void:

	var hw : float = 42.0
	var leg_h : float = 38.0
	var top_th : float = 10.0
	# Two legs.
	draw_rect(Rect2(-hw + 5.0, -leg_h, 7.0, leg_h), COLOR_LEG)
	draw_rect(Rect2(hw - 12.0, -leg_h, 7.0, leg_h), COLOR_LEG)
	# Tabletop.
	var top : Rect2 = Rect2(-hw, -leg_h - top_th, hw * 2.0, top_th)
	draw_rect(top, COLOR_TOP)
	draw_rect(top, COLOR_TOP_EDGE, false, 1.5)
	# The hull panel being mended, sitting on the bench — planks with ONE missing (a breach) so it
	# reads as "a repair in progress".
	var panel_w : float = 64.0
	var panel_h : float = 32.0
	var panel : Rect2 = Rect2(-panel_w * 0.5, -leg_h - top_th - panel_h, panel_w, panel_h)
	draw_rect(panel, COLOR_BREACH)
	var plank_h : float = panel_h / 4.0
	for i in 4:
		if i == 2:
			continue   # the missing plank — the breach shows through
		var pr : Rect2 = Rect2(panel.position.x, panel.position.y + float(i) * plank_h, panel_w, plank_h - 1.0)
		draw_rect(pr, COLOR_PLANK)
		draw_rect(pr, COLOR_PLANK_EDGE, false, 1.0)
	draw_circle(panel.position + Vector2(8.0, plank_h * 0.5), 1.8, COLOR_NAIL)
	draw_circle(panel.position + Vector2(panel_w - 8.0, plank_h * 0.5), 1.8, COLOR_NAIL)
	# A mallet leaning against the bench (handle + a blocky head).
	var grip : Vector2 = Vector2(hw - 8.0, -8.0)
	var head_c : Vector2 = Vector2(hw + 9.0, -leg_h - 6.0)
	draw_line(grip, head_c, COLOR_MALLET_HANDLE, 3.5)
	draw_rect(Rect2(head_c.x - 6.0, head_c.y - 7.0, 13.0, 13.0), COLOR_MALLET_HEAD)
