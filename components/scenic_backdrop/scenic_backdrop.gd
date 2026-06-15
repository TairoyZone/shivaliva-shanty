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


@export_enum("forest", "quarry", "sky_battle", "stardust_drift", "ship_hold", "hull_repair", "tavern") var mode : String = "forest" :
	set(value):
		mode = value
		queue_redraw()


func _draw() -> void:

	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	if mode == "quarry":
		rng.seed = 20260616
		_draw_quarry(rng)
	elif mode == "sky_battle":
		rng.seed = 20260617
		_draw_sky_battle(rng)
	elif mode == "stardust_drift":
		rng.seed = 20260618
		_draw_stardust_drift(rng)
	elif mode == "ship_hold":
		rng.seed = 20260619
		_draw_ship_hold(rng)
	elif mode == "hull_repair":
		rng.seed = 20260620
		_draw_hull_repair(rng)
	elif mode == "tavern":
		rng.seed = 20260621
		_draw_tavern(rng)
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


func _draw_canopy(rng: RandomNumberGenerator, deep: Color, tuft: Color, _edge: Color) -> void:

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


func _draw_prop(_rng: RandomNumberGenerator, cx: float, face: Color, dark: Color, lit: Color, inner_dir: float) -> void:

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


# ======================================================== SKY BATTLE ==========
# A sky-pirate BOARDING battle at altitude (the Skirmish backdrop): two grappled
# airships flank the boards, crews clashing on their decks, under a dramatic dusk
# sky with cloud banks + floating islands. The sky-canon answer to YPP's deck
# brawl ([[sky-canon]]: airships among floating islands, never water). The boards
# sit centre-screen, so the ships/crew live in the GUTTERS, sky up top, deck below.

func _draw_sky_battle(rng: RandomNumberGenerator) -> void:

	var SKY_TOP : Color = Color(0.09, 0.08, 0.20)
	var SKY_MID : Color = Color(0.34, 0.20, 0.36)
	var SKY_HORIZON : Color = Color(0.96, 0.55, 0.30)
	var SKY_HAZE : Color = Color(0.50, 0.33, 0.40)
	var SUN : Color = Color(1.0, 0.88, 0.58)
	var CLOUD_DK : Color = Color(0.36, 0.27, 0.40)
	var CLOUD_LT : Color = Color(0.98, 0.76, 0.56)
	var ISLAND : Color = Color(0.16, 0.13, 0.24)
	var EMBER : Color = Color(1.0, 0.72, 0.34)
	var horizon : float = 442.0

	# 1. Dusk sky: indigo high -> fiery horizon, then a hazy abyss below (you're aloft).
	for i in 24:
		var t : float = float(i) / 23.0
		var c : Color = SKY_TOP.lerp(SKY_MID, t / 0.7) if t < 0.7 else SKY_MID.lerp(SKY_HORIZON, (t - 0.7) / 0.3)
		draw_rect(Rect2(0.0, horizon * float(i) / 24.0, W, horizon / 24.0 + 1.0), c)
	for i in 10:
		var t : float = float(i) / 9.0
		draw_rect(Rect2(0.0, horizon + (H - horizon) * float(i) / 10.0, W, (H - horizon) / 10.0 + 1.0),
			SKY_HORIZON.lerp(SKY_HAZE, t).darkened(0.12 * t))

	# 2. Low sun bloom (centre, behind the gap between the boards).
	var sun_c : Vector2 = Vector2(640.0, horizon - 18.0)
	for i in 9:
		draw_circle(sun_c, 230.0 - float(i) * 24.0, Color(SUN.r, SUN.g, SUN.b, 0.11 - float(i) * 0.011))
	draw_circle(sun_c, 44.0, Color(SUN.r, SUN.g, SUN.b, 0.5))

	# 3. Distant floating islands on the horizon.
	for ix in [150.0, 640.0, 1140.0]:
		_draw_floating_island(Vector2(ix, horizon - rng.randf_range(4.0, 16.0)), rng.randf_range(64.0, 104.0), ISLAND)

	# 4. Cloud banks (dark base, warm-lit crowns).
	for _k in 8:
		_draw_cloud(Vector2(rng.randf_range(0.0, W), rng.randf_range(170.0, 410.0)),
			rng.randf_range(130.0, 250.0), CLOUD_DK, CLOUD_LT, rng)

	# 5. The two grappled airships (flanks), crews clashing on the decks.
	_draw_airship(rng, 0.0, 1.0)
	_draw_airship(rng, W, -1.0)

	# 6. Grappling lines slung across the top, ship to ship (the boarding hooks).
	for i in 3:
		var y0 : float = 96.0 + float(i) * 16.0
		var rope : PackedVector2Array = PackedVector2Array()
		for s in 13:
			var tt : float = float(s) / 12.0
			rope.append(Vector2(lerpf(150.0, 1130.0, tt), y0 + sin(tt * PI) * (54.0 + float(i) * 8.0)))
		draw_polyline(rope, Color(0.16, 0.12, 0.08, 0.9), 2.0)

	# 7. Battle embers drifting up + a deep vignette.
	for _i in 22:
		var p : Vector2 = Vector2(rng.randf_range(0.0, W), rng.randf_range(300.0, 700.0))
		draw_circle(p, rng.randf_range(1.0, 2.2), Color(EMBER.r, EMBER.g, EMBER.b, rng.randf_range(0.3, 0.7)))
	_draw_vignette(Color(0.03, 0.02, 0.05), 0.6, 150.0)


