## A procedural scene backdrop drawn BEHIND a puzzle board (on a low CanvasLayer),
## in full-screen space (1280x720). Two modes: a pre-dawn timber FOREST behind
## Lumberjacking, and an underground QUARRY behind Mining. Everything is a single
## seeded, drawn-once _draw() (no per-frame cost) following the Stardust Well
## house pattern; the board interior stays dark so the gameplay tiles pop and the
## backdrop only "breathes" in the gutters around the board.
##
## Art direction from the 2026-06-15 backdrop pass. Placeholder-first: pure
## procedural shapes, no imported assets.
@tool
class_name ScenicBackdrop
extends Node2D


const W : float = 1280.0
const H : float = 720.0


@export_enum("forest", "quarry") var mode : String = "forest" :
	set(value):
		mode = value
		queue_redraw()


func _draw() -> void:

	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	if mode == "quarry":
		rng.seed = 20260616
		_draw_quarry(rng)
	else:
		rng.seed = 20260615
		_draw_forest(rng)


# ============================================================ FOREST ==========

func _draw_forest(rng: RandomNumberGenerator) -> void:

	var SKY_TOP : Color = Color(0.18, 0.21, 0.27)
	var SKY_DAWN : Color = Color(0.42, 0.35, 0.31)
	var FOG_FAR : Color = Color(0.30, 0.40, 0.42, 0.10)
	var TREE_FAR : Color = Color(0.23, 0.32, 0.33)
	var TREE_MID : Color = Color(0.17, 0.27, 0.27)
	var CANOPY_DEEP : Color = Color(0.09, 0.15, 0.14)
	var CANOPY : Color = Color(0.13, 0.21, 0.18)
	var BARK_FACE : Color = Color(0.20, 0.25, 0.24)
	var BARK_DARK : Color = Color(0.13, 0.16, 0.16)
	var BARK_LIT : Color = Color(0.30, 0.36, 0.30)
	var RAY : Color = Color(1.0, 0.88, 0.56, 0.07)
	var FLOOR_DK : Color = Color(0.14, 0.13, 0.11)
	var FLOOR_LIT : Color = Color(0.22, 0.19, 0.14)
	var NEEDLE : Color = Color(0.26, 0.27, 0.17)
	var MOTE : Color = Color(0.95, 0.86, 0.62)

	# 1. Dawn sky wash (warm low -> cool high) + a soft warm bloom behind the board.
	for i in 16:
		var t : float = pow(float(i) / 15.0, 1.4)
		draw_rect(Rect2(0.0, H - float(i + 1) * 45.0, W, 46.0), SKY_DAWN.lerp(SKY_TOP, t))
	for i in 6:
		draw_circle(Vector2(640.0, 320.0), 360.0 - float(i) * 48.0, Color(RAY.r, RAY.g, RAY.b, 0.05 - float(i) * 0.008))

	# 2. Far misty treeline (jagged silhouette filling to the floor) + haze.
	_jagged_silhouette(TREE_FAR, 250.0, 0.013, 22.0, 0.041, 9.0, 1.7, 560.0)
	for i in 4:
		draw_rect(Rect2(0.0, 270.0 + float(i) * 14.0, W, 18.0), FOG_FAR)

	# 3. Mid pine wall — overlapping triangular tips, the dark band the board sits on.
	var tips : int = 20
	for k in tips:
		var cx : float = (float(k) + 0.5) * W / float(tips)
		var apex : float = 360.0 + rng.randf_range(0.0, 70.0)
		var half : float = W / float(tips) * 0.95
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - half, 600.0), Vector2(cx, apex), Vector2(cx + half, 600.0)]), TREE_MID)

	# 4. Canopy overhang (top mass, scalloped bottom that lifts over the board).
	_draw_canopy(rng, CANOPY_DEEP, CANOPY, TREE_MID)

	# 5. Flanking trunks in the gutters (timber posts bracketing the bin).
	for x in [70.0, 156.0, 252.0]:
		_draw_trunk(rng, x, 44.0, BARK_FACE, BARK_DARK, BARK_LIT, 1.0)
	for x in [1028.0, 1124.0, 1210.0]:
		_draw_trunk(rng, x, 44.0, BARK_FACE, BARK_DARK, BARK_LIT, -1.0)

	# 6. God-ray shafts through the canopy gap (kept to the gutters).
	_draw_ray(Vector2(360.0, 110.0), Vector2(250.0, 640.0), 70.0, RAY)
	_draw_ray(Vector2(900.0, 110.0), Vector2(1010.0, 640.0), 64.0, RAY)

	# 7. Forest floor + scattered needles + chips.
	draw_rect(Rect2(0.0, 610.0, W, 110.0), FLOOR_DK)
	draw_rect(Rect2(0.0, 666.0, W, 54.0), FLOOR_LIT)
	for _i in 60:
		var p : Vector2 = Vector2(rng.randf_range(0.0, W), rng.randf_range(616.0, 712.0))
		var a : float = rng.randf_range(-0.5, 0.5)
		draw_line(p, p + Vector2(cos(a), sin(a)) * rng.randf_range(6.0, 12.0), NEEDLE, 1.4)

	# 8. Vignette + a few warm sawdust motes.
	_draw_vignette(Color(0.04, 0.05, 0.05), 0.5, 120.0)
	for _i in 16:
		var p : Vector2 = Vector2(rng.randf_range(0.0, W), rng.randf_range(120.0, 620.0))
		draw_circle(p, rng.randf_range(1.2, 2.0), Color(MOTE.r, MOTE.g, MOTE.b, rng.randf_range(0.30, 0.55)))


