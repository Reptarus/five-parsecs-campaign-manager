extends Character
class_name Enemy

@export var enemy_type: int = GlobalEnums.EnemyType.GRUNT
@export var enemy_class: int = GlobalEnums.Class.WARRIOR
@export var ai_behavior: int = GlobalEnums.AIBehavior.CAUTIOUS
@export var attack_power: int = 10

var weapon_system: WeaponSystem
var weapons: Array[Weapon] = []
var threat_level: int = 0
var defense: int = 5
var morale: int = 10
var reactions: int = 2
var enemy_category: int = GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS
var enemy_rank: int = GlobalEnums.EnemyRank.REGULAR
var special_rules: Array[int] = []
var current_action: int = GlobalEnums.EnemyAction.NONE

# Special rules variables
var has_leg_it: bool = false
var is_careless: bool = false
var is_bad_shot: bool = false

func _ready() -> void:
	weapon_system = WeaponSystem.new()
	
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
	var pistol = Weapon.new()
	pistol.setup("Hand gun", GlobalEnums.WeaponType.HAND_GUN, 12, 1, 0)
	var knife = Weapon.new()
	knife.setup("Blade", GlobalEnums.WeaponType.BLADE, 0, 1, 0)
	weapons = [pistol, knife]

func setup_enemy(type: int, level: int = 1) -> void:
	enemy_type = type
	self.level = level
	
	match enemy_type:
		GlobalEnums.EnemyType.GRUNT:
			_setup_grunt()
		GlobalEnums.EnemyType.ELITE:
			_setup_elite()
		GlobalEnums.EnemyType.BOSS:
			_setup_boss()
		GlobalEnums.EnemyType.MINION:
			_setup_minion()
		GlobalEnums.EnemyType.SUPPORT:
			_setup_support()
		GlobalEnums.EnemyType.HEAVY:
			_setup_heavy()
		GlobalEnums.EnemyType.SPECIALIST:
			_setup_specialist()
		GlobalEnums.EnemyType.COMMANDER:
			_setup_commander()

func _setup_grunt() -> void:
	attack_power = 10
	defense = 5
	morale = 8
	ai_behavior = GlobalEnums.AIBehavior.AGGRESSIVE
	threat_level = 1

func _setup_elite() -> void:
	attack_power = 15
	defense = 8
	morale = 12
	ai_behavior = GlobalEnums.AIBehavior.TACTICAL
	threat_level = 2

func _setup_boss() -> void:
	attack_power = 20
	defense = 12
	morale = 15
	ai_behavior = GlobalEnums.AIBehavior.AGGRESSIVE
	threat_level = 3

func _setup_minion() -> void:
	attack_power = 8
	defense = 3
	morale = 6
	ai_behavior = GlobalEnums.AIBehavior.CAUTIOUS
	threat_level = 1

func _setup_support() -> void:
	attack_power = 7
	defense = 4
	morale = 8
	ai_behavior = GlobalEnums.AIBehavior.DEFENSIVE
	threat_level = 1

func _setup_heavy() -> void:
	attack_power = 15
	defense = 10
	morale = 10
	ai_behavior = GlobalEnums.AIBehavior.RAMPAGE
	threat_level = 2

func _setup_specialist() -> void:
	attack_power = 12
	defense = 6
	morale = 9
	ai_behavior = GlobalEnums.AIBehavior.TACTICAL
	threat_level = 2

func _setup_commander() -> void:
	attack_power = 18
	defense = 10
	morale = 14
	ai_behavior = GlobalEnums.AIBehavior.GUARDIAN
	threat_level = 3

func get_enemy_data() -> Dictionary:
	return {
		"name": character_name,
		"attack_power": attack_power,
		"threat_level": threat_level,
		"speed": stats[GlobalEnums.CharacterStats.SPEED],
		"combat_skill": stats[GlobalEnums.CharacterStats.COMBAT_SKILL],
		"toughness": stats[GlobalEnums.CharacterStats.TOUGHNESS],
		"savvy": stats[GlobalEnums.CharacterStats.SAVVY],
		"weapons": weapons.map(func(w): return w.serialize()),
		"category": GlobalEnums.EnemyCategory.keys()[enemy_category],
		"rank": GlobalEnums.EnemyRank.keys()[enemy_rank],
		"special_rules": special_rules.map(func(rule): return GlobalEnums.EnemySpecialRule.keys()[rule])
	}

func set_threat_level(level: int) -> void:
	threat_level = level

func get_threat_level() -> int:
	return threat_level

