extends Character
class_name Enemy

var threat_level: int = 1
var loot_table: Array[Dictionary] = []
var enemy_type: String = "Default"

var weapon_system: WeaponSystem

func _init() -> void:
	super._init()
	weapon_system = WeaponSystem.new()
	set_default_stats()
	equip_default_weapons()

func set_default_stats() -> void:
	self.name = "Default Enemy"
	self.health = 100
	self.max_health = 100
	self.attack_power = 10
	self.speed = 4
	self.combat_skill = 0
	self.toughness = 3
	self.savvy = 0

func equip_default_weapons() -> void:
	var pistol = Weapon.new("Hand gun", GlobalEnums.WeaponType.PISTOL, 12, 1, 0)
	var knife = Weapon.new("Blade", GlobalEnums.WeaponType.MELEE, 0, 1, 0)
	self.weapons = [pistol, knife]

func initialize(species: GlobalEnums.Species, background: GlobalEnums.Background, 
				motivation: GlobalEnums.Motivation, enemy_class: GlobalEnums.Class) -> void:
	self.species = species
	self.background = background
	self.motivation = motivation
	self.enemy_class = enemy_class
	var enemy_data = EnemyTypes.get_enemy_type(enemy_type)
	
	self.name = enemy_type
	self.speed = enemy_data.speed
	self.combat_skill = enemy_data.combat_skill
	self.toughness = enemy_data.toughness
	
	# Set AI type
	self.ai_type = enemy_data.ai
	
	# Set weapons based on the enemy type
	set_weapons(enemy_data.weapons)
	
	# Set special rules
	set_special_rules(enemy_data.special_rules)

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
		"name": self.name,
		"health": self.health,
		"max_health": self.max_health,
		"attack_power": self.attack_power,
		"threat_level": self.threat_level,
		"loot_table": self.loot_table,
		"speed": self.speed,
		"combat_skill": self.combat_skill,
		"toughness": self.toughness,
		"savvy": self.savvy,
		"weapons": self.weapons.map(func(w): return w.serialize()),
		"enemy_type": self.enemy_type
	}

func set_threat_level(level: int) -> void:
	threat_level = level
	# Adjust enemy stats based on threat level

func drop_loot() -> Array[Dictionary]:
	return loot_table.duplicate()

# Override or add any enemy-specific methods
func enemy_specific_action() -> void:
	print("Performing enemy-specific action for ", self.name)
