## THE JUNGLE ORDEAL — the Cradle Gym's beast trial. The maze is HAND-AUTHORED in the scene as REAL,
## editable nodes (a floor + a raised-wall TileMapLayer painted with Troy's iso atlas, plus the [BeastGate]
## + exit-door instances — open jungle_ordeal.tscn to edit it), NOT generated at runtime. This script only
## carries the live logic: it inherits the universal Stardust SKY (sky_mode = Always on the scene root, same
## background as the shore) and records a gate WIN when you return from its Skirmish bout. Five gates bar the
## solution corridor — Lion → Gorilla → Rhino → Bear → the Jungle King — each blocks its own cell until you
## beat its serious bout; clear the King → the Badge of Honour + town-wide respect. See [[cradle-gym-jungle-ordeal]].
class_name JungleOrdeal
extends BaseLocation

# Per-beast labels (id → display name), for the win log on return. The gate prop carries its own profile +
# colour (set per-instance in the scene); this is only the name shown when a beast falls.
const BEASTS : Dictionary = {
	"lion": {"label": "Maned Lion"},
	"gorilla": {"label": "Silverback Gorilla"},
	"rhino": {"label": "Charging Rhino"},
	"bear": {"label": "Grizzled Bear"},
	"king": {"label": "The Jungle King"},
}

## Rapport every islander gains when you win the whole Ordeal — the town-wide respect (one-time; the
## defeat record is idempotent so it can't be farmed).
const TOWN_RESPECT : int = 12


func _ready() -> void:

	super._ready()        # BaseLocation: the universal sky (sky_mode), mood wash, + spawns the player
	_resolve_fight_return()


# On return from a beast bout, record a WIN (the gate then opens). A loss leaves it standing.
func _resolve_fight_return() -> void:

	var id : String = PlayerState.jungle_ordeal_pending
	if id.is_empty():
		return
	PlayerState.jungle_ordeal_pending = ""
	if PlayerState.last_skirmish_won and PlayerState.ordeal_mark_defeated(id):
		var label : String = String(BEASTS.get(id, {}).get("label", "the beast"))
		if id == PlayerState.ORDEAL_KING:
			PlayerState.log_event("The Jungle King falls! The Ordeal is won — the island salutes you.", Color(1.0, 0.86, 0.4))
			_grant_town_respect()
		else:
			PlayerState.log_event("%s is beaten — the way opens." % label, Color(0.7, 0.95, 0.6))


# Win the Ordeal → every islander gains rapport (the town-wide respect). One-time (gated by the idempotent
# defeat record above), so it can't be farmed.
func _grant_town_respect() -> void:

	for profile in NpcRegistry.all():
		PlayerState.add_affinity(profile.npc_name, TOWN_RESPECT)
