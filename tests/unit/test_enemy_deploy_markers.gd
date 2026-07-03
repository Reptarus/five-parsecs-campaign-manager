extends GdUnitTestSuite
## Enemy deployment markers vs Core Rules p.110 (rules-audit F3/F4/F6):
##   Aggressive/Rampaging = one cluster; Tactical AND Defensive = 3 teams
##   8" apart; Cautious = 2 groups 6" apart; Beast = pairs across table
##   thirds 2" apart (+ odd figure alone). All markers land inside the
##   enemy edge band, at every book table size, as JSON-safe positions.

const GeneratorClass = preload("res://src/core/battle/BattlefieldGenerator.gd")
const Grid = preload("res://src/core/battle/BattlefieldGrid.gd")

const SIZES: Array[float] = [2.0, 2.5, 3.0]


func _markers(ai: String, count: int, dims: Dictionary,
		seed_val: int = 42) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return GeneratorClass.compute_enemy_deploy_markers(ai, count, rng, dims)


func _assert_common(markers: Array, count: int, dims: Dictionary) -> void:
	assert_int(markers.size()).is_equal(count)
	var band: Dictionary = Grid.enemy_edge_band(dims)
	for m: Dictionary in markers:
		var pos: Variant = m.get("position")
		assert_bool(pos is Array and pos.size() == 2).is_true()
		var x: int = int(pos[0])
		var y: int = int(pos[1])
		assert_bool(x >= 0 and x < int(dims["cols"])).is_true()
		assert_bool(y >= int(band["start"]) and y <= int(band["end"])) \
			.is_true()
		assert_str(str(m.get("team", ""))).is_equal("enemy")


func test_all_ai_types_stay_in_enemy_band_all_sizes() -> void:
	for ft: float in SIZES:
		var dims: Dictionary = Grid.dims_for_table(ft)
		for ai in ["A", "R", "T", "D", "C", "B", "G", "?"]:
			_assert_common(_markers(ai, 6, dims), 6, dims)


func test_aggressive_is_one_cluster() -> void:
	var dims: Dictionary = Grid.dims_for_table(3.0)
	var two_inch: int = maxi(int(roundf(Grid.inches_to_cells(2.0))), 1)
	var mid_x: int = int(dims["cols"] / 2.0)
	for ai in ["A", "R"]:
		for m: Dictionary in _markers(ai, 8, dims):
			var x: int = int(m.get("position")[0])
			assert_bool(absi(x - mid_x) <= two_inch).is_true()


func test_f4_defensive_deploys_as_3_teams_like_tactical() -> void:
	var dims: Dictionary = Grid.dims_for_table(3.0)
	var team_gap: int = maxi(int(roundf(Grid.inches_to_cells(8.0))), 1)
	var one_inch: int = maxi(int(roundf(Grid.inches_to_cells(1.0))), 1)
	for ai in ["T", "D"]:
		var xs: Array = []
		for m: Dictionary in _markers(ai, 9, dims):
			xs.append(int(m.get("position")[0]))
		xs.sort()
		# 3 teams 8" apart -> the spread spans roughly two team gaps
		var spread: int = xs[xs.size() - 1] - xs[0]
		assert_bool(spread >= team_gap * 2 - 2 * one_inch).is_true()


func test_cautious_is_2_groups() -> void:
	var dims: Dictionary = Grid.dims_for_table(3.0)
	var group_gap: int = maxi(int(roundf(Grid.inches_to_cells(6.0))), 1)
	var one_inch: int = maxi(int(roundf(Grid.inches_to_cells(1.0))), 1)
	var mid_x: int = int(dims["cols"] / 2.0)
	var half_gap: int = maxi(int(group_gap / 2.0), 1)
	for m: Dictionary in _markers("C", 6, dims):
		var x: int = int(m.get("position")[0])
		var near_left: bool = absi(x - (mid_x - half_gap)) <= one_inch
		var near_right: bool = absi(x - (mid_x + half_gap)) <= one_inch
		assert_bool(near_left or near_right).is_true()


func test_f3_beast_deploys_in_pairs_across_thirds() -> void:
	var dims: Dictionary = Grid.dims_for_table(3.0)
	var cols: int = int(dims["cols"])
	var markers: Array = _markers("B", 7, dims)
	assert_int(markers.size()).is_equal(7)
	# Pairs share a row (placed together, 2" apart on x)
	for p in range(3):
		var a: Dictionary = markers[p * 2]
		var b: Dictionary = markers[p * 2 + 1]
		assert_int(int(a.get("position")[1])) \
			.is_equal(int(b.get("position")[1]))
		assert_bool(int(b.get("position")[0]) > int(a.get("position")[0])) \
			.is_true()
	# One pair per table third (p.110: "Divide the table in 3 roughly
	# equal parts, and place one pair in each")
	var third: float = cols / 3.0
	assert_bool(float(markers[0].get("position")[0]) < third).is_true()
	assert_bool(float(markers[2].get("position")[0]) >= third - 1.0 \
		and float(markers[2].get("position")[0]) < third * 2.0 + 1.0).is_true()
	assert_bool(float(markers[4].get("position")[0]) >= third * 2.0 - 1.0) \
		.is_true()
	# "Any odd figure left over is set up on its own" — the 7th exists
	assert_int(markers.size() % 2).is_equal(1)


func test_markers_deterministic_under_seed() -> void:
	var dims: Dictionary = Grid.dims_for_table(2.5)
	var a: Array = _markers("T", 7, dims, 1234)
	var b: Array = _markers("T", 7, dims, 1234)
	assert_str(JSON.stringify(a)).is_equal(JSON.stringify(b))
