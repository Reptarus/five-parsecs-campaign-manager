extends Resource
class_name EnemyData

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameWeapon = preload("res://src/core/systems/items/Weapon.gd")

# Core enemy properties
@export var enemy_type: GlobalEnums.EnemyType = GlobalEnums.EnemyType.NONE
@export var enemy_category: GlobalEnums.EnemyCategory = GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS
@export var enemy_behavior: GlobalEnums.EnemyBehavior = GlobalEnums.EnemyBehavior.CAUTIOUS
@export var character_name: String = ""

# Combat properties
var stats: Dictionary = {
	GlobalEnums.CharacterStats.REACTIONS: 1,
	GlobalEnums.CharacterStats.SPEED: 4,
	GlobalEnums.CharacterStats.COMBAT_SKILL: 0,
	GlobalEnums.CharacterStats.TOUGHNESS: 3,
	GlobalEnums.CharacterStats.SAVVY: 0,
	GlobalEnums.CharacterStats.LUCK: 0
}

# Combat equipment and status
var equipped_weapons: Array[GameWeapon] = []
var weapon_class: GlobalEnums.EnemyWeaponClass = GlobalEnums.EnemyWeaponClass.BASIC
var armor_save: int = 0 # 0 means no save, otherwise represents X+ save
var panic: int = 2 # Default panic value
var morale: int = 10 # Default morale value
var deployment_pattern: GlobalEnums.EnemyDeploymentPattern = GlobalEnums.EnemyDeploymentPattern.STANDARD

# Traits and characteristics
var characteristics: Array[GlobalEnums.EnemyCharacteristic] = []
var special_rules: Array[String] = []

# Rewards and loot
var loot_table: Dictionary = {} # Dictionary[GlobalEnums.EnemyReward, float]
var experience_value: int = 0

func _init(type: GlobalEnums.EnemyType = GlobalEnums.EnemyType.NONE,
		  category: GlobalEnums.EnemyCategory = GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS) -> void:
	enemy_type = type
	enemy_category = category
	_initialize_default_values()

func _initialize_default_values() -> void:
	# First set base values by category
	_setup_category_defaults()
	
	# Then apply specific type modifications
	match enemy_type:
		GlobalEnums.EnemyType.ELITE:
			_setup_elite()
		GlobalEnums.EnemyType.BOSS:
			_setup_boss()
		GlobalEnums.EnemyType.MINION:
			_setup_minion()
		GlobalEnums.EnemyType.NONE:
			push_warning("Initializing enemy with NONE type")
			_setup_standard()
		_:
			_setup_specific_type()

func _setup_category_defaults() -> void:
	match enemy_category:
		GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS:
			morale = 8
			weapon_class = GlobalEnums.EnemyWeaponClass.BASIC
			add_characteristic(GlobalEnums.EnemyCharacteristic.SCAVENGER)
		GlobalEnums.EnemyCategory.HIRED_MUSCLE:
			morale = 12
			weapon_class = GlobalEnums.EnemyWeaponClass.ADVANCED
			add_characteristic(GlobalEnums.EnemyCharacteristic.TOUGH_FIGHT)
		GlobalEnums.EnemyCategory.MILITARY_FORCES:
			morale = 15
			weapon_class = GlobalEnums.EnemyWeaponClass.ELITE
			add_characteristic(GlobalEnums.EnemyCharacteristic.ALERT)
		GlobalEnums.EnemyCategory.ALIEN_THREATS:
			morale = 20
			weapon_class = GlobalEnums.EnemyWeaponClass.ELITE
			add_characteristic(GlobalEnums.EnemyCharacteristic.FEROCIOUS)

func _setup_specific_type() -> void:
	match enemy_type:
		GlobalEnums.EnemyType.GANGERS, GlobalEnums.EnemyType.PUNKS:
			_setup_gang_type()
		GlobalEnums.EnemyType.RAIDERS, GlobalEnums.EnemyType.PIRATES:
			_setup_raider_type()
		GlobalEnums.EnemyType.CULTISTS, GlobalEnums.EnemyType.PSYCHOS:
			_setup_fanatic_type()
		GlobalEnums.EnemyType.WAR_BOTS, GlobalEnums.EnemyType.SECURITY_BOTS:
			_setup_robot_type()
		GlobalEnums.EnemyType.BLACK_OPS_TEAM, GlobalEnums.EnemyType.SECRET_AGENTS:
			_setup_elite_agent_type()
		_:
			_setup_standard()

func _setup_gang_type() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 0
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 3
	add_characteristic(GlobalEnums.EnemyCharacteristic.LEG_IT)
	add_characteristic(GlobalEnums.EnemyCharacteristic.FRIDAY_NIGHT_WARRIORS)
	deployment_pattern = GlobalEnums.EnemyDeploymentPattern.SCATTERED

func _setup_raider_type() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 1
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 4
	add_characteristic(GlobalEnums.EnemyCharacteristic.AGGRO)
	add_characteristic(GlobalEnums.EnemyCharacteristic.UP_CLOSE)
	deployment_pattern = GlobalEnums.EnemyDeploymentPattern.AMBUSH

