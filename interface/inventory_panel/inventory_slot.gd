## ONE backpack cell with native Godot drag-and-drop (the reliable virtual-method pattern). Holds its slot
## index + a back-ref to the [InventoryPanel] for the shared preview helper; the move routes through
## PlayerState.move_inventory, which re-emits inventory_changed so the panel rebuilds. (Troy 2026-06-11.)
class_name InventorySlot
extends Panel


var slot_index : int = -1
var inv_panel : InventoryPanel = null


func _ready() -> void:
	# CRITICAL: the item ICON (WoodIcon/OreIcon) sets mouse_filter = STOP in its OWN _ready (it shows tooltips
	# elsewhere), which would steal the drag — you could only grab the bare 8px frame, not the icon. OUR _ready
	# runs AFTER the children's, so force every descendant mouse-transparent: now the whole cell is draggable.
	pass_mouse_through(self)


## Make every Control descendant of [param node] ignore the mouse, so a parent cell owns the whole drag area.
## Static so [WeaponSlot] reuses it. Run from _ready (after children's _ready) or it gets overridden.
static func pass_mouse_through(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		pass_mouse_through(child)


# Begin a drag: pick up this slot's stack (hold SHIFT to split off half). Returns null on an empty slot, so
# empty slots are drop targets only. Returning non-null is what STARTS the drag.
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

	if not (data is Dictionary):
		return false
	var kind : String = String((data as Dictionary).get("kind", ""))
	# An item move, OR the EQUIPPED weapon dropped here to unequip it back into the bag.
	return kind == "item" or (kind == "weapon" and String((data as Dictionary).get("action", "")) == "unequip")


# Drop onto this slot: an item → EMPTY place / SAME merge / DIFFERENT swap (PlayerState.move_inventory); the
# equipped weapon → unequip back to bare fists (it already lives in owned_weapons).
func _drop_data(_at: Vector2, data: Variant) -> void:

	if not (data is Dictionary):
		return
	var d : Dictionary = data
	var kind : String = String(d.get("kind", ""))
	if kind == "item":
		PlayerState.move_inventory(int(d["from"]), slot_index, int(d.get("amount", -1)))
	elif kind == "weapon" and String(d.get("action", "")) == "unequip":
		PlayerState.equip_weapon(SkirmishWeapon.DEFAULT_WEAPON)
