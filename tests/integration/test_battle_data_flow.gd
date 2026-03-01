extends GdUnitTestSuite

## Integration tests for battle phase data flow
## Tests the complete PreBattle → Battle → PostBattle pipeline

const BattleSetupData = preload("res://src/core/battle/BattleSetupData.gd")
const BattleResults = preload("res://src/core/battle/BattleResults.gd")
const BattleCalculations = preload("res://src/core/battle/BattleCalculations.gd")
const BattleTestFactory = preload("res://tests/fixtures/BattleTestFactory.gd")

var battle_phase: Node = null

func before_test() -> void:
	var BattlePhaseClass = load("res://src/core/campaign/phases/BattlePhase.gd")
	if BattlePhaseClass:
		battle_phase = BattlePhaseClass.new()
		add_child(battle_phase)

func after_test() -> void:
	if battle_phase:
		battle_phase.queue_free()
		battle_phase = null

#region Data Flow Tests

func test_pre_battle_to_battle_data_flow() -> void:
	var setup := BattleSetupData.new()
	var crew := BattleTestFactory.create_test_crew(4)
	var enemies := BattleTestFactory.create_test_enemies(3)
	var mission := BattleTestFactory.create_mission()

	setup.initialize(crew, enemies, mission)
	setup.set_initiative_results(true, 10, 3)
	setup.set_deployment_condition("standard", "Standard rules apply")

	var setup_dict := setup.to_dictionary()
	assert_bool(setup_dict.has("crew_count")).is_true()
	assert_int(setup_dict["crew_count"]).is_equal(4)
	assert_bool(setup_dict["initiative_seized"]).is_true()

func test_battle_to_post_battle_data_flow() -> void:
	var results := BattleResults.new()
	results.set_outcome("victory")
	results.mission_id = "test_mission"
	results.rounds_fought = 4
	results.enemies_defeated = 3

	for i in range(4):
		results.add_participant("crew_" + str(i))

	var crew_data := BattleTestFactory.create_crew_xp_data(4)
	var xp_awards := BattleCalculations.calculate_battle_xp(crew_data, true)
	for crew_id in xp_awards:
		results.set_xp(crew_id, xp_awards[crew_id])

	results.add_injury("crew_1", "light_wound", 1, 1)
	results.base_payment = 10
	results.danger_pay = 4
	results.loot_rolls = BattleCalculations.calculate_loot_rolls(
		true, results.enemies_defeated, results.hold_field
	)

	var post_data := results.to_post_battle_format()

	assert_bool(post_data["success"]).is_true()
	assert_int(post_data["crew_participants"].size()).is_equal(4)
	assert_int(post_data["enemies_defeated"]).is_equal(3)
	assert_int(post_data["base_payment"]).is_equal(10)
	assert_int(post_data["injuries_sustained"].size()).is_equal(1)
	assert_bool(post_data["xp_earned"].size() > 0).is_true()

func test_complete_battle_flow_simulation() -> void:
	# Phase 1: Pre-Battle Setup
	var setup := BattleSetupData.new()
	var crew := BattleTestFactory.create_test_crew(4)
	var enemies := BattleTestFactory.create_test_enemies(3)
	var mission := BattleTestFactory.create_mission("patrol", 2, 10)

	setup.initialize(crew, enemies, mission)

	var init := BattleCalculations.check_seize_initiative(4, 5, 2)
	setup.set_initiative_results(init["seized"], init["roll_total"], 2)
	setup.set_deployment_condition("standard", "Standard deployment")

	assert_bool(setup.is_valid()).is_true()

	# Phase 2: Battle Execution (simulated)
	var results := BattleResults.new()
	results.mission_id = mission["id"]
	results.set_outcome("victory")
	results.rounds_fought = 4
	results.enemies_defeated = 3

	for crew_member in crew:
		results.add_participant(crew_member["id"])

	var xp_data: Array = []
	for i in range(crew.size()):
		xp_data.append({
			"id": crew[i]["id"],
			"participated": true,
			"kills": 1 if i == 0 else 0,
			"injured": i == crew.size() - 1,
			"achievements": []
		})

	var xp_awards := BattleCalculations.calculate_battle_xp(xp_data, true)
	for crew_id in xp_awards:
		results.set_xp(crew_id, xp_awards[crew_id])

	results.base_payment = mission["base_payment"]
	results.danger_pay = mission["danger_pay"]
	results.loot_rolls = BattleCalculations.calculate_loot_rolls(true, 3, true)

	# Phase 3: Post-Battle Data
	var post_battle := results.to_post_battle_format()

	assert_bool(post_battle["success"]).is_true()
	assert_int(post_battle["crew_participants"].size()).is_equal(4)
	assert_int(post_battle["base_payment"]).is_equal(10)
	assert_int(post_battle["danger_pay"]).is_equal(4)
	assert_bool(post_battle["xp_earned"].size() > 0).is_true()

	var leader_id: String = crew[0]["id"]
	assert_bool(post_battle["xp_earned"].has(leader_id)).is_true()
	assert_int(post_battle["xp_earned"][leader_id]).is_equal(4)

#endregion

#region BattlePhase Handler Tests

func test_battle_phase_handler_exists() -> void:
	if not battle_phase:
		return

	assert_object(battle_phase).is_not_null()
	assert_bool(battle_phase.has_signal("battle_phase_completed")).is_true()
	assert_bool(battle_phase.has_signal("battle_results_ready")).is_true()

func test_battle_phase_get_results() -> void:
	if not battle_phase:
		return

	var results: Dictionary = battle_phase.get_battle_results()
	assert_bool(results.is_empty()).is_true()

#endregion

#region Edge Cases

func test_defeat_results_format() -> void:
	var results := BattleResults.new()
	results.set_outcome("defeat")

	assert_bool(results.is_defeat()).is_true()
	assert_bool(results.hold_field).is_false()

	var post_data := results.to_post_battle_format()
	assert_bool(post_data["success"]).is_false()

func test_empty_crew_handling() -> void:
	var setup := BattleSetupData.new()
	var init := setup.initialize([], [], null)
	assert_bool(init).is_false()

func test_multiple_injuries_same_crew() -> void:
	var results := BattleResults.new()
	results.add_injury("crew_1", "light_wound", 1, 1)
	results.add_injury("crew_1", "serious_wound", 2, 3)

	assert_int(results.get_injury_count()).is_equal(2)

#endregion
