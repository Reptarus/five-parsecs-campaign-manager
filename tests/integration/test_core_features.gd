@tool
extends BaseTest

var game_state: GameState

func before_all() -> void:
	super.before_all()
	_performance_monitoring = true

func after_all() -> void:
	super.after_all()
	_performance_monitoring = false

func before_each() -> void:
	super.before_each()
	game_state = _create_test_game_state()

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
	track_resource(character)
	
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

func test_mission_logging() -> void:
	var mission := TestHelper.create_test_mission(GameEnums.MissionType.PATROL)
	track_resource(mission)
	
	game_state.add_active_mission(mission)
	assert_true(game_state.has_active_mission(mission.mission_id), "Mission should be active")
	
	mission.is_completed = true
	game_state.update_mission_status(mission)
	assert_true(game_state.has_completed_mission(mission.mission_id), "Mission should be completed")

# Test Cases - Table Rolling Automation
func test_planet_generation() -> void:
	var planet_data: Dictionary = game_state.generate_planet()
	assert_not_null(planet_data, "Planet data should be generated")
	assert_has(planet_data, "environment", "Planet should have environment")
	assert_has(planet_data, "threats", "Planet should have threats")

func test_npc_generation() -> void:
	var npc_data: Dictionary = game_state.generate_npc()
	assert_not_null(npc_data, "NPC data should be generated")
	assert_has(npc_data, "name", "NPC should have name")
	assert_has(npc_data, "faction", "NPC should have faction")

func test_loot_generation() -> void:
	var loot_data: Dictionary = game_state.generate_loot(GameEnums.ItemRarity.COMMON)
	assert_not_null(loot_data, "Loot data should be generated")
	assert_has(loot_data, "items", "Loot should have items")
	assert_has(loot_data, "credits", "Loot should have credits")

# Test Cases - Character Development
func test_character_advancement() -> void:
	var character := TestHelper.create_test_character(GameEnums.ArmorClass.LIGHT)
	track_resource(character)
	game_state.add_crew_member(character)
	
	game_state.award_experience(character.character_id, 100)
	assert_eq(character.experience, 100, "Experience should be tracked")
	
	var level_up_result: Dictionary = game_state.attempt_level_up(character.character_id)
	assert_true(level_up_result.success, "Character should level up")
	assert_gt(character.level, 1, "Level should increase")

func test_skill_acquisition() -> void:
	var character := TestHelper.create_test_character(GameEnums.ArmorClass.LIGHT)
	track_resource(character)
	game_state.add_crew_member(character)
	
	var skill: int = GameEnums.CharacterClass.SOLDIER
	game_state.add_skill(character.character_id, skill)
	assert_true(character.has_skill(skill), "Character should learn skill")

# Test Cases - Inventory Management
func test_equipment_management() -> void:
	var item := TestHelper.create_test_item(GameEnums.WeaponType.RIFLE)
	track_resource(item)
	
	game_state.add_item(item)
	assert_true(game_state.has_item(item.item_id), "Item should be in inventory")
	
	game_state.remove_item(item.item_id)
	assert_false(game_state.has_item(item.item_id), "Item should be removed")

func test_equipment_assignment() -> void:
	var character := TestHelper.create_test_character(GameEnums.ArmorClass.LIGHT)
	var item := TestHelper.create_test_item(GameEnums.WeaponType.RIFLE)
	track_resource(character)
	track_resource(item)
	
	game_state.add_crew_member(character)
	game_state.add_item(item)
	
	game_state.equip_item(character.character_id, item.item_id)
	assert_true(character.has_equipment(item.item_id), "Character should have equipment")

# Test Cases - Story Progression
func test_story_tracking() -> void:
	var story_event := {
		"type": "patron_quest",
		"description": "Test story event",
		"choices": ["Accept", "Decline"]
	}
	
	game_state.add_story_event(story_event)
	assert_true(game_state.has_active_story_event(), "Story event should be active")
	
	game_state.resolve_story_event(0) # Accept
	assert_false(game_state.has_active_story_event(), "Story event should be resolved")

func test_relationship_tracking() -> void:
	var faction_id := "test_faction"
	game_state.modify_faction_standing(faction_id, 10)
	assert_eq(
		game_state.get_faction_standing(faction_id),
		10,
		"Faction standing should be tracked"
	)

# Test Cases - Performance
func test_state_serialization_performance() -> void:
	if not _performance_monitoring:
		return
		
	var execution_time := TestHelper.measure_execution_time(func():
		for i in range(100):
			var save_data: Dictionary = game_state.save_state()
			var new_state := GameState.new()
			new_state.load_state(save_data)
			track_resource(new_state)
	)
	
	print("State serialization time (100 cycles): %.3f seconds" % execution_time)
	assert_between(
		execution_time,
		0.0,
		2.0,
		"State serialization should complete within 2 seconds"
	)

func test_table_rolling_performance() -> void:
	if not _performance_monitoring:
		return
		
	var execution_time := TestHelper.measure_execution_time(func():
		for i in range(100):
			var planet: Dictionary = game_state.generate_planet()
			var npc: Dictionary = game_state.generate_npc()
			var loot: Dictionary = game_state.generate_loot(GameEnums.ItemRarity.COMMON)
	)
	
	print("Table rolling time (300 rolls): %.3f seconds" % execution_time)
	assert_between(
		execution_time,
		0.0,
		2.0,
		"Table rolling should complete within 2 seconds"
	)