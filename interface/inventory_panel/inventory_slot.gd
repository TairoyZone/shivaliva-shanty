## ONE backpack cell — items AND weapons, the same class (Troy 2026-06-11: "item class is item class in the
## inventory"). Native Godot drag-drop (the virtual-method pattern) to rearrange, PLUS double-click a WEAPON to
## equip it. Holds its slot index + a back-ref to the [InventoryPanel] for the drag preview; moves route
## through PlayerState.move_inventory, which re-emits inventory_changed so the panel rebuilds.
class_name InventorySlot
extends Panel


var slot_index : int = -1
var inv_panel : InventoryPanel = null


func _ready() -> void:
	# The item ICON sets mouse_filter = STOP in its OWN _ready (tooltips elsewhere), which would steal the drag
	# so only the bare frame is grabbable. OUR _ready runs AFTER the children's, so force every descendant
	# mouse-transparent: the whole cell (icon included) is then draggable AND double-clickable.
	pass_mouse_through(self)


## Make every Control descendant of [param node] ignore the mouse, so the cell owns the whole interaction area.
static func pass_mouse_through(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		pass_mouse_through(child)


# Double-click a WEAPON to equip it (double-click the equipped one to go back to bare fists). Single-click +
# drag are untouched — drag rearranges a weapon exactly like any other item.
func _gui_input(event: InputEvent) -> void:

	if not (event is InputEventMouseButton):
		return
	var mb : InputEventMouseButton = event
	if not (mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT):
		return
	if slot_index < 0 or slot_index >= PlayerState.inventory.size():
		return
	var slot : Dictionary = PlayerState.inventory[slot_index]
	if slot.is_empty():
		return
	var wid : String = String(slot["id"])
	if not PlayerState.is_weapon(wid):
		return
	PlayerState.equip_weapon(SkirmishWeapon.DEFAULT_WEAPON if PlayerState.equipped_weapon == wid else wid)
	accept_event()


# Begin a drag: pick up this slot's stack (hold SHIFT to split off half). Null on an empty slot (drop target
# only). Returning non-null is what STARTS the drag.
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


# Drop onto this slot: EMPTY → place; SAME item → merge to cap (leftover stays); DIFFERENT → swap. The rules
# (weapons included — a weapon is just an item) live in PlayerState.move_inventory.
func _drop_data(_at: Vector2, data: Variant) -> void:

	if data is Dictionary and String((data as Dictionary).get("kind", "")) == "item":
		PlayerState.move_inventory(int(data["from"]), slot_index, int(data.get("amount", -1)))
