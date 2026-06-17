## DEV-ONLY: verify the power-type system — gate, choose, equip, gossip, the Mystic scatter, and persistence.
extends Node
func _ready() -> void:
	call_deferred("_go")
func _go() -> void:
	var fails := 0
	PlayerState.player_name = "Bulldog"
	PlayerState.player_power_type = ""
	PlayerState.recent_happenings = []

	# GATE: no type chosen yet.
	if PlayerState.has_power_type(): fails += 1; print("FAIL: has_power_type true before choosing")

	# CHOOSE: sets the class + equips it + gossips.
	PlayerState.choose_power_type("mystic")
	if not PlayerState.has_power_type(): fails += 1; print("FAIL: not chosen after choose")
	if PlayerState.player_power_type != "mystic": fails += 1; print("FAIL: type != mystic")
	if PlayerState.equipped_weapon != "mystic": fails += 1; print("FAIL: equipped_weapon not set to the type")
	var gossiped := false
	for e in PlayerState.recent_happenings:
		if "Mystic's path" in String(e.get("text", "")): gossiped = true
	print("CHOICE gossiped: ", gossiped)
	if not gossiped: fails += 1

	# MYSTIC attack = a scatter spanning several columns (chaos), with the mystic colour.
	var atk : Dictionary = SkirmishWeapon.make_attack("mystic", 8, null, 1)
	var cols := {}
	for c in atk["shape"]: cols[c.x] = true
	print("MYSTIC attack: cells=", atk["shape"].size(), " distinct_cols=", cols.size())
	if cols.size() < 3: fails += 1; print("FAIL: mystic not spread across columns")
	if atk["color"] != SkirmishWeapon.COLOR_MYSTIC: fails += 1; print("FAIL: mystic colour wrong")

	# NAMES: power-type labels.
	print("NAMES: ", SkirmishWeapon.power_type_name("long_range"), " / ", SkirmishWeapon.power_type_name("brawl"))
	if SkirmishWeapon.power_type_name("long_range") != "Marksman": fails += 1; print("FAIL: power_type_name")
	if SkirmishWeapon.ALL.size() != 4: fails += 1; print("FAIL: expected 4 types, got %d" % SkirmishWeapon.ALL.size())

	# PERSIST across save/reload.
	PlayerState._save()
	PlayerState.player_power_type = ""
	PlayerState._load()
	print("PERSIST: ", PlayerState.player_power_type)
	if PlayerState.player_power_type != "mystic": fails += 1; print("FAIL: did not persist")

	print("POWER TEST: %s (%d fail)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit()
