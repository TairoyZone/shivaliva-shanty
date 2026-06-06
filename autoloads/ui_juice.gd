## UiJuice — system-wide button FEEL. Listens on the tree's node_added and gives every BaseButton a subtle
## scale on HOVER (up) and PRESS (down) — one hook, so every button (code- or scene-built) feels alive and
## new ones inherit it for free. Pairs with the Audio click hook (which handles the sound). PROCESS_MODE_ALWAYS
## so paused panels still react. Re-entrancy-safe — kills the prior tween before a new one. See [[godot-borrow-todo]].
extends Node

const HOVER_SCALE : float = 1.06
const PRESS_SCALE : float = 0.94


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS
	if get_tree() != null:
		get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:

	if node is BaseButton and not node.has_meta("_uijuice"):
		var b : BaseButton = node as BaseButton
		b.set_meta("_uijuice", true)
		b.mouse_entered.connect(_scale_to.bind(b, HOVER_SCALE, 0.12))
		b.mouse_exited.connect(_scale_to.bind(b, 1.0, 0.12))
		b.button_down.connect(_scale_to.bind(b, PRESS_SCALE, 0.06))
		b.button_up.connect(_scale_to.bind(b, HOVER_SCALE, 0.10))


func _scale_to(b: Control, s: float, dur: float) -> void:

	if not is_instance_valid(b):
		return
	b.pivot_offset = b.size * 0.5   # centre the pivot now that the button is laid out
	if b.has_meta("_juice_tw"):     # has_meta first — get_meta(name, null) errors on a missing key
		var prev : Variant = b.get_meta("_juice_tw")
		if prev is Tween and (prev as Tween).is_valid():
			(prev as Tween).kill()
	var tw : Tween = b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * s, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	b.set_meta("_juice_tw", tw)