# A floating-rock island silhouette: flat lit top, a chunky off-centre rocky
# underside (kept convex so draw_colored_polygon triangulates it correctly).
func _draw_floating_island(c: Vector2, w: float, col: Color) -> void:

	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - w * 0.5, c.y), Vector2(c.x + w * 0.5, c.y),
		Vector2(c.x + w * 0.36, c.y + w * 0.30), Vector2(c.x + w * 0.06, c.y + w * 0.44),
		Vector2(c.x - w * 0.28, c.y + w * 0.34), Vector2(c.x - w * 0.44, c.y + w * 0.14)]), col)
	draw_line(Vector2(c.x - w * 0.5, c.y), Vector2(c.x + w * 0.5, c.y), col.lightened(0.22), 2.0)


# A cloud bank: overlapping puffs, dark body with a warm-lit upper edge.
func _draw_cloud(c: Vector2, w: float, dk: Color, lt: Color, rng: RandomNumberGenerator) -> void:

	var n : int = 5
	for i in n:
		var px : float = c.x - w * 0.5 + w * float(i) / float(n - 1)
		var r : float = rng.randf_range(w * 0.18, w * 0.30)
		draw_circle(Vector2(px, c.y), r, dk)
		draw_circle(Vector2(px, c.y - r * 0.34), r * 0.7, Color(lt.r, lt.g, lt.b, 0.45))


# A flanking airship: dark hull in the bottom corner, a mast + billowing sail in
# the gutter, rigging, and two crew silhouettes brawling on the deck. `dir` = +1
# anchors at the LEFT edge (everything extends inward/right), -1 mirrors it right.
func _draw_airship(_rng: RandomNumberGenerator, edge_x: float, dir: float) -> void:

	var HULL : Color = Color(0.19, 0.12, 0.07)
	var HULL_LT : Color = Color(0.42, 0.27, 0.15)
	var SAIL : Color = Color(0.80, 0.73, 0.60)
	var SAIL_DK : Color = Color(0.55, 0.47, 0.41)
	var deck_y : float = 566.0
	var prow_x : float = edge_x + dir * 388.0
	# Hull (sweeps from the outer-bottom up to a prow reaching toward the centre).
	draw_colored_polygon(PackedVector2Array([
		Vector2(edge_x - dir * 60.0, deck_y), Vector2(edge_x + dir * 70.0, deck_y - 16.0),
		Vector2(prow_x, deck_y + 26.0), Vector2(prow_x - dir * 34.0, deck_y + 96.0),
		Vector2(edge_x - dir * 60.0, H + 40.0)]), HULL)
	draw_line(Vector2(edge_x + dir * 70.0, deck_y - 16.0), Vector2(prow_x, deck_y + 26.0), HULL_LT, 3.0)
	# Gunport row + a couple of plank lines.
	for g in 3:
		var gx : float = edge_x + dir * (70.0 + float(g) * 95.0)
		draw_rect(Rect2(gx - 9.0, deck_y + 36.0, 18.0, 16.0), Color(0.07, 0.05, 0.03, 1.0))
	# Mast + yard + a billowing sail, set in the gutter.
	var mast_x : float = edge_x + dir * 96.0
	draw_line(Vector2(mast_x, deck_y), Vector2(mast_x, 92.0), Color(0.16, 0.10, 0.06, 1.0), 6.0)
	var yard_y : float = 196.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(mast_x, yard_y), Vector2(mast_x + dir * 132.0, yard_y + 14.0),
		Vector2(mast_x + dir * 120.0, yard_y + 150.0), Vector2(mast_x, yard_y + 138.0)]), SAIL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(mast_x, yard_y + 70.0), Vector2(mast_x + dir * 124.0, yard_y + 84.0),
		Vector2(mast_x + dir * 120.0, yard_y + 150.0), Vector2(mast_x, yard_y + 138.0)]), SAIL_DK)
	draw_line(Vector2(mast_x - dir * 36.0, yard_y), Vector2(mast_x + dir * 150.0, yard_y), Color(0.16, 0.10, 0.06, 1.0), 3.0)
	# Ratlines (rigging triangle).
	for s in 4:
		var rx : float = mast_x + dir * (18.0 + float(s) * 16.0)
		draw_line(Vector2(mast_x, 150.0), Vector2(rx, deck_y), Color(0.16, 0.11, 0.07, 0.7), 1.0)
	# Two crew on the deck — one of theirs, one lunging toward the centre fight.
	_draw_fighter(Vector2(edge_x + dir * 64.0, deck_y - 2.0), dir, 1.05)
	_draw_fighter(Vector2(edge_x + dir * 168.0, deck_y + 10.0), -dir, 0.92)


