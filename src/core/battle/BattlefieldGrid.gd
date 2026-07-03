class_name FPCM_BattlefieldGrid
extends RefCounted

## Battlefield grid geometry — single source of truth.
##
## Core Rules p.108 recommends square tables of 2x2, 2.5x2.5, or 3x3 feet.
## The Compendium terrain generator (p.94) always divides the table into
## 4 quarters of 4 sectors (a fixed 4x4 sector grid) regardless of size.
## The app models the table as a square cell grid at 1.5" per cell:
##   2x2 ft  -> 16x16 cells (4-cell sectors)
##   2.5x2.5 -> 20x20 cells (5-cell sectors)
##   3x3 ft  -> 24x24 cells (6-cell sectors)
## All grid math (sector centers, deployment bands, inch conversion,
## JSON-safe position round-trip) lives here. Static only — never instantiate.

const CELL_INCHES := 1.5
const SECTOR_GRID := 4  # 4x4 sectors — book-fixed (Compendium p.94)
const VALID_TABLE_SIZES_FT: Array[float] = [2.0, 2.5, 3.0]  # Core Rules p.108
const ENEMY_EDGE_BAND_CELLS := 4  # suggestion-band depth along the enemy edge (6")

const ROW_LABELS: Array[String] = ["A", "B", "C", "D"]
const COL_LABELS: Array[String] = ["1", "2", "3", "4"]


## Snap an arbitrary float to the nearest book table size (Core Rules p.108).
static func sanitize_table_size(table_size_ft: float) -> float:
	var best: float = 3.0
	var best_dist: float = INF
	for size: float in VALID_TABLE_SIZES_FT:
		var dist: float = absf(size - table_size_ft)
		if dist < best_dist:
			best_dist = dist
			best = size
	return best


## Grid dimensions for a book table size.
static func dims_for_table(table_size_ft: float = 3.0) -> Dictionary:
	var size_ft: float = sanitize_table_size(table_size_ft)
	var table_inches: float = size_ft * 12.0
	var cells: int = int(roundf(table_inches / CELL_INCHES))
	@warning_ignore("integer_division")
	var sector_cells: int = cells / SECTOR_GRID
	return {
		"cols": cells,
		"rows": cells,
		"sector_cols": sector_cells,
		"sector_rows": sector_cells,
		"table_inches": table_inches,
		"table_size_ft": size_ft,
	}


## Display label for a table size ("2x2 ft", "2.5x2.5 ft", "3x3 ft").
static func table_size_label(table_size_ft: float) -> String:
	var size_ft: float = sanitize_table_size(table_size_ft)
	if is_equal_approx(size_ft, 2.5):
		return "2.5x2.5 ft"
	return "%dx%d ft" % [int(size_ft), int(size_ft)]


## JSON key used by standard_terrain_set.by_table_size in compendium_terrain.json.
static func table_size_json_key(table_size_ft: float) -> String:
	var size_ft: float = sanitize_table_size(table_size_ft)
	if is_equal_approx(size_ft, 2.5):
		return "2.5x2.5"
	return "%dx%d" % [int(size_ft), int(size_ft)]


## Convert a sector label (e.g. "B3") to its grid-center cell coordinates.
static func sector_label_to_grid_center(label: String, dims: Dictionary = {}) -> Vector2:
	var d: Dictionary = dims if not dims.is_empty() else dims_for_table()
	if label.length() < 2:
		return center_cell(d)
	var row_idx: int = ROW_LABELS.find(label[0])
	var col_idx: int = COL_LABELS.find(label[1])
	if row_idx < 0 or col_idx < 0:
		return center_cell(d)
	var sc: float = float(d.get("sector_cols", 6))
	var sr: float = float(d.get("sector_rows", 6))
	return Vector2(col_idx * sc + sc / 2.0, row_idx * sr + sr / 2.0)


## The table's center cell (mission objectives at "exact center", Core Rules p.90).
static func center_cell(dims: Dictionary = {}) -> Vector2:
	var d: Dictionary = dims if not dims.is_empty() else dims_for_table()
	return Vector2(float(d.get("cols", 24)) / 2.0, float(d.get("rows", 24)) / 2.0)


## Crew deployment half: rows [start, end] inclusive (map convention: crew = top).
static func crew_row_band(dims: Dictionary = {}) -> Dictionary:
	var d: Dictionary = dims if not dims.is_empty() else dims_for_table()
	var rows: int = int(d.get("rows", 24))
	@warning_ignore("integer_division")
	return {"start": 0, "end": rows / 2 - 1}


## Enemy deployment half: rows [start, end] inclusive (map convention: enemy = bottom).
static func enemy_row_band(dims: Dictionary = {}) -> Dictionary:
	var d: Dictionary = dims if not dims.is_empty() else dims_for_table()
	var rows: int = int(d.get("rows", 24))
	@warning_ignore("integer_division")
	return {"start": rows / 2, "end": rows - 1}


## Suggestion band hugging the enemy battlefield edge (enemy sets up on the
## opposite edge, Core Rules p.110). Last ENEMY_EDGE_BAND_CELLS rows.
static func enemy_edge_band(dims: Dictionary = {}) -> Dictionary:
	var d: Dictionary = dims if not dims.is_empty() else dims_for_table()
	var rows: int = int(d.get("rows", 24))
	return {"start": maxi(rows - ENEMY_EDGE_BAND_CELLS, 0), "end": rows - 1}


## Convert tabletop inches to grid cells (book spacing -> marker spacing).
static func inches_to_cells(inches: float) -> float:
	return inches / CELL_INCHES


## JSON-safe serialization for grid positions (JSON has no Vector2).
static func grid_pos_to_json(pos: Vector2) -> Array:
	return [pos.x, pos.y]


## Rehydrate a grid position from JSON ([x, y] Array); passes Vector2/Vector2i through.
static func json_to_grid_pos(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
