extends Character
class_name Enemy

var enemy_class: String
var enemy_type: String

@export var attack_power: int = 10

var weapon_system: WeaponSystem
var weapons: Array[Weapon] = []
var threat_level: int = 0

# Special rules variables
var has_leg_it: bool = false
var is_careless: bool = false
var is_bad_shot: bool = false

func _init(p_enemy_type: String, p_enemy_class: String) -> void:
	super()
	enemy_type = p_enemy_type
	enemy_class = p_enemy_class
	
	var enemy_data = EnemyTypes.get_enemy_type(enemy_type)
	speed = enemy_data.speed
	combat_skill = enemy_data.combat_skill
	# Initialize other properties as needed
func _ready() -> void:
	weapon_system = WeaponSystem.new()
	set_default_stats()
	equip_default_weapons()

func set_default_stats() -> void:
	name = "Default Enemy"
	speed = 5  # Default human Speed
	combat_skill = 0  # Default human Combat Skill
	toughness = 5  # Default human Toughness
	savvy = 0  # Default human Savvy
	reactions = 2  # Default human Reactions
	luck = 1  # Default human Luck
	# Other stats can be initialized as needed

func equip_default_weapons() -> void:
	var pistol = Weapon.new("Hand gun", GlobalEnums.WeaponType.PISTOL, 12, 1, 0)
	var knife = Weapon.new("Blade", GlobalEnums.WeaponType.MELEE, 0, 1, 0)
	weapons = [pistol, knife]

func set_weapons(weapon_code: String) -> void:
	weapons.clear()
	var weapon_parts = weapon_code.split(" ")
	var num_weapons = int(weapon_parts[0])
	var weapon_tier = weapon_parts[1]
	
	for i in range(num_weapons):
		var weapon_name = get_random_weapon_of_tier(weapon_tier)
		var weapon = Weapon.new(weapon_name)
		weapons.append(weapon)

func get_random_weapon_of_tier(_tier: String) -> String:
	# This function should return a random weapon name based on the tier
	# You'll need to implement this based on your weapon tiers
	return "Hand gun"  # Placeholder

func set_special_rules(rules: Array) -> void:
	for rule in rules:
		match rule:
			"Leg it":
				has_leg_it = true
			"Careless":
				is_careless = true
			"Bad shots":
				is_bad_shot = true
			# Add more special rules as needed

func get_enemy_data() -> Dictionary:
	return {
		"name": name,
		"attack_power": attack_power,
		"threat_level": threat_level,
		"speed": speed,
		"combat_skill": combat_skill,
		"toughness": toughness,
		"savvy": savvy,
		"weapons": weapons.map(func(w): return w.serialize()),
		"enemy_type": enemy_type
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
	print("Performing enemy-specific action for ", name)

# Note: We've removed the delegated methods (add_xp, get_xp_for_next_level, get_available_upgrades)
# as they should now be inherited from the Character class
