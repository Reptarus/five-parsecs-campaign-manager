@tool
extends FiveParsecsEnemyTest

func test_enemy_data_initialization() -> void:
	var data = create_test_enemy_data()
	
	# Verify default values
	assert_eq(data.enemy_type, GameEnums.EnemyType.NONE,
		"Enemy type should default to NONE")
	assert_eq(data.enemy_category, GameEnums.EnemyCategory.CRIMINAL_ELEMENTS,
		"Enemy category should default to CRIMINAL_ELEMENTS")
	assert_eq(data.enemy_behavior, GameEnums.EnemyBehavior.CAUTIOUS,
		"Enemy behavior should default to CAUTIOUS")

func test_enemy_data_stats() -> void:
	var data = create_test_enemy_data("ELITE")
	
	# Verify base stats
	assert_eq(data.get_stat(GameEnums.CharacterStats.COMBAT_SKILL), 1,
		"Elite enemy should have combat skill 1")
	assert_eq(data.get_stat(GameEnums.CharacterStats.TOUGHNESS), 4,
		"Elite enemy should have toughness 4")
	
	# Test stat modification
	data.set_stat(GameEnums.CharacterStats.COMBAT_SKILL, 2)
	assert_eq(data.get_stat(GameEnums.CharacterStats.COMBAT_SKILL), 2,
		"Combat skill should be updated")

func test_enemy_data_weapons() -> void:
	var data = create_test_enemy_data("ELITE")
	var weapon = GameWeapon.new()
	
	# Test weapon management
	data.add_weapon(weapon)
	assert_has(data.get_weapons(), weapon,
		"Weapon should be added to enemy data")
	
	data.remove_weapon(weapon)
	assert_does_not_have(data.get_weapons(), weapon,
		"Weapon should be removed from enemy data")

func test_enemy_data_characteristics() -> void:
	var data = create_test_enemy_data()
	var test_trait = GameEnums.EnemyTrait.ALERT
	
	# Test characteristic management
	data.add_characteristic(test_trait)
	assert_true(data.has_characteristic(test_trait),
		"Enemy should have added characteristic")
	
	data.remove_characteristic(test_trait)
	assert_false(data.has_characteristic(test_trait),
		"Enemy should not have removed characteristic")

func test_enemy_data_special_rules() -> void:
	var data = create_test_enemy_data()
	var test_rule = "TEST_RULE"
	
	# Test special rule management
	data.add_special_rule(test_rule)
	assert_has(data.special_rules, test_rule,
		"Enemy should have added special rule")
	
	data.remove_special_rule(test_rule)
	assert_does_not_have(data.special_rules, test_rule,
		"Enemy should not have removed special rule")

func test_enemy_data_loot() -> void:
	var data = create_test_enemy_data()
	
	# Test common loot
	var common_loot = {
		"name": "Credits",
		"quantity": "1D6 x 10",
		"chance": 30
	}
	data.add_loot_reward("Common Loot", common_loot)
	var loot_table = data.get_loot_table()
	assert_has(loot_table["Common Loot"], common_loot,
		"Loot table should contain added common reward")
	
	# Test rare loot
	var rare_loot = {
		"name": "Advanced Weapon",
		"quantity": 1,
		"chance": 20
	}
	data.add_loot_reward("Rare Loot", rare_loot)
	loot_table = data.get_loot_table()
	assert_has(loot_table["Rare Loot"], rare_loot,
		"Loot table should contain added rare reward")
	
	# Test battlefield finds
	var battlefield_loot = {
		"name": "Weapon",
		"effect": "Roll on Weapon table",
		"chance": 15
	}
	data.add_loot_reward("Battlefield Finds", battlefield_loot)
	loot_table = data.get_loot_table()
	assert_has(loot_table["Battlefield Finds"], battlefield_loot,
		"Loot table should contain added battlefield reward")
	
	# Test removing loot
	data.remove_loot_reward("Common Loot", common_loot)
	loot_table = data.get_loot_table()
	assert_does_not_have(loot_table.get("Common Loot", []), common_loot,
		"Loot table should not contain removed reward")

func test_enemy_data_experience() -> void:
	var data = create_test_enemy_data("BOSS")
	
	# Test experience value
	assert_eq(data.get_experience_value(), 3,
		"Boss enemy should have correct experience value")
	
	data.set_experience_value(5)
	assert_eq(data.get_experience_value(), 5,
		"Experience value should be updated")

func test_enemy_data_serialization() -> void:
	var original_data = create_test_enemy_data("ELITE")
	var weapon = GameWeapon.new()
	original_data.add_weapon(weapon)
	original_data.add_characteristic(GameEnums.EnemyTrait.ALERT)
	original_data.add_special_rule("TEST_RULE")
	
	# Add loot for serialization test
	var test_loot = {
		"name": "Credits",
		"quantity": "1D6 x 10",
		"chance": 30
	}
	original_data.add_loot_reward("Common Loot", test_loot)
	
	# Serialize
	var serialized = original_data.serialize()
	
	# Create new data and deserialize
	var new_data = create_test_enemy_data()
	new_data.deserialize(serialized)
	
	# Verify serialization preserved all data
	assert_eq(new_data.enemy_type, original_data.enemy_type,
		"Enemy type should be preserved")
	assert_eq(new_data.enemy_category, original_data.enemy_category,
		"Enemy category should be preserved")
	assert_eq(new_data.enemy_behavior, original_data.enemy_behavior,
		"Enemy behavior should be preserved")
	assert_eq(new_data.get_weapons().size(), original_data.get_weapons().size(),
		"Weapons should be preserved")
	assert_eq(new_data.characteristics, original_data.characteristics,
		"Characteristics should be preserved")
	assert_eq(new_data.special_rules, original_data.special_rules,
		"Special rules should be preserved")
	assert_eq(new_data.get_loot_table(), original_data.get_loot_table(),
		"Loot table should be preserved")