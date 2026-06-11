## A draggable bag cell in the [TradeWindow] — DRAG it onto the Offering zone to put it up (or just CLICK it;
## both work). Same native drag-drop foundation as the inventory (Troy 2026-06-11: the trade window goes
## drag-drop). The window owns the offer logic; this cell only sources the drag + forwards the click.
class_name TradeBagCell
extends Panel


var item_id : String = ""
var window : TradeWindow = null


func _ready() -> void:
	# The item icon re-asserts mouse_filter = STOP in its own _ready — force children transparent so the WHOLE
	# cell (icon included) is grabbable, exactly like the backpack.
	InventorySlot.pass_mouse_through(self)


func _gui_input(event: InputEvent) -> void:
	# Click also offers one. RELEASE (not press) so STARTING a drag never also counts as a click.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if window != null:
			window._add_item(item_id)
		accept_event()


func _get_drag_data(_at: Vector2) -> Variant:
	if window == null or item_id.is_empty():
		return null
	var prev : Control = window.make_item_preview(item_id)
	if prev != null:
		set_drag_preview(prev)
	return {"kind": "trade", "id": item_id}
