## ScreenFlash — a one-shot full-screen colour PUNCH for a combo / KO / sink. Self-contained + self-freeing,
## on a high CanvasLayer + process-always so it reads over any scene (even a paused result screen). Add it
## to the tree root so it survives the moment that spawned it:
##   get_tree().root.add_child(ScreenFlash.make(Color(1, 0.85, 0.4), 0.4))
## Tweens a full-rect ColorRect alpha 0 → peak → 0, then frees. Keep the peak modest so UI text reads
## through it. Placeholder-first; pure procedural. See [[godot-borrow-todo]] / [[animate-everything-principle]].
class_name ScreenFlash
extends CanvasLayer

var _color : Color = Color(1, 1, 1)
var _peak : float = 0.4
var _dur : float = 0.35


static func make(color: Color, peak: float = 0.4, dur: float = 0.35) -> ScreenFlash:

	var f : ScreenFlash = ScreenFlash.new()
	f._color = color
	f._peak = peak
	f._dur = dur
	return f


func _ready() -> void:

	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS   # a KO can flash over a paused result screen
	var rect : ColorRect = ColorRect.new()
	rect.color = Color(_color.r, _color.g, _color.b, 0.0)
	rect.size = get_viewport().get_visible_rect().size
	rect.position = Vector2.ZERO
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	var tw : Tween = create_tween()
	tw.tween_property(rect, "color:a", _peak, _dur * 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "color:a", 0.0, _dur * 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.finished.connect(queue_free)
