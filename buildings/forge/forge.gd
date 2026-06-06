## Cinder Troy's forge — the smithy on Cradle Rock, and (per the
## "live where they work" model in [[cradle-rock-cast]]) his home too.
## Iron-grey stone walls + a rust-red fired-clay roof set it apart from
## the warm-oak Inn at a glance. All wall/roof/window drawing inherits
## from [Building]; this stays thin so future forge-only touches (a
## chimney, a glowing furnace window) have a place to land.
@tool
class_name Forge
extends Building


func _ready() -> void:

	if Engine.is_editor_hint():
		return
	# A warm furnace glow — the "glowing furnace window" touch noted above (borrow #6). Tune the
	# position/radius to the furnace in-editor.
	var glow : Glow = Glow.make(Color(1.0, 0.5, 0.16, 0.7), 66.0)
	glow.position = Vector2(0.0, -26.0)
	add_child(glow)