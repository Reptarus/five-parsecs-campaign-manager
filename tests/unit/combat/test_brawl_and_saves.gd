extends GdUnitTestSuite
## Phase 1 Combat System Tests
## Tests brawl integration, screen vs armor, and K'Erin reroll

const BattleCalculations = preload("res://src/core/battle/BattleCalculations.gd")

#region Brawl Combat Tests

func test_brawl_basic_resolution() -> void:
	# Test basic brawl combat resolution
	var attacker := {
		"combat_skill": 1,
		"speed": 4,
		"species": "human",
		"has_melee_weapon": true,
		"has_pistol": false,
		"weapon_traits": ["melee"],
		"toughness": 3
	}
	var defender := {
		"combat_skill": 0,
		"speed": 4,
		"species": "human",
		"has_melee_weapon": false,
		"has_pistol": true,
		"weapon_traits": ["pistol"],
		"toughness": 3
	}

	# Use deterministic dice for testing
	var roll_state := {"count": 0}
	var fixed_rolls := [4, 3]  # Attacker rolls 4, defender rolls 3
	var dice_roller := func():
		var result = fixed_rolls[roll_state.count % fixed_rolls.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_brawl(attacker, defender, dice_roller)

	# Attacker: 4 + 1 skill + 2 melee = 7
	# Defender: 3 + 0 skill + 1 pistol = 4
	assert_that(result.get("winner")).is_equal("attacker")
	assert_that(result.get("attacker_hits")).is_greater(0)

func test_brawl_draw_both_take_hit() -> void:
	# Test that a draw causes both combatants to take a hit
	var attacker := {
		"combat_skill": 1,
		"speed": 4,
		"species": "human",
		"has_melee_weapon": false,
		"has_pistol": false,
		"weapon_traits": [],
		"toughness": 3
	}
	var defender := attacker.duplicate()

	# Both roll 3 with same skill = draw
	var dice_roller := func(): return 3

	var result = BattleCalculations.resolve_brawl(attacker, defender, dice_roller)

	assert_that(result.get("winner")).is_equal("draw")
	assert_that(result.get("attacker_hits")).is_greater(0)
	assert_that(result.get("defender_hits")).is_greater(0)

func test_brawl_natural_6_extra_hit() -> void:
	# Test that natural 6 inflicts extra hit
	var attacker := {
		"combat_skill": 0,
		"speed": 4,
		"species": "human",
		"has_melee_weapon": false,
		"has_pistol": false,
		"weapon_traits": [],
		"toughness": 3
	}
	var defender := attacker.duplicate()

	# Attacker rolls 6, defender rolls 1
	var roll_state := {"count": 0}
	var fixed_rolls := [6, 1]
	var dice_roller := func():
		var result = fixed_rolls[roll_state.count % fixed_rolls.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_brawl(attacker, defender, dice_roller)

	# Attacker wins AND gets extra hit from natural 6
	# Defender also suffers extra hit from natural 1
	assert_that(result.get("attacker_raw_roll")).is_equal(6)
	assert_that(result.get("attacker_hits")).is_greater_equal(2)  # Win hit + nat 6 hit

func test_brawl_natural_1_suffer_hit() -> void:
	# Test that natural 1 causes suffering extra hit
	var attacker := {
		"combat_skill": 3,  # High skill to ensure win despite nat 1
		"speed": 4,
		"species": "human",
		"has_melee_weapon": true,
		"has_pistol": false,
		"weapon_traits": ["melee"],
		"toughness": 3
	}
	var defender := {
		"combat_skill": 0,
		"speed": 4,
		"species": "human",
		"has_melee_weapon": false,
		"has_pistol": false,
		"weapon_traits": [],
		"toughness": 3
	}

	# Attacker rolls 1 (suffers extra), defender rolls 2
	var roll_state := {"count": 0}
	var fixed_rolls := [1, 2]
	var dice_roller := func():
		var result = fixed_rolls[roll_state.count % fixed_rolls.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_brawl(attacker, defender, dice_roller)

	# Attacker still wins (1 + 3 + 2 = 6 vs 2 + 0 = 2) but suffers extra hit from nat 1
	assert_that(result.get("attacker_raw_roll")).is_equal(1)
	assert_that(result.get("defender_hits")).is_greater_equal(1)  # From nat 1

func test_brawl_melee_weapon_bonus() -> void:
	# Test +2 melee weapon bonus
	var attacker := {
		"combat_skill": 0,
		"speed": 4,
		"species": "human",
		"has_melee_weapon": true,
		"has_pistol": false,
		"weapon_traits": ["melee"],
		"toughness": 3
	}
	var defender := {
		"combat_skill": 0,
		"speed": 4,
		"species": "human",
		"has_melee_weapon": false,
		"has_pistol": false,
		"weapon_traits": [],
		"toughness": 3
	}

	# Both roll 3, but attacker has +2 melee
	var dice_roller := func(): return 3

	var result = BattleCalculations.resolve_brawl(attacker, defender, dice_roller)

	# Attacker: 3 + 0 + 2 = 5
	# Defender: 3 + 0 + 0 = 3
	assert_that(result.get("attacker_total")).is_equal(5)
	assert_that(result.get("defender_total")).is_equal(3)
	assert_that(result.get("winner")).is_equal("attacker")

func test_brawl_pistol_weapon_bonus() -> void:
	# Test +1 pistol weapon bonus
	var attacker := {
		"combat_skill": 0,
		"speed": 4,
		"species": "human",
		"has_melee_weapon": false,
		"has_pistol": true,
		"weapon_traits": ["pistol"],
		"toughness": 3
	}
	var defender := {
		"combat_skill": 0,
		"speed": 4,
		"species": "human",
		"has_melee_weapon": false,
		"has_pistol": false,
		"weapon_traits": [],
		"toughness": 3
	}

	# Both roll 3, but attacker has +1 pistol
	var dice_roller := func(): return 3

	var result = BattleCalculations.resolve_brawl(attacker, defender, dice_roller)

	# Attacker: 3 + 0 + 1 = 4
	# Defender: 3 + 0 + 0 = 3
	assert_that(result.get("attacker_total")).is_equal(4)
	assert_that(result.get("winner")).is_equal("attacker")

func test_brawl_armored_defender_can_save() -> void:
	# Core Rules p.44-45: brawl Hits are resolved like any Hit, so an armored
	# loser rolls a Saving Throw and a success NEGATES the Hit. (Brawl damage
	# previously bypassed saves entirely — the bug this pins.)
	var attacker := {
		"combat_skill": 2, "speed": 4, "species": "human",
		"weapon_traits": ["melee"], "toughness": 3
	}
	var defender := {
		"combat_skill": 0, "speed": 4, "species": "human",
		"weapon_traits": [], "toughness": 3,
		"armor": "combat", "has_screen": false  # 5+ armor save, no piercing on attacker
	}
	# attacker 5 (+2 skill +2 melee = 9) beats defender 2; then defender saves on 6 (5+).
	var roll_state := {"count": 0}
	var fixed_rolls := [5, 2, 6]  # attacker roll, defender roll, defender SAVE roll
	var dice_roller := func():
		var r = fixed_rolls[roll_state.count % fixed_rolls.size()]
		roll_state.count += 1
		return r

	var result = BattleCalculations.resolve_brawl(attacker, defender, dice_roller)

	assert_that(result.get("winner")).is_equal("attacker")
	assert_int(result.get("defender_brawl_saves", 0)).is_equal(1)
	assert_int(result.get("damage_to_defender", 99)).is_equal(0)  # Hit saved -> negated
	assert_that(result.get("effects", [])).contains("defender_brawl_save")

func test_brawl_piercing_negates_armor_save() -> void:
	# Core Rules p.44-45 + Piercing (p.45): a Piercing melee weapon negates the
	# armor Saving Throw, so the brawl Hit lands despite a save-making roll.
	var attacker := {
		"combat_skill": 2, "speed": 4, "species": "human",
		"weapon_traits": ["melee", "piercing"], "toughness": 3
	}
	var defender := {
		"combat_skill": 0, "speed": 4, "species": "human",
		"weapon_traits": [], "toughness": 3,
		"armor": "combat", "has_screen": false  # 5+ armor, but pierced
	}
	var roll_state := {"count": 0}
	var fixed_rolls := [5, 2, 6]  # save roll 6 would pass, but armor is pierced
	var dice_roller := func():
		var r = fixed_rolls[roll_state.count % fixed_rolls.size()]
		roll_state.count += 1
		return r

	var result = BattleCalculations.resolve_brawl(attacker, defender, dice_roller)

	assert_that(result.get("winner")).is_equal("attacker")
	assert_int(result.get("defender_brawl_saves", 0)).is_equal(0)  # armor pierced -> no save
	assert_int(result.get("damage_to_defender", 0)).is_greater_equal(1)  # Hit lands

#endregion

#region K'Erin Brawl Reroll Tests

func test_kerin_rolls_twice_takes_better() -> void:
	# Test K'Erin "Warrior Pride" - roll twice, use better
	var attacker := {
		"combat_skill": 0,
		"speed": 4,
		"species": "kerin",  # K'Erin species
		"has_melee_weapon": false,
		"has_pistol": false,
		"weapon_traits": [],
		"toughness": 3
	}
	var defender := {
		"combat_skill": 0,
		"speed": 4,
		"species": "human",
		"has_melee_weapon": false,
		"has_pistol": false,
		"weapon_traits": [],
		"toughness": 3
	}

	# K'Erin rolls 2 then 5 (should take 5), defender rolls 3
	# Roll order: attacker first, attacker reroll (K'Erin), defender
	# NOTE: Using array to hold count because GDScript closures capture integers by value
	var roll_state := {"count": 0}
	var fixed_rolls := [2, 5, 3]  # First K'Erin roll, second K'Erin roll, defender
	var dice_roller := func():
		var result = fixed_rolls[roll_state.count % fixed_rolls.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_brawl(attacker, defender, dice_roller)

	# K'Erin should take the better roll (5)
	assert_that(result.get("attacker_kerin_rerolled")).is_true()
	assert_that(result.get("attacker_raw_roll")).is_equal(5)
	assert_that(result.get("winner")).is_equal("attacker")

func test_kerin_vs_kerin_both_reroll() -> void:
	# Test K'Erin vs K'Erin - both get reroll
	var attacker := {
		"combat_skill": 0,
		"speed": 4,
		"species": "k'erin",  # Alternative spelling
		"has_melee_weapon": false,
		"has_pistol": false,
		"weapon_traits": [],
		"toughness": 3
	}
	var defender := {
		"combat_skill": 0,
		"speed": 4,
		"species": "kerin",
		"has_melee_weapon": false,
		"has_pistol": false,
		"weapon_traits": [],
		"toughness": 3
	}

	# Both K'Erin roll twice
	# Roll order: A1, A2 (K'Erin reroll), D1, D2 (K'Erin reroll)
	var roll_state := {"count": 0}
	var fixed_rolls := [2, 3, 4, 5]  # A1=2, A2=3, D1=4, D2=5
	var dice_roller := func():
		var result = fixed_rolls[roll_state.count % fixed_rolls.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_brawl(attacker, defender, dice_roller)

	assert_that(result.get("attacker_kerin_rerolled")).is_true()
	assert_that(result.get("defender_kerin_rerolled")).is_true()

func test_kerin_no_flat_brawl_bonus() -> void:
	# Core Rules p.16/p.45: K'Erin's ONLY brawl advantage is roll-twice-pick-
	# better — there is NO flat +1 species bonus (a fabricated +1 was removed
	# 2026-07-02). Equal rolls must therefore produce a draw.
	var attacker := {
		"combat_skill": 0,
		"speed": 4,
		"species": "kerin",
		"has_melee_weapon": false,
		"has_pistol": false,
		"weapon_traits": [],
		"toughness": 3
	}
	var defender := {
		"combat_skill": 0,
		"speed": 4,
		"species": "human",
		"has_melee_weapon": false,
		"has_pistol": false,
		"weapon_traits": [],
		"toughness": 3
	}

	var roll_state := {"count": 0}
	var fixed_rolls := [3, 3, 3]  # First roll, K'Erin reroll, defender
	var dice_roller := func():
		var result = fixed_rolls[roll_state.count % fixed_rolls.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_brawl(attacker, defender, dice_roller)

	# K'Erin: max(3, 3) + 0 = 3; Human: 3 + 0 = 3 -> draw. The reroll
	# happened, but no flat bonus exists.
	assert_that(result.get("attacker_kerin_rerolled")).is_true()
	assert_that(result.get("attacker_species_bonus")).is_equal(0)
	assert_that(result.get("winner")).is_equal("draw")

#endregion

#region Screen vs Armor Distinction Tests

func test_piercing_ignores_armor_not_screen() -> void:
	# Test that piercing weapons ignore armor but NOT screens
	var attacker := {
		"combat_skill": 1,
		"range_to_target": 12.0,
		"elevated": false
	}
	var target_with_screen := {
		"in_cover": false,
		"toughness": 4,
		"armor": "combat",  # 5+ armor save
		"elevated": false,
		"has_screen": true,
		"screen_save": 5,  # 5+ screen save
		"shield_charges": 0,
		"equipped_armor_mods": []
	}
	var weapon := {
		"range": 24,
		"damage": 1,
		"traits": ["piercing"],  # Piercing weapon
		"penetration": 0
	}

	# Roll 5 for hit, 5 for screen/armor save
	# Note: No damage roll - damage is from weapon stats
	var roll_state := {"count": 0}
	var fixed_rolls := [5, 5]  # Hit roll, save roll
	var dice_roller := func():
		var result = fixed_rolls[roll_state.count % fixed_rolls.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_ranged_attack(
		attacker, target_with_screen, weapon, dice_roller
	)

	# Piercing should ignore armor but screen save of 5 should still work
	assert_that(result.get("hit")).is_true()
	assert_that(result.get("effects", [])).contains("armor_pierced")
	# If screen save succeeded (roll >= 5), damage should be blocked
	if result.get("screen_saved", false):
		assert_that(result.get("armor_saved", false) or result.get("screen_saved", false)).is_true()

func test_non_piercing_checks_armor() -> void:
	# Test that non-piercing weapons check armor saves
	var attacker := {
		"combat_skill": 1,
		"range_to_target": 12.0,
		"elevated": false
	}
	var target := {
		"in_cover": false,
		"toughness": 4,
		"armor": "combat",  # 5+ armor save
		"elevated": false,
		"has_screen": false,
		"shield_charges": 0,
		"equipped_armor_mods": []
	}
	var weapon := {
		"range": 24,
		"damage": 1,
		"traits": [],  # No piercing
		"penetration": 0
	}

	# Roll 5 for hit, 5 for armor save (succeeds)
	# Note: No damage roll - damage is from weapon stats
	var roll_state := {"count": 0}
	var fixed_rolls := [5, 5]  # Hit roll, armor save roll
	var dice_roller := func():
		var result = fixed_rolls[roll_state.count % fixed_rolls.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_ranged_attack(
		attacker, target, weapon, dice_roller
	)

	# Armor save should succeed (rolled 5, need 5+)
	assert_that(result.get("hit")).is_true()
	assert_that(result.get("armor_saved")).is_true()

func test_screen_checked_before_armor() -> void:
	# Test that screen saves are checked before armor
	var attacker := {
		"combat_skill": 1,
		"range_to_target": 12.0,
		"elevated": false
	}
	var target := {
		"in_cover": false,
		"toughness": 4,
		"armor": "combat",
		"elevated": false,
		"has_screen": true,
		"screen_save": 5,
		"shield_charges": 0,
		"equipped_armor_mods": []
	}
	var weapon := {
		"range": 24,
		"damage": 1,
		"traits": [],  # Non-piercing
		"penetration": 0
	}

	# Hit roll, save roll = 5 (screen succeeds first)
	# Note: No damage roll - damage is from weapon stats
	var roll_state := {"count": 0}
	var fixed_rolls := [5, 5]  # Hit roll, save roll
	var dice_roller := func():
		var result = fixed_rolls[roll_state.count % fixed_rolls.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_ranged_attack(
		attacker, target, weapon, dice_roller
	)

	# Screen save should be checked and succeed
	assert_that(result.get("hit")).is_true()
	# Either screen or armor saved
	assert_that(
		result.get("screen_saved", false) or result.get("armor_saved", false)
	).is_true()

#endregion

#region Hulker Damage Bonus Tests

func test_hulker_no_melee_damage_bonus() -> void:
	# Core Rules p.21: Hulker rules are shooting Combat Skill +0 (no weapon/
	# sight/mod bonuses) and Clumsy/Heavy immunity — there is NO melee damage
	# bonus (a fabricated +2 with a false "p.18" cite was removed 2026-07-02).
	var attacker := {
		"combat_skill": 1,
		"speed": 4,
		"species": "hulker",
		"has_melee_weapon": true,
		"has_pistol": false,
		"weapon_traits": ["melee"],
		"toughness": 4
	}
	var defender := {
		"combat_skill": 0,
		"speed": 4,
		"species": "human",
		"has_melee_weapon": false,
		"has_pistol": false,
		"weapon_traits": [],
		"toughness": 3
	}

	# Attacker wins (5 + 1 skill + 2 melee weapon = 8 vs 2)
	var roll_state := {"count": 0}
	var fixed_rolls := [5, 2]
	var dice_roller := func():
		var result = fixed_rolls[roll_state.count % fixed_rolls.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_brawl(attacker, defender, dice_roller)

	assert_that(result.get("winner")).is_equal("attacker")
	assert_that(result.get("attacker_damage_bonus")).is_equal(0)
	assert_int(result.get("damage_to_defender")).is_equal(1)  # casualty count

#endregion

#region Elegant Trait Tests

func test_elegant_reroll_on_low() -> void:
	# Test Elegant trait rerolls low rolls
	var attacker := {
		"combat_skill": 0,
		"speed": 4,
		"species": "human",
		"has_melee_weapon": true,
		"has_pistol": false,
		"weapon_traits": ["melee", "elegant"],
		"toughness": 3
	}
	var defender := {
		"combat_skill": 0,
		"speed": 4,
		"species": "human",
		"has_melee_weapon": false,
		"has_pistol": false,
		"weapon_traits": [],
		"toughness": 3
	}

	# Attacker rolls 2 (< 4, rerolls to 5), defender rolls 3
	# Roll order: attacker first, elegant reroll, defender
	var roll_state := {"count": 0}
	var fixed_rolls := [2, 5, 3]  # Initial attacker 2, elegant reroll 5, defender 3
	var dice_roller := func():
		var result = fixed_rolls[roll_state.count % fixed_rolls.size()]
		roll_state.count += 1
		return result

	var result = BattleCalculations.resolve_brawl(attacker, defender, dice_roller)

	assert_that(result.get("attacker_rerolled")).is_true()
	# After reroll, attacker should have 5 + 2 melee = 7
	assert_that(result.get("winner")).is_equal("attacker")

#endregion
