## The "Offering" drop zone in the [TradeWindow] — drop a bag item here (dragged from a [TradeBagCell]) to put
## it up for trade. Native drag-drop, the same foundation as the backpack (Troy 2026-06-11).
class_name TradeOfferZone
extends PanelContainer


var window : TradeWindow = null


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and String((data as Dictionary).get("kind", "")) == "trade"


func _drop_data(_at: Vector2, data: Variant) -> void:
	if window != null and data is Dictionary and String((data as Dictionary).get("kind", "")) == "trade":
		window._add_item(String((data as Dictionary).get("id", "")))
