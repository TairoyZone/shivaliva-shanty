## EquipWeaponSlot — the VISIBLE weapon slot in the Backpack (the Minecraft-style equip cell). It SHOWS what
## you're wielding (PlayerState.current_weapon_view: your class STARTER — a Swordsman's Twig — or the bought
## FORGE upgrade, or bare Fists) and lets you swap it: DRAG a matching weapon item from the bag onto it to equip,
## or DOUBLE-CLICK to drop back to your class. It is a REPRESENTATION of combat_weapon() — combat reads that; the
## slot only routes through the guarded, STYLE-LOCKED equip_weapon(). A future paper-doll of cosmetic armour slots
## (head/torso/legs/feet) joins it here. (Troy 2026-06-17.)
class_name EquipWeaponSlot
extends Control


const SIZE : float = 64.0

var inv_panel : InventoryPanel = null   # the bag this slot belongs to (for the drag payload origin)
var _icon : WeaponIcon


func _ready() -> void:

	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon = WeaponIcon.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 12.0
	_icon.offset_top = 12.0
	_icon.offset_right = -12.0
	_icon.offset_bottom = -12.0
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	refresh()
	if not Engine.is_editor_hint():
		PlayerState.weapons_changed.connect(refresh)
		PlayerState.power_type_changed.connect(refresh)


## The display name of the weapon currently shown (so the panel can label it).
func weapon_name() -> String:

	return String(PlayerState.current_weapon_view().get("name", ""))


func refresh() -> void:

	if _icon == null:
		return
	var view : Dictionary = PlayerState.current_weapon_view()
	_icon.weapon_id = String(view["id"])
	_icon.starter = bool(view["starter"])
	tooltip_text = "Wielding: %s\nDrag a weapon of your class here to equip it — double-click to go back to your class." % String(view["name"])
	queue_redraw()


# Double-click to UNEQUIP back to your class/fists. The click lands ON the slot body (click-on-target rule).
func _gui_input(event: InputEvent) -> void:

	if not (event is InputEventMouseButton):
		return
	var mb : InputEventMouseButton = event
	if mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
		PlayerState.equip_weapon(SkirmishWeapon.DEFAULT_WEAPON)
		accept_event()


func _can_drop_data(_at: Vector2, data: Variant) -> bool:

	if not (data is Dictionary) or String((data as Dictionary).get("kind", "")) != "item":
		return false
	var from : int = int((data as Dictionary).get("from", -1))
	if from < 0 or from >= PlayerState.inventory.size():
		return false
	var slot : Dictionary = PlayerState.inventory[from]
	if slot.is_empty():
		return false
	var wid : String = String(slot["id"])
	return PlayerState.is_weapon(wid) and PlayerState.weapon_matches_style(wid)   # only YOUR class's weapons


func _drop_data(_at: Vector2, data: Variant) -> void:

	if not (data is Dictionary):
		return
	var from : int = int((data as Dictionary).get("from", -1))
	if from < 0 or from >= PlayerState.inventory.size():
		return
	var slot : Dictionary = PlayerState.inventory[from]
	if slot.is_empty():
		return
	PlayerState.equip_weapon(String(slot["id"]))   # guarded by ownership + style; refresh follows the signal


func _draw() -> void:

	# Always the "equipped" cell look (accent rim + glow) — this IS your live weapon.
	draw_style_box(UiStyle.slot(true, true), Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)))
