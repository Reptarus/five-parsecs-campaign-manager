@tool
extends Resource
# Important: Do NOT add class_name declaration here to avoid conflicts
# This script should be accessed via preload/load, NOT via global class name
# The main EnemyData class is defined in src/core/enemy/EnemyData.gd

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const GameWeapon = preload("res://src/core/systems/items/GameWeapon.gd")

# Core enemy properties
@export var enemy_type: int = GameEnums.EnemyType.NONE
@export var enemy_category: int = GameEnums.EnemyCategory.CRIMINAL_ELEMENTS
@export var enemy_behavior: int = GameEnums.EnemyBehavior.CAUTIOUS
@export var character_name: String = ""

# Combat properties
var stats: Dictionary = {
	GameEnums.CharacterStats.REACTIONS: 1,
	GameEnums.CharacterStats.NAVIGATION: 4,
	GameEnums.CharacterStats.COMBAT_SKILL: 0,
	GameEnums.CharacterStats.TOUGHNESS: 3,
	GameEnums.CharacterStats.SAVVY: 0,
	GameEnums.CharacterStats.SOCIAL: 0
}

# Combat equipment and status
var equipped_weapons: Array[GameWeapon] = []
var weapon_class: int = GameEnums.EnemyWeaponClass.BASIC
var armor_save: int = 0 # 0 means no save, otherwise represents X+ save
var panic: int = 2 # Default panic value
var morale: int = 10 # Default morale value
var deployment_pattern: int = GameEnums.EnemyDeploymentPattern.STANDARD

# Traits and characteristics
var characteristics: Array[int] = []
var special_rules: Array[String] = []

# Rewards and loot
var loot_table: Dictionary = {} # Dictionary[int, float]
var experience_value: int = 0

func _init(type: int = GameEnums.EnemyType.NONE,
		  category: int = GameEnums.EnemyCategory.CRIMINAL_ELEMENTS) -> void:
	enemy_type = type
	enemy_category = category
	_initialize_default_values()

func _initialize_default_values() -> void:
	# First set base values by category
	_setup_category_defaults()
	
	# Then apply specific type modifications
	match enemy_type:
		GameEnums.EnemyType.ELITE:
			_setup_elite()
		GameEnums.EnemyType.BOSS:
			_setup_boss()
		GameEnums.EnemyType.MINION:
			_setup_minion()
		GameEnums.EnemyType.NONE:
			push_warning("Initializing enemy with NONE type")
			_setup_standard()
		_:
			_setup_specific_type()

func _setup_category_defaults() -> void:
	match enemy_category:
		GameEnums.EnemyCategory.CRIMINAL_ELEMENTS:
			morale = 8
			weapon_class = GameEnums.EnemyWeaponClass.BASIC
			add_characteristic(GameEnums.EnemyTrait.SCAVENGER)
		GameEnums.EnemyCategory.HIRED_MUSCLE:
			morale = 12
			weapon_class = GameEnums.EnemyWeaponClass.ADVANCED
			add_characteristic(GameEnums.EnemyTrait.TOUGH_FIGHT)
		GameEnums.EnemyCategory.MILITARY_FORCES:
			morale = 15
			weapon_class = GameEnums.EnemyWeaponClass.ELITE
			add_characteristic(GameEnums.EnemyTrait.ALERT)
		GameEnums.EnemyCategory.ALIEN_THREATS:
			morale = 20
			weapon_class = GameEnums.EnemyWeaponClass.ELITE
			add_characteristic(GameEnums.EnemyTrait.FEROCIOUS)

func _setup_specific_type() -> void:
	match enemy_type:
		GameEnums.EnemyType.GANGERS, GameEnums.EnemyType.PUNKS:
			_setup_gang_type()
		GameEnums.EnemyType.RAIDERS, GameEnums.EnemyType.PIRATES:
			_setup_raider_type()
		GameEnums.EnemyType.CULTISTS, GameEnums.EnemyType.PSYCHOS:
			_setup_fanatic_type()
		GameEnums.EnemyType.WAR_BOTS, GameEnums.EnemyType.SECURITY_BOTS:
			_setup_robot_type()
		GameEnums.EnemyType.BLACK_OPS_TEAM, GameEnums.EnemyType.SECRET_AGENTS:
			_setup_elite_agent_type()
		_:
			_setup_standard()

