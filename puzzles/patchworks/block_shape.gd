## The varied BLOCK-BLAST-style piece set for THE PATCHWORKS (1..9 cells) + the grid helpers
## (normalize / rotate / flip / weighted draw). The board rotates/flips these live; a piece fits a
## hole via [method PatchworksBoard.can_place]. Pure data + statics. See [[patchworks-spec]].
class_name BlockShape
extends RefCounted


## Each entry: a name, its canonical cells (origin at top-left of the bounding box, +x right / +y
## down), and a draw WEIGHT. Mixed sizes — a 1×1 "dot" filler up to a chunky 3×3 — à la Block Blast.
const SET : Array = [
	{"name": "dot", "cells": [Vector2i(0, 0)], "weight": 6},
	{"name": "duo", "cells": [Vector2i(0, 0), Vector2i(1, 0)], "weight": 8},
	{"name": "tri_i", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)], "weight": 8},
	{"name": "tri_l", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)], "weight": 9},
	{"name": "quad_o", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], "weight": 9},
	{"name": "quad_i", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)], "weight": 6},
	{"name": "quad_l", "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)], "weight": 8},
	{"name": "quad_t", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)], "weight": 8},
	{"name": "quad_s", "cells": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)], "weight": 7},
	{"name": "pent_p", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)], "weight": 6},
	{"name": "pent_l", "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3)], "weight": 5},
	{"name": "pent_i", "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)], "weight": 4},
	{"name": "square3", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)], "weight": 3},
]


## A fresh, weight-biased random piece: {"name": String, "cells": Array[Vector2i]} (cells are a
## mutable copy so the board can rotate/flip them in place).
static func random_piece() -> Dictionary:

	var total : int = 0
	for p in SET:
		total += int(p["weight"])
	var roll : int = randi() % total
	for p in SET:
		roll -= int(p["weight"])
		if roll < 0:
			return {"name": p["name"], "cells": (p["cells"] as Array).duplicate()}
	return {"name": SET[0]["name"], "cells": (SET[0]["cells"] as Array).duplicate()}


## Shift cells so the bounding box starts at (0, 0).
static func normalize(cells: Array) -> Array:

	var minx : int = 1 << 30
	var miny : int = 1 << 30
	for c in cells:
		minx = mini(minx, c.x)
		miny = mini(miny, c.y)
	var out : Array = []
	for c in cells:
		out.append(Vector2i(c.x - minx, c.y - miny))
	return out


## Rotate 90° clockwise about the origin, re-normalized. (x, y) -> (-y, x).
static func rotate_cw(cells: Array) -> Array:

	var out : Array = []
	for c in cells:
		out.append(Vector2i(-c.y, c.x))
	return normalize(out)


## Mirror horizontally (x -> -x), re-normalized.
static func flip_h(cells: Array) -> Array:

	var out : Array = []
	for c in cells:
		out.append(Vector2i(-c.x, c.y))
	return normalize(out)
