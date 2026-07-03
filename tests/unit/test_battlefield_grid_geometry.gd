extends GdUnitTestSuite
## FPCM_BattlefieldGrid geometry SSOT (Core Rules p.108 table sizes).
## Pins: dims per size, sector-label centers, deployment bands, inch<->cell
## conversion, and the JSON-safe position round-trip used by persistence.

const Grid = preload("res://src/core/battle/BattlefieldGrid.gd")

const SIZES: Array[float] = [2.0, 2.5, 3.0]


func test_dims_for_book_sizes() -> void:
	var expected := {
		2.0: {"cells": 16, "sector": 4, "inches": 24.0},
		2.5: {"cells": 20, "sector": 5, "inches": 30.0},
		3.0: {"cells": 24, "sector": 6, "inches": 36.0},
	}
	for ft: float in expected:
		var d: Dictionary = Grid.dims_for_table(ft)
		assert_int(d["cols"]).is_equal(expected[ft]["cells"])
		assert_int(d["rows"]).is_equal(expected[ft]["cells"])  # square (p.108)
		assert_int(d["sector_cols"]).is_equal(expected[ft]["sector"])
		assert_int(d["sector_rows"]).is_equal(expected[ft]["sector"])
		assert_float(d["table_inches"]).is_equal_approx(
			expected[ft]["inches"], 0.001)


func test_sanitize_snaps_to_book_sizes() -> void:
	assert_float(Grid.sanitize_table_size(2.4)).is_equal_approx(2.5, 0.001)
	assert_float(Grid.sanitize_table_size(1.0)).is_equal_approx(2.0, 0.001)
	assert_float(Grid.sanitize_table_size(5.0)).is_equal_approx(3.0, 0.001)
	assert_float(Grid.sanitize_table_size(3.0)).is_equal_approx(3.0, 0.001)


func test_sector_label_centers_all_labels_all_sizes() -> void:
	for ft: float in SIZES:
		var d: Dictionary = Grid.dims_for_table(ft)
		var sc: float = float(d["sector_cols"])
		for row_i in range(4):
			for col_i in range(4):
				var label: String = Grid.ROW_LABELS[row_i] + Grid.COL_LABELS[col_i]
				var center: Vector2 = Grid.sector_label_to_grid_center(label, d)
				assert_float(center.x).is_equal_approx(
					col_i * sc + sc / 2.0, 0.001)
				assert_float(center.y).is_equal_approx(
					row_i * sc + sc / 2.0, 0.001)
				# Always inside the grid
				assert_bool(center.x > 0.0 and center.x < d["cols"]).is_true()
				assert_bool(center.y > 0.0 and center.y < d["rows"]).is_true()


func test_invalid_label_falls_back_to_center() -> void:
	var d: Dictionary = Grid.dims_for_table(3.0)
	assert_that(Grid.sector_label_to_grid_center("Z9", d)) \
		.is_equal(Grid.center_cell(d))
	assert_that(Grid.sector_label_to_grid_center("", d)) \
		.is_equal(Grid.center_cell(d))


func test_center_cell() -> void:
	for ft: float in SIZES:
		var d: Dictionary = Grid.dims_for_table(ft)
		var c: Vector2 = Grid.center_cell(d)
		assert_float(c.x).is_equal_approx(float(d["cols"]) / 2.0, 0.001)
		assert_float(c.y).is_equal_approx(float(d["rows"]) / 2.0, 0.001)


func test_deployment_bands_partition_the_grid() -> void:
	for ft: float in SIZES:
		var d: Dictionary = Grid.dims_for_table(ft)
		var crew: Dictionary = Grid.crew_row_band(d)
		var enemy: Dictionary = Grid.enemy_row_band(d)
		assert_int(crew["start"]).is_equal(0)
		assert_int(crew["end"] + 1).is_equal(enemy["start"])
		assert_int(enemy["end"]).is_equal(int(d["rows"]) - 1)
		var edge: Dictionary = Grid.enemy_edge_band(d)
		assert_int(edge["start"]).is_equal(int(d["rows"]) - 4)
		assert_int(edge["end"]).is_equal(int(d["rows"]) - 1)
		# Edge band sits inside the enemy half
		assert_bool(edge["start"] >= enemy["start"]).is_true()


func test_inches_to_cells() -> void:
	assert_float(Grid.inches_to_cells(1.5)).is_equal_approx(1.0, 0.001)
	assert_float(Grid.inches_to_cells(6.0)).is_equal_approx(4.0, 0.001)
	assert_float(Grid.inches_to_cells(8.0)).is_equal_approx(5.333, 0.001)


func test_json_position_round_trip() -> void:
	var json: Array = Grid.grid_pos_to_json(Vector2(3.0, 4.5))
	assert_int(json.size()).is_equal(2)
	assert_that(Grid.json_to_grid_pos(json)).is_equal(Vector2(3.0, 4.5))
	# Passthrough forms
	assert_that(Grid.json_to_grid_pos(Vector2(1, 2))).is_equal(Vector2(1, 2))
	assert_that(Grid.json_to_grid_pos(Vector2i(1, 2))).is_equal(Vector2(1, 2))
	# Degenerate input
	assert_that(Grid.json_to_grid_pos(null)).is_equal(Vector2.ZERO)
	assert_that(Grid.json_to_grid_pos([])).is_equal(Vector2.ZERO)


func test_size_labels_and_json_keys() -> void:
	assert_str(Grid.table_size_label(2.0)).is_equal("2x2 ft")
	assert_str(Grid.table_size_label(2.5)).is_equal("2.5x2.5 ft")
	assert_str(Grid.table_size_label(3.0)).is_equal("3x3 ft")
	assert_str(Grid.table_size_json_key(2.0)).is_equal("2x2")
	assert_str(Grid.table_size_json_key(2.5)).is_equal("2.5x2.5")
	assert_str(Grid.table_size_json_key(3.0)).is_equal("3x3")
