## THE JUNGLE ORDEAL — the Cradle Gym's beast trial (the Pokémon-gym "trial" off the Forest). A true
## navigable jungle MAZE (a fixed-seed perfect labyrinth of foliage walls): you wind through it and the
## five beasts bar your way one at a time — Lion → Gorilla → Rhino → Bear, then the Jungle King at the
## heart — each a [BeastGate] blocking the corridor until you beat its serious Skirmish bout. Lose and your
## health drops but the run continues (retreat to the gym to rest at Jade, then come back). Beat the King
## and the Ordeal is won (the badge-of-honour trophy — C4). Placeholder-first procedural jungle. Extends
## [BaseLocation]; the maze + props are built in code so the layout is data-driven (tune the seed / size).
class_name JungleOrdeal
extends BaseLocation

const CELL : float = 80.0     # world px per maze-grid cell (corridor width)
const MAZE_W : int = 8        # maze cells wide / tall (grid is 2N+1)
const MAZE_H : int = 8
const MAZE_SEED : int = 20260616

const GATE_SCENE : PackedScene = preload("res://levels/jungle_ordeal/beast_gate.tscn")
const DOOR_SCENE : PackedScene = preload("res://levels/door/door.tscn")
const FOREST_SCENE : String = "res://levels/forest/forest.tscn"

# Per-beast gate config (id → its profile, display name, hue), in escalating order + the King.
const BEASTS : Dictionary = {
	"lion": {"path": "res://puzzles/skirmish/beasts/beast_lion.tres", "label": "Maned Lion", "color": Color(0.82, 0.6, 0.26, 1.0)},
	"gorilla": {"path": "res://puzzles/skirmish/beasts/beast_gorilla.tres", "label": "Silverback Gorilla", "color": Color(0.42, 0.42, 0.48, 1.0)},
	"rhino": {"path": "res://puzzles/skirmish/beasts/beast_rhino.tres", "label": "Charging Rhino", "color": Color(0.58, 0.58, 0.54, 1.0)},
	"bear": {"path": "res://puzzles/skirmish/beasts/beast_bear.tres", "label": "Grizzled Bear", "color": Color(0.5, 0.34, 0.22, 1.0)},
	"king": {"path": "res://puzzles/skirmish/beasts/beast_jungle_king.tres", "label": "The Jungle King", "color": Color(0.72, 0.22, 0.26, 1.0)},
}

const GROUND : Color = Color(0.16, 0.22, 0.13, 1.0)
const GROUND_PATH : Color = Color(0.22, 0.27, 0.16, 1.0)
const FOLIAGE_DARK : Color = Color(0.08, 0.16, 0.08, 1.0)
const FOLIAGE : Color = Color(0.13, 0.32, 0.15, 1.0)
const FOLIAGE_LIGHT : Color = Color(0.22, 0.46, 0.22, 1.0)

var _gw : int = 0
var _gh : int = 0
var _wall : Array = []   # [_gw][_gh] bool — true = foliage wall


func _ready() -> void:

	_generate_maze()
	_build_wall_collision()
	_place_props()        # gates + exit + sets pirate_spawn_position — BEFORE super spawns the player
	super._ready()        # BaseLocation: spawn player (at the gate anchor on return, else the maze start)
	_resolve_fight_return()
	queue_redraw()


# --- Maze generation (recursive backtracker, fixed seed → same labyrinth every run) ---
func _generate_maze() -> void:

	_gw = MAZE_W * 2 + 1
	_gh = MAZE_H * 2 + 1
	_wall = []
	for x in _gw:
		var col : Array = []
		for y in _gh:
			col.append(true)
		_wall.append(col)
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = MAZE_SEED
	var visited : Dictionary = {}
	var stack : Array = [Vector2i(0, 0)]
	visited[Vector2i(0, 0)] = true
	_wall[1][1] = false
	while not stack.is_empty():
		var c : Vector2i = stack[stack.size() - 1]
		var nbrs : Array = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n : Vector2i = c + d
			if n.x >= 0 and n.x < MAZE_W and n.y >= 0 and n.y < MAZE_H and not visited.has(n):
				nbrs.append(n)
		if nbrs.is_empty():
			stack.pop_back()
			continue
		var nn : Vector2i = nbrs[rng.randi() % nbrs.size()]
		visited[nn] = true
		var gc : Vector2i = Vector2i(c.x * 2 + 1, c.y * 2 + 1)
		var gn : Vector2i = Vector2i(nn.x * 2 + 1, nn.y * 2 + 1)
		_wall[(gc.x + gn.x) / 2][(gc.y + gn.y) / 2] = false
		_wall[gn.x][gn.y] = false
		stack.append(nn)


