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

	# NOTE: Using dictionary to hold count because GDScript closures capture integers by value
	var dice_results := [4, 4, 5, 5, 5]  # Hit roll, armor saves
	var roll_state := {"count": 0}
	var dice_roller := func() -> int:
		var result = dice_results[roll_state.count % dice_results.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_area_attack(
		attacker, primary_target, all_targets, weapon, dice_roller
	)

	assert_str(result["template_type"]).is_equal("area")
	assert_float(result["area_radius"]).is_equal(2.0)
	assert_bool(result["primary_result"]["hit"]).is_true()
	assert_int(result["secondary_targets"].size()).is_greater_equal(1)

func test_non_area_weapon_falls_through_to_regular_resolution() -> void:
	# A weapon without the Area trait must NOT be treated as a template weapon.
	# (Fabricated "spread"/"explosive"/"template" traits were removed per Core Rules p.50.)
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

	var all_targets := [primary_target]

	var weapon := {
		"damage": 2,
		"range": 6,
		"traits": ["Focused"]
	}

	var dice_results := [5, 4, 5, 5]
	var roll_state := {"count": 0}
	var dice_roller := func() -> int:
		var result = dice_results[roll_state.count % dice_results.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_area_attack(
		attacker, primary_target, all_targets, weapon, dice_roller
	)

	# No template type assigned; regular single-target resolution was used
	assert_str(result["template_type"]).is_equal("")
	assert_int(result["secondary_targets"].size()).is_equal(0)

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

	# NOTE: Using dictionary to hold count because GDScript closures capture integers by value
	var dice_results := [5, 4, 6, 6]  # Hit, damage roll, armor saves
	var roll_state := {"count": 0}
	var dice_roller := func() -> int:
		var result = dice_results[roll_state.count % dice_results.size()]
		roll_state.count += 1
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
		"traits": ["Area"]  # Core Rules p.50: resolve all shots within 2"
	}

	# NOTE: Using dictionary to hold count because GDScript closures capture integers by value
	var dice_results := [5, 3, 5, 6]  # Hit, damage, primary armor (saves), secondary armor (saves)
	var roll_state := {"count": 0}
	var dice_roller := func() -> int:
		var result = dice_results[roll_state.count % dice_results.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_area_attack(
		attacker, primary_target, all_targets, weapon, dice_roller
	)

	# Primary target has combat armor (5+), should save with roll of 5
	assert_bool(result["primary_result"].get("armor_saved", false)).is_true()

	# Secondary target has light armor (6+), should save with roll of 6
	if result["secondary_targets"].size() > 0:
		var secondary_result = result["secondary_targets"][0]
		assert_bool(secondary_result.get("armor_saved", false)).is_true()

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

	# NOTE: Using dictionary to hold count because GDScript closures capture integers by value
	var dice_results := [5, 3, 6, 6]
	var roll_state := {"count": 0}
	var dice_roller := func() -> int:
		var result = dice_results[roll_state.count % dice_results.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_area_attack(
		attacker, primary_target, all_targets, weapon, dice_roller
	)

	# Piercing should bypass armor saves
	var effects: Array = result["primary_result"].get("effects", [])
	assert_bool("armor_pierced" in effects).is_true()

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

	# NOTE: Using dictionary to hold count because GDScript closures capture integers by value
	var dice_results := [5, 6, 3, 3]  # Hit, damage roll 6 (elimination), armor fails
	var roll_state := {"count": 0}
	var dice_roller := func() -> int:
		var result = dice_results[roll_state.count % dice_results.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_area_attack(
		attacker, primary_target, all_targets, weapon, dice_roller
	)

	# Natural 6 on damage roll should eliminate all targets
	assert_bool(result["primary_result"].get("target_eliminated", false)).is_true()
	assert_int(result.get("total_eliminations", 0)).is_greater_equal(1)

func test_is_area_weapon_detects_only_book_area_trait() -> void:
	# Core Rules p.50: the only area trait is "Area". Fabricated explosive/spread/
	# template traits were removed.
	assert_bool(BattleCalculations.is_area_weapon(["area"])).is_true()
	assert_bool(BattleCalculations.is_area_weapon(["Area"])).is_true()
	assert_bool(BattleCalculations.is_area_weapon(["explosive"])).is_false()
	assert_bool(BattleCalculations.is_area_weapon(["spread"])).is_false()
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

	# NOTE: Using dictionary to hold count because GDScript closures capture integers by value
	var dice_results := [5, 4]
	var roll_state := {"count": 0}
	var dice_roller := func() -> int:
		var result = dice_results[roll_state.count % dice_results.size()]
		roll_state.count += 1
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
