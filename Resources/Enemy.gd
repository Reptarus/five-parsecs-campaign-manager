extends Node2D
class_name Enemy

var character: Character
var enemy_class: String
var enemy_type: String

@export var health: int = 100
@export var max_health: int = 100
@export var attack_power: int = 10

var weapon_system: WeaponSystem
var weapons: Array[Weapon] = []
var threat_level: int = 0

# Add these variables to match the special rules
var has_leg_it: bool = false
var is_careless: bool = false
var is_bad_shot: bool = false

func _init(p_enemy_type: String, p_enemy_class: String) -> void:
	character = Character.new()
	enemy_type = p_enemy_type
	enemy_class = p_enemy_class
	
	var enemy_data = EnemyTypes.get_enemy_type(enemy_type)
	character.speed = enemy_data.speed
	character.combat_skill = enemy_data.combat_skill
	# Initialize other properties as needed

func _ready() -> void:
	weapon_system = WeaponSystem.new()
	set_default_stats()
	equip_default_weapons()

func set_default_stats() -> void:
	character.name = "Default Enemy"
	character.health = 100
	character.max_health = 100
	# ... other stat initializations

func equip_default_weapons() -> void:
	var pistol = Weapon.new("Hand gun", GlobalEnums.WeaponType.PISTOL, 12, 1, 0)
	var knife = Weapon.new("Blade", GlobalEnums.WeaponType.MELEE, 0, 1, 0)
	self.weapons = [pistol, knife]

func set_weapons(weapon_code: String) -> void:
	self.weapons.clear()
	var weapon_parts = weapon_code.split(" ")
	var num_weapons = int(weapon_parts[0])
	var weapon_tier = weapon_parts[1]
	
	for i in range(num_weapons):
		var weapon_name = get_random_weapon_of_tier(weapon_tier)
		var weapon = Weapon.new(weapon_name)
		self.weapons.append(weapon)

func get_random_weapon_of_tier(tier: String) -> String:
	# This function should return a random weapon name based on the tier
	# You'll need to implement this based on your weapon tiers
	return "Hand gun"  # Placeholder

func set_special_rules(rules: Array) -> void:
	# Implement special rules here
	for rule in rules:
		match rule:
			"Leg it":
				self.has_leg_it = true
			"Careless":
				self.is_careless = true
			"Bad shots":
				self.is_bad_shot = true
			# Add more special rules as needed

func get_enemy_data() -> Dictionary:
	return {
		"name": character.name,
		"health": character.health,
		"max_health": character.max_health,
		"attack_power": self.attack_power,
		"threat_level": self.threat_level,
		"speed": character.speed,
		"combat_skill": character.combat_skill,
		"toughness": character.toughness,
		"savvy": character.savvy,
		"weapons": self.weapons.map(func(w): return w.serialize()),
		"enemy_type": self.enemy_type
	}

func set_threat_level(level: int) -> void:
	threat_level = level
	# Adjust enemy stats based on threat level

func drop_loot() -> Array:
	var loot_generator = LootGenerator.new()
	var loot_items = []
	for _i in range(randi() % 3 + 1):  # Generate 1 to 3 loot items
		loot_items.append(loot_generator.generate_loot())
	return loot_items

# Override or add any enemy-specific methods
func enemy_specific_action() -> void:
	print("Performing enemy-specific action for ", character.name)

# Delegate methods to character resource as needed
func add_xp(amount: int) -> void:
	character.add_xp(amount)

func get_xp_for_next_level() -> int:
	return character.get_xp_for_next_level()

func get_available_upgrades() -> Array:
	return character.get_available_upgrades()
