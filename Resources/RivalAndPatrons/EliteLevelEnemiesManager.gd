class_name EliteLevelEnemiesManager
extends Resource

const ELITE_DAMAGE_BONUS: int = 1
const ELITE_TOUGHNESS_BONUS: int = 1
const ELITE_COMBAT_SKILL_BONUS: int = 1
const ELITE_PANIC_REDUCTION: int = 1

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

var game_state: GameState

func _ready() -> void:
	game_state = Engine.get_main_loop().get_root().get_node("/root/GameState")
	if not game_state:
		push_error("GameState singleton not found. Make sure it's properly set up as an AutoLoad.")

func generate_elite_enemy(enemy_type: String) -> Dictionary:
	var base_enemy: Dictionary = EnemyTypes.get_enemy_type(enemy_type)
	assert(base_enemy, "Invalid enemy type: " + enemy_type)
	
	var elite_enemy: Dictionary = base_enemy.duplicate(true)
	
	elite_enemy.numbers += 1
	elite_enemy.combat_skill = mini(elite_enemy.combat_skill + ELITE_COMBAT_SKILL_BONUS, 3)
	elite_enemy.toughness = mini(elite_enemy.toughness + ELITE_TOUGHNESS_BONUS, 6)
	
	if "panic" in elite_enemy:
		elite_enemy.panic = _reduce_panic(elite_enemy.panic)
	
	elite_enemy.special_rules.append("Elite: This enemy is tougher and more skilled than normal.")
	
	return _apply_elite_modifications(elite_enemy)

func _reduce_panic(panic: String) -> String:
	var panic_values := panic.split("-")
	if panic_values.size() == 2:
		var lower := int(panic_values[0])
		var upper := int(panic_values[1])
		upper = maxi(lower, upper - ELITE_PANIC_REDUCTION)
		return "%d-%d" % [lower, upper]
	elif panic_values.size() == 1:
		return str(maxi(0, int(panic_values[0]) - ELITE_PANIC_REDUCTION))
	else:
		return panic  # Return original if format is unexpected

func _apply_elite_modifications(enemy: Dictionary) -> Dictionary:
	var roll := randf()
	
	if roll <= 0.2:
		enemy = apply_elite_weaponry(enemy)
	elif roll <= 0.4:
		enemy = _apply_elite_armor(enemy)
	elif roll <= 0.6:
		enemy = _apply_elite_skills(enemy)
	elif roll <= 0.8:
		enemy = _apply_elite_ability(enemy)
	else:
		enemy = _apply_elite_leadership(enemy)
	
	return enemy

func apply_elite_weaponry(enemy: Dictionary) -> Dictionary:
	var new_enemy := enemy.duplicate(true)
	var weapons: Array = (new_enemy.get("weapons", "") as String).split(" ")
	var new_weapons: Array[String] = []
	
	for weapon in weapons:
		match weapon:
			"1A": new_weapons.append("2B")
			"1B": new_weapons.append("2C")
			"2A": new_weapons.append("3B")
			"2B", "2C": new_weapons.append("3C")
			"3A", "3B", "3C": new_weapons.append(weapon)
	
	new_enemy["weapons"] = " ".join(new_weapons)
	new_enemy["special_rules"].append("Elite Weaponry: This enemy is equipped with more powerful weapons.")
	return new_enemy

func _apply_elite_armor(enemy: Dictionary) -> Dictionary:
	var new_enemy := enemy.duplicate(true)
	if "Saving Throw" in new_enemy:
		var current_save := int(new_enemy["Saving Throw"].split("+")[0])
		new_enemy["Saving Throw"] = "%d+" % maxi(current_save - 1, 4)
	else:
		new_enemy["Saving Throw"] = "5+"
	
	new_enemy.special_rules.append("Elite Armor: This enemy has improved armor or defenses.")
	return new_enemy

func _apply_elite_skills(enemy: Dictionary) -> Dictionary:
	var new_enemy := enemy.duplicate(true)
	new_enemy.combat_skill = mini(new_enemy.combat_skill + ELITE_COMBAT_SKILL_BONUS, 3)
	new_enemy.speed += 1
	new_enemy.special_rules.append("Elite Skills: This enemy is exceptionally skilled and quick.")
	return new_enemy