# A sky-pirate silhouette mid-brawl: body + head + braced legs + a raised cutlass
# (a faint steel glint). `face` is the swing direction.
func _draw_fighter(pos: Vector2, face: float, s: float) -> void:

	var col : Color = Color(0.07, 0.05, 0.08, 1.0)
	draw_line(pos, Vector2(pos.x - 6.0 * s, pos.y + 13.0 * s), col, 3.0 * s)
	draw_line(pos, Vector2(pos.x + 6.0 * s, pos.y + 13.0 * s), col, 3.0 * s)
	draw_rect(Rect2(pos.x - 4.0 * s, pos.y - 22.0 * s, 8.0 * s, 22.0 * s), col)
	draw_circle(Vector2(pos.x, pos.y - 27.0 * s), 5.0 * s, col)
	var hand : Vector2 = Vector2(pos.x + face * 12.0 * s, pos.y - 32.0 * s)
	draw_line(Vector2(pos.x + face * 3.0 * s, pos.y - 18.0 * s), hand, col, 3.0 * s)
	draw_line(hand, hand + Vector2(face * 17.0 * s, -9.0 * s), Color(0.82, 0.84, 0.90, 0.9), 2.0 * s)


# ===================================================== STARDUST DRIFT =========
# The LOFT backdrop ([[loft-spec]] / [[sky-canon]]): floating islands hang in the
# high sky above a glowing violet STARDUST DRIFT — the luminous sea you sing the
# ship aloft over. Serene but tense (the drift is what swallows you if you sink).
# The board sits centre-screen, so islands live in the gutters/top, the drift below.

func _draw_stardust_drift(rng: RandomNumberGenerator) -> void:

	var SKY_TOP : Color = Color(0.08, 0.10, 0.21)
	var SKY_MID : Color = Color(0.25, 0.20, 0.40)
	var SKY_LOW : Color = Color(0.44, 0.29, 0.52)
	var DRIFT_DK : Color = Color(0.15, 0.09, 0.30)
	var DRIFT_MID : Color = Color(0.34, 0.20, 0.54)
	var DRIFT_GLOW : Color = Color(0.64, 0.44, 0.96)
	var STAR : Color = Color(0.95, 0.93, 1.0)
	var ISLAND : Color = Color(0.13, 0.12, 0.23)
	var drift_top : float = 454.0

	# 1. High-altitude sky (deep indigo top -> warm violet toward the drift).
	for i in 22:
		var t : float = float(i) / 21.0
		var c : Color = SKY_TOP.lerp(SKY_MID, t / 0.65) if t < 0.65 else SKY_MID.lerp(SKY_LOW, (t - 0.65) / 0.35)
		draw_rect(Rect2(0.0, drift_top * float(i) / 22.0, W, drift_top / 22.0 + 1.0), c)

	# 2. Stars scattered across the upper sky.
	for _i in 90:
		var p : Vector2 = Vector2(rng.randf_range(0.0, W), rng.randf_range(0.0, drift_top * 0.82))
		draw_circle(p, rng.randf_range(0.5, 1.6), Color(STAR.r, STAR.g, STAR.b, rng.randf_range(0.25, 0.9)))

	# 3. Floating islands hanging in the sky, some tethered to the drift by a wisp.
	for spec in [Vector2(118.0, 232.0), Vector2(258.0, 150.0), Vector2(1052.0, 250.0),
			Vector2(1176.0, 158.0), Vector2(640.0, 116.0)]:
		var iw : float = rng.randf_range(46.0, 78.0)
		_draw_floating_island(spec, iw, ISLAND)
		# a faint lit crown (dawn catching the top)
		draw_line(spec + Vector2(-iw * 0.42, 0.0), spec + Vector2(iw * 0.42, 0.0), Color(0.55, 0.46, 0.66, 0.5), 1.5)

	# 4. Soft drifting cloud wisps.
	for _k in 5:
		_draw_cloud(Vector2(rng.randf_range(0.0, W), rng.randf_range(150.0, 420.0)),
			rng.randf_range(150.0, 250.0), Color(0.22, 0.16, 0.34), SKY_LOW.lightened(0.18), rng)

	# 5. THE STARDUST DRIFT — a glowing violet nebula filling the lower screen.
	for i in 13:
		var t : float = float(i) / 12.0
		draw_rect(Rect2(0.0, drift_top + (H - drift_top) * float(i) / 13.0, W, (H - drift_top) / 13.0 + 1.0),
			DRIFT_DK.lerp(DRIFT_MID, t))
	# A big soft glow welling up from the bottom centre.
	for i in 9:
		draw_circle(Vector2(640.0, H + 50.0), 560.0 - float(i) * 54.0, Color(DRIFT_GLOW.r, DRIFT_GLOW.g, DRIFT_GLOW.b, 0.05))
	# The churning surface: a wavy bright crest line + puffs of stardust.
	var crest : PackedVector2Array = PackedVector2Array()
	var x : float = 0.0
	while x <= W:
		crest.append(Vector2(x, drift_top + sin(x * 0.012) * 10.0 + sin(x * 0.031 + 1.0) * 6.0))
		x += 24.0
	draw_polyline(crest, Color(DRIFT_GLOW.r, DRIFT_GLOW.g, DRIFT_GLOW.b, 0.7), 2.0)
	for _k in 16:
		var pc : Vector2 = Vector2(rng.randf_range(0.0, W), drift_top + rng.randf_range(-6.0, 40.0))
		draw_circle(pc, rng.randf_range(8.0, 22.0), Color(DRIFT_MID.r, DRIFT_MID.g, DRIFT_MID.b, 0.4))
	# Stardust motes glittering within the drift.
	for _i in 70:
		var pd : Vector2 = Vector2(rng.randf_range(0.0, W), rng.randf_range(drift_top, H))
		var g : Color = DRIFT_GLOW.lightened(0.2)
		draw_circle(pd, rng.randf_range(0.6, 2.1), Color(g.r, g.g, g.b, rng.randf_range(0.3, 0.85)))
	# Rising wisps (faint vertical streaks lifting off the drift).
	for _w in 7:
		var wx : float = rng.randf_range(0.0, W)
		var wtop : float = drift_top - rng.randf_range(40.0, 150.0)
		draw_line(Vector2(wx, drift_top), Vector2(wx + rng.randf_range(-14.0, 14.0), wtop),
			Color(DRIFT_GLOW.r, DRIFT_GLOW.g, DRIFT_GLOW.b, 0.10), rng.randf_range(6.0, 16.0))

	# 6. Vignette + a few floating glimmer motes.
	_draw_vignette(Color(0.04, 0.03, 0.09), 0.55, 140.0)
	for _i in 18:
		var pm : Vector2 = Vector2(rng.randf_range(0.0, W), rng.randf_range(120.0, 600.0))
		draw_circle(pm, rng.randf_range(1.0, 2.0), Color(0.85, 0.80, 0.98, rng.randf_range(0.3, 0.6)))


