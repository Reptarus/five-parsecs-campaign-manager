extends GdUnitTestSuite

## The Planetfall campaign map's own rules (pp.52-53, pp.156-157).
##
## Eight suites build a map through PlanetfallMap.generate() and then test something
## else on it. None asserted the map itself: which square a D8 result names, how far
## apart two sectors are, how many Investigation Sites a new map gets, or where a
## Tactical Enemy may emerge. Each case below quotes the page it pins.

const CoreScript = preload("res://src/game/campaign/PlanetfallCampaignCore.gd")
const MapScript = preload("res://src/core/systems/PlanetfallMap.gd")
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _user_state: Dictionary
var _dm: Node


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_dm = get_tree().root.get_node_or_null("/root/DiceManager")


func after_test() -> void:
	if _dm != null:
		_dm.clear_forced_results()
	SaveDirGuard.restore(_user_state)


func _core(rows: int = 6, cols: int = 6, home: Array = [2, 2]) -> Resource:
	var core = CoreScript.new()
	core.colony_name = "Probe"
	MapScript.generate(core, rows, cols, home, 0)
	return core


## p.52: "The top left adjacent square is numbered 1 and you then just count clockwise
## around the target". From R3 C3 (key "2,2") the eight results go NW, N, NE, E, SE, S,
## SW, W.
func test_a_d8_counts_clockwise_from_the_top_left() -> void:
	var md: Dictionary = _core().map_data
	var expected := ["1,1", "1,2", "1,3", "2,3", "3,3", "3,2", "3,1", "2,1"]
	for d in range(1, 9):
		assert_str(MapScript.neighbor(md, "2,2", d)) \
			.override_failure_message("D8 %d from R3 C3" % d).is_equal(expected[d - 1])
	assert_str(MapScript.neighbor(md, "2,2", 0)).is_empty()
	assert_str(MapScript.neighbor(md, "2,2", 9)).is_empty()


## A D8 result that points off the map names no sector; a corner has three neighbours.
func test_the_map_edge_has_no_neighbour() -> void:
	var md: Dictionary = _core().map_data
	assert_str(MapScript.neighbor(md, "0,0", 1)).is_empty()
	assert_array(MapScript.adjacent_keys(md, "0,0")).contains_exactly_in_any_order(
		["0,1", "1,1", "1,0"])
	assert_int(MapScript.adjacent_keys(md, "2,2").size()).is_equal(8)
	assert_bool(MapScript.in_bounds(md, "5,5")).is_true()
	assert_bool(MapScript.in_bounds(md, "6,0")).is_false()
	assert_bool(MapScript.in_bounds(md, "0,-1")).is_false()


## Adjacency on p.52 includes the diagonals, so a diagonal step is one sector away.
func test_distance_counts_a_diagonal_as_one() -> void:
	assert_int(MapScript.distance("2,2", "3,3")).is_equal(1)
	assert_int(MapScript.distance("2,2", "2,3")).is_equal(1)
	assert_int(MapScript.distance("0,0", "3,5")).is_equal(5)
	assert_int(MapScript.distance("4,1", "4,1")).is_equal(0)


## p.52: "The default is a 6 x 6 grid". A map with no recorded size is that grid, and
## sector labels are 1-based for the player.
func test_the_default_grid_is_six_by_six() -> void:
	assert_int(MapScript.rows({})).is_equal(6)
	assert_int(MapScript.cols({})).is_equal(6)
	assert_int(MapScript.all_keys({}).size()).is_equal(36)
	assert_str(MapScript.label("0,0")).is_equal("R1 C1")
	assert_str(MapScript.label("2,4")).is_equal("R3 C5")
	var md: Dictionary = _core(8, 10).map_data
	assert_int(MapScript.all_keys(md).size()).is_equal(80)


## p.53: "mark 10 sectors on the map as Investigation Sites"; p.52 Corporate Funded
## "begins with 2 additional Investigation Sites". Read from expedition_types.json.
func test_a_new_map_gets_ten_sites_and_corporate_funded_two_more() -> void:
	assert_int(MapScript.site_count_for("Scientific Mission")).is_equal(10)
	assert_int(MapScript.site_count_for("Corporate Funded")).is_equal(12)
	assert_int(MapScript.site_count_for("")).is_equal(10)
	var core = CoreScript.new()
	MapScript.generate(core, 6, 6, [2, 2], MapScript.site_count_for("Corporate Funded"))
	var md: Dictionary = core.map_data
	var sites: Array = MapScript.all_keys(md).filter(func(k: String) -> bool:
		return bool(MapScript.sector(md, k).get("investigation", false)))
	assert_int(sites.size()).is_equal(12)
	# The colony's own sector is never an Investigation Site.
	assert_bool(sites.has("2,2")).is_false()


## p.53: "if you roll a sector that already has been selected, pick any empty sector
## adjacent instead." Forcing the same row and column twice puts the second site next to
## the first, at the D8 direction rolled.
func test_a_repeated_site_roll_moves_to_an_adjacent_sector() -> void:
	if _dm == null:
		return
	var core = _core()
	_dm.queue_forced_result(MapScript.ROW_DIE, 1)
	_dm.queue_forced_result(MapScript.COL_DIE, 1)
	assert_str(MapScript.place_investigation_site(core)).is_equal("0,0")
	_dm.queue_forced_result(MapScript.ROW_DIE, 1)
	_dm.queue_forced_result(MapScript.COL_DIE, 1)
	# D8 4 is east of R1 C1.
	_dm.queue_forced_result(MapScript.ADJACENT_DIE, 4)
	assert_str(MapScript.place_investigation_site(core)).is_equal("0,1")