func _apply_elite_ability(enemy: Dictionary) -> Dictionary:
	var new_enemy := enemy.duplicate(true)
	var ability: int = randi() % GlobalEnums.PsionicAbility.size()
	
	match ability:
		GlobalEnums.PsionicAbility.TELEPATHY:
			new_enemy.special_rules.append("Mind Reading: Can detect enemy intentions at start of each round.")
		GlobalEnums.PsionicAbility.TELEKINESIS:
			new_enemy.special_rules.append("Telekinetic: Can move objects and enemies at range.")
		GlobalEnums.PsionicAbility.BARRIER:
			new_enemy.special_rules.append("Energy Shield: The first hit each round is automatically negated.")
		GlobalEnums.PsionicAbility.PYROKINESIS:
			new_enemy.special_rules.append("Pyrokinetic: Gains fire-based attacks.")
		_:
			new_enemy.special_rules.append("Enhanced: This enemy has mysterious powers.")
	
	return new_enemy

func _apply_elite_leadership(enemy: Dictionary) -> Dictionary:
	var new_enemy := enemy.duplicate(true)
	new_enemy.special_rules.append("Elite Leadership: All friendly units within 6\" gain +1 to hit rolls.")
	return new_enemy

func get_elite_enemy_reward(_enemy: Dictionary) -> Dictionary:
	var credits: int = randi() % 6 + 5
	var item: Equipment = _generate_random_item()
	
	return {
		"credits": credits,
		"item": item
	}

func _generate_random_item() -> Equipment:
	var item_types: Array[GlobalEnums.ItemType] = [
		GlobalEnums.ItemType.WEAPON,
		GlobalEnums.ItemType.ARMOR,
		GlobalEnums.ItemType.GEAR,
		GlobalEnums.ItemType.CONSUMABLE
	]
	var random_type: GlobalEnums.ItemType = item_types[randi() % item_types.size()]
	
	match random_type:
		GlobalEnums.ItemType.WEAPON:
			return _generate_random_weapon()
		GlobalEnums.ItemType.ARMOR:
			return _generate_random_armor()
		GlobalEnums.ItemType.GEAR:
			return _generate_random_gear()
		GlobalEnums.ItemType.CONSUMABLE:
			return _generate_random_consumable()
	
	return null  # This should never happen, but satisfies the compiler

func _generate_random_weapon() -> Equipment:
	var weapons = [
		{"name": "Auto rifle", "range": 24, "shots": 2, "damage": 0, "traits": []},
		{"name": "Beam pistol", "range": 8, "shots": 1, "damage": 1, "traits": ["Pistol", "Critical"]},
		{"name": "Blast rifle", "range": 18, "shots": 1, "damage": 1, "traits": []},
		{"name": "Hand cannon", "range": 6, "shots": 1, "damage": 2, "traits": ["Pistol"]},
		{"name": "Hunting rifle", "range": 30, "shots": 1, "damage": 1, "traits": ["Heavy", "Critical"]}
	]
	var weapon = weapons[randi() % weapons.size()]
	var equipment = Equipment.new()
	equipment.name = weapon.name
	equipment.type = GlobalEnums.ItemType.WEAPON
	equipment.stats = {
		"range": weapon.range,
		"shots": weapon.shots,
		"damage": weapon.damage
	}
	equipment.traits = weapon.traits
	return equipment

func _generate_random_armor() -> Equipment:
	var armors = [
		{"name": "Light armor", "toughness_bonus": 1},
		{"name": "Medium armor", "toughness_bonus": 2},
		{"name": "Heavy armor", "toughness_bonus": 3}
	]
	var armor = armors[randi() % armors.size()]
	var equipment = Equipment.new()
	equipment.name = armor.name
	equipment.type = GlobalEnums.ItemType.ARMOR
	equipment.stats = {
		"toughness_bonus": armor.toughness_bonus
	}
	return equipment

func _generate_random_gear() -> Equipment:
	var gears = [
		"Medkit",
		"Grappling hook",
		"Binoculars",
		"Comms unit",
		"Toolkit"
	]
	var gear_name = gears[randi() % gears.size()]
	var equipment = Equipment.new()
	equipment.name = gear_name
	equipment.type = GlobalEnums.ItemType.GEAR
	return equipment

func _generate_random_consumable() -> Equipment:
	var consumables = [
		"Stim pack",
		"Grenade",
		"Repair kit",
		"Antidote",
		"Energy cell"
	]
	var consumable_name = consumables[randi() % consumables.size()]
	var equipment = Equipment.new()
	equipment.name = consumable_name
	equipment.type = GlobalEnums.ItemType.CONSUMABLE
	return equipment
