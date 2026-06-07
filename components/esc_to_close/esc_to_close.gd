## EscToClose — drop this as a CHILD of any closable window/modal and ESC will close it. STANDING RULE
## (Troy 2026-06-07): every window that can be exited must exit on ESC. Instead of copying an ESC handler
## into every panel, add ONE of these: `add_child(EscToClose.new(_close))` (or any close Callable). It
## processes ALWAYS, so it works even while the modal pauses the tree, and it CONSUMES the key so a
## stacked HUD/parent doesn't also act on it. See [[esc-closes-every-window]].
class_name EscToClose
extends Node

var _close : Callable
## Optional open-check: when set, ESC only acts if it returns true. For PERSISTENT modals that stay in the
## tree and toggle a CHILD's visibility (not their own) — e.g. the Overlay autoload — where the parent
## visibility guard can't tell they're closed. Transient (freed-on-close) modals don't need it.
var _is_open : Callable


func _init(close_action: Callable = Callable(), is_open: Callable = Callable()) -> void:

	_close = close_action
	_is_open = is_open


func _ready() -> void:

	process_mode = Node.PROCESS_MODE_ALWAYS


# Uses _input (not _unhandled_input) so an open modal's ESC is consumed BEFORE the HUD's _unhandled_input
# (which would otherwise also open the pause menu on the same press). Only ever acts on ui_cancel.
func _input(event: InputEvent) -> void:

	if not event.is_action_pressed("ui_cancel") or not _close.is_valid():
		return
	# Explicit open-check first (persistent modals that toggle a child, not themselves).
	if _is_open.is_valid() and not bool(_is_open.call()):
		return
	# Don't swallow ESC when the modal isn't actually showing — some windows persist hidden (the Overlay
	# autoload, toggled shop panels) and would otherwise eat every ESC in the game.
	var p : Node = get_parent()
	if p is CanvasItem and not (p as CanvasItem).is_visible_in_tree():
		return
	if p is CanvasLayer and not (p as CanvasLayer).visible:
		return
	var vp : Viewport = get_viewport()   # capture before the close (it may free us / change scene)
	_close.call()
	if vp != null:
		vp.set_input_as_handled()