func _setup_gang_type() -> void:
	stats[GameEnums.CharacterStats.COMBAT_SKILL] = 0
	stats[GameEnums.CharacterStats.TOUGHNESS] = 3
	add_characteristic(GameEnums.EnemyTrait.LEG_IT)
	add_characteristic(GameEnums.EnemyTrait.FRIDAY_NIGHT_WARRIORS)
	deployment_pattern = GameEnums.EnemyDeploymentPattern.SCATTERED

func _setup_raider_type() -> void:
	stats[GameEnums.CharacterStats.COMBAT_SKILL] = 1
	stats[GameEnums.CharacterStats.TOUGHNESS] = 4
	add_characteristic(GameEnums.EnemyTrait.AGGRO)
	add_characteristic(GameEnums.EnemyTrait.UP_CLOSE)
	deployment_pattern = GameEnums.EnemyDeploymentPattern.AMBUSH

func _setup_fanatic_type() -> void:
	stats[GameEnums.CharacterStats.COMBAT_SKILL] = 1
	stats[GameEnums.CharacterStats.TOUGHNESS] = 3
	add_characteristic(GameEnums.EnemyTrait.FEARLESS)
	add_characteristic(GameEnums.EnemyTrait.GRUESOME)
	deployment_pattern = GameEnums.EnemyDeploymentPattern.OFFENSIVE

func _setup_robot_type() -> void:
	stats[GameEnums.CharacterStats.COMBAT_SKILL] = 2
	stats[GameEnums.CharacterStats.TOUGHNESS] = 5
	add_characteristic(GameEnums.EnemyTrait.SAVING_THROW)
	deployment_pattern = GameEnums.EnemyDeploymentPattern.STANDARD

func _setup_elite_agent_type() -> void:
	stats[GameEnums.CharacterStats.COMBAT_SKILL] = 2
	stats[GameEnums.CharacterStats.TOUGHNESS] = 4
	add_characteristic(GameEnums.EnemyTrait.TRICK_SHOT)
	add_characteristic(GameEnums.EnemyTrait.ALERT)
	deployment_pattern = GameEnums.EnemyDeploymentPattern.CONCEALED

func _setup_elite() -> void:
	stats[GameEnums.CharacterStats.COMBAT_SKILL] = 1
	stats[GameEnums.CharacterStats.TOUGHNESS] = 4
	armor_save = 5
	morale = 12
	experience_value = 2
	weapon_class = GameEnums.EnemyWeaponClass.ADVANCED
	deployment_pattern = GameEnums.EnemyDeploymentPattern.OFFENSIVE

func _setup_boss() -> void:
	stats[GameEnums.CharacterStats.COMBAT_SKILL] = 2
	stats[GameEnums.CharacterStats.TOUGHNESS] = 5
	armor_save = 4
	morale = 15
	experience_value = 3
	weapon_class = GameEnums.EnemyWeaponClass.ELITE
	deployment_pattern = GameEnums.EnemyDeploymentPattern.DEFENSIVE

func _setup_minion() -> void:
	stats[GameEnums.CharacterStats.COMBAT_SKILL] = 0
	stats[GameEnums.CharacterStats.TOUGHNESS] = 2
	morale = 8
	experience_value = 1
	weapon_class = GameEnums.EnemyWeaponClass.BASIC
	deployment_pattern = GameEnums.EnemyDeploymentPattern.STANDARD

func _setup_standard() -> void:
	stats[GameEnums.CharacterStats.COMBAT_SKILL] = 0
	stats[GameEnums.CharacterStats.TOUGHNESS] = 3
	morale = 10
	experience_value = 1
	weapon_class = GameEnums.EnemyWeaponClass.BASIC
	deployment_pattern = GameEnums.EnemyDeploymentPattern.STANDARD