# ======================================================== SHIP HOLD ===========
# The LOFT backdrop ([[loft-spec]] / YPP Bilging): the board sits INSIDE the rock-
# ship's HOLD — warm planked walls + curved hull ribs, deck beams overhead, barrels
# + crates of cargo, a hanging lantern, and a porthole onto the stardust outside.
# The board (the bilge well) lives centre-screen; the hold dressing fills the gutters.

func _draw_ship_hold(rng: RandomNumberGenerator) -> void:

	var WALL : Color = Color(0.22, 0.15, 0.08)
	var WALL_DK : Color = Color(0.13, 0.08, 0.04)
	var WALL_LT : Color = Color(0.40, 0.27, 0.14)
	var BEAM : Color = Color(0.27, 0.18, 0.09)
	var LAMP : Color = Color(1.0, 0.84, 0.46)

	# 1. Planked back wall + a warm lantern-lit pool over the centre.
	draw_rect(Rect2(0.0, 0.0, W, H), WALL)
	var y : float = 40.0
	while y < H:
		draw_line(Vector2(0.0, y), Vector2(W, y), Color(0.0, 0.0, 0.0, 0.30), 1.5)
		draw_line(Vector2(0.0, y + 1.5), Vector2(W, y + 1.5), Color(WALL_LT.r, WALL_LT.g, WALL_LT.b, 0.18), 1.0)
		y += 46.0
	for i in 7:
		draw_circle(Vector2(640.0, 250.0), 460.0 - float(i) * 56.0, Color(LAMP.r, LAMP.g, LAMP.b, 0.045))

	# 2. Heavy DECK BEAMS overhead (the underside of the deck above the hold).
	draw_rect(Rect2(0.0, 0.0, W, 56.0), BEAM)
	draw_line(Vector2(0.0, 56.0), Vector2(W, 56.0), Color(0.0, 0.0, 0.0, 0.4), 2.0)
	draw_line(Vector2(0.0, 57.5), Vector2(W, 57.5), Color(WALL_LT.r, WALL_LT.g, WALL_LT.b, 0.3), 1.0)
	var bx : float = 90.0
	while bx < W:
		draw_rect(Rect2(bx - 9.0, 0.0, 18.0, 84.0), BEAM.darkened(0.12))
		draw_line(Vector2(bx - 9.0, 0.0), Vector2(bx - 9.0, 84.0), Color(0.0, 0.0, 0.0, 0.3), 1.0)
		bx += 175.0

	# 3. Curved HULL RIBS flanking the hold (the ship's frames bowing out).
	_draw_hold_rib(132.0, -1.0)
	_draw_hold_rib(W - 132.0, 1.0)

	# 4. FLOOR planks at the bottom of the hold.
	draw_rect(Rect2(0.0, H - 84.0, W, 84.0), WALL_DK)
	draw_line(Vector2(0.0, H - 84.0), Vector2(W, H - 84.0), Color(WALL_LT.r, WALL_LT.g, WALL_LT.b, 0.3), 2.0)
	for fx in range(0, int(W), 70):
		draw_line(Vector2(float(fx), H - 84.0), Vector2(float(fx), H), Color(0.0, 0.0, 0.0, 0.28), 1.0)

	# 5. Cargo — barrels + crates stacked in the gutters, on the floor.
	_draw_crate(Vector2(78.0, H - 150.0), 92.0)
	_draw_barrel(Vector2(172.0, H - 122.0))
	_draw_barrel(Vector2(232.0, H - 116.0))
	_draw_barrel(Vector2(1050.0, H - 120.0))
	_draw_crate(Vector2(1170.0, H - 148.0), 86.0)

	# 6. A hanging LANTERN casting the hold's warm light.
	_draw_lantern(Vector2(316.0, 150.0))

	# 7. A PORTHOLE onto the stardust outside (the threat the hull holds back).
	_draw_porthole(rng, Vector2(966.0, 230.0), 52.0)

	# 8. Vignette + a few drifting dust motes.
	_draw_vignette(Color(0.02, 0.015, 0.01), 0.55, 140.0)
	for _i in 16:
		var p : Vector2 = Vector2(rng.randf_range(0.0, W), rng.randf_range(80.0, 600.0))
		draw_circle(p, rng.randf_range(1.0, 1.8), Color(0.85, 0.75, 0.55, rng.randf_range(0.25, 0.5)))