func _jagged_silhouette(col: Color, base_y: float, f1: float, a1: float, f2: float, a2: float, ph: float, fill_to: float) -> void:

	var pts : PackedVector2Array = PackedVector2Array()
	pts.append(Vector2(0.0, fill_to))
	var x : float = 0.0
	while x <= W:
		pts.append(Vector2(x, base_y + sin(x * f1) * a1 + sin(x * f2 + ph) * a2))
		x += 32.0
	pts.append(Vector2(W, fill_to))
	draw_colored_polygon(pts, col)


func _draw_canopy(rng: RandomNumberGenerator, deep: Color, tuft: Color, edge: Color) -> void:

	var pts : PackedVector2Array = PackedVector2Array([Vector2(0.0, 0.0)])
	var x : float = 0.0
	while x <= W:
		# Scalloped bottom that DIPS UP over the board centre (a gaussian lift).
		var lift : float = 70.0 * exp(-pow((x - 640.0) / 180.0, 2.0))
		pts.append(Vector2(x, 120.0 + sin(x * 0.02) * 30.0 + sin(x * 0.05 + 2.0) * 14.0 - lift))
		x += 28.0
	pts.append(Vector2(W, 0.0))
	draw_colored_polygon(pts, deep)
	for _i in 90:
		var p : Vector2 = Vector2(rng.randf_range(0.0, W), rng.randf_range(10.0, 150.0))
		draw_circle(p, rng.randf_range(4.0, 9.0), tuft if rng.randf() < 0.5 else deep)


func _draw_trunk(rng: RandomNumberGenerator, cx: float, base_w: float, face: Color, dark: Color, lit: Color, inner_dir: float) -> void:

	var top_w : float = base_w * 0.74
	var quad : PackedVector2Array = PackedVector2Array([
		Vector2(cx - top_w * 0.5, 0.0), Vector2(cx + top_w * 0.5, 0.0),
		Vector2(cx + base_w * 0.5, H), Vector2(cx - base_w * 0.5, H)])
	draw_colored_polygon(quad, face)
	# Cylindrical shade on the half away from the dawn light.
	var shade : PackedVector2Array = PackedVector2Array([
		Vector2(cx - top_w * 0.5, 0.0), Vector2(cx, 0.0), Vector2(cx, H), Vector2(cx - base_w * 0.5, H)])
	draw_colored_polygon(shade, dark)
	# Lit rim on the inner (board-facing) edge.
	var rim_x : float = cx + inner_dir * top_w * 0.5
	var rim_xb : float = cx + inner_dir * base_w * 0.5
	draw_line(Vector2(rim_x, 0.0), Vector2(rim_xb, H), lit, 3.0)
	# Vertical bark striations + a few crack nicks.
	for s in 5:
		var sx : float = cx + lerpf(-base_w * 0.35, base_w * 0.35, float(s) / 4.0)
		var pts : PackedVector2Array = PackedVector2Array()
		var y : float = 0.0
		while y <= H:
			pts.append(Vector2(sx + sin(y * 0.05 + float(s)) * 2.0, y))
			y += 40.0
		draw_polyline(pts, dark, 1.4)
	for _i in 8:
		var y : float = rng.randf_range(0.0, H)
		draw_line(Vector2(cx - base_w * 0.3, y), Vector2(cx - base_w * 0.1, y + 3.0), dark, 1.0)


