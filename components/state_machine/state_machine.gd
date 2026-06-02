## A minimal finite state machine (the GDQuest pattern). Add [FsmState] nodes
## as children, point [member initial_state] at the starting one, and this node
## forwards _process / _physics_process / _unhandled_input to whichever state
## is current — running [method FsmState.exit] then [method FsmState.enter]
## across every transition. States drive transitions by calling
## [method FsmState.transition_to]; the target is the sibling state's node name.
##
## The reusable chassis for any multi-mode flow whose complexity actually earns
## an explicit machine — the Voyage loop is the intended first user. Don't
## retrofit simple 2-mode scripts onto it (see [[inheritance-pattern]] /
## keep-it-simple). Script-only: drop a Node with this script into a scene,
## parent your [FsmState] children under it, and set [member initial_state].
class_name StateMachine
extends Node


## Emitted after every committed transition, for outside observers (a HUD,
## a debug overlay, analytics). Carries the leaving + entering state names.
signal state_changed(from_state: StringName, to_state: StringName)

## The state to enter on ready. Must be one of this machine's [FsmState]
## children; if left null, the first [FsmState] child is used.
@export var initial_state : FsmState

## The currently-active state — null until [method _ready] runs.
var current_state : FsmState


func _ready() -> void:

	# Wire every child state's transition request back to us.
	for child in get_children():
		if child is FsmState:
			(child as FsmState).transitioned.connect(_on_state_transitioned)
	# Default to the first FsmState child if none was assigned in the inspector.
	if initial_state == null:
		for child in get_children():
			if child is FsmState:
				initial_state = child as FsmState
				break
	if initial_state != null:
		current_state = initial_state
		current_state.enter()


func _process(delta: float) -> void:

	if current_state != null:
		current_state.update(delta)


func _physics_process(delta: float) -> void:

	if current_state != null:
		current_state.physics_update(delta)


func _unhandled_input(event: InputEvent) -> void:

	if current_state != null:
		current_state.handle_input(event)


## Force a transition from OUTSIDE a state — e.g. the host scene kicking off
## the first real state. Same path as a state's [method FsmState.transition_to].
func transition_to(target: StringName, data: Dictionary = {}) -> void:

	_on_state_transitioned(target, data)


func _on_state_transitioned(target: StringName, data: Dictionary) -> void:

	var next : FsmState = get_node_or_null(NodePath(String(target))) as FsmState
	if next == null:
		push_warning("StateMachine: no child FsmState named '%s'." % target)
		return
	if next == current_state:
		return
	var from_name : StringName = current_state.name if current_state != null else &""
	if current_state != null:
		current_state.exit()
	current_state = next
	current_state.enter(data)
	# If enter() itself triggered a transition (re-entrancy), current_state has
	# already moved on and that nested call emitted its own state_changed — so
	# only announce this transition if we're still the state we just entered.
	# Guarantees every emitted to_state matches the live current_state.
	if current_state == next:
		state_changed.emit(from_name, next.name)