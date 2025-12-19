extends GdUnitTestSuite

## Unit tests for BattleCalculations
## Tests all pure battle math functions in isolation

# Preload the classes we're testing
const BattleCalculations = preload("res://src/core/battle/BattleCalculations.gd")
const BattleTestFactory = preload("res://tests/fixtures/BattleTestFactory.gd")

#region Hit Calculation Tests

func test_base_hit_threshold_is_4() -> void:
	# With no modifiers, base hit threshold should be 4
	var threshold := BattleCalculations.calculate_hit_threshold(
		0,  # combat_skill
		false,  # target_in_cover
		false,  # attacker_elevated
		false,  # target_elevated
		12.0,  # range_inches
		24  # weapon_range
	)
	assert_int(threshold).is_equal(4)

func test_combat_skill_reduces_hit_threshold() -> void:
	# Combat skill 3 should reduce threshold by 3
	var threshold := BattleCalculations.calculate_hit_threshold(
		3,  # combat_skill
		false, false, false,
		12.0, 24
	)
	assert_int(threshold).is_equal(1)  # 4 - 3 = 1

func test_cover_increases_hit_threshold() -> void:
	# Cover should add +1 to threshold (harder to hit)
	var threshold := BattleCalculations.calculate_hit_threshold(
		0,  # combat_skill
		true,  # target_in_cover
		false, false,
		12.0, 24
	)
	assert_int(threshold).is_equal(5)  # 4 + 1 = 5

func test_elevation_bonus_helps_attacker() -> void:
	# Elevated attacker shooting down gets -1 to threshold
	var threshold := BattleCalculations.calculate_hit_threshold(
		0,
		false,
		true,  # attacker_elevated
		false,  # target_not_elevated
		12.0, 24
	)
	assert_int(threshold).is_equal(3)  # 4 - 1 = 3

func test_point_blank_bonus() -> void:
	# Within 2" gets point blank bonus
	var threshold := BattleCalculations.calculate_hit_threshold(
		0, false, false, false,
		1.5,  # within 2"
		24
	)
	assert_int(threshold).is_equal(3)  # 4 - 1 = 3

func test_long_range_penalty() -> void:
	# Beyond weapon range gets penalty
	var threshold := BattleCalculations.calculate_hit_threshold(
		0, false, false, false,
		30.0,  # beyond 24" range
		24
	)
	assert_int(threshold).is_equal(5)  # 4 + 1 = 5

func test_threshold_clamped_to_valid_range() -> void:
	# Very high skill shouldn't go below 1
	var threshold := BattleCalculations.calculate_hit_threshold(
		10,  # very high skill
		false, false, false,
		12.0, 24
	)
	assert_int(threshold).is_equal(1)  # Minimum is 1

func test_impossible_hit_threshold() -> void:
	# Many penalties can make hit impossible (7)
	var threshold := BattleCalculations.calculate_hit_threshold(
		0,  # no skill
		true,  # in cover
		false,
		true,  # target elevated
		30.0,  # long range
		24
	)
	assert_int(threshold).is_equal(7)  # 4 + 1 + 1 + 1 = 7 (impossible)

func test_check_hit_success() -> void:
	assert_bool(BattleCalculations.check_hit(4, 4)).is_true()
	assert_bool(BattleCalculations.check_hit(5, 4)).is_true()
	assert_bool(BattleCalculations.check_hit(6, 4)).is_true()

func test_check_hit_failure() -> void:
	assert_bool(BattleCalculations.check_hit(3, 4)).is_false()
	assert_bool(BattleCalculations.check_hit(1, 4)).is_false()

#endregion

#region Damage Calculation Tests

func test_base_weapon_damage() -> void:
	var damage := BattleCalculations.calculate_weapon_damage(2, false)
	assert_int(damage).is_equal(2)

func test_critical_instant_kill_by_default() -> void:
	# Per Five Parsecs rules: Critical = instant kill (999 damage)
	# House rule "brutal_combat" would change this to double damage
	var damage := BattleCalculations.calculate_weapon_damage(2, true)
	assert_int(damage).is_equal(999)  # Instant kill by default

func test_minimum_damage_is_one() -> void:
	var damage := BattleCalculations.calculate_weapon_damage(0, false)
	assert_int(damage).is_equal(1)  # Minimum is 1

func test_damage_after_armor_basic() -> void:
	# Raw damage 2, toughness 3, no penetration
	var damage := BattleCalculations.calculate_damage_after_armor(2, 3, 0)
	assert_int(damage).is_equal(0)  # 2 - 3 = 0 (minimum)

func test_damage_after_armor_with_penetration() -> void:
	# Raw damage 2, toughness 3, penetration 2
	var damage := BattleCalculations.calculate_damage_after_armor(2, 3, 2)
	assert_int(damage).is_equal(1)  # 2 - (3-2) = 1

func test_damage_against_low_toughness() -> void:
	# Raw damage 3, toughness 1, no penetration
	var damage := BattleCalculations.calculate_damage_after_armor(3, 1, 0)
	assert_int(damage).is_equal(2)  # 3 - 1 = 2

