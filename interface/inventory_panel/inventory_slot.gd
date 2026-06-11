## ONE backpack cell with native Godot drag-and-drop. Uses the reliable VIRTUAL-METHOD pattern
## (_get_drag_data / _can_drop_data / _drop_data on the dragged control itself) — the earlier
## set_drag_forwarding approach silently never started a drag. Holds its slot index + a back-ref to the
## [InventoryPanel] (for the shared icon/preview helpers); the move routes through PlayerState.move_inventory,
## which re-emits inventory_changed so the panel rebuilds. (Troy 2026-06-11.)
class_name InventorySlot
extends Panel


var slot_index : int = -1
var inv_panel : InventoryPanel = null


# Begin a drag: pick up this slot's stack (hold SHIFT to split off half). Returns null on an empty slot, so
# empty slots are drop targets only — never a drag source. Returning non-null is what STARTS the drag.
func _get_drag_data(_at: Vector2) -> Variant:

	if inv_panel == null or slot_index < 0 or slot_index >= PlayerState.inventory.size():
		return null
	var slot : Dictionary = PlayerState.inventory[slot_index]
	if slot.is_empty():
		return null
	var n : int = int(slot["count"])
	var amount : int = -1   # whole stack
	if n > 1 and Input.is_key_pressed(KEY_SHIFT):
		@warning_ignore("integer_division")
		amount = n / 2       # SHIFT = split off half
	set_drag_preview(inv_panel.make_drag_preview(String(slot["id"]), n if amount < 0 else amount))
	return {"kind": "item", "from": slot_index, "amount": amount}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:

	return data is Dictionary and String((data as Dictionary).get("kind", "")) == "item"


# Drop onto this slot: EMPTY → place; SAME item → merge to cap (leftover stays); DIFFERENT → swap. All the
# rules live in PlayerState.move_inventory.
func _drop_data(_at: Vector2, data: Variant) -> void:

	if data is Dictionary and String((data as Dictionary).get("kind", "")) == "item":
		PlayerState.move_inventory(int(data["from"]), slot_index, int(data.get("amount", -1)))
