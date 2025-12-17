extends GdUnitTestSuite

## Test suite for area/template weapon resolution
## Tests BattleCalculations.resolve_area_attack() and helper functions

const BattleCalculations = preload("res://src/core/battle/BattleCalculations.gd")

func test_get_targets_in_area_finds_units_in_radius() -> void:
	var impact_pos := Vector2(10.0, 10.0)
	var radius_inches := 3.0  # 6 game units

	var all_units := [
		{"id": "target1", "position": Vector2(10.0, 10.0)},  # At impact point
		{"id": "target2", "position": Vector2(12.0, 12.0)},  # ~2.8 units away
		{"id": "target3", "position": Vector2(15.0, 15.0)},  # ~7 units away
		{"id": "target4", "position": Vector2(11.0, 11.0)}   # ~1.4 units away
	]

	var targets_in_area = BattleCalculations.get_targets_in_area(impact_pos, radius_inches, all_units)

	assert_int(targets_in_area.size()).is_equal(3)
	assert_bool(_has_target(targets_in_area, "target1")).is_true()
	assert_bool(_has_target(targets_in_area, "target2")).is_true()
	assert_bool(_has_target(targets_in_area, "target4")).is_true()
	assert_bool(_has_target(targets_in_area, "target3")).is_false()

func test_get_targets_in_area_empty_when_no_units_in_range() -> void:
	var impact_pos := Vector2(10.0, 10.0)
	var radius_inches := 1.0

	var all_units := [
		{"id": "target1", "position": Vector2(50.0, 50.0)},
		{"id": "target2", "position": Vector2(100.0, 100.0)}
	]

	var targets_in_area = BattleCalculations.get_targets_in_area(impact_pos, radius_inches, all_units)

	assert_int(targets_in_area.size()).is_equal(0)

func test_get_targets_in_spread_finds_units_in_cone() -> void:
	var attacker_pos := Vector2(0.0, 0.0)
	var primary_target_pos := Vector2(10.0, 0.0)  # Directly right
	var cone_width := 30.0  # 30 degree cone

	var all_units := [
		{"id": "target1", "position": Vector2(10.0, 0.0)},   # Dead center (0°)
		{"id": "target2", "position": Vector2(10.0, 2.0)},   # ~11° off center
		{"id": "target3", "position": Vector2(10.0, 5.0)},   # ~26° off center
		{"id": "target4", "position": Vector2(10.0, 8.0)},   # ~38° off center (outside)
		{"id": "target5", "position": Vector2(0.0, 10.0)}    # 90° off (outside)
	]

	var targets_in_spread = BattleCalculations.get_targets_in_spread(
		attacker_pos, primary_target_pos, cone_width, all_units
	)

	# Should hit targets within 15° of center (30° cone / 2)
	assert_int(targets_in_spread.size()).is_greater_equal(3)
	assert_bool(_has_target(targets_in_spread, "target1")).is_true()
	assert_bool(_has_target(targets_in_spread, "target2")).is_true()
	assert_bool(_has_target(targets_in_spread, "target3")).is_true()
	assert_bool(_has_target(targets_in_spread, "target5")).is_false()

func test_resolve_area_attack_with_area_trait() -> void:
	var attacker := {
		"combat_skill": 1,
		"position": Vector2(0.0, 0.0),
		"range_to_target": 10.0
	}

	var primary_target := {
		"id": "primary",
		"name": "Primary Target",
		"position": Vector2(10.0, 10.0),
		"in_cover": false,
		"toughness": 3,
		"armor": "none"
	}

	var secondary1 := {
		"id": "secondary1",
		"name": "Secondary 1",
		"position": Vector2(11.0, 11.0),  # ~1.4 units from primary
		"toughness": 3,
		"armor": "none"
	}

	var secondary2 := {
		"id": "secondary2",
		"name": "Secondary 2",
		"position": Vector2(12.0, 12.0),  # ~2.8 units from primary
		"toughness": 3,
		"armor": "none"
	}

	var all_targets := [primary_target, secondary1, secondary2]

	var weapon := {
		"damage": 2,
		"range": 24,
		"traits": ["area"],
		"area_radius": 2.0  # 4 game units
	}

	var dice_results := [4, 4, 5, 5, 5]  # Hit roll, armor saves
	var dice_index := 0
	var dice_roller := func() -> int:
		var result = dice_results[dice_index]
		dice_index += 1
		return result

	var result = BattleCalculations.resolve_area_attack(
		attacker, primary_target, all_targets, weapon, dice_roller
	)

	assert_str(result["template_type"]).is_equal("area")
	assert_float(result["area_radius"]).is_equal(2.0)
	assert_bool(result["primary_result"]["hit"]).is_true()
	assert_int(result["secondary_targets"].size()).is_greater_equal(1)

