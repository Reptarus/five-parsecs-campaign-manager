extends GdUnitTestSuite

## Unit tests for BattleSetupData
## Tests the PreBattle → Battle data contract

const BattleSetupData = preload("res://src/core/battle/BattleSetupData.gd")
const BattleTestFactory = preload("res://tests/fixtures/BattleTestFactory.gd")

func test_battle_setup_data_creation() -> void:
	var setup := BattleSetupData.new()
	assert_object(setup).is_not_null()
	assert_str(setup.setup_id).is_not_empty()

func test_battle_setup_data_initialize() -> void:
	var setup := BattleSetupData.new()
	var crew := BattleTestFactory.create_test_crew(4)
	var enemies := BattleTestFactory.create_test_enemies(3)
	var mission := BattleTestFactory.create_mission()

	var result := setup.initialize(crew, enemies, mission)

	assert_bool(result).is_true()
	assert_int(setup.get_crew_count()).is_equal(4)
	assert_int(setup.get_enemy_count()).is_equal(3)

func test_battle_setup_data_initiative() -> void:
	var setup := BattleSetupData.new()
	setup.set_initiative_results(true, 10, 3)

	assert_bool(setup.initiative_seized).is_true()
	assert_int(setup.initiative_roll).is_equal(10)
	assert_int(setup.initiative_savvy_bonus).is_equal(3)

func test_battle_setup_data_validation() -> void:
	var setup := BattleSetupData.new()
	# Empty setup should fail validation
	var errors := setup.validate()
	assert_bool(errors.size() > 0).is_true()

	# Add required data
	var crew := BattleTestFactory.create_test_crew(2)
	var enemies := BattleTestFactory.create_test_enemies(2)
	var mission := BattleTestFactory.create_mission()
	setup.initialize(crew, enemies, mission)
	setup.set_initiative_results(false, 7, 2)

	errors = setup.validate()
	assert_int(errors.size()).is_equal(0)

func test_battle_setup_highest_savvy() -> void:
	var setup := BattleSetupData.new()
	var crew := [
		{"id": "c1", "savvy": 1},
		{"id": "c2", "savvy": 4},
		{"id": "c3", "savvy": 2}
	]
	setup.initialize(crew, [], null)

	var highest := setup.get_highest_crew_savvy()
	assert_int(highest).is_equal(4)
