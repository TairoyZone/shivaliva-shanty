## DEV-ONLY: verify permanent door-unlock + trashable keys — discarding a key must NOT re-lock its door, and a
## re-grant (the load backfill) must NOT re-add a discarded key.
extends Node
func _ready() -> void:
	call_deferred("_go")
func _go() -> void:
	var fails := 0
	var MINE := PlayerState.KEY_MINE
	PlayerState.unlocked_doors = []
	for i in PlayerState.inventory.size():
		var s : Dictionary = PlayerState.inventory[i]
		if not s.is_empty() and String(s.get("id", "")).begins_with("key_"):
			PlayerState.inventory[i] = {}

	# GRANT: unlocks + lands the keepsake.
	PlayerState.grant_key(MINE)
	if not PlayerState.door_unlocked(MINE): fails += 1; print("FAIL: not unlocked after grant")
	if PlayerState.item_count(MINE) <= 0: fails += 1; print("FAIL: key keepsake not in bag")

	# DISCARD the key → item gone, but the door stays unlocked.
	var slot := -1
	for i in PlayerState.inventory.size():
		if not (PlayerState.inventory[i] as Dictionary).is_empty() and PlayerState.inventory[i]["id"] == MINE: slot = i
	PlayerState.discard_inventory(slot, -1)
	print("after discard: item_count=", PlayerState.item_count(MINE), " door_unlocked=", PlayerState.door_unlocked(MINE))
	if PlayerState.item_count(MINE) > 0: fails += 1; print("FAIL: key not discarded")
	if not PlayerState.door_unlocked(MINE): fails += 1; print("FAIL: DOOR RE-LOCKED after discarding the key!")

	# RE-GRANT (mimics the load backfill) must be a no-op — no re-minted key.
	if PlayerState.grant_key(MINE): fails += 1; print("FAIL: grant_key re-minted an earned key")
	if PlayerState.item_count(MINE) > 0: fails += 1; print("FAIL: re-grant re-added the discarded key")

	# PERSIST the unlock across save/reload.
	PlayerState._save()
	PlayerState.unlocked_doors = []
	PlayerState._load()
	if not PlayerState.door_unlocked(MINE): fails += 1; print("FAIL: unlock did not persist")

	print("KEYS TEST: %s (%d fail) | unlocked=%s" % ["PASS" if fails == 0 else "FAIL", fails, str(PlayerState.unlocked_doors)])
	get_tree().quit()