# A bowed timber HULL RIB (a ship's frame), floor-to-ceiling, bowing `dir` toward the
# screen edge in its middle. Thick dark wood + a lit inner edge + iron cross-braces.
func _draw_hold_rib(cx: float, dir: float) -> void:

	var RIB : Color = Color(0.18, 0.11, 0.06)
	var RIB_LT : Color = Color(0.38, 0.25, 0.13)
	var spine : PackedVector2Array = PackedVector2Array()
	var lit : PackedVector2Array = PackedVector2Array()
	for s in 11:
		var t : float = float(s) / 10.0
		var bow : float = sin(t * PI) * 34.0 * dir
		spine.append(Vector2(cx + bow, t * H))
		lit.append(Vector2(cx + bow - dir * 13.0, t * H))
	draw_polyline(spine, RIB, 30.0)
	draw_polyline(lit, RIB_LT, 3.0)
	for by in [120.0, 320.0, 520.0]:
		var t : float = by / H
		var rx : float = cx + sin(t * PI) * 34.0 * dir
		draw_rect(Rect2(rx - 18.0, by - 4.0, 36.0, 8.0), Color(0.26, 0.26, 0.30))
		draw_circle(Vector2(rx - 11.0, by), 2.2, Color(0.5, 0.5, 0.55))
		draw_circle(Vector2(rx + 11.0, by), 2.2, Color(0.5, 0.5, 0.55))


# A wooden BARREL: staves + iron hoops, a lit crown.
func _draw_barrel(c: Vector2) -> void:

	var BODY : Color = Color(0.40, 0.27, 0.14)
	var HOOP : Color = Color(0.28, 0.28, 0.32)
	var w : float = 46.0
	var h : float = 66.0
	var r : Rect2 = Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h)
	draw_rect(r, BODY)
	draw_rect(Rect2(r.position, Vector2(w, h * 0.30)), BODY.lightened(0.12))
	draw_rect(Rect2(Vector2(r.position.x, r.end.y - h * 0.26), Vector2(w, h * 0.26)), BODY.darkened(0.18))
	for sx in [0.3, 0.5, 0.7]:
		draw_line(Vector2(r.position.x + w * sx, r.position.y + 2.0), Vector2(r.position.x + w * sx, r.end.y - 2.0),
			Color(0.0, 0.0, 0.0, 0.22), 1.0)
	for hy in [0.16, 0.5, 0.84]:
		var yy : float = r.position.y + h * hy
		draw_rect(Rect2(r.position.x - 1.0, yy - 3.0, w + 2.0, 6.0), HOOP)
		draw_line(Vector2(r.position.x - 1.0, yy - 2.0), Vector2(r.end.x + 1.0, yy - 2.0), HOOP.lightened(0.3), 1.0)


# A wooden CRATE: planked box with an X-brace + a corner-bracket frame.
func _draw_crate(c: Vector2, sz: float) -> void:

	var BODY : Color = Color(0.42, 0.29, 0.15)
	var r : Rect2 = Rect2(c.x - sz * 0.5, c.y - sz * 0.5, sz, sz)
	draw_rect(r, BODY)
	draw_rect(Rect2(r.position, Vector2(sz, sz * 0.5)), BODY.lightened(0.08))
	draw_rect(r, BODY.darkened(0.45), false, 3.0)
	draw_rect(r.grow(-7.0), BODY.darkened(0.32), false, 2.0)
	draw_line(r.position, r.end, BODY.lightened(0.14), 2.5)
	draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), BODY.lightened(0.14), 2.5)


# A hanging LANTERN: chain, a warm glow, a brass cage + glass.
func _draw_lantern(pos: Vector2) -> void:

	var GLOW : Color = Color(1.0, 0.82, 0.42)
	var BRASS : Color = Color(0.30, 0.20, 0.10)
	draw_line(Vector2(pos.x, 0.0), Vector2(pos.x, pos.y - 14.0), Color(0.16, 0.12, 0.07), 2.0)
	for i in 7:
		draw_circle(pos, 110.0 - float(i) * 14.0, Color(GLOW.r, GLOW.g, GLOW.b, 0.05))
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-11.0, -12.0), pos + Vector2(11.0, -12.0), pos + Vector2(14.0, 8.0),
		pos + Vector2(0.0, 18.0), pos + Vector2(-14.0, 8.0)]), BRASS)
	draw_circle(pos, 8.0, Color(1.0, 0.90, 0.58))
	draw_circle(pos, 4.0, Color(1.0, 0.97, 0.8))