func test_resolve_area_attack_with_spread_trait() -> void:
	var attacker := {
		"combat_skill": 1,
		"position": Vector2(0.0, 0.0),
		"range_to_target": 10.0
	}

	var primary_target := {
		"id": "primary",
		"name": "Primary Target",
		"position": Vector2(10.0, 0.0),
		"in_cover": false,
		"toughness": 3,
		"armor": "none"
	}

	var secondary1 := {
		"id": "secondary1",
		"name": "Secondary 1",
		"position": Vector2(10.0, 2.0),  # In cone
		"toughness": 3,
		"armor": "none"
	}

	var all_targets := [primary_target, secondary1]

	var weapon := {
		"damage": 2,
		"range": 6,
		"traits": ["spread"],
		"spread_width": 30.0
	}

	var dice_results := [5, 4, 5, 5]
	var dice_index := 0
	var dice_roller := func() -> int:
		var result = dice_results[dice_index]
		dice_index += 1
		return result

	var result = BattleCalculations.resolve_area_attack(
		attacker, primary_target, all_targets, weapon, dice_roller
	)

	assert_str(result["template_type"]).is_equal("spread")
	assert_float(result["spread_width"]).is_equal(30.0)
	assert_bool(result["primary_result"]["hit"]).is_true()

func test_resolve_area_attack_shared_damage_roll() -> void:
	var attacker := {
		"combat_skill": 2,
		"position": Vector2(0.0, 0.0),
		"range_to_target": 10.0
	}

	var primary_target := {
		"id": "primary",
		"position": Vector2(10.0, 10.0),
		"in_cover": false,
		"toughness": 3,
		"armor": "none"
	}

	var secondary1 := {
		"id": "secondary1",
		"position": Vector2(11.0, 11.0),
		"toughness": 3,
		"armor": "none"
	}

	var all_targets := [primary_target, secondary1]

	var weapon := {
		"damage": 2,
		"range": 24,
		"traits": ["area"],
		"area_radius": 3.0
	}

	var dice_results := [5, 4, 6, 6]  # Hit, damage roll, armor saves
	var dice_index := 0
	var dice_roller := func() -> int:
		var result = dice_results[dice_index]
		dice_index += 1
		return result

	var result = BattleCalculations.resolve_area_attack(
		attacker, primary_target, all_targets, weapon, dice_roller
	)

	# Verify shared damage roll used for all targets
	assert_that(result.has("shared_damage_roll")).is_true()
	assert_int(result["shared_damage_roll"]).is_equal(4)

func test_resolve_area_attack_individual_armor_saves() -> void:
	var attacker := {
		"combat_skill": 2,
		"position": Vector2(0.0, 0.0),
		"range_to_target": 10.0
	}

	var primary_target := {
		"id": "primary",
		"position": Vector2(10.0, 10.0),
		"in_cover": false,
		"toughness": 3,
		"armor": "combat"  # 5+ save
	}

	var secondary1 := {
		"id": "secondary1",
		"position": Vector2(11.0, 11.0),
		"toughness": 3,
		"armor": "light"  # 6+ save
	}

	var all_targets := [primary_target, secondary1]

	var weapon := {
		"damage": 2,
		"range": 24,
		"traits": ["explosive"],
		"explosion_radius": 3.0
	}

	var dice_results := [5, 3, 5, 6]  # Hit, damage, primary armor (saves), secondary armor (saves)
	var dice_index := 0
	var dice_roller := func() -> int:
		var result = dice_results[dice_index]
		dice_index += 1
		return result

	var result = BattleCalculations.resolve_area_attack(
		attacker, primary_target, all_targets, weapon, dice_roller
	)

	# Primary target has combat armor (5+), should save with roll of 5
	assert_bool(result["primary_result"]["armor_saved"]).is_true()

	# Secondary target has light armor (6+), should save with roll of 6
	if result["secondary_targets"].size() > 0:
		var secondary_result = result["secondary_targets"][0]
		assert_bool(secondary_result["armor_saved"]).is_true()