func drop_loot() -> Array:
	var loot_generator = LootGenerator.new()
	var loot_items = []
	for _i in range(randi() % 3 + 1):  # Generate 1 to 3 loot items
		loot_items.append(loot_generator.generate_loot())
	return loot_items

func _get_enemy_type_data(category: GlobalEnums.EnemyCategory, rank: GlobalEnums.EnemyRank) -> Dictionary:
	var base_data := {
		GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS: {
			"speed": 5,
			"combat_skill": 1,
			"toughness": 5,
			"weapon_group": GlobalEnums.EnemyWeaponGroup.GROUP_1
		},
		GlobalEnums.EnemyCategory.HIRED_MUSCLE: {
			"speed": 5,
			"combat_skill": 2,
			"toughness": 6,
			"weapon_group": GlobalEnums.EnemyWeaponGroup.GROUP_2
		},
		GlobalEnums.EnemyCategory.INTERESTED_PARTIES: {
			"speed": 6,
			"combat_skill": 2,
			"toughness": 5,
			"weapon_group": GlobalEnums.EnemyWeaponGroup.GROUP_3
		}
	}
	
	var rank_modifiers := {
		GlobalEnums.EnemyRank.SPECIALIST: {
			"combat_skill": 1,
			"toughness": 1
		},
		GlobalEnums.EnemyRank.LIEUTENANT: {
			"combat_skill": 2,
			"toughness": 2,
			"special_rules": [GlobalEnums.EnemySpecialRule.STUBBORN]
		},
		GlobalEnums.EnemyRank.UNIQUE_INDIVIDUAL: {
			"combat_skill": 3,
			"toughness": 3,
			"special_rules": [GlobalEnums.EnemySpecialRule.FEARLESS]
		}
	}
	
	var data = base_data.get(category, base_data[GlobalEnums.EnemyCategory.CRIMINAL_ELEMENTS]).duplicate()
	if rank_modifiers.has(rank):
		var mods = rank_modifiers[rank]
		data["combat_skill"] += mods.get("combat_skill", 0)
		data["toughness"] += mods.get("toughness", 0)
		if mods.has("special_rules"):
			data["special_rules"] = mods["special_rules"]
	
	return data

# Required by Character parent class
func can_act() -> bool:
	return status != GlobalEnums.CharacterStatus.CRITICAL and status != GlobalEnums.CharacterStatus.INJURED and current_action == GlobalEnums.EnemyAction.NONE

func perform_actions() -> void:
	if not can_act():
		return
		
	match ai_behavior:
		GlobalEnums.AIBehavior.CAUTIOUS:
			current_action = GlobalEnums.EnemyAction.MOVE_AND_FIRE
		GlobalEnums.AIBehavior.AGGRESSIVE:
			current_action = GlobalEnums.EnemyAction.CHARGE
		GlobalEnums.AIBehavior.TACTICAL:
			current_action = GlobalEnums.EnemyAction.FIRE
		GlobalEnums.AIBehavior.DEFENSIVE:
			current_action = GlobalEnums.EnemyAction.TAKE_COVER
		GlobalEnums.AIBehavior.RAMPAGE:
			current_action = GlobalEnums.EnemyAction.CHARGE
		GlobalEnums.AIBehavior.BEAST:
			current_action = GlobalEnums.EnemyAction.CHARGE
		GlobalEnums.AIBehavior.GUARDIAN:
			current_action = GlobalEnums.EnemyAction.PROTECT

func reset_action_state() -> void:
	current_action = GlobalEnums.EnemyAction.NONE

func serialize() -> Dictionary:
	var data = super.serialize()
	data["enemy_type"] = GlobalEnums.EnemyType.keys()[enemy_type]
	data["enemy_class"] = GlobalEnums.Class.keys()[enemy_class]
	data["ai_behavior"] = GlobalEnums.AIBehavior.keys()[ai_behavior]
	data["threat_level"] = threat_level
	data["defense"] = defense
	data["morale"] = morale
	data["reactions"] = reactions
	return data

static func deserialize(data: Dictionary) -> Enemy:
	var enemy = Enemy.new()
	enemy.enemy_type = GlobalEnums.EnemyType[data["enemy_type"]]
	enemy.enemy_class = GlobalEnums.Class[data["enemy_class"]]
	enemy.ai_behavior = GlobalEnums.AIBehavior[data["ai_behavior"]]
	enemy.threat_level = data.get("threat_level", 0)
	enemy.defense = data.get("defense", 5)
	enemy.morale = data.get("morale", 10)
	enemy.reactions = data.get("reactions", 2)
	return enemy
