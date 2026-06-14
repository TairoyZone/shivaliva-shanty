## DEV-ONLY: build side-by-side BEFORE/AFTER collages for marketing, from
## clean 1280x720 frames already saved in user://shots. Captures one collage
## PNG per pair. Windowed; caller backs up the save. Not shipped.
extends Node2D

const OUT : String = "user://shots"
const PAIRS : Array = [
	["gemdrop_before.png", "gemdrop_after.png", "gemdrop_before_after.png", "Gem Drop  -  the Stardust Well glow-up"],
	["mining_before.png", "mining_after.png", "mining_before_after.png", "Mining  -  honest dirt, treasure that pops"],
]

var _before : Texture2D = null
var _after : Texture2D = null
var _title : String = ""


func _ready() -> void:

	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_go")


func _go() -> void:

	_hide_autoload_ui()
	for p in PAIRS:
		_before = _tex(p[0])
		_after = _tex(p[1])
		_title = p[3]
		_hide_autoload_ui()   # re-hide in case an autoload re-showed itself
		queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		var img : Image = get_viewport().get_texture().get_image()
		img.save_png("%s/%s" % [OUT, p[2]])
	get_tree().quit()


# Hide the autoload UI subtrees (they may be CanvasLayers OR plain Controls) so
# only this Node2D's collage shows; its opaque background covers the rest.
func _hide_autoload_ui() -> void:
	for n in ["HUD", "Overlay", "EventFeed", "ChatBox", "UserPanel"]:
		var node : Node = get_node_or_null("/root/" + n)
		if node:
			_hide_subtree(node)

func _hide_subtree(node: Node) -> void:
	if node is CanvasItem or node is CanvasLayer:
		node.visible = false
	for c in node.get_children():
		_hide_subtree(c)


func _tex(file_name: String) -> Texture2D:

	var img : Image = Image.new()
	if img.load("%s/%s" % [OUT, file_name]) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _draw() -> void:

	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color(0.05, 0.06, 0.09, 1.0))
	if _before == null or _after == null:
		return
	var font : Font = ThemeDB.fallback_font
	var iw : float = 600.0
	var ih : float = 337.5
	var y : float = 150.0
	var lx : float = 20.0
	var rx : float = 660.0
	draw_string(font, Vector2(40.0, 60.0), _title, HORIZONTAL_ALIGNMENT_LEFT, 1200, 34, Color(0.96, 0.82, 0.40, 1.0))
	draw_string(font, Vector2(lx + iw * 0.5 - 44.0, y - 16.0), "BEFORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.92, 0.55, 0.50, 1.0))
	draw_string(font, Vector2(rx + iw * 0.5 - 36.0, y - 16.0), "AFTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.55, 0.92, 0.60, 1.0))
	draw_texture_rect(_before, Rect2(Vector2(lx, y), Vector2(iw, ih)), false)
	draw_texture_rect(_after, Rect2(Vector2(rx, y), Vector2(iw, ih)), false)
	draw_rect(Rect2(Vector2(lx, y), Vector2(iw, ih)), Color(0.78, 0.58, 0.24, 1.0), false, 2.0)
	draw_rect(Rect2(Vector2(rx, y), Vector2(iw, ih)), Color(0.78, 0.58, 0.24, 1.0), false, 2.0)
	draw_string(font, Vector2(40.0, y + ih + 50.0), "Shivaliva Shanty   .   tairoyzone.itch.io/shivaliva-shanty   .   Trojan Bulldog",
		HORIZONTAL_ALIGNMENT_LEFT, 1200, 20, Color(0.60, 0.66, 0.78, 1.0))