func validate_behavior_pattern() -> bool:
	# Validate that deployment pattern matches behavior
	match enemy_behavior:
		GameEnums.EnemyBehavior.AGGRESSIVE:
			return deployment_pattern in [
				GameEnums.EnemyDeploymentPattern.OFFENSIVE,
				GameEnums.EnemyDeploymentPattern.AMBUSH
			]
		GameEnums.EnemyBehavior.DEFENSIVE:
			return deployment_pattern in [
				GameEnums.EnemyDeploymentPattern.DEFENSIVE,
				GameEnums.EnemyDeploymentPattern.BOLSTERED_LINE
			]
		GameEnums.EnemyBehavior.TACTICAL:
			return deployment_pattern in [
				GameEnums.EnemyDeploymentPattern.STANDARD,
				GameEnums.EnemyDeploymentPattern.CONCEALED
			]
		GameEnums.EnemyBehavior.BEAST:
			return deployment_pattern in [
				GameEnums.EnemyDeploymentPattern.SCATTERED,
				GameEnums.EnemyDeploymentPattern.AMBUSH
			]
		GameEnums.EnemyBehavior.RAMPAGE:
			return deployment_pattern == GameEnums.EnemyDeploymentPattern.OFFENSIVE
		GameEnums.EnemyBehavior.GUARDIAN:
			return deployment_pattern in [
				GameEnums.EnemyDeploymentPattern.DEFENSIVE,
				GameEnums.EnemyDeploymentPattern.STANDARD
			]
	return true

func get_stat(stat_type: int) -> int:
	return stats.get(stat_type, 0)

func set_stat(stat_type: int, value: int) -> void:
	stats[stat_type] = value

func add_weapon(weapon: GameWeapon) -> void:
	if not weapon in equipped_weapons:
		equipped_weapons.append(weapon)

func remove_weapon(weapon: GameWeapon) -> void:
	equipped_weapons.erase(weapon)

func get_weapons() -> Array[GameWeapon]:
	return equipped_weapons

func set_weapon_class(new_class: int) -> void:
	weapon_class = new_class

func get_weapon_class() -> int:
	return weapon_class

func set_deployment_pattern(pattern: int) -> void:
	deployment_pattern = pattern

func get_deployment_pattern() -> int:
	return deployment_pattern

func has_characteristic(characteristic: int) -> bool:
	return characteristic in characteristics

func add_characteristic(characteristic: int) -> void:
	if not has_characteristic(characteristic):
		characteristics.append(characteristic)

func remove_characteristic(characteristic: int) -> void:
	characteristics.erase(characteristic)

func add_special_rule(rule: String) -> void:
	if not rule in special_rules:
		special_rules.append(rule)

func remove_special_rule(rule: String) -> void:
	special_rules.erase(rule)

func add_loot_reward(reward_type: int, probability: float) -> void:
	loot_table[reward_type] = probability

func remove_loot_reward(reward_type: int) -> void:
	loot_table.erase(reward_type)

func get_loot_table() -> Dictionary:
	return loot_table

func get_experience_value() -> int:
	return experience_value

func set_experience_value(value: int) -> void:
	experience_value = value

# Serialization
func serialize() -> Dictionary:
	return {
		"enemy_type": enemy_type,
		"enemy_category": enemy_category,
		"enemy_behavior": enemy_behavior,
		"character_name": character_name,
		"stats": stats.duplicate(),
		"equipped_weapons": equipped_weapons.map(func(w): return w.serialize()),
		"weapon_class": weapon_class,
		"armor_save": armor_save,
		"panic": panic,
		"morale": morale,
		"deployment_pattern": deployment_pattern,
		"characteristics": characteristics.duplicate(),
		"special_rules": special_rules.duplicate(),
		"loot_table": loot_table.duplicate(),
		"experience_value": experience_value
	}

func deserialize(data: Dictionary) -> void:
	if not data.has_all(["enemy_type", "enemy_category", "enemy_behavior"]):
		push_error("Invalid enemy data for deserialization")
		return
		
	enemy_type = data.get("enemy_type", enemy_type)
	enemy_category = data.get("enemy_category", enemy_category)
	enemy_behavior = data.get("enemy_behavior", enemy_behavior)
	character_name = data.get("character_name", character_name)
	stats = data.get("stats", stats)
	weapon_class = data.get("weapon_class", weapon_class)
	armor_save = data.get("armor_save", armor_save)
	panic = data.get("panic", panic)
	morale = data.get("morale", morale)
	deployment_pattern = data.get("deployment_pattern", deployment_pattern)
	characteristics = data.get("characteristics", characteristics)
	special_rules = data.get("special_rules", special_rules)
	loot_table = data.get("loot_table", loot_table)
	experience_value = data.get("experience_value", experience_value)
	
	equipped_weapons.clear()
	if data.has("equipped_weapons"):
		for weapon_data in data.equipped_weapons:
			var weapon = GameWeapon.new()
			weapon.deserialize(weapon_data)
			equipped_weapons.append(weapon)