# A PORTHOLE onto the stardust outside: a glowing void disc in a bolted brass ring.
func _draw_porthole(rng: RandomNumberGenerator, c: Vector2, r: float) -> void:

	var DUST : Color = Color(0.45, 0.30, 0.74)
	var BRASS : Color = Color(0.66, 0.50, 0.24)
	draw_circle(c, r, Color(0.10, 0.07, 0.18))
	draw_circle(c, r * 0.92, DUST.darkened(0.2))
	draw_circle(c, r * 0.55, DUST)
	for _i in 7:
		var a : float = rng.randf_range(0.0, TAU)
		var d : float = rng.randf_range(0.0, r * 0.82)
		draw_circle(c + Vector2(cos(a), sin(a)) * d, rng.randf_range(0.6, 1.6), Color(0.92, 0.88, 1.0, 0.8))
	draw_arc(c, r, 0.0, TAU, 40, BRASS, 5.0)
	draw_arc(c, r - 2.0, 0.0, TAU, 40, BRASS.lightened(0.25), 1.5)
	for i in 8:
		var ang : float = float(i) / 8.0 * TAU
		draw_circle(c + Vector2(cos(ang), sin(ang)) * r, 2.2, BRASS.darkened(0.3))


# ====================================================== HULL REPAIR ===========
# The PATCHWORKS backdrop ([[patchworks-spec]]): you're sealing the ship's hull
# against the STARDUST VOID outside (what the breaches open onto). The grid is the
# damaged hull section; warm timber ribs + work-lanterns + hanging tools frame it,
# against the cool glowing void — the contrast IS the stakes (warm ship vs cold drift).

func _draw_hull_repair(rng: RandomNumberGenerator) -> void:

	var VOID_TOP : Color = Color(0.10, 0.07, 0.18)
	var VOID_MID : Color = Color(0.19, 0.12, 0.32)
	var GLOW : Color = Color(0.52, 0.34, 0.82)
	var STAR : Color = Color(0.90, 0.86, 1.0)
	var BEAM : Color = Color(0.26, 0.17, 0.09)

	# 1. The stardust VOID outside the hull (cool, glowing) — what the breaches open to.
	for i in 16:
		var t : float = float(i) / 15.0
		draw_rect(Rect2(0.0, H * float(i) / 16.0, W, H / 16.0 + 1.0), VOID_TOP.lerp(VOID_MID, t))
	for _i in 70:
		var p : Vector2 = Vector2(rng.randf_range(0.0, W), rng.randf_range(0.0, H * 0.75))
		draw_circle(p, rng.randf_range(0.5, 1.5), Color(STAR.r, STAR.g, STAR.b, rng.randf_range(0.25, 0.8)))
	for i in 8:
		draw_circle(Vector2(640.0, H + 40.0), 520.0 - float(i) * 54.0, Color(GLOW.r, GLOW.g, GLOW.b, 0.05))
	for _w in 6:
		var wx : float = rng.randf_range(0.0, W)
		draw_line(Vector2(wx, H * 0.7), Vector2(wx + rng.randf_range(-12.0, 12.0), H * 0.7 - rng.randf_range(60.0, 160.0)),
			Color(GLOW.r, GLOW.g, GLOW.b, 0.08), rng.randf_range(6.0, 14.0))

	# 2. Heavy DECK BEAM overhead + drop-beams (the ship structure above the work).
	draw_rect(Rect2(0.0, 0.0, W, 54.0), BEAM)
	draw_line(Vector2(0.0, 54.0), Vector2(W, 54.0), Color(0.0, 0.0, 0.0, 0.4), 2.0)
	var bx : float = 120.0
	while bx < W:
		draw_rect(Rect2(bx - 8.0, 0.0, 16.0, 78.0), BEAM.darkened(0.12))
		bx += 200.0

	# 3. Flanking HULL RIBS (warm timber against the void) — reusing the hold rib.
	_draw_hold_rib(108.0, -1.0)
	_draw_hold_rib(W - 108.0, 1.0)

	# 4. Work-LANTERNS lighting the repair.
	_draw_lantern(Vector2(268.0, 150.0))
	_draw_lantern(Vector2(W - 268.0, 150.0))

	# 5. Hanging TOOLS — a saw on the left rib, a mallet on the right.
	_draw_saw(Vector2(176.0, 256.0))
	_draw_mallet(Vector2(W - 176.0, 256.0))

	# 6. Sawdust motes + vignette.
	_draw_vignette(Color(0.03, 0.02, 0.06), 0.55, 140.0)
	for _i in 16:
		var pm : Vector2 = Vector2(rng.randf_range(0.0, W), rng.randf_range(80.0, 620.0))
		draw_circle(pm, rng.randf_range(1.0, 1.8), Color(0.82, 0.72, 0.52, rng.randf_range(0.25, 0.5)))