#endregion

#region Armor Save Tests

func test_no_armor_save_threshold() -> void:
	var threshold := BattleCalculations.get_armor_save_threshold("none")
	assert_int(threshold).is_equal(7)  # Cannot save

func test_light_armor_save_threshold() -> void:
	var threshold := BattleCalculations.get_armor_save_threshold("light")
	assert_int(threshold).is_equal(6)

func test_combat_armor_save_threshold() -> void:
	var threshold := BattleCalculations.get_armor_save_threshold("combat")
	assert_int(threshold).is_equal(5)

func test_battle_suit_save_threshold() -> void:
	var threshold := BattleCalculations.get_armor_save_threshold("battle_suit")
	assert_int(threshold).is_equal(4)

func test_armor_save_success() -> void:
	assert_bool(BattleCalculations.check_armor_save(6, "light")).is_true()
	assert_bool(BattleCalculations.check_armor_save(5, "combat")).is_true()

func test_armor_save_failure() -> void:
	assert_bool(BattleCalculations.check_armor_save(5, "light")).is_false()
	assert_bool(BattleCalculations.check_armor_save(4, "combat")).is_false()

func test_high_damage_makes_saves_harder() -> void:
	# High damage (3+) increases save threshold by 1
	# Light armor normally saves on 6+, but with 3 damage needs 7+ (impossible)
	assert_bool(BattleCalculations.check_armor_save(6, "light", 3)).is_false()

#endregion

#region Combat Resolution Tests

func test_resolve_ranged_attack_hit() -> void:
	var attacker := BattleTestFactory.create_attacker(3, 12.0)
	var target := BattleTestFactory.create_target(3, "none", false)
	var weapon := BattleTestFactory.create_rifle()

	# Fixed dice roller: 5 for hit, 3 for armor
	var roller := BattleTestFactory.create_fixed_roller([5, 3])

	var result := BattleCalculations.resolve_ranged_attack(
		attacker, target, weapon, roller
	)

	assert_bool(result["hit"]).is_true()
	assert_int(result["hit_roll"]).is_equal(5)

func test_resolve_ranged_attack_miss() -> void:
	var attacker := BattleTestFactory.create_attacker(0, 12.0)  # No skill
	var target := BattleTestFactory.create_target(3, "none", true)  # In cover
	var weapon := BattleTestFactory.create_rifle()

	# Fixed dice roller: 4 (needs 5+ with cover and no skill)
	var roller := BattleTestFactory.create_constant_roller(4)

	var result := BattleCalculations.resolve_ranged_attack(
		attacker, target, weapon, roller
	)

	assert_bool(result["hit"]).is_false()

func test_resolve_ranged_attack_critical() -> void:
	var attacker := BattleTestFactory.create_attacker(2, 12.0)
	var target := BattleTestFactory.create_target(3, "none", false)
	var weapon := BattleTestFactory.create_rifle()

	# Natural 6 is critical
	var roller := BattleTestFactory.create_fixed_roller([6, 1])  # Hit, failed armor

	var result := BattleCalculations.resolve_ranged_attack(
		attacker, target, weapon, roller
	)

	assert_bool(result["hit"]).is_true()
	assert_bool(result["critical"]).is_true()

func test_resolve_ranged_attack_armor_saves() -> void:
	var attacker := BattleTestFactory.create_attacker(3, 12.0)
	var target := BattleTestFactory.create_target(3, "combat", false)  # Combat armor
	var weapon := BattleTestFactory.create_rifle()

	# 5 to hit, 5 for armor save (saves on 5+)
	var roller := BattleTestFactory.create_fixed_roller([5, 5])

	var result := BattleCalculations.resolve_ranged_attack(
		attacker, target, weapon, roller
	)

	assert_bool(result["hit"]).is_true()
	assert_bool(result["armor_saved"]).is_true()
	assert_int(result["wounds_inflicted"]).is_equal(0)

func test_resolve_brawl_attacker_wins() -> void:
	var attacker := {"combat_skill": 3}
	var defender := {"combat_skill": 1}

	# Attacker rolls 4+3=7, defender rolls 2+1=3
	var roller := BattleTestFactory.create_fixed_roller([4, 2])

	var result := BattleCalculations.resolve_brawl(attacker, defender, roller)

	assert_str(result["winner"]).is_equal("attacker")
	assert_int(result["damage_to_defender"]).is_equal(1)

func test_resolve_brawl_defender_wins() -> void:
	var attacker := {"combat_skill": 1}
	var defender := {"combat_skill": 3}

	# Attacker rolls 2+1=3, defender rolls 4+3=7
	var roller := BattleTestFactory.create_fixed_roller([2, 4])

	var result := BattleCalculations.resolve_brawl(attacker, defender, roller)

	assert_str(result["winner"]).is_equal("defender")
	assert_int(result["damage_to_attacker"]).is_equal(1)

