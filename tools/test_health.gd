## DEV-ONLY logic test for the fighter-health mechanic (Slice A). Prints PASS/FAIL for the health ->
## starting-footing mapping, damage/restore clamping, and the full-health check. Caller backs up the save.
extends Node


func _ready() -> void:
	call_deferred("_go")


func _go() -> void:

	var fails : int = 0
	var P : Object = PlayerState

	# 1) health -> footing clumps: clampi((100 - h) / 20, 0, 5)
	var cases : Array = [[100, 0], [99, 0], [80, 1], [79, 1], [60, 2], [40, 3], [20, 4], [1, 4], [0, 5]]
	for c in cases:
		P.health = int(c[0])
		var got : int = P.health_footing_clumps()
		if got != int(c[1]):
			fails += 1
			print("FAIL footing: health %d -> %d (expected %d)" % [int(c[0]), got, int(c[1])])

	# 2) damage clamps at 0
	P.health = 10
	P.damage_health(20)
	if P.health != 0:
		fails += 1
		print("FAIL damage clamp: expected 0, got %d" % P.health)

	# 3) restore tops up to max, is_full_health true
	P.restore_health()
	if P.health != P.HEALTH_MAX or not P.is_full_health():
		fails += 1
		print("FAIL restore: expected full, got %d (full=%s)" % [P.health, str(P.is_full_health())])

	# 4) default defeat damage
	P.health = P.HEALTH_MAX
	P.damage_health()
	if P.health != P.HEALTH_MAX - P.HEALTH_PER_DEFEAT:
		fails += 1
		print("FAIL defeat: expected %d, got %d" % [P.HEALTH_MAX - P.HEALTH_PER_DEFEAT, P.health])
	if P.health_footing_clumps() != 1:
		fails += 1
		print("FAIL defeat footing: expected 1 clump after one defeat, got %d" % P.health_footing_clumps())

	print("HEALTH TEST: %s (%d failure(s))" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit()
