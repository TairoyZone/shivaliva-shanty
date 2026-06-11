## DEV-ONLY screenshot harness (not shipped). Boots as a throwaway scene, seeds a little PlayerState, opens the
## new UI in code, and saves PNGs to user://shots/ so Claude can eyeball the LAYOUT/RENDER of panels it can't
## otherwise see. Runs WINDOWED (headless can't render). The caller backs up + restores the real save.
extends Control

const OUT : String = "user://shots"


func _ready() -> void:

	set_anchors_preset(Control.PRESET_FULL_RECT)
	DirAccess.make_dir_recursive_absolute(OUT)
	# Seed enough state for the panels to have content.
	PlayerState.add_coins(500)
	PlayerState.add_item("wood", 12)
	PlayerState.add_item("ore", 6)
	PlayerState.add_item("sword", 1)              # a weapon-as-item in the bag
	PlayerState.add_affinity("Mossy Jade", 85)    # Confidant — vow-eligible
	PlayerState.set_romance_stage("Mossy Jade", 2)  # Smitten
	await get_tree().process_frame

	# 1 + 2. Romance vow modal — the PROMPT, then the drawn-heart RESULT.
	var vow : RomanceVowModal = RomanceVowModal.new()
	vow._npc_name = "Mossy Jade"
	vow._npc_color = Color(0.30, 0.62, 0.36, 1.0)
	get_tree().root.add_child(vow)
	await _settle()
	await _capture("01_romance_vow_prompt")
	vow._on_yes()                                  # trigger the deterministic vow → the heart result screen
	await _settle()
	await _capture("02_romance_vow_heart")
	vow.queue_free()
	await get_tree().process_frame

	# 3. Trade window — the drag-drop layout (Offering drop-zone + draggable bag cells).
	var trade : TradeWindow = TradeWindow.new()
	trade._npc_name = "Mossy Jade"
	trade._npc_color = Color(0.30, 0.62, 0.36, 1.0)
	trade._liked_item = "wood"
	get_tree().root.add_child(trade)
	await _settle()
	await _capture("03_trade_window")
	trade.queue_free()

	await get_tree().process_frame
	get_tree().quit()


func _settle() -> void:

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout   # let the ModalFx pop-in + any tween settle


func _capture(shot_name: String) -> void:

	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT, shot_name])
	await get_tree().process_frame
