## ONE-SHOT AUTHORING TOOL (not shipped, not runtime). Computes the Jungle Ordeal maze with Godot's OWN
## RNG — so it matches the map handed to Troy exactly — then prints the encoded `tile_map_data` for the floor
## + wall TileMapLayers and the world positions for each beast gate + the exit door. I paste those static
## values into jungle_ordeal.tscn as REAL editable nodes (no runtime generation). Run headless:
##   godot --headless --path <project> --script res://tools/bake_jungle_ordeal.gd
extends SceneTree

const TILE_SET : TileSet = preload("res://assets/iso/isometric_tileset.tres")
const TILE_SRC : int = 0
const FLOOR_TILE : Vector2i = Vector2i(2, 0)
const WALL_TILE : Vector2i = Vector2i(3, 0)
const MAZE_W : int = 5
const MAZE_H : int = 5
const MAZE_SEED : int = 20260616

# Beast order along the corridor (must match PlayerState.ORDEAL_BEASTS + ORDEAL_KING), hardcoded so this
# tool has no autoload dependency.
const ORDER : Array = ["lion", "gorilla", "rhino", "bear"]
const KING : String = "king"

var _gw : int = 0
var _gh : int = 0
var _wall : Array = []


func _initialize() -> void:

	_generate_maze()
	var path : Array = _solution_path()
	var gate_cells : Dictionary = _gate_cells(path)
	var cell_is_gate : Dictionary = {}
	for id in gate_cells:
		cell_is_gate[gate_cells[id]] = String(id)

	var ground : TileMapLayer = TileMapLayer.new()
	ground.tile_set = TILE_SET
	var walls : TileMapLayer = TileMapLayer.new()
	walls.tile_set = TILE_SET
	get_root().add_child(ground)
	get_root().add_child(walls)

	for x in _gw:
		for y in _gh:
			var cell : Vector2i = Vector2i(x, y)
			ground.set_cell(cell, TILE_SRC, FLOOR_TILE)
			# A raised wall on every wall cell EXCEPT a gate cell (gates sit in OPEN corridor + block
			# themselves, so the path is editable independently of the gates).
			if _wall[x][y] and not cell_is_gate.has(cell):
				walls.set_cell(cell, TILE_SRC, WALL_TILE)

	print("=== JUNGLE ORDEAL BAKE ===")
	print("GROUND_DATA=", Marshalls.raw_to_base64(ground.tile_map_data))
	print("WALLS_DATA=", Marshalls.raw_to_base64(walls.tile_map_data))
	var start : Vector2i = path[0] if not path.is_empty() else Vector2i(1, 1)
	var start_world : Vector2 = ground.map_to_local(start)
	print("START cell=%s world=%s spawn=%s door=%s" % [start, start_world, start_world + Vector2(0, 18.0), start_world])
	for id in gate_cells:
		var cell : Vector2i = gate_cells[id]
		var pos : Vector2 = ground.map_to_local(cell)
		var idx : int = path.find(cell)
		var approach : Vector2i = path[idx - 1] if idx > 0 else cell
		var off : Vector2 = ground.map_to_local(approach) - pos
		print("GATE %s cell=%s pos=%s spawn_offset=%s" % [id, cell, pos, off])
	print("=== END ===")
	quit()


# --- maze logic copied verbatim from jungle_ordeal.gd so the bake matches the handed-out map ---
func _gate_cells(path: Array) -> Dictionary:

	var out : Dictionary = {}
	if path.size() < 6:
		return out
	var fracs : Array = [0.26, 0.46, 0.64, 0.82]
	var used : Dictionary = {}
	for i in ORDER.size():
		var idx : int = clampi(int(round(float(path.size()) * float(fracs[i]))), 2, path.size() - 2)
		while used.has(idx) and idx < path.size() - 2:
			idx += 1
		used[idx] = true
		out[String(ORDER[i])] = path[idx]
	out[KING] = path[path.size() - 1]
	return out


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
