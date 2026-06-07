## UserPanel (autoload) — the persistent "Sunshine widget" side panel (researched from YPPedia's Happy
## Sunshine Widget). A foldable tab RAIL docked on the RIGHT, present EVERYWHERE the player is — the
## overworld AND inside puzzles (right beside the board) — and hidden only on the title. Wraps the
## [InventoryPanel] Control (the rail + Tutorial / Backpack / Hearts / Profile tabs + a Jobs launcher; the
## Ahoy / trophy-claim tab is coming). Unlike the [HUD] (which hides in puzzles), THIS stays up, which is
## the whole point — help + your stuff are always one click away. The HUD delegates open/close/etc. here.
extends CanvasLayer


var _panel : InventoryPanel
var _last_scene : Node = null


func _ready() -> void:

	layer = 11   # above the world; below the puzzle Leave button (20) + the event feed (15)
	_panel = InventoryPanel.new()
	add_child(_panel)
	visible = false


func _process(_delta: float) -> void:

	# Fold the pane on any scene change (entering/leaving a puzzle) so it never lingers open across a cut.
	var scene : Node = get_tree().current_scene if get_tree() != null else null
	if scene != _last_scene:
		_last_scene = scene
		if _panel != null:
			_panel.close()
	visible = _should_show()


# Show in the overworld (the HUD is up) and inside puzzles (a PuzzleScene is current); hide on the title.
func _should_show() -> bool:

	var scene : Node = get_tree().current_scene if get_tree() != null else null
	if scene == null:
		return false
	if scene is PuzzleScene:
		return true
	return HUD != null and HUD.visible


# --- delegated API (the HUD + PuzzleScene call these) ----------------

func open(tab: String = "items") -> void:
	_panel.open(tab)

func close() -> void:
	_panel.close()

func toggle() -> void:
	_panel.toggle()

func is_open() -> bool:
	return _panel != null and _panel.is_open()

func current_tab() -> String:
	return _panel.current_tab()

func bump_backpack() -> void:
	_panel.bump_backpack()

func set_puzzle_help(text: String) -> void:
	_panel.set_puzzle_help(text)
