@tool
extends "res://tests/performance/perf_test_base.gd"

const TestHelper := preload("res://tests/fixtures/test_helper.gd")
const GameState := preload("res://src/core/state/GameState.gd")
const TableProcessor := preload("res://src/core/systems/TableProcessor.gd")

var game_state: GameState

func before_each() -> void:
	super.before_each()
	game_state = _create_test_game_state()
	add_child(game_state)

func after_each() -> void:
	super.after_each()
	game_state = null

# Helper Functions
func _create_test_game_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	var test_state := TestHelper.setup_test_game_state()
	state.load_state(test_state)
	return state

# Test Cases - Campaign Management
func test_crew_roster_management() -> void:
	var character := TestHelper.create_test_character(GameEnums.ArmorClass.LIGHT)
	track_test_resource(character)
	
	game_state.add_crew_member(character)
	assert_eq(game_state.get_crew_size(), 1, "Crew should have one member")
	
	game_state.remove_crew_member(character.character_id)
	assert_eq(game_state.get_crew_size(), 0, "Crew should be empty")

func test_resource_tracking() -> void:
	game_state.modify_credits(1000)
	game_state.modify_resource(GameEnums.ResourceType.FUEL, 50)
	
	assert_eq(game_state.get_credits(), 1000, "Credits should be tracked")
	assert_eq(
		game_state.get_resource(GameEnums.ResourceType.FUEL),
		50,
		"Resources should be tracked"
	)

func test_mission_management() -> void:
	var mission := TestHelper.create_test_mission(GameEnums.MissionType.PATROL)
	track_test_resource(mission)
	
	game_state.add_active_mission(mission)
	assert_eq(game_state.get_active_missions().size(), 1, "Should have one active mission")
	
	game_state.complete_mission(mission.mission_id)
	assert_eq(game_state.get_completed_missions().size(), 1, "Should have one completed mission")

func test_equipment_management() -> void:
	var item := TestHelper.create_test_item(GameEnums.WeaponType.BASIC)
	track_test_resource(item)
	
	game_state.add_equipment(item)
	assert_true(game_state.has_equipment(item.item_id), "Should have added equipment")
	
	game_state.remove_equipment(item.item_id)
	assert_false(game_state.has_equipment(item.item_id), "Should have removed equipment")

func test_state_serialization() -> void:
	var mission := TestHelper.create_test_mission(GameEnums.MissionType.PATROL)
	track_test_resource(mission)
	game_state.add_active_mission(mission)
	
	var data: Dictionary = game_state.serialize()
	var restored := GameState.new()
	restored.deserialize(data)
	
	assert_eq(restored.get_active_missions().size(), 1, "Should restore active missions")
	assert_eq(restored.get_credits(), game_state.get_credits(), "Should restore credits")

# Test Cases - Table Rolling
func test_table_rolling() -> void:
	var table_processor := TableProcessor.new()
	add_child(table_processor)
	
	var result: Dictionary = table_processor.roll_on_table("test_table", 1)
	assert_not_null(result, "Should get a result from table roll")
	
	var weighted_result: Dictionary = table_processor.roll_weighted("test_table", {"weight": 2})
	assert_not_null(weighted_result, "Should get a weighted result")
	
	table_processor = null

func test_table_chaining() -> void:
	var table_processor := TableProcessor.new()
	add_child(table_processor)
	
	var chain_result: Array = table_processor.process_table_chain([
		{"table": "test_table_1", "modifier": 1},
		{"table": "test_table_2", "weight": 2}
	])
	assert_not_null(chain_result, "Should process table chain")
	assert_eq(chain_result.size(), 2, "Should have results from both tables")
	
	table_processor = null