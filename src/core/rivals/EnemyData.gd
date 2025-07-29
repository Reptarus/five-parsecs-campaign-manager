@tool
extends Resource

# GlobalEnums available as autoload singleton
const GameWeapon = preload("res://src/core/systems/items/GameWeapon.gd")

# Core enemy properties
@export var enemy_type: int = GlobalEnums.EnemyType.NONE
@export var enemy_category: int = GlobalEnums.EnemyType.NONE
@export var enemy_behavior: int = 0 # Default behavior
@export var character_name: String = ""

# Combat properties
var stats: Dictionary = {
	GlobalEnums.CharacterStats.REACTIONS: 1,
	GlobalEnums.CharacterStats.SPEED: 4,
	GlobalEnums.CharacterStats.COMBAT_SKILL: 0,
	GlobalEnums.CharacterStats.TOUGHNESS: 3,
	GlobalEnums.CharacterStats.SAVVY: 0,
	GlobalEnums.CharacterStats.TECH: 0
}

# Combat equipment and status
var equipped_weapons: Array[GameWeapon] = []
var weapon_class: int = 0 # Default weapon class
var armor_save: int = 0 # 0 means no save, otherwise represents X+ save
var panic: int = 2 # Default panic _value
var morale: int = 10 # Default morale _value
var deployment_pattern: int = 0 # Default deployment pattern

# Traits and characteristics
var characteristics: Array[int] = []
var special_abilities: Array[String] = []
var equipment_restrictions: Array[String] = []

# Enemy category and behavior
var category: int = GlobalEnums.EnemyType.NONE
var behavior_type: int = 0 # Default behavior
var weapon_class_type: int = 0 # Default weapon class
var trait_type: int = 0 # Default trait
var category_type: int = GlobalEnums.EnemyType.NONE
var weapon_class_category: int = 0 # Default weapon class
var trait_category: int = 0 # Default trait
var category_weapon: int = GlobalEnums.EnemyType.NONE

# Rewards and loot
var loot_table: Dictionary = {} # Dictionary[int, float]
var experience_value: int = 0

func _init(type: int = GlobalEnums.EnemyType.NONE,
		  category: int = GlobalEnums.EnemyType.NONE) -> void:
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
		GlobalEnums.EnemyType.NONE:
			morale = 8
			weapon_class = 0 # BASIC
			add_characteristic(0) # SCAVENGER
		GlobalEnums.EnemyType.ELITE:
			morale = 12
			weapon_class = 1 # ADVANCED
			add_characteristic(1) # TOUGH_FIGHT
		GlobalEnums.EnemyType.BOSS:
			morale = 15
			weapon_class = 2 # ELITE
			add_characteristic(2) # ALERT
		GlobalEnums.EnemyType.MINION:
			morale = 20
			weapon_class = 2 # ELITE
			add_characteristic(3) # FEROCIOUS
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
	add_characteristic(0) # LEG_IT
	add_characteristic(1) # FRIDAY_NIGHT_WARRIORS
	deployment_pattern = 0 # SCATTERED
func _setup_raider_type() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 1
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 4
	add_characteristic(2) # AGGRO
	add_characteristic(3) # UP_CLOSE
	deployment_pattern = 1 # AMBUSH
func _setup_fanatic_type() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 1
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 3
	add_characteristic(4) # FEARLESS
	add_characteristic(5) # GRUESOME
	deployment_pattern = 2 # OFFENSIVE
func _setup_robot_type() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 2
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 5
	add_characteristic(6) # SAVING_THROW
	deployment_pattern = 3 # STANDARD
func _setup_elite_agent_type() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 2
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 4
	add_characteristic(7) # TRICK_SHOT
	add_characteristic(2) # ALERT
	deployment_pattern = 4 # CONCEALED
func _setup_elite() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 1
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 4
	armor_save = 5
	morale = 12
	experience_value = 2
	weapon_class = 1 # ADVANCED
	deployment_pattern = 2 # OFFENSIVE

func _setup_boss() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 2
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 5
	armor_save = 4
	morale = 15
	experience_value = 3
	weapon_class = 2 # ELITE
	deployment_pattern = 3 # DEFENSIVE

func _setup_minion() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 0
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 2
	morale = 8
	experience_value = 1
	weapon_class = 0 # BASIC
	deployment_pattern = 3 # STANDARD

func _setup_standard() -> void:
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 0
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 3
	morale = 10
	experience_value = 1
	weapon_class = 0 # BASIC
	deployment_pattern = 3 # STANDARD

func validate_behavior_pattern() -> bool:
	# Validate that deployment pattern matches behavior
	match enemy_behavior:
		0: # AGGRESSIVE
			return deployment_pattern in [2, 1] # OFFENSIVE, AMBUSH
		1: # DEFENSIVE
			return deployment_pattern in [3, 4] # DEFENSIVE, BOLSTERED_LINE
		2: # TACTICAL
			return deployment_pattern in [3, 4] # STANDARD, CONCEALED
		3: # BEAST
			return deployment_pattern in [0, 1] # SCATTERED, AMBUSH
		4: # RAMPAGE
			return deployment_pattern == 2 # OFFENSIVE
		5: # GUARDIAN
			return deployment_pattern in [3, 3] # DEFENSIVE, STANDARD
	return true

func get_stat(stat_type: int) -> int:
	return stats.get(stat_type, 0)

func set_stat(stat_type: int, _value: int) -> void:
	stats[stat_type] = _value
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
	if not rule in special_abilities:
		special_abilities.append(rule)

func remove_special_rule(rule: String) -> void:
	special_abilities.erase(rule)
func add_loot_reward(reward_type: int, probability: float) -> void:
	loot_table[reward_type] = probability
func remove_loot_reward(reward_type: int) -> void:
	loot_table.erase(reward_type)
func get_loot_table() -> Dictionary:
	return loot_table

func get_experience_value() -> int:
	return experience_value

func set_experience_value(_value: int) -> void:
	experience_value = _value

# Serialization
func serialize() -> Dictionary:
	return {
		"enemy_type": enemy_type,
		"enemy_category": enemy_category,
		"enemy_behavior": enemy_behavior,
		"character_name": character_name,
		"stats": stats.duplicate(),
		"equipped_weapons": equipped_weapons.map(func(w): return w.serialize() if w and w.has_method("serialize") else {}),
		"weapon_class": weapon_class,
		"armor_save": armor_save,
		"panic": panic,
		"morale": morale,
		"deployment_pattern": deployment_pattern,
		"characteristics": characteristics.duplicate(),
		"special_rules": special_abilities.duplicate(),
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

	special_abilities = data.get("special_rules", special_abilities)

	loot_table = data.get("loot_table", loot_table)

	experience_value = data.get("experience_value", experience_value)

	equipped_weapons.clear()
	if data.has("equipped_weapons"):
		for weapon_data in data.equipped_weapons:
			var weapon := GameWeapon.new()
			if weapon and weapon.has_method("deserialize"): weapon.deserialize(weapon_data)
			equipped_weapons.append(weapon)
