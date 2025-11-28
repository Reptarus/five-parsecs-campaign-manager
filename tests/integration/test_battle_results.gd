extends GdUnitTestSuite

## Unit tests for BattleResults
## Tests the Battle → PostBattle data contract

const BattleResults = preload("res://src/core/battle/BattleResults.gd")

func test_battle_results_creation() -> void:
	var results := BattleResults.new()
	assert_object(results).is_not_null()
	assert_str(results.battle_id).is_not_empty()

func test_battle_results_outcome() -> void:
	var results := BattleResults.new()
	results.set_outcome("victory")

	assert_str(results.outcome).is_equal("victory")
	assert_bool(results.is_victory()).is_true()
	assert_bool(results.hold_field).is_true()

func test_battle_results_participants() -> void:
	var results := BattleResults.new()
	results.add_participant("crew_1")
	results.add_participant("crew_2")
	results.add_participant("crew_1")  # Duplicate should be ignored

	assert_int(results.crew_participants.size()).is_equal(2)

func test_battle_results_casualties() -> void:
	var results := BattleResults.new()
	results.add_participant("crew_1")
	results.add_participant("crew_2")
	results.add_casualty("crew_2", "killed", 3, "enemy_fire")

	assert_int(results.get_casualty_count()).is_equal(1)
	var survivors := results.get_survivors()
	assert_int(survivors.size()).is_equal(1)
	assert_str(survivors[0]).is_equal("crew_1")

func test_battle_results_xp() -> void:
	var results := BattleResults.new()
	results.set_xp("crew_1", 3)
	results.add_xp("crew_1", 2)
	results.set_xp("crew_2", 2)

	assert_int(results.xp_earned["crew_1"]).is_equal(5)
	assert_int(results.get_total_xp()).is_equal(7)

func test_battle_results_credits() -> void:
	var results := BattleResults.new()
	results.base_payment = 10
	results.danger_pay = 4
	results.bonus_credits = 5

	assert_int(results.get_total_credits()).is_equal(19)

func test_battle_results_to_post_battle_format() -> void:
	var results := BattleResults.new()
	results.set_outcome("victory")
	results.add_participant("crew_1")
	results.add_participant("crew_2")
	results.enemies_defeated = 3
	results.base_payment = 10
	results.danger_pay = 4
	results.set_xp("crew_1", 3)
	results.add_injury("crew_2", "light_wound", 1, 1)

	var post_battle := results.to_post_battle_format()

	# Verify critical fields for PostBattlePhase
	assert_bool(post_battle["success"]).is_true()
	assert_int(post_battle["crew_participants"].size()).is_equal(2)
	assert_int(post_battle["injuries_sustained"].size()).is_equal(1)
	assert_int(post_battle["base_payment"]).is_equal(10)
	assert_int(post_battle["danger_pay"]).is_equal(4)
	assert_int(post_battle["enemies_defeated"]).is_equal(3)
	assert_bool(post_battle.has("xp_earned")).is_true()

func test_battle_results_validation() -> void:
	var results := BattleResults.new()
	var errors := results.validate()
	assert_bool(errors.size() > 0).is_true()  # Missing outcome and participants

	results.set_outcome("victory")
	results.add_participant("crew_1")
	errors = results.validate()
	assert_int(errors.size()).is_equal(0)
