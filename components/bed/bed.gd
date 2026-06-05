## A bed the player can rest at. Currently a stub: pressing E shows
## the interact_message. Future: actual sleep-to-save logic that calls
## [PlayerState.save_session] and fades the screen out/in.
##
## When a second bed variant appears (an inn bed you have to pay for,
## a Doraka burrow cot, etc.), extract a `Furniture` base from this
## per the [[inheritance-pattern]] rule.
@tool
class_name Bed
extends Interactable


# E on the bed surfaces its message (the authored interact_message, else a default) via the lore overlay
# — so the first thing a new player tries E on (their cot) actually responds instead of doing nothing.
func interact() -> void:

	super.interact()
	if Engine.is_editor_hint():
		return
	var msg : String = interact_message if not interact_message.is_empty() \
		else "Your cot. You'll be able to sleep here to save your game, once resting's in."
	Overlay.show_lore("Your cot", msg)


func _draw() -> void:

	# Iso bed per Troy's sketch: thick rectangular box on four stubby
	# legs, top split by a single seam line into a foot-side blanket and
	# a smaller head-side sheet/pillow strip. Origin = floor center.

	# Floor footprint — 2:1 parallelogram (length along iso x, width
	# along iso y).
	var fs : Vector2 = Vector2(-20.0, 30.0)
	var fn : Vector2 = Vector2(-60.0, 10.0)
	var hn : Vector2 = Vector2(20.0, -30.0)
	var hs : Vector2 = Vector2(60.0, -10.0)

	var leg_h : float = 11.0
	var body_h : float = 22.0
	var leg_half_w : float = 3.5
	# Legs are nudged inward from the corners so each leg's top is
	# INSIDE the body's footprint — the body cleanly covers it and the
	# leg reads as a stub poking out from under the bed instead of a
	# diamond cap floating below it.
	var leg_inset : float = 0.10

	var wood : Color = Color(0.52, 0.34, 0.18)
	var wood_lit : Color = Color(0.66, 0.44, 0.24)
	var wood_dark : Color = Palette.WOOD_PIVOT
	var blanket : Color = Color(0.94, 0.72, 0.22)
	var sheet : Color = Color(0.95, 0.93, 0.85)

	# --- 1. Legs (flat rects, drawn back-to-front so closer ones overlap) ---
	var fs_l : Vector2 = fs * (1.0 - leg_inset)
	var fn_l : Vector2 = fn * (1.0 - leg_inset)
	var hn_l : Vector2 = hn * (1.0 - leg_inset)
	var hs_l : Vector2 = hs * (1.0 - leg_inset)
	_draw_leg(hn_l, leg_h, leg_half_w, wood, wood_dark)
	_draw_leg(hs_l, leg_h, leg_half_w, wood, wood_dark)
	_draw_leg(fn_l, leg_h, leg_half_w, wood, wood_dark)
	_draw_leg(fs_l, leg_h, leg_half_w, wood, wood_dark)

	# --- 2. Bed body (box sitting on top of the legs) ---
	var bot : Vector2 = Vector2(0.0, -leg_h)
	var top : Vector2 = Vector2(0.0, -(leg_h + body_h))
	var fs_b : Vector2 = fs + bot
	var fn_b : Vector2 = fn + bot
	var hs_b : Vector2 = hs + bot
	var fs_t : Vector2 = fs + top
	var fn_t : Vector2 = fn + top
	var hs_t : Vector2 = hs + top
	var hn_t : Vector2 = hn + top
	# South face (front-facing, lit). Covers the upper portion of every leg.
	draw_colored_polygon(PackedVector2Array([fs_b, hs_b, hs_t, fs_t]), wood_lit)
	# West face (foot end, in shadow).
	draw_colored_polygon(PackedVector2Array([fn_b, fs_b, fs_t, fn_t]), wood)

	# --- 3. Top split — smaller pillow area (sheet covers head ~28%) ---
	var seam_t : float = 0.72
	var bs : Vector2 = fs_t.lerp(hs_t, seam_t)
	var bn : Vector2 = fn_t.lerp(hn_t, seam_t)
	draw_colored_polygon(PackedVector2Array([fs_t, bs, bn, fn_t]), blanket)
	draw_colored_polygon(PackedVector2Array([bs, hs_t, hn_t, bn]), sheet)

	# --- 4. Outlines ---
	draw_polyline(PackedVector2Array([fn_b, fs_b, hs_b]), wood_dark, 1.2)
	draw_polyline(PackedVector2Array([fs_t, hs_t, hn_t, fn_t, fs_t]), wood_dark, 1.2)
	draw_line(fs_b, fs_t, wood_dark, 1.2)
	draw_line(hs_b, hs_t, wood_dark, 1.2)
	draw_line(fn_b, fn_t, wood_dark, 1.2)
	draw_line(bs, bn, wood_dark, 1.0)


## Flat rectangular leg at position `c`, rising `h` pixels with half-width
## `hw`. Left half slightly darkened so it picks up the bed's own
## shadow/light direction. Top is a clean horizontal line that nests
## inside the body's footprint when the leg is inset.
func _draw_leg(c: Vector2, h: float, hw: float, color: Color, color_dark: Color) -> void:

	var x_left : float = c.x - hw
	var y_top : float = c.y - h
	# Shadow half (left) + lit half (right).
	draw_rect(Rect2(x_left, y_top, hw, h), color.darkened(0.18))
	draw_rect(Rect2(c.x, y_top, hw, h), color)
	# Outline the full leg silhouette.
	draw_rect(Rect2(x_left, y_top, hw * 2.0, h), color_dark, false, 1.0)