# A hand-SAW hanging from a hook: a wood handle + a toothed steel blade.
func _draw_saw(pos: Vector2) -> void:

	var STEEL : Color = Color(0.46, 0.48, 0.53)
	var WOOD : Color = Color(0.40, 0.26, 0.13)
	draw_line(Vector2(pos.x, pos.y - 40.0), Vector2(pos.x, 54.0), Color(0.16, 0.11, 0.06), 1.5)
	draw_rect(Rect2(pos.x - 11.0, pos.y - 44.0, 24.0, 13.0), WOOD)
	draw_rect(Rect2(pos.x - 11.0, pos.y - 44.0, 24.0, 13.0), WOOD.darkened(0.4), false, 1.5)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-7.0, -34.0), pos + Vector2(9.0, -34.0), pos + Vector2(19.0, 66.0), pos + Vector2(7.0, 66.0)]), STEEL)
	for i in 9:   # teeth down the cutting edge
		var ty : float = pos.y - 28.0 + float(i) * 10.0
		draw_line(Vector2(pos.x + 9.0 + float(i) * 0.6, ty), Vector2(pos.x + 13.0 + float(i) * 0.6, ty + 3.0), STEEL.darkened(0.3), 1.0)


# A wooden MALLET hanging from a hook: a block head on a handle.
func _draw_mallet(pos: Vector2) -> void:

	var WOOD : Color = Color(0.42, 0.28, 0.14)
	draw_line(Vector2(pos.x, pos.y - 30.0), Vector2(pos.x, 54.0), Color(0.16, 0.11, 0.06), 1.5)
	draw_rect(Rect2(pos.x - 3.0, pos.y - 26.0, 6.0, 78.0), WOOD)               # handle
	draw_rect(Rect2(pos.x - 17.0, pos.y - 34.0, 34.0, 22.0), WOOD.darkened(0.12))  # head
	draw_rect(Rect2(pos.x - 17.0, pos.y - 34.0, 34.0, 22.0), WOOD.darkened(0.42), false, 1.5)
	draw_rect(Rect2(pos.x - 17.0, pos.y - 34.0, 34.0, 7.0), WOOD.lightened(0.12))   # lit top band


# =========================================================== TAVERN ===========
# The POKER backdrop: a cosy sky-tavern parlour the card table sits in — a warm
# planked back wall with a hearth + lanterns, a receding PLANK FLOOR, and stools +
# barrels as dressing in the gutters (the felt oval covers the centre, so the
# tavern reads around its rim). (Troy 2026-06-16.)

func _draw_tavern(rng: RandomNumberGenerator) -> void:

	var WALL : Color = Color(0.21, 0.14, 0.08)
	var WALL_DK : Color = Color(0.12, 0.08, 0.05)
	var WALL_LT : Color = Color(0.37, 0.25, 0.14)
	var FLOOR : Color = Color(0.32, 0.21, 0.12)
	var FLOOR_LT : Color = Color(0.45, 0.31, 0.17)
	var horizon : float = 152.0
	var vanish : Vector2 = Vector2(640.0, horizon)

	# 1. PLANK FLOOR — receding boards (seams converge to a vanishing point) + rows.
	draw_rect(Rect2(0.0, 0.0, W, H), FLOOR)
	for i in 17:
		var fx : float = lerpf(-220.0, W + 220.0, float(i) / 16.0)
		draw_line(Vector2(fx, H), vanish, Color(0.0, 0.0, 0.0, 0.22), 1.5)
		draw_line(Vector2(fx + 3.0, H), vanish, Color(FLOOR_LT.r, FLOOR_LT.g, FLOOR_LT.b, 0.10), 1.0)
	for i in 7:
		var t : float = float(i) / 6.0
		var yy : float = lerpf(H, horizon + 18.0, t * t)
		draw_line(Vector2(0.0, yy), Vector2(W, yy), Color(0.0, 0.0, 0.0, 0.15), 1.5)

	# 2. Back WALL (top band, planked) + a baseboard beam at the floor line.
	draw_rect(Rect2(0.0, 0.0, W, horizon), WALL)
	for i in 4:
		var wy : float = float(i) * (horizon / 4.0)
		draw_line(Vector2(0.0, wy), Vector2(W, wy), Color(0.0, 0.0, 0.0, 0.30), 1.5)
		draw_line(Vector2(0.0, wy + 1.5), Vector2(W, wy + 1.5), Color(WALL_LT.r, WALL_LT.g, WALL_LT.b, 0.16), 1.0)
	var studx : float = 86.0
	while studx < W:
		draw_line(Vector2(studx, 0.0), Vector2(studx, horizon), Color(0.0, 0.0, 0.0, 0.16), 1.0)
		studx += 132.0
	draw_rect(Rect2(0.0, horizon - 7.0, W, 7.0), WALL_DK)
	draw_line(Vector2(0.0, horizon - 7.0), Vector2(W, horizon - 7.0), Color(WALL_LT.r, WALL_LT.g, WALL_LT.b, 0.30), 1.5)

	# 3. A HEARTH on the back wall + flanking lanterns.
	_draw_hearth(Vector2(640.0, 8.0))
	_draw_lantern(Vector2(150.0, 66.0))
	_draw_lantern(Vector2(1130.0, 66.0))

	# 4. STOOLS + BARRELS dressing the gutters (clear of the felt + seat ring).
	_draw_stool(Vector2(70.0, 432.0))
	_draw_stool(Vector2(1210.0, 432.0))
	_draw_stool(Vector2(70.0, 612.0))
	_draw_stool(Vector2(1210.0, 612.0))
	_draw_barrel(Vector2(152.0, 668.0))
	_draw_barrel(Vector2(1128.0, 668.0))

	# 5. Warm vignette + a few dust motes drifting in the lamp light.
	_draw_vignette(Color(0.03, 0.02, 0.01), 0.5, 150.0)
	for _i in 14:
		var pm : Vector2 = Vector2(rng.randf_range(0.0, W), rng.randf_range(120.0, 600.0))
		draw_circle(pm, rng.randf_range(1.0, 1.8), Color(0.85, 0.72, 0.50, rng.randf_range(0.2, 0.45)))


