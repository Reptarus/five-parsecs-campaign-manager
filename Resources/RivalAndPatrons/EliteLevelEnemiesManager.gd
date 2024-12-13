class_name EliteLevelEnemiesManager
extends Resource

const ELITE_DAMAGE_BONUS: int = 1
const ELITE_TOUGHNESS_BONUS: int = 1
const ELITE_COMBAT_SKILL_BONUS: int = 1
const ELITE_PANIC_REDUCTION: int = 1

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const EnemyData = preload("../RivalAndPatrons/EnemyData.gd")
const Equipment = preload("res://Resources/Core/Character/Equipment/Equipment.gd")

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

func _reduce_panic(panic_value: String) -> String:
	if "-" in panic_value:
		var parts = panic_value.split("-")
		var min_panic = int(parts[0])
		var max_panic = int(parts[1])
		max_panic = maxi(max_panic - ELITE_PANIC_REDUCTION, min_panic)
		return "%d-%d" % [min_panic, max_panic]
	else:
		var panic = int(panic_value)
		return str(maxi(panic - ELITE_PANIC_REDUCTION, 0))

func _apply_elite_modifications(enemy: Dictionary) -> Dictionary:
	var modifications = [
		"apply_elite_weaponry",
		"_apply_elite_armor",
		"_apply_elite_skills",
		"_apply_elite_ability",
		"_apply_elite_leadership"
	]
	
	var num_mods = randi() % 2 + 1  # Apply 1-2 random modifications
	modifications.shuffle()
	
	var modified_enemy = enemy
	for i in range(num_mods):
		var method = modifications[i]
		modified_enemy = call(method, modified_enemy)
	
	return modified_enemy

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
	var ability: int = randi() % GameEnums.PsionicAbility.size()
	
	match ability:
		GameEnums.PsionicAbility.TELEPATHY:
			new_enemy.special_rules.append("Mind Reading: Can detect enemy intentions at start of each round.")
		GameEnums.PsionicAbility.TELEKINESIS:
			new_enemy.special_rules.append("Telekinetic: Can move objects and enemies at range.")
		GameEnums.PsionicAbility.BARRIER:
			new_enemy.special_rules.append("Energy Shield: The first hit each round is automatically negated.")
		GameEnums.PsionicAbility.PYROKINESIS:
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
	var item_types = [
		GameEnums.ItemType.WEAPON,
		GameEnums.ItemType.ARMOR,
		GameEnums.ItemType.GEAR,
		GameEnums.ItemType.CONSUMABLE
	]
	var random_type: int = item_types[randi() % item_types.size()]
	
	match random_type:
		GameEnums.ItemType.WEAPON:
			return _generate_random_weapon()
		GameEnums.ItemType.ARMOR:
			return _generate_random_armor()
		GameEnums.ItemType.GEAR:
			return _generate_random_gear()
		GameEnums.ItemType.CONSUMABLE:
			return _generate_random_consumable()
		_:
			push_error("Invalid item type")
			return null

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
	equipment.type = GameEnums.ItemType.WEAPON
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
	equipment.type = GameEnums.ItemType.ARMOR
	equipment.stats = {
		"toughness_bonus": armor.toughness_bonus
	}
	return equipment

func _generate_random_gear() -> Equipment:
	var equipment = Equipment.new()
	equipment.name = _generate_gear_name()
	equipment.type = GameEnums.ItemType.GEAR
	return equipment

func _generate_gear_name() -> String:
	var gear_names = [
		"Medkit",
		"Grappling Hook",
		"Binoculars",
		"Comms Unit",
		"Toolkit",
		"Scanner",
		"Repair Kit",
		"Survival Pack",
		"Hacking Device",
		"Shield Generator"
	]
	return gear_names[randi() % gear_names.size()]

func _generate_random_consumable() -> Equipment:
	var equipment = Equipment.new()
	equipment.name = "Consumable Item"
	equipment.type = GameEnums.ItemType.CONSUMABLE
	return equipment
