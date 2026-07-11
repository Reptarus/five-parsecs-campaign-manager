extends GdUnitTestSuite

## Battle-deployment eligibility filter (Core Rules pp.55, 76, 128-130).
## GameStateManager.filter_deployable() is the single authority the battle-deployment
## sites route through. Excludes DEAD/MISSING/RETIRED, Sick Bay / recovering
## (recovery_turns > 0), and the departed / skip_next_battle status effects.

const CharacterScript = preload("res://src/core/character/Character.gd")

func _deployable(members: Array) -> Array:
	return GameStateManager.filter_deployable(members)

func test_active_dict_member_is_deployable() -> void:
	var out := _deployable([{"name": "A", "status": "ACTIVE"}])
	assert_int(out.size()).is_equal(1)

func test_dead_missing_retired_excluded() -> void:
	var out := _deployable([
		{"name": "Dead", "status": "DEAD"},
		{"name": "Missing", "status": "MISSING"},
		{"name": "Retired", "status": "RETIRED"},
		{"name": "Live", "status": "ACTIVE"},
	])
	assert_int(out.size()).is_equal(1)
	assert_str(str(out[0]["name"])).is_equal("Live")

func test_sick_bay_recovery_turns_excluded() -> void:
	# p.55: a Sick Bay character cannot participate in battles.
	var out := _deployable([{"name": "Hurt", "status": "ACTIVE", "recovery_turns": 2}])
	assert_int(out.size()).is_equal(0)

func test_in_sick_bay_flag_excluded() -> void:
	var out := _deployable([{"name": "Bay", "status": "ACTIVE", "in_sick_bay": true}])
	assert_int(out.size()).is_equal(0)

func test_recovered_member_is_deployable() -> void:
	# p.76: once recovery reaches 0 they rejoin for battle.
	var out := _deployable([{"name": "Healed", "status": "ACTIVE", "recovery_turns": 0}])
	assert_int(out.size()).is_equal(1)

func test_departed_effect_excluded() -> void:
	var out := _deployable([{"name": "Gone", "status": "ACTIVE",
		"status_effects": [{"type": "departed"}]}])
	assert_int(out.size()).is_equal(0)

func test_skip_next_battle_effect_excluded() -> void:
	var out := _deployable([{"name": "Skip", "status": "ACTIVE",
		"status_effects": [{"type": "skip_next_battle"}]}])
	assert_int(out.size()).is_equal(0)

func test_unrelated_status_effect_stays_deployable() -> void:
	var out := _deployable([{"name": "Buffed", "status": "ACTIVE",
		"status_effects": [{"type": "extra_action"}]}])
	assert_int(out.size()).is_equal(1)

func test_character_resource_recovering_excluded() -> void:
	# Character Resource path: current_recovery_turns getter sums injuries[].recovery_turns.
	var c = CharacterScript.new()
	c.injuries.assign([{"type": "Gut Wound", "recovery_turns": 2}])
	var out := _deployable([c])
	assert_int(out.size()).is_equal(0)

func test_character_resource_recovered_but_wounded_is_deployable() -> void:
	# Injury record present (is_wounded == true) but recovery reached 0 → deployable (p.76).
	var c = CharacterScript.new()
	c.injuries.assign([{"type": "Old Scar", "recovery_turns": 0}])
	assert_bool(c.is_wounded).is_true()
	assert_int(c.current_recovery_turns).is_equal(0)
	var out := _deployable([c])
	assert_int(out.size()).is_equal(1)