# A stone HEARTH with a live fire + a wooden mantel — the tavern's warm heart.
# `top` is the top-centre of the surround.
func _draw_hearth(top: Vector2) -> void:

	var STONE : Color = Color(0.33, 0.31, 0.29)
	var STONE_DK : Color = Color(0.18, 0.17, 0.16)
	var FIRE : Color = Color(1.0, 0.6, 0.22)
	var w : float = 156.0
	var h : float = 96.0
	var x0 : float = top.x - w * 0.5
	for i in 6:   # warm glow pool
		draw_circle(Vector2(top.x, top.y + h * 0.8), 168.0 - float(i) * 24.0, Color(FIRE.r, FIRE.g, FIRE.b, 0.05))
	draw_rect(Rect2(x0, top.y, w, h), STONE)
	draw_rect(Rect2(x0, top.y, w, h), STONE_DK, false, 3.0)
	for by in [0.34, 0.66]:   # mortar courses
		draw_line(Vector2(x0, top.y + h * by), Vector2(x0 + w, top.y + h * by), STONE_DK, 1.5)
	var op : Rect2 = Rect2(x0 + 24.0, top.y + 20.0, w - 48.0, h - 20.0)
	draw_rect(op, Color(0.05, 0.03, 0.02))
	var fb : Vector2 = Vector2(top.x, op.end.y - 6.0)
	for i in 5:   # fire bed glow
		draw_circle(fb, 30.0 - float(i) * 5.0, Color(FIRE.r, FIRE.g, FIRE.b, 0.38))
	for f in 3:   # flames
		var fx : float = top.x + (float(f) - 1.0) * 17.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(fx - 8.0, op.end.y - 4.0), Vector2(fx, op.end.y - 34.0), Vector2(fx + 8.0, op.end.y - 4.0)]),
			Color(1.0, 0.76, 0.32, 0.9))
	draw_line(Vector2(op.position.x + 6.0, op.end.y - 5.0), Vector2(op.end.x - 6.0, op.end.y - 5.0), Color(0.22, 0.13, 0.07), 5.0)  # log
	draw_rect(Rect2(x0 - 12.0, top.y - 9.0, w + 24.0, 13.0), Color(0.31, 0.21, 0.11))   # mantel beam
	draw_line(Vector2(x0 - 12.0, top.y - 9.0), Vector2(x0 + w + 12.0, top.y - 9.0), Color(0.50, 0.34, 0.18), 1.5)


# A wooden bar STOOL: a round seat on three splayed legs with a rung.
func _draw_stool(c: Vector2) -> void:

	var WOOD : Color = Color(0.36, 0.24, 0.13)
	var WOOD_DK : Color = Color(0.20, 0.13, 0.07)
	var WOOD_LT : Color = Color(0.50, 0.34, 0.18)
	draw_line(c + Vector2(-15.0, 4.0), c + Vector2(-22.0, 48.0), WOOD_DK, 4.0)
	draw_line(c + Vector2(15.0, 4.0), c + Vector2(22.0, 48.0), WOOD_DK, 4.0)
	draw_line(c + Vector2(0.0, 6.0), c + Vector2(0.0, 52.0), WOOD_DK, 4.0)
	draw_line(c + Vector2(-18.0, 30.0), c + Vector2(18.0, 30.0), WOOD, 3.0)   # rung
	draw_colored_polygon(_ellipse_pts_bd(c, 25.0, 9.0), WOOD)
	draw_colored_polygon(_ellipse_pts_bd(c + Vector2(0.0, -2.0), 25.0, 8.0), WOOD_LT)
	var loop : PackedVector2Array = _ellipse_pts_bd(c, 25.0, 9.0)
	loop.append(loop[0])
	draw_polyline(loop, WOOD_DK, 1.5)


func _ellipse_pts_bd(c: Vector2, rx: float, ry: float) -> PackedVector2Array:

	var p : PackedVector2Array = PackedVector2Array()
	for i in 20:
		var a : float = float(i) / 20.0 * TAU
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p


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
