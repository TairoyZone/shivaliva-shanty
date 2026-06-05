## One fighter in a boarding melee: a [SkirmishBoard] + its identity / AI state + who it attacks. Shared
## between the persistent [BoardingMelee] sim (which owns the board + drives the AI) and the boarding
## VIEW (skirmish_boarding.gd, which sets the UI refs while it's on-screen). See [[live-melee-boarding]].
class_name BoardingCombatant
extends RefCounted


# --- Sim state (owned/used by BoardingMelee) ---
var board : SkirmishBoard
var cname : String = "?"
var weapon : String = "brawl"
var color : Color = Color(0.92, 0.44, 0.40, 1.0)   # weapon colour (opaque)
var portrait : Color = Color(0.6, 0.6, 0.65, 1.0)
var skill : float = 0.5
var aggr : float = 0.5
var is_player : bool = false
var enemy : bool = false            # true = the opposing crew
var alive : bool = true
var think_t : float = -1.0          # AI piece-place countdown (-1 = idle)
var sent : int = 0
var target : BoardingCombatant = null   # who this fighter mails garbage to

# --- View refs (set by the boarding scene when attached; null while the sim runs headless) ---
var header : Control
var name_label : Label
var dots_box : HBoxContainer
var dot_count : int = 0             # live attacker dots (for centring the header)
var move_tween : Tween             # active slide (defeated-shuffle); killed before a new one
