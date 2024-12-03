extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

@export var enemy_type: int = GlobalEnums.EnemyType.GRUNT
@export var enemy_class: int = GlobalEnums.Class.WARRIOR
@export var ai_behavior: int = GlobalEnums.AIBehavior.CAUTIOUS
@export var attack_power: int = 10

var weapon_system: WeaponSystem
var stats: Dictionary = {}
var equipped_weapons: Array[Weapon] = []
var equipped_armor: Array[Armor] = []
var morale: int = 10
var reactions: int = 2
var enemy_category: int = GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS
var enemy_rank: int = GlobalEnums.EnemyRank.REGULAR
var special_rules: Array[int] = []

# Special rules variables
var is_stunned: bool = false
var stun_count: int = 0
var must_retreat: bool = false
var retreat_distance: int = 0

func _init() -> void:
	# Initialize enemy data
	var enemy_data = _get_enemy_type_data(enemy_category, enemy_rank)
	stats[GlobalEnums.CharacterStats.SPEED] = enemy_data.get("speed", 0)
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = enemy_data.get("combat_skill", 0)
	stats[GlobalEnums.CharacterStats.REACTIONS] = enemy_data.get("reactions", 0)
	stats[GlobalEnums.CharacterStats.SAVVY] = enemy_data.get("savvy", 0)
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = enemy_data.get("toughness", 0)
	ai_behavior = enemy_data.get("ai_behavior", GlobalEnums.AIBehavior.CAUTIOUS)
	
	set_default_stats()
	equip_default_weapons()

func set_default_stats() -> void:
	character_name = "Default Enemy"
	stats[GlobalEnums.CharacterStats.REACTIONS] = 1
	stats[GlobalEnums.CharacterStats.SPEED] = 4
	stats[GlobalEnums.CharacterStats.COMBAT_SKILL] = 0
	stats[GlobalEnums.CharacterStats.TOUGHNESS] = 3
	stats[GlobalEnums.CharacterStats.SAVVY] = 0

func equip_default_weapons() -> void:
	var default_weapon = Weapon.new("Hand Gun", GlobalEnums.WeaponType.HAND_GUN, 12, 1, 1)
	equipped_weapons.append(default_weapon)
	var melee_weapon = Weapon.new("Combat Blade", GlobalEnums.WeaponType.BLADE, 1, 1, 2)
	equipped_weapons.append(melee_weapon)

func has_special_rule(rule: int) -> bool:
	return rule in special_rules

func _get_enemy_type_data(category: GlobalEnums.EnemyCategory, rank: GlobalEnums.EnemyRank) -> Dictionary:
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
		GlobalEnums.EnemyRank.MINION: 0,
		GlobalEnums.EnemyRank.REGULAR: 1,
		GlobalEnums.EnemyRank.ELITE: 2,
		GlobalEnums.EnemyRank.CHAMPION: 3,
		GlobalEnums.EnemyRank.BOSS: 4
	}
	
	var data = base_data[category].duplicate()
	var modifier = rank_modifiers[rank]
	
	data.combat_skill += modifier
	data.toughness += modifier
	if rank >= GlobalEnums.EnemyRank.ELITE:
		data.reactions += 1
	if rank >= GlobalEnums.EnemyRank.CHAMPION:
		data.savvy += 1
	
	return data