func test_resolve_area_attack_with_piercing_ignores_armor() -> void:
	var attacker := {
		"combat_skill": 2,
		"position": Vector2(0.0, 0.0),
		"range_to_target": 10.0
	}

	var primary_target := {
		"id": "primary",
		"position": Vector2(10.0, 10.0),
		"in_cover": false,
		"toughness": 3,
		"armor": "combat"  # Should be ignored
	}

	var secondary1 := {
		"id": "secondary1",
		"position": Vector2(11.0, 11.0),
		"toughness": 3,
		"armor": "combat"
	}

	var all_targets := [primary_target, secondary1]

	var weapon := {
		"damage": 2,
		"range": 24,
		"traits": ["area", "piercing"],
		"area_radius": 3.0
	}

	var dice_results := [5, 3, 6, 6]
	var dice_index := 0
	var dice_roller := func() -> int:
		var result = dice_results[dice_index]
		dice_index += 1
		return result

	var result = BattleCalculations.resolve_area_attack(
		attacker, primary_target, all_targets, weapon, dice_roller
	)

	# Piercing should bypass armor saves
	assert_bool("armor_pierced" in result["primary_result"]["effects"]).is_true()

func test_resolve_area_attack_elimination_check() -> void:
	var attacker := {
		"combat_skill": 2,
		"position": Vector2(0.0, 0.0),
		"range_to_target": 10.0
	}

	var primary_target := {
		"id": "primary",
		"position": Vector2(10.0, 10.0),
		"in_cover": false,
		"toughness": 3,
		"armor": "none"
	}

	var secondary1 := {
		"id": "secondary1",
		"position": Vector2(11.0, 11.0),
		"toughness": 3,
		"armor": "none"
	}

	var all_targets := [primary_target, secondary1]

	var weapon := {
		"damage": 2,
		"range": 24,
		"traits": ["area"],
		"area_radius": 3.0
	}

	var dice_results := [5, 6, 3, 3]  # Hit, damage roll 6 (elimination), armor fails
	var dice_index := 0
	var dice_roller := func() -> int:
		var result = dice_results[dice_index]
		dice_index += 1
		return result

	var result = BattleCalculations.resolve_area_attack(
		attacker, primary_target, all_targets, weapon, dice_roller
	)

	# Natural 6 on damage roll should eliminate all targets
	assert_bool(result["primary_result"]["target_eliminated"]).is_true()
	assert_int(result["total_eliminations"]).is_greater_equal(1)

func test_is_area_weapon_detects_all_area_traits() -> void:
	assert_bool(BattleCalculations.is_area_weapon(["area"])).is_true()
	assert_bool(BattleCalculations.is_area_weapon(["template"])).is_true()
	assert_bool(BattleCalculations.is_area_weapon(["explosive"])).is_true()
	assert_bool(BattleCalculations.is_area_weapon(["spread"])).is_true()
	assert_bool(BattleCalculations.is_area_weapon(["accurate"])).is_false()

func test_resolve_area_attack_removes_primary_from_secondary_list() -> void:
	var attacker := {
		"combat_skill": 2,
		"position": Vector2(0.0, 0.0),
		"range_to_target": 10.0
	}

	var primary_target := {
		"id": "primary",
		"position": Vector2(10.0, 10.0),
		"in_cover": false,
		"toughness": 3,
		"armor": "none"
	}

	var all_targets := [primary_target]  # Only primary target in range

	var weapon := {
		"damage": 2,
		"range": 24,
		"traits": ["area"],
		"area_radius": 5.0
	}

	var dice_results := [5, 4]
	var dice_index := 0
	var dice_roller := func() -> int:
		var result = dice_results[dice_index]
		dice_index += 1
		return result

	var result = BattleCalculations.resolve_area_attack(
		attacker, primary_target, all_targets, weapon, dice_roller
	)

	# Secondary targets should be empty (primary already resolved)
	assert_int(result["secondary_targets"].size()).is_equal(0)

## Helper function to check if target ID exists in array
func _has_target(targets: Array, target_id: String) -> bool:
	for target in targets:
		if target is Dictionary and target.get("id", "") == target_id:
			return true
	return false