func _draw_ray(top: Vector2, bottom: Vector2, width: float, col: Color) -> void:

	draw_colored_polygon(PackedVector2Array([
		top + Vector2(-6.0, 0.0), top + Vector2(6.0, 0.0),
		bottom + Vector2(width * 0.5, 0.0), bottom + Vector2(-width * 0.5, 0.0)]), col)
	draw_colored_polygon(PackedVector2Array([
		top + Vector2(-2.0, 0.0), top + Vector2(2.0, 0.0),
		bottom + Vector2(width * 0.22, 0.0), bottom + Vector2(-width * 0.22, 0.0)]),
		Color(col.r, col.g, col.b, 0.04))


# ============================================================ QUARRY ==========

func _draw_quarry(rng: RandomNumberGenerator) -> void:

	var STONE_DK : Color = Color(0.12, 0.12, 0.15)
	var STONE_MID : Color = Color(0.19, 0.19, 0.23)
	var STONE_LT : Color = Color(0.27, 0.27, 0.31)
	var STONE_WARM : Color = Color(0.30, 0.27, 0.26)
	var PIT : Color = Color(0.05, 0.05, 0.07)
	var CRACK : Color = Color(0.0, 0.0, 0.0, 0.45)
	var VEIN_TEAL : Color = Color(0.34, 0.62, 0.60, 0.50)
	var VEIN_AMBER : Color = Color(0.78, 0.55, 0.30, 0.50)
	var GLINT : Color = Color(0.85, 0.95, 0.95, 0.90)
	var PROP_FACE : Color = Color(0.34, 0.24, 0.13)
	var PROP_DK : Color = Color(0.16, 0.11, 0.07)
	var PROP_LIT : Color = Color(0.50, 0.37, 0.20)
	var LANTERN_CORE : Color = Color(1.0, 0.80, 0.40)
	var LANTERN_GLASS : Color = Color(1.0, 0.90, 0.55)
	var DUST : Color = Color(0.85, 0.78, 0.60)
	var lantern : Vector2 = Vector2(942.0, 150.0)

	# 1. Rock depth gradient (lit mouth -> near-black pit).
	for i in 14:
		draw_rect(Rect2(0.0, float(i) * H / 14.0, W, H / 14.0 + 1.0), STONE_MID.lerp(PIT, float(i) / 13.0))

	# 2. Warm lantern bloom (+ a soft dig-face pool over the board).
	for i in 8:
		draw_circle(lantern, 360.0 - float(i) * 40.0, Color(LANTERN_CORE.r, LANTERN_CORE.g, LANTERN_CORE.b, 0.16 - float(i) * 0.02))
	for i in 6:
		draw_circle(Vector2(640.0, 360.0), 300.0 - float(i) * 44.0, Color(LANTERN_CORE.r, LANTERN_CORE.g, LANTERN_CORE.b, 0.05 - float(i) * 0.008))

	# 3. Rock strata walls — banded steps with wavy carved seams + cracks.
	var y : float = 0.0
	var band : int = 0
	while y < H:
		var step : float = rng.randf_range(28.0, 52.0)
		var base : Color = [STONE_DK, STONE_MID, STONE_LT][band % 3]
		# Warm-shift bands near the lantern bloom.
		if absf(y - lantern.y) < 220.0:
			base = base.lerp(STONE_WARM, 0.35)
		draw_rect(Rect2(0.0, y, W, step + 1.0), base)
		# Wavy bedding seam + a lifted lip (the board's groove+lip language).
		var seam : PackedVector2Array = PackedVector2Array()
		var x : float = 0.0
		while x <= W:
			seam.append(Vector2(x, y + sin(x * 0.02 + float(band)) * 2.2))
			x += 64.0
		draw_polyline(seam, CRACK, 1.5)
		var lip : PackedVector2Array = PackedVector2Array()
		for p in seam:
			lip.append(p + Vector2(0.0, 1.6))
		draw_polyline(lip, Color(STONE_LT.r, STONE_LT.g, STONE_LT.b, 0.18), 1.0)
		y += step
		band += 1
	# Hairline cracks (flanks only).
	for _i in 30:
		var ox : float = (rng.randf_range(20.0, 430.0)) if rng.randf() < 0.5 else (rng.randf_range(850.0, 1260.0))
		var oy : float = rng.randf_range(40.0, 600.0)
		var cpts : PackedVector2Array = PackedVector2Array([Vector2(ox, oy)])
		for s in 4:
			oy += rng.randf_range(14.0, 30.0)
			ox += rng.randf_range(-14.0, 14.0)
			cpts.append(Vector2(ox, oy))
		draw_polyline(cpts, CRACK, 1.3)

	# 4. Ore veins + crystal glints (flanks; glints concentrated in the bloom).
	for v in 6:
		var on_left : bool = (v % 2 == 0)
		var vx : float = rng.randf_range(40.0, 360.0) if on_left else rng.randf_range(900.0, 1240.0)
		var vy : float = rng.randf_range(120.0, 480.0)
		var vpts : PackedVector2Array = PackedVector2Array([Vector2(vx, vy)])
		for s in 9:
			vx += rng.randf_range(-22.0, 22.0)
			vy += rng.randf_range(18.0, 34.0)
			vpts.append(Vector2(vx, vy))
		var vcol : Color = VEIN_AMBER if v == 3 else VEIN_TEAL
		draw_polyline(vpts, vcol, 2.0)
		draw_polyline(vpts, Color(vcol.r, vcol.g, vcol.b, 0.85), 1.0)
		for s in range(0, vpts.size(), 2):
			var gp : Vector2 = vpts[s]
			var lit_boost : float = 1.0 if gp.distance_to(lantern) < 260.0 else 0.5
			draw_colored_polygon(PackedVector2Array([
				gp + Vector2(0.0, -3.5), gp + Vector2(3.0, 0.0), gp + Vector2(0.0, 3.5), gp + Vector2(-3.0, 0.0)]),
				Color(GLINT.r, GLINT.g, GLINT.b, GLINT.a * lit_boost))

	# 5. Pit-support timbers framing the board + a header beam.
	_draw_prop(rng, 426.0, PROP_FACE, PROP_DK, PROP_LIT, 1.0)
	_draw_prop(rng, 854.0, PROP_FACE, PROP_DK, PROP_LIT, -1.0)
	draw_rect(Rect2(410.0, 62.0, 460.0, 40.0), PROP_FACE)
	draw_line(Vector2(410.0, 62.0), Vector2(870.0, 62.0), PROP_LIT, 2.0)
	draw_rect(Rect2(410.0, 96.0, 460.0, 6.0), PROP_DK)

	# 6. Pit floor + rubble.
	draw_rect(Rect2(0.0, 600.0, W, 120.0), PIT)
	for _i in 30:
		var c : Vector2 = Vector2(rng.randf_range(0.0, W), rng.randf_range(606.0, 706.0))
		var r : float = rng.randf_range(6.0, 16.0)
		var rock : PackedVector2Array = PackedVector2Array([
			c + Vector2(-r, r * 0.3), c + Vector2(-r * 0.4, -r), c + Vector2(r * 0.6, -r * 0.7),
			c + Vector2(r, r * 0.2), c + Vector2(r * 0.3, r)])
		draw_colored_polygon(rock, STONE_MID if rng.randf() < 0.5 else STONE_DK)
		draw_line(c + Vector2(-r * 0.4, -r), c + Vector2(r * 0.6, -r * 0.7), Color(STONE_LT.r, STONE_LT.g, STONE_LT.b, 0.7), 1.0)

	# 7. Hanging lantern on the chain + a faint downward cone.
	for i in 6:
		draw_arc(Vector2(lantern.x, 8.0 + float(i) * 16.0), 4.0, 0.0, PI, 6, PROP_DK, 1.6)
	var cage : PackedVector2Array = PackedVector2Array([
		lantern + Vector2(-12.0, -10.0), lantern + Vector2(12.0, -10.0), lantern + Vector2(16.0, 6.0),
		lantern + Vector2(0.0, 18.0), lantern + Vector2(-16.0, 6.0)])
	draw_colored_polygon(cage, PROP_DK)
	draw_circle(lantern + Vector2(0.0, 1.0), 9.0, LANTERN_GLASS)
	draw_arc(lantern + Vector2(0.0, 1.0), 12.0, 0.0, TAU, 18, Color(LANTERN_GLASS.r, LANTERN_GLASS.g, LANTERN_GLASS.b, 0.4), 2.0)

	# 8. Vignette (deeper than the forest) + dust motes biased into the bloom.
	_draw_vignette(Color(0.03, 0.03, 0.05), 0.6, 140.0)
	for _i in 14:
		var p : Vector2 = Vector2(rng.randf_range(0.0, W), rng.randf_range(80.0, 600.0))
		var a : float = rng.randf_range(0.25, 0.50) * (1.6 if p.distance_to(lantern) < 280.0 else 0.7)
		draw_circle(p, rng.randf_range(1.4, 2.0), Color(DUST.r, DUST.g, DUST.b, clampf(a, 0.0, 0.6)))