func _setup_fanatic_type() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 1
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 3
	add_characteristic(GlobalEnums.EnemyCharacteristic.FEARLESS)
	add_characteristic(GlobalEnums.EnemyCharacteristic.GRUESOME)
	deployment_pattern = GlobalEnums.EnemyDeploymentPattern.OFFENSIVE

func _setup_robot_type() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 2
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 5
	add_characteristic(GlobalEnums.EnemyCharacteristic.SAVING_THROW)
	deployment_pattern = GlobalEnums.EnemyDeploymentPattern.STANDARD

func _setup_elite_agent_type() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 2
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 4
	add_characteristic(GlobalEnums.EnemyCharacteristic.TRICK_SHOT)
	add_characteristic(GlobalEnums.EnemyCharacteristic.ALERT)
	deployment_pattern = GlobalEnums.EnemyDeploymentPattern.CONCEALED

func _setup_elite() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 1
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 4
	armor_save = 5
	morale = 12
	experience_value = 2
	weapon_class = GlobalEnums.EnemyWeaponClass.ADVANCED
	deployment_pattern = GlobalEnums.EnemyDeploymentPattern.OFFENSIVE

func _setup_boss() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 2
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 5
	armor_save = 4
	morale = 15
	experience_value = 3
	weapon_class = GlobalEnums.EnemyWeaponClass.ELITE
	deployment_pattern = GlobalEnums.EnemyDeploymentPattern.DEFENSIVE

func _setup_minion() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 0
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 2
	morale = 8
	experience_value = 1
	weapon_class = GlobalEnums.EnemyWeaponClass.BASIC
	deployment_pattern = GlobalEnums.EnemyDeploymentPattern.STANDARD

func _setup_standard() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 0
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 3
	morale = 10
	experience_value = 1
	weapon_class = GlobalEnums.EnemyWeaponClass.BASIC
	deployment_pattern = GlobalEnums.EnemyDeploymentPattern.STANDARD

func validate_behavior_pattern() -> bool:
	# Validate that deployment pattern matches behavior
	match enemy_behavior:
		GlobalEnums.EnemyBehavior.AGGRESSIVE:
			return deployment_pattern in [
				GlobalEnums.EnemyDeploymentPattern.OFFENSIVE,
				GlobalEnums.EnemyDeploymentPattern.AMBUSH
			]
		GlobalEnums.EnemyBehavior.DEFENSIVE:
			return deployment_pattern in [
				GlobalEnums.EnemyDeploymentPattern.DEFENSIVE,
				GlobalEnums.EnemyDeploymentPattern.BOLSTERED_LINE
			]
		GlobalEnums.EnemyBehavior.TACTICAL:
			return deployment_pattern in [
				GlobalEnums.EnemyDeploymentPattern.STANDARD,
				GlobalEnums.EnemyDeploymentPattern.CONCEALED
			]
		GlobalEnums.EnemyBehavior.BEAST:
			return deployment_pattern in [
				GlobalEnums.EnemyDeploymentPattern.SCATTERED,
				GlobalEnums.EnemyDeploymentPattern.AMBUSH
			]
		GlobalEnums.EnemyBehavior.RAMPAGE:
			return deployment_pattern == GlobalEnums.EnemyDeploymentPattern.OFFENSIVE
		GlobalEnums.EnemyBehavior.GUARDIAN:
			return deployment_pattern in [
				GlobalEnums.EnemyDeploymentPattern.DEFENSIVE,
				GlobalEnums.EnemyDeploymentPattern.STANDARD
			]
	return true

func get_stat(stat_type: GlobalEnums.CharacterStats) -> int:
	return stats.get(stat_type, 0)

func set_stat(stat_type: GlobalEnums.CharacterStats, value: int) -> void:
	stats[stat_type] = value

func add_weapon(weapon: GameWeapon) -> void:
	if not weapon in equipped_weapons:
		equipped_weapons.append(weapon)

func remove_weapon(weapon: GameWeapon) -> void:
	equipped_weapons.erase(weapon)

func get_weapons() -> Array[GameWeapon]:
	return equipped_weapons

func set_weapon_class(new_class: GlobalEnums.EnemyWeaponClass) -> void:
	weapon_class = new_class

func get_weapon_class() -> GlobalEnums.EnemyWeaponClass:
	return weapon_class

func set_deployment_pattern(pattern: GlobalEnums.EnemyDeploymentPattern) -> void:
	deployment_pattern = pattern

func get_deployment_pattern() -> GlobalEnums.EnemyDeploymentPattern:
	return deployment_pattern

func has_characteristic(characteristic: GlobalEnums.EnemyCharacteristic) -> bool:
	return characteristic in characteristics

func add_characteristic(characteristic: GlobalEnums.EnemyCharacteristic) -> void:
	if not has_characteristic(characteristic):
		characteristics.append(characteristic)

func remove_characteristic(characteristic: GlobalEnums.EnemyCharacteristic) -> void:
	characteristics.erase(characteristic)

func add_special_rule(rule: String) -> void:
	if not rule in special_rules:
		special_rules.append(rule)

func remove_special_rule(rule: String) -> void:
	special_rules.erase(rule)

func add_loot_reward(reward_type: GlobalEnums.EnemyReward, probability: float) -> void:
	loot_table[reward_type] = probability

func remove_loot_reward(reward_type: GlobalEnums.EnemyReward) -> void:
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