## Juice — a tiny STATIC tween library (no state, never instanced). Bakes our "animate everything" rule into
## one-liners: a state change SHOWS as motion instead of popping in, and the same springy feel is reused
## instead of re-rolled per file. Every func RETURNS the Tween (await it, or chain more `.tween_*` on it).
## Mirrors the gem demo's elastic appear + parallel collect-and-free (godot-4-features tweens/gem.gd).
##
## Nodes should scale around their CENTRE: Node2D scales about its own origin already; for a Control,
## pop_in/bump/pulse centre its `pivot_offset` for you (best-effort — only once it has a size). Capture any
## data off a node BEFORE collect_fly (it frees itself). See [[godot-borrow-todo]] / [[animate-everything-principle]].
class_name Juice
extends RefCounted


## A springy ENTRANCE — scale ZERO → ONE (elastic), optionally spinning upright from [param spin] radians.
## For piece spawns, toasts, result cards, intro panels — anything that would otherwise pop into existence.
static func pop_in(node: CanvasItem, dur: float = 0.45, spin: float = 0.0) -> Tween:

	_center_pivot(node)
	var tw : Tween = node.create_tween().set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ONE, dur).from(Vector2.ZERO).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if spin != 0.0:
		tw.tween_property(node, "rotation", 0.0, dur).from(spin).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tw


## A cleared piece FLIES OFF and frees itself — parallel scale→ZERO + a full spin + drift to
## [param target_global], then queue_free. For gems/ore/coins streaming to the purse or the score pill.
## ⚠️ Capture any scoring data as primitives BEFORE calling — the node is gone when this finishes.
static func collect_fly(node: Node2D, target_global: Vector2, dur: float = 0.7) -> Tween:

	var tw : Tween = node.create_tween().set_parallel(true)
	tw.tween_property(node, "scale", Vector2.ZERO, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "rotation", node.rotation + TAU, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "global_position", target_global, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.finished.connect(node.queue_free)
	return tw


## A quick "I just changed" BUMP — scale up then settle back to ONE. For a value tick, a button press, the
## backpack bag-bump, a freshly-banked reward.
static func bump(node: CanvasItem, amount: float = 1.18, dur: float = 0.14) -> Tween:

	_center_pivot(node)
	var tw : Tween = node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * amount, dur * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, dur * 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tw


## A looping BREATHE — cheap aliveness / a "look here" hint. Store the returned Tween and `kill()` to stop.
static func pulse(node: CanvasItem, amount: float = 1.08, dur: float = 0.7) -> Tween:

	_center_pivot(node)
	var tw : Tween = node.create_tween().set_loops()
	tw.tween_property(node, "scale", Vector2.ONE * amount, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


## A gentle looping vertical BOB — idle "aliveness" for NPCs, props, a hovering ship. Tweens position.y
## ±[param height] around where the node sits NOW. Store the returned Tween + `kill()` to stop.
static func bob(node: Node2D, height: float = 3.0, dur: float = 1.8) -> Tween:

	var base_y : float = node.position.y
	var tw : Tween = node.create_tween().set_loops()
	tw.tween_property(node, "position:y", base_y - height, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "position:y", base_y, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


## Fade to transparent, then FREE. For a dismissed toast/panel that shouldn't just vanish.
static func fade_out_free(node: CanvasItem, dur: float = 0.3) -> Tween:

	var tw : Tween = node.create_tween()
	tw.tween_property(node, "modulate:a", 0.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.finished.connect(node.queue_free)
	return tw


## Fade UP from transparent (sets alpha 0 first). For a panel/label appearing.
static func fade_in(node: CanvasItem, dur: float = 0.3) -> Tween:

	var c : Color = node.modulate
	c.a = 0.0
	node.modulate = c
	var tw : Tween = node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tw


# Centre a Control's scale pivot so pop_in/bump/pulse grow from the middle, not the top-left corner. Node2D
# scales about its own origin already, so this only touches a Control that has been laid out (size > 0).
static func _center_pivot(node: CanvasItem) -> void:

	if node is Control and (node as Control).size != Vector2.ZERO:
		(node as Control).pivot_offset = (node as Control).size * 0.5
