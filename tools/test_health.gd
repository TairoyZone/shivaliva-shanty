## DEV-ONLY logic test for the fighter-health mechanic (Slice A). Prints PASS/FAIL for the health ->
## starting-footing mapping, damage/restore clamping, and the full-health check. Caller backs up the save.
extends Node


func _ready() -> void:
	call_deferred("_go")


func _go() -> void:

	var fails : int = 0
	var P : Object = PlayerState

	# 1) health -> footing FILL fraction: (1 - h/100) * 0.80
	var cases : Array = [[100, 0.0], [80, 0.16], [50, 0.40], [20, 0.64], [0, 0.80]]
	for c in cases:
		P.health = int(c[0])
		var got : float = P.health_footing_fill()
		if absf(got - float(c[1])) > 0.001:
			fails += 1
			print("FAIL footing: health %d -> %.3f (expected %.3f)" % [int(c[0]), got, float(c[1])])

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
	# one defeat (health 80) → fill (1 - 0.8)*0.8 = 0.16
	if absf(P.health_footing_fill() - 0.16) > 0.001:
		fails += 1
		print("FAIL defeat footing: expected 0.16 fill after one defeat, got %.3f" % P.health_footing_fill())

	print("HEALTH TEST: %s (%d failure(s))" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit()
