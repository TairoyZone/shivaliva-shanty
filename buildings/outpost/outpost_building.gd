## Cradle Rock's first building — the Inn, run by Hearty Brian and host
## to the puzzle minigames + the rest of the village cast (see
## [[cradle-rock-cast]]). All wall / roof / window drawing logic lives
## in [Building]; this class stays thin so future Inn-only touches
## (a chimney, a hanging sign, a unique door) have a place to land
## without polluting the base.
@tool
class_name OutpostBuilding
extends Building
