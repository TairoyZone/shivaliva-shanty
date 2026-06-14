## DEV-ONLY screenshot for the poker felt + the parchment chat Log (Troy 2026-06-14 aesthetics pass). Draws a
## faithful copy of the felt vignette, seeds sample chat lines through the REAL ChatBox log (player/NPC/announcer
## + suit glyphs), and captures before/after opening the Log. Windowed (headless can't render); caller backs up
## the save. Not shipped.
extends Node2D

const OUT : String = "user://shots"
const CENTER : Vector2 = Vector2(640.0, 250.0)


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	await get_tree().process_frame
	await _capture("pretty_felt")   # felt alone (log still closed)

	# Seed the parchment Log with one of each bucket + suit glyphs, via the REAL log path.
	PlayerState.log_event("You: nice flop", ChatBox.CHAT_COLOR)
	PlayerState.log_event("Flint Kerr: don't get comfortable, traveller", ChatBox.NPC_CHAT_COLOR)
	PlayerState.log_event("Hearty Brian: ha, lucky one.", ChatBox.NPC_CHAT_COLOR)
	PlayerState.log_event("Flop: A♥ 3♦ K♠")            # announcer (gold default) — red + black suits
	PlayerState.log_event("Turn: J♣")
	PlayerState.log_event("River: 9♥")
	PlayerState.log_event("Cinder Troy has Two pair, Aces and Kings.")
	PlayerState.log_event("Troy won 240 from the pot.")
	PlayerState.log_event("Ranked up: Gem Drop — Hand")
	if ChatBox.has_method("_toggle_log"):
		ChatBox._toggle_log()
	else:
		ChatBox._log_panel.visible = true
		ChatBox._log_open = true
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	await _capture("pretty_chatlog")
	get_tree().quit()


func _capture(shot_name: String) -> void:

	var img : Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT, shot_name])
	await get_tree().process_frame


# A faithful copy of poker_scene._draw's felt, so this PNG shows exactly what the table renders.
func _draw() -> void:

	_stad(CENTER, Vector2(1016.0, 482.0), Color(0.28, 0.18, 0.09))
	_stad(CENTER, Vector2(1004.0, 470.0), Color(0.20, 0.13, 0.06))
	_stad(CENTER, Vector2(1000.0, 466.0), Color(0.80, 0.60, 0.26))
	_stad(CENTER, Vector2(986.0, 452.0), Color(0.55, 0.40, 0.16))
	var felt_rim : Color = Color(0.085, 0.24, 0.15)
	var felt_lit : Color = Color(0.185, 0.46, 0.29)
	var edge : Vector2 = Vector2(972.0, 438.0)
	var core : Vector2 = Vector2(330.0, 150.0)
	for i in 22:
		var t : float = float(i) / 21.0
		_stad(CENTER, edge.lerp(core, t), felt_rim.lerp(felt_lit, smoothstep(0.0, 1.0, t)))


func _stad(c: Vector2, sz: Vector2, color: Color) -> void:

	var r : float = sz.y * 0.5
	var mid : float = maxf(sz.x * 0.5 - r, 0.0)
	if mid > 0.0:
		draw_rect(Rect2(c.x - mid, c.y - r, mid * 2.0, r * 2.0), color, true)
	draw_circle(Vector2(c.x - mid, c.y), r, color)
	draw_circle(Vector2(c.x + mid, c.y), r, color)
