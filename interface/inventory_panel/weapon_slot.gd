## A weapon cell with native drag-drop, mirroring [InventorySlot] (Troy 2026-06-11: "the sword should behave
## the same"). Two modes: a BACKPACK weapon (drag it onto the equip slot to equip) or the EQUIP slot itself (a
## drop target for a weapon → equip; drag it out onto the bag to unequip). Click still works — the panel's
## gui_input fires on RELEASE, so starting a drag never also clicks. Routes through PlayerState.equip_weapon.
class_name WeaponSlot
extends Panel


var weapon_id : String = ""
var is_equip_slot : bool = false


func _ready() -> void:
	# Same icon-steals-the-drag fix as InventorySlot — force children mouse-transparent AFTER their _ready.
	InventorySlot.pass_mouse_through(self)


func _get_drag_data(_at: Vector2) -> Variant:

	if weapon_id.is_empty() or weapon_id == SkirmishWeapon.DEFAULT_WEAPON:
		return null   # nothing to drag from the bare-fists / empty equip slot
	var icon : WeaponIcon = WeaponIcon.new()
	icon.weapon_id = weapon_id
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size = Vector2(48, 48)
	icon.position = Vector2(-24, -24)   # centered on the cursor
	icon.modulate = Color(1, 1, 1, 0.9)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var root : Control = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon)
	set_drag_preview(root)
	return {"kind": "weapon", "id": weapon_id, "action": ("unequip" if is_equip_slot else "equip")}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:

	# Only the EQUIP slot is a drop target — drop a backpack weapon here to equip it.
	return is_equip_slot and data is Dictionary and String((data as Dictionary).get("kind", "")) == "weapon" \
		and String((data as Dictionary).get("action", "")) == "equip"


func _drop_data(_at: Vector2, data: Variant) -> void:

	if is_equip_slot and data is Dictionary and String((data as Dictionary).get("kind", "")) == "weapon":
		PlayerState.equip_weapon(String((data as Dictionary).get("id", "")))
