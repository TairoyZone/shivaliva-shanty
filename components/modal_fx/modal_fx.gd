## ModalFx — appear/dismiss animation for the menu/modal family (pause · options · voyages · shoppe ·
## favor · intro). They don't share a base class (each clones the chrome), so this is a tiny STATIC helper
## rather than a base class: call [method appear] right after building, and route the close path through
## [method dismiss] so the panel scales + fades OUT before the real close (unpause / free / emit) runs —
## a modal appearing/vanishing is a state change, so it animates (never an instant pop, see
## [[animate-everything-principle]]). [method dismiss] is reentrancy-guarded by a meta flag so a button +
## the dim + ESC all calling close don't restart it. The tweens run on the panel, which is
## PROCESS_MODE_ALWAYS via its modal parent, so they play even while the modal pauses the tree.
class_name ModalFx
extends RefCounted

const IN_TIME : float = 0.16
const OUT_TIME : float = 0.12
const FROM_SCALE : float = 0.92          # the scale a panel grows from / shrinks to
const _CLOSING : StringName = &"_modalfx_closing"


## Fade the dim + pop the panel IN. Waits one frame so the panel is laid out (size known → it scales from
## its own centre, not the top-left corner). Safe no-op on a null/freed panel.
static func appear(panel: Control, dim: CanvasItem = null) -> void:

	if not is_instance_valid(panel) or panel.get_tree() == null:
		return
	_set_alpha(panel, 0.0)   # hide pre-await so there's no full-alpha flash before the tween starts
	if dim != null and is_instance_valid(dim):
		_set_alpha(dim, 0.0)
	await panel.get_tree().process_frame
	if not is_instance_valid(panel):
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE * FROM_SCALE
	var tw : Tween = panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE, IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, IN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if dim != null and is_instance_valid(dim):
		tw.tween_property(dim, "modulate:a", 1.0, IN_TIME)


## Scale + fade the panel OUT, then run [param finish] — the REAL close (unpause / queue_free / emit /
## scene-change). Guarded so a second close (button + dim + ESC) doesn't re-fire. If the panel is already
## gone, [param finish] runs immediately so nothing ever gets stuck open.
static func dismiss(layer: Node, panel: Control, dim: CanvasItem, finish: Callable) -> void:

	if layer == null or not is_instance_valid(layer):
		return
	if bool(layer.get_meta(_CLOSING, false)):
		return
	layer.set_meta(_CLOSING, true)
	if not is_instance_valid(panel) or panel.get_tree() == null:
		if finish.is_valid():
			finish.call()
		return
	panel.pivot_offset = panel.size * 0.5
	var tw : Tween = panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2.ONE * FROM_SCALE, OUT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(panel, "modulate:a", 0.0, OUT_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if dim != null and is_instance_valid(dim):
		tw.tween_property(dim, "modulate:a", 0.0, OUT_TIME)
	tw.chain().tween_callback(finish)


# Set a CanvasItem's alpha without disturbing its RGB (modulate is a value type — can't write .a in place).
static func _set_alpha(ci: CanvasItem, a: float) -> void:

	var c : Color = ci.modulate
	c.a = a
	ci.modulate = c
