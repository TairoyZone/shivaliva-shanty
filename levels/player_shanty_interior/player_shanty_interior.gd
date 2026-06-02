## Inside the player's shanty — the first scene of a fresh new game.
## Empty by design: a bed in one corner, the door home. Future hooks:
## sleep-to-save on the bed, a storage chest, decorations earned from
## puzzles or NPCs. All shared level behavior lives in [BaseLocation].
##
## On a brand-new game (PlayerState.has_seen_intro == false) this shows
## the one-time [IntroOverlay] welcome that orients the player + sets the
## first goal.
extends BaseLocation


func _ready() -> void:

	super._ready()
	if not PlayerState.has_seen_intro:
		add_child(IntroOverlay.new())