# BFS over open cells from the start node to the King node → the unique solution corridor (grid cells).
func _solution_path() -> Array:

	var start : Vector2i = Vector2i(1, 1)
	var goal : Vector2i = Vector2i(_gw - 2, _gh - 2)
	var came : Dictionary = {start: start}
	var q : Array = [start]
	while not q.is_empty():
		var c : Vector2i = q.pop_front()
		if c == goal:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n : Vector2i = c + d
			if n.x < 0 or n.x >= _gw or n.y < 0 or n.y >= _gh:
				continue
			if _wall[n.x][n.y] or came.has(n):
				continue
			came[n] = c
			q.append(n)
	var path : Array = []
	if not came.has(goal):
		return path
	var cur : Vector2i = goal
	while cur != start:
		path.append(cur)
		cur = came[cur]
	path.append(start)
	path.reverse()
	return path


func _cell_world(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * CELL, (float(cell.y) + 0.5) * CELL)


# --- Collision (one static body, a rect per foliage-wall cell) ---
func _build_wall_collision() -> void:

	var body : StaticBody2D = StaticBody2D.new()
	body.name = "MazeWalls"
	body.collision_layer = 2   # the solid layer the player collides with
	body.collision_mask = 0
	for x in _gw:
		for y in _gh:
			if not _wall[x][y]:
				continue
			var cs : CollisionShape2D = CollisionShape2D.new()
			var shape : RectangleShape2D = RectangleShape2D.new()
			shape.size = Vector2(CELL, CELL)
			cs.shape = shape
			cs.position = _cell_world(Vector2i(x, y))
			body.add_child(cs)
	add_child(body)


# --- Props: the exit door + the five beast gates along the solution path ---
func _place_props() -> void:

	var path : Array = _solution_path()
	var start : Vector2i = path[0] if not path.is_empty() else Vector2i(1, 1)
	var start_world : Vector2 = _cell_world(start)
	pirate_spawn_position = start_world + Vector2(0, 36)

	var door : Node = DOOR_SCENE.instantiate()
	door.name = "ForestExit"
	door.position = start_world
	door.target_scene = FOREST_SCENE
	door.target_spawn_anchor = "JungleEntry"
	door.marker_label = "Back to the forest"
	door.spawn_offset = Vector2(0, 48)
	add_child(door)

	if path.size() < 6:
		return   # degenerate maze (shouldn't happen) — leave the gates out rather than stack them
	var order : Array = PlayerState.ORDEAL_BEASTS
	var fracs : Array = [0.26, 0.46, 0.64, 0.82]
	var used : Dictionary = {}
	for i in order.size():
		var idx : int = clampi(int(round(float(path.size()) * float(fracs[i]))), 2, path.size() - 2)
		while used.has(idx) and idx < path.size() - 2:
			idx += 1
		used[idx] = true
		_spawn_gate(String(order[i]), path[idx], path[idx - 1])
	var gidx : int = path.size() - 1
	_spawn_gate(PlayerState.ORDEAL_KING, path[gidx], path[gidx - 1])


func _spawn_gate(id: String, cell: Vector2i, approach: Vector2i) -> void:

	var cfg : Dictionary = BEASTS[id]
	var g : BeastGate = GATE_SCENE.instantiate()
	g.name = "Gate_%s" % id
	g.beast_id = id
	g.beast_path = String(cfg["path"])
	g.beast_label = String(cfg["label"])
	g.beast_color = cfg["color"]
	g.position = _cell_world(cell)
	g.spawn_offset = Vector2(approach - cell) * (CELL * 0.66)   # come back on the approach side, in the corridor
	add_child(g)


# On return from a beast bout, record a WIN (the gate then reads as cleared). A loss leaves it standing.
func _resolve_fight_return() -> void:

	var id : String = PlayerState.jungle_ordeal_pending
	if id.is_empty():
		return
	PlayerState.jungle_ordeal_pending = ""
	if PlayerState.last_skirmish_won:
		if PlayerState.ordeal_mark_defeated(id):
			var label : String = String(BEASTS.get(id, {}).get("label", "the beast"))
			if id == PlayerState.ORDEAL_KING:
				PlayerState.log_event("The Jungle King falls! The Ordeal is won.", Color(1.0, 0.86, 0.4))
			else:
				PlayerState.log_event("%s is beaten — the way opens." % label, Color(0.7, 0.95, 0.6))


func _draw() -> void:

	if _wall.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(float(_gw) * CELL, float(_gh) * CELL)), GROUND)
	for x in _gw:
		for y in _gh:
			var c : Vector2 = _cell_world(Vector2i(x, y))
			if _wall[x][y]:
				_draw_foliage(c)
			else:
				draw_rect(Rect2(c - Vector2(CELL, CELL) * 0.5, Vector2(CELL, CELL)), GROUND_PATH)


# A clump of dark jungle leaves filling a wall cell.
func _draw_foliage(c: Vector2) -> void:

	draw_circle(c, CELL * 0.52, FOLIAGE_DARK)
	for o in [Vector2(-16, -12), Vector2(15, -9), Vector2(0, 13), Vector2(-12, 9), Vector2(13, 12), Vector2(2, -16)]:
		draw_circle(c + o, 15.0, FOLIAGE)
	draw_circle(c + Vector2(-7, -13), 11.0, FOLIAGE_LIGHT)
	draw_circle(c + Vector2(9, 3), 9.0, FOLIAGE_LIGHT)
