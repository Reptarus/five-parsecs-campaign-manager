extends GdUnitTestSuite
## Battlefield terrain passthrough contract test
##
## PreBattleUI writes battlefield terrain to GameStateManager.set_temp_data(
##   "battlefield_terrain", {"sectors": Array, "theme_name": String}).
## PostBattleSummarySheet reads it back with the same key + shape.
## Sprint 2 F1 retargeted both ends from the dead GameState.temp_data path
## to the real GameStateManager API. This test pins the contract.
##
## gdUnit4 v6.0.3 compatible.

const KEY := "battlefield_terrain"

var _had_key: bool = false
var _prior_value: Variant = null

func before_test() -> void:
	# Snapshot any existing value so we leave the autoload clean.
	if GameStateManager.has_temp_data(KEY):
		_had_key = true
		_prior_value = GameStateManager.get_temp_data(KEY, null)
	GameStateManager.clear_temp_data(KEY)


func after_test() -> void:
	GameStateManager.clear_temp_data(KEY)
	if _had_key:
		GameStateManager.set_temp_data(KEY, _prior_value)
	_had_key = false
	_prior_value = null


func test_terrain_passthrough_round_trips_sectors_and_theme() -> void:
	var sectors: Array = [
		{"label": "NW", "features": ["crashed_ship"]},
		{"label": "NE", "features": ["ruined_wall", "scatter"]},
	]
	var theme: String = "crash_site"

	# PreBattleUI write side
	GameStateManager.set_temp_data(KEY, {
		"sectors": sectors,
		"theme_name": theme,
	})

	# PostBattleSummarySheet read side
	var bf_terrain: Dictionary = GameStateManager.get_temp_data(KEY, {})
	var read_sectors: Array = bf_terrain.get("sectors", [])
	var read_theme: String = bf_terrain.get("theme_name", "")

	assert_int(read_sectors.size()).is_equal(2)
	assert_str(read_theme).is_equal("crash_site")
	# Verify the shape inside survives intact (Dictionary fields preserved)
	assert_str(str(read_sectors[0].get("label", ""))).is_equal("NW")
	assert_int(int(read_sectors[1].get("features", []).size())).is_equal(2)


func test_terrain_passthrough_default_when_unset() -> void:
	# No prior set_temp_data — get with default should return the default.
	GameStateManager.clear_temp_data(KEY)
	var bf_terrain: Dictionary = GameStateManager.get_temp_data(KEY, {})
	assert_int(bf_terrain.size()).is_equal(0)
	# Reads using the agreed shape on the empty default should still work.
	assert_int(bf_terrain.get("sectors", []).size()).is_equal(0)
	assert_str(str(bf_terrain.get("theme_name", ""))).is_equal("")
