## Base class for ONE state in a [StateMachine] (the GDQuest finite-state-
## machine pattern). A state is a plain [Node] child of the StateMachine; the
## machine forwards the game loop to whichever state is current and calls
## [method enter] / [method exit] across every transition.
##
## Named [FsmState] (not "State") on purpose — several puzzles already declare
## their own local `enum State`, and a global `class_name State` would shadow
## them (it broke knot.gd). Subclass this per state and override ONLY the hooks
## you need (everything is a no-op by default) — see [[inheritance-pattern]].
## To change state, call [method transition_to] with the sibling state's node
## name; the owning [StateMachine] does the swap.
##
## Reach for it when a flow has 3+ modes with distinct per-frame/input
## behaviour and real transitions (e.g. the Voyage loop). Do NOT wrap simple
## 2-mode scripts in it — that's over-engineering.
class_name FsmState
extends Node


## Request a transition to the sibling state named [param target] (its node
## name), handing [param data] to that state's [method enter]. The parent
## [StateMachine] connects to this in its _ready.
signal transitioned(target: StringName, data: Dictionary)


## Called once when this state becomes active. [param data] is whatever the
## previous state passed to [method transition_to] (empty by default).
func enter(_data: Dictionary = {}) -> void:
	pass


## Called once as this state is leaving — before the next state's
## [method enter]. Tear down timers / connections started in [method enter].
func exit() -> void:
	pass


## Per-frame while active (forwarded from the machine's _process).
func update(_delta: float) -> void:
	pass


## Per-physics-frame while active (forwarded from _physics_process).
func physics_update(_delta: float) -> void:
	pass


## Unhandled input while active (forwarded from _unhandled_input).
func handle_input(_event: InputEvent) -> void:
	pass


## Convenience for subclasses: ask the machine to switch to sibling state
## [param target]. Equivalent to emitting [signal transitioned] directly.
func transition_to(target: StringName, data: Dictionary = {}) -> void:
	transitioned.emit(target, data)