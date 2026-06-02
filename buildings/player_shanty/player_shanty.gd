## The player's own humble shanty — the foundational beat of the game
## (the word "shanty" in the title is literally THIS). Smaller than
## the Inn / outpost; a single-room dwelling where the player wakes up
## at the start of a new game. All visual + collision foundation logic
## inherits from [Building]; this class stays minimal so future
## player-shanty-only touches (a custom door, an upgrade-state, a
## chimney once the player earns it) have a place to land.
@tool
class_name PlayerShanty
extends Building