func test_resolve_brawl_draw() -> void:
	var attacker := {"combat_skill": 2}
	var defender := {"combat_skill": 2}

	# Both roll same: 3+2=5
	var roller := BattleTestFactory.create_constant_roller(3)

	var result := BattleCalculations.resolve_brawl(attacker, defender, roller)

	assert_str(result["winner"]).is_equal("draw")
	assert_int(result["damage_to_attacker"]).is_equal(0)
	assert_int(result["damage_to_defender"]).is_equal(0)

#endregion

#region Experience Calculation Tests

func test_xp_for_participation() -> void:
	var xp := BattleCalculations.calculate_crew_xp(true, false, 0, false)
	# Participation (1) + defeat bonus (1) = 2
	assert_int(xp).is_equal(2)

func test_xp_for_victory() -> void:
	var xp := BattleCalculations.calculate_crew_xp(true, true, 0, false)
	# Participation (1) + victory bonus (2) = 3
	assert_int(xp).is_equal(3)

func test_xp_for_first_kill() -> void:
	var xp := BattleCalculations.calculate_crew_xp(true, true, 1, false)
	# Participation (1) + victory (2) + kill (1) = 4
	assert_int(xp).is_equal(4)

func test_xp_for_survival() -> void:
	var xp := BattleCalculations.calculate_crew_xp(true, true, 0, true)
	# Participation (1) + victory (2) + survival (1) = 4
	assert_int(xp).is_equal(4)

func test_no_xp_without_participation() -> void:
	var xp := BattleCalculations.calculate_crew_xp(false, true, 5, true)
	assert_int(xp).is_equal(0)

func test_calculate_battle_xp_for_crew() -> void:
	var crew_data := BattleTestFactory.create_crew_xp_data(3)
	var xp_awards := BattleCalculations.calculate_battle_xp(crew_data, true)

	assert_int(xp_awards.size()).is_equal(3)
	# Each should have at least participation + victory = 3
	for crew_id in xp_awards:
		assert_int(xp_awards[crew_id]).is_greater_equal(3)

#endregion

#region Loot Calculation Tests

func test_loot_rolls_on_victory() -> void:
	var rolls := BattleCalculations.calculate_loot_rolls(true, 3, true)
	# Base (1) + hold field (1) = 2
	assert_int(rolls).is_equal(2)

func test_loot_rolls_no_loot_on_defeat() -> void:
	var rolls := BattleCalculations.calculate_loot_rolls(false, 3, false)
	assert_int(rolls).is_equal(0)

func test_loot_rolls_bonus_for_many_enemies() -> void:
	var rolls := BattleCalculations.calculate_loot_rolls(true, 6, true)
	# Base (1) + many enemies (1) + hold field (1) = 3
	assert_int(rolls).is_equal(3)

func test_calculate_battle_credits() -> void:
	var credits := BattleCalculations.calculate_battle_credits(10, 4, 1.0)
	assert_int(credits).is_equal(14)

func test_calculate_battle_credits_with_bonus() -> void:
	var credits := BattleCalculations.calculate_battle_credits(10, 4, 1.5)
	assert_int(credits).is_equal(21)  # (10 + 4) * 1.5 = 21

#endregion

#region Initiative Tests

func test_seize_initiative_success() -> void:
	# 4 + 3 + 2 = 9 (just enough)
	var result := BattleCalculations.check_seize_initiative(4, 3, 2)
	assert_bool(result["seized"]).is_true()
	assert_int(result["roll_total"]).is_equal(9)

func test_seize_initiative_failure() -> void:
	# 3 + 3 + 2 = 8 (not enough)
	var result := BattleCalculations.check_seize_initiative(3, 3, 2)
	assert_bool(result["seized"]).is_false()
	assert_int(result["roll_total"]).is_equal(8)

func test_high_savvy_helps_initiative() -> void:
	# 2 + 2 + 5 = 9 (high savvy compensates)
	var result := BattleCalculations.check_seize_initiative(2, 2, 5)
	assert_bool(result["seized"]).is_true()

#endregion

#region Reaction Dice Tests

func test_reaction_dice_count() -> void:
	assert_int(BattleCalculations.get_reaction_dice_count(4)).is_equal(4)
	assert_int(BattleCalculations.get_reaction_dice_count(6)).is_equal(6)

func test_quick_action_threshold() -> void:
	assert_bool(BattleCalculations.is_quick_action(4)).is_true()
	assert_bool(BattleCalculations.is_quick_action(5)).is_true()
	assert_bool(BattleCalculations.is_quick_action(6)).is_true()

func test_slow_action_threshold() -> void:
	assert_bool(BattleCalculations.is_quick_action(1)).is_false()
	assert_bool(BattleCalculations.is_quick_action(2)).is_false()
	assert_bool(BattleCalculations.is_quick_action(3)).is_false()

#endregion

#region Utility Tests

func test_calculate_distance() -> void:
	var dist := BattleCalculations.calculate_distance(Vector2(0, 0), Vector2(3, 4))
	assert_float(dist).is_equal_approx(5.0, 0.01)

func test_calculate_grid_distance() -> void:
	var dist := BattleCalculations.calculate_grid_distance(Vector2i(0, 0), Vector2i(3, 4))
	assert_int(dist).is_equal(7)  # Manhattan distance

#endregion