func _draw_prop(rng: RandomNumberGenerator, cx: float, face: Color, dark: Color, lit: Color, inner_dir: float) -> void:

	var hw : float = 18.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - hw, 60.0), Vector2(cx + hw, 60.0), Vector2(cx + hw, H), Vector2(cx - hw, H)]), face)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - hw, 60.0), Vector2(cx, 60.0), Vector2(cx, H), Vector2(cx - hw, H)]), dark)
	var rim_x : float = cx + inner_dir * hw
	draw_line(Vector2(rim_x, 60.0), Vector2(rim_x, H), lit, 3.0)
	for s in 5:
		var sx : float = cx + lerpf(-hw * 0.7, hw * 0.7, float(s) / 4.0)
		draw_line(Vector2(sx, 60.0), Vector2(sx, H), dark, 1.2)
	for yy in [180.0, 360.0, 540.0]:
		draw_line(Vector2(cx - hw, yy), Vector2(cx + hw, yy), dark, 1.4)
		draw_circle(Vector2(cx - hw * 0.5, yy), 2.4, dark)
		draw_circle(Vector2(cx + hw * 0.5, yy), 2.4, dark)


# ============================================================ SHARED ==========

func _draw_vignette(col: Color, max_a: float, depth: float) -> void:

	var steps : int = 6
	for i in steps:
		var a : float = max_a * (1.0 - float(i) / float(steps))
		var t : float = depth * float(i) / float(steps)
		var c : Color = Color(col.r, col.g, col.b, a / float(steps) * 2.2)
		draw_rect(Rect2(0.0, t, W, depth / float(steps) + 1.0), c)                       # top
		draw_rect(Rect2(0.0, H - t - depth / float(steps), W, depth / float(steps) + 1.0), c)  # bottom
		draw_rect(Rect2(t, 0.0, depth / float(steps) + 1.0, H), c)                       # left
		draw_rect(Rect2(W - t - depth / float(steps), 0.0, depth / float(steps) + 1.0, H), c)  # right