func _enemy_core() -> Resource:
	var core = _core()
	core.tactical_enemies = [{"type": {"name": "First"}}, {"type": {"name": "Second"}}]
	return core


## p.156 1st Milestone: the enemy emerges in a sector that "cannot be in or adjacent to
## your colony". Forcing a roll onto the colony's own neighbour must be refused.
func test_an_enemy_never_emerges_in_or_beside_the_colony() -> void:
	var core = _enemy_core()
	for i in range(40):
		core.tactical_enemies[0]["occupied_sectors"] = []
		var at: String = MapScript.emerge(core, 0, false)
		assert_str(at).is_not_empty()
		assert_int(MapScript.distance(at, "2,2")).is_greater(1)
	if _dm == null:
		return
	core.tactical_enemies[0]["occupied_sectors"] = []
	# R3 C4 is beside the colony; the forced roll must be rerolled, never taken.
	_dm.queue_forced_result(MapScript.ROW_DIE, 3)
	_dm.queue_forced_result(MapScript.COL_DIE, 4)
	assert_int(MapScript.distance(MapScript.emerge(core, 0, false), "2,2")).is_greater(1)


## p.157 2nd/3rd Milestones: "This cannot be in or adjacent to your colony or a sector
## held by another enemy". The first emergence keeps only the colony clear.
func test_a_later_enemy_keeps_clear_of_the_first() -> void:
	var core = _enemy_core()
	MapScript.occupy(core, 0, "5,5")
	for i in range(40):
		core.tactical_enemies[1]["occupied_sectors"] = []
		var at: String = MapScript.emerge(core, 1, true)
		assert_str(at).is_not_empty()
		assert_int(MapScript.distance(at, "5,5")).is_greater(1)
		assert_int(MapScript.distance(at, "2,2")).is_greater(1)
	assert_array(MapScript.held_by(core, 0)).contains_exactly(["5,5"])
	if _dm == null:
		return
	# A forced roll beside the first enemy (R5 C5) is refused and rerolled.
	core.tactical_enemies[1]["occupied_sectors"] = []
	_dm.queue_forced_result(MapScript.ROW_DIE, 5)
	_dm.queue_forced_result(MapScript.COL_DIE, 5)
	assert_int(MapScript.distance(MapScript.emerge(core, 1, true), "5,5")).is_greater(1)
	# Without the keep-clear rule, a sector beside the first enemy is a legal emergence.
	core.tactical_enemies[1]["occupied_sectors"] = []
	_dm.queue_forced_result(MapScript.ROW_DIE, 5)
	_dm.queue_forced_result(MapScript.COL_DIE, 5)
	assert_str(MapScript.emerge(core, 1, false)).is_equal("4,4")


## A sector has one occupant: occupying it takes it from the enemy that held it, and a
## defeated enemy holds nothing (p.51).
func test_a_sector_has_one_occupant_and_the_defeated_hold_none() -> void:
	var core = _enemy_core()
	MapScript.occupy(core, 0, "4,4")
	assert_int(MapScript.occupant(core, "4,4")).is_equal(0)
	MapScript.occupy(core, 1, "4,4")
	assert_int(MapScript.occupant(core, "4,4")).is_equal(1)
	assert_array(MapScript.held_by(core, 0)).is_empty()
	core.tactical_enemies[1]["defeated"] = true
	assert_bool(MapScript.is_occupied(core, "4,4")).is_false()
	MapScript.release(core, 1, "4,4")
	assert_array(MapScript.held_by(core, 1)).is_empty()


## p.54: "Once Resources reach 0, the sector's status changes to Exploited".
func test_a_sector_is_exploited_when_its_resources_run_out() -> void:
	var core = _core()
	assert_str(MapScript.status(core.map_data, "4,4")).is_equal("unexplored")
	MapScript.set_explored(core, "4,4", 2, 1)
	assert_str(MapScript.status(core.map_data, "4,4")).is_equal("explored")
	assert_int(MapScript.reduce_resource(core, "4,4", 1)).is_equal(1)
	assert_str(MapScript.status(core.map_data, "4,4")).is_equal("explored")
	assert_int(MapScript.reduce_resource(core, "4,4", 5)).is_equal(0)
	assert_str(MapScript.status(core.map_data, "4,4")).is_equal("exploited")
	# A Resource raise brings an Exploited sector back to Explored.
	MapScript.raise_resource(core, "4,4", 2)
	assert_str(MapScript.status(core.map_data, "4,4")).is_equal("explored")
	# An unexplored sector keeps the raise until it is explored.
	MapScript.raise_resource(core, "0,5", 1)
	assert_str(MapScript.status(core.map_data, "0,5")).is_equal("unexplored")
	assert_int(int(MapScript.sector(core.map_data, "0,5").get("resource_bonus", 0))).is_equal(1)
