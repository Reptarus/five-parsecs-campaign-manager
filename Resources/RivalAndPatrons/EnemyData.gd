extends Resource
class_name EnemyData

const GlobalEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const GameWeapon = preload("res://Resources/Core/Items/Weapons/Weapon.gd")
const GameArmor = preload("res://Resources/Core/Character/Equipment/Armor.gd")

@export var enemy_type: int = GlobalEnums.EnemyType.GRUNT
@export var enemy_class: int = GlobalEnums.CharacterClass.SOLDIER
@export var ai_behavior: int = GlobalEnums.AIBehavior.CAUTIOUS
@export var attack_power: int = 10
@export var character_name: String = "Default Enemy"

var weapon_system: Node
var stats: Dictionary = {}
var equipped_weapons: Array[GameWeapon] = []
var equipped_armor: Array[GameArmor] = []
var morale: int = 10
var reactions: int = 2
var enemy_category: int = GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS
var enemy_rank: int = 0
var special_rules: Array[int] = []

# Special rules variables
var is_stunned: bool = false
var stun_count: int = 0
var must_retreat: bool = false
var retreat_distance: int = 0

func _init() -> void:
	# Initialize enemy data
	var enemy_data = _get_enemy_type_data(enemy_category, enemy_rank)
	stats[GlobalEnums.CharacterStats.REACTIONS] = enemy_data.get("reactions", 1)
	stats[GlobalEnums.CharacterStats.SPEED] = enemy_data.get("speed", 4)
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = enemy_data.get("combat_skill", 0)
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = enemy_data.get("toughness", 3)
	stats[GlobalEnums.CharacterStats.SAVVY] = enemy_data.get("savvy", 0)
	stats[GlobalEnums.CharacterStats.LUCK] = enemy_data.get("luck", 0)
	ai_behavior = enemy_data.get("ai_behavior", GlobalEnums.AIBehavior.CAUTIOUS)
	
	set_default_stats()
	equip_default_weapons()

func set_default_stats() -> void:
	# Set Core Rules base stats
	stats[GlobalEnums.CharacterStats.REACTIONS] = 1
	stats[GlobalEnums.CharacterStats.SPEED] = 4
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 0
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 3
	stats[GlobalEnums.CharacterStats.SAVVY] = 0
	stats[GlobalEnums.CharacterStats.LUCK] = 0

func equip_default_weapons() -> void:
	var default_weapon = GameWeapon.new()
	default_weapon.name = "Hand Gun"
	default_weapon.weapon_type = GlobalEnums.WeaponType.PISTOL
	equipped_weapons.append(default_weapon)
	
	var melee_weapon = GameWeapon.new()
	melee_weapon.name = "Combat Blade"
	melee_weapon.weapon_type = GlobalEnums.WeaponType.MELEE
	equipped_weapons.append(melee_weapon)

func has_special_rule(rule: int) -> bool:
	return rule in special_rules

func _get_enemy_type_data(category: int, rank: int) -> Dictionary:
	var base_data := {
		GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS: {
			"speed": 5,
			"combat_skill": 1,
			"reactions": 2,
			"savvy": 1,
			"toughness": 3,
			"ai_behavior": GlobalEnums.AIBehavior.AGGRESSIVE
		},
		GlobalEnums.EnemyCategory.HIRED_MUSCLE: {
			"speed": 4,
			"combat_skill": 2,
			"reactions": 2,
			"savvy": 0,
			"toughness": 4,
			"ai_behavior": GlobalEnums.AIBehavior.TACTICAL
		},
		GlobalEnums.EnemyCategory.INTERESTED_PARTIES: {
			"speed": 4,
			"combat_skill": 1,
			"reactions": 3,
			"savvy": 2,
			"toughness": 3,
			"ai_behavior": GlobalEnums.AIBehavior.CAUTIOUS
		}
	}
	
	var rank_modifiers := {
		0: 0,
		1: 1,
		2: 2,
		3: 3,
		4: 4
	}
	
	var data = base_data[category].duplicate()
	var modifier = rank_modifiers[rank]
	
	data.combat_skill += modifier
	data.toughness += modifier
	if rank >= 2:
		data.reactions += 1
	if rank >= 3:
		data.savvy += 1
	
	return data