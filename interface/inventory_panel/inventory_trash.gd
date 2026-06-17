## A TRASH drop-target in the backpack — DRAG any item onto it to throw it away (e.g. a redundant door key, whose
## door stays unlocked for good without it). Native Godot drag-drop, mirroring [InventorySlot]. (Troy 2026-06-17.)
class_name InventoryTrash
extends Control


const SIZE : float = 52.0


func _ready() -> void:

	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Drag an item here to throw it away"


func _can_drop_data(_at: Vector2, data: Variant) -> bool:

	return data is Dictionary and String((data as Dictionary).get("kind", "")) == "item"


func _drop_data(_at: Vector2, data: Variant) -> void:

	if data is Dictionary and String((data as Dictionary).get("kind", "")) == "item":
		PlayerState.discard_inventory(int(data["from"]), int(data.get("amount", -1)))
		Audio.play_sfx("toss")
	queue_redraw()


func _draw() -> void:

	var w : float = SIZE
	# Slot backing — matches the walnut inventory cells.
	draw_rect(Rect2(0.0, 0.0, w, w), Color(0.16, 0.12, 0.09, 0.85))
	draw_rect(Rect2(0.0, 0.0, w, w), Color(0.5, 0.36, 0.20, 0.9), false, 1.5)
	# A little grey trash can.
	var cx : float = w * 0.5
	var top : float = w * 0.36
	var bot : float = w * 0.80
	var ht : float = w * 0.19
	var hb : float = w * 0.14
	var body : PackedVector2Array = PackedVector2Array([
		Vector2(cx - ht, top), Vector2(cx + ht, top), Vector2(cx + hb, bot), Vector2(cx - hb, bot)])
	draw_colored_polygon(body, Color(0.60, 0.62, 0.66))
	draw_polyline(body + PackedVector2Array([Vector2(cx - ht, top)]), Color(0.28, 0.29, 0.32), 1.4)
	# Lid + handle.
	draw_rect(Rect2(cx - ht - 2.0, top - 5.0, (ht + 2.0) * 2.0, 4.0), Color(0.52, 0.54, 0.58))
	draw_rect(Rect2(cx - 4.0, top - 9.0, 8.0, 4.0), Color(0.52, 0.54, 0.58))
	# Vertical ribs.
	for k in [-1.0, 0.0, 1.0]:
		draw_line(Vector2(cx + k * hb * 0.55, top + 3.0), Vector2(cx + k * hb * 0.8, bot - 2.0), Color(0.40, 0.42, 0.45), 1.0)
