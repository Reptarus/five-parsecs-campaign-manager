class_name LootGenerator
extends Node

var game_state: GameState

func _init(_game_state: GameState):
	game_state = _game_state

enum LootType {
	WEAPON,
	ARMOR,
	GEAR,
	CONSUMABLE,
	CREDITS,
	STORY_POINT
}

const LOOT_TABLE: Dictionary = {
	LootType.WEAPON: 25,
	LootType.ARMOR: 10,
	LootType.GEAR: 20,
	LootType.CONSUMABLE: 20,
	LootType.CREDITS: 20,
	LootType.STORY_POINT: 5
}

func generate_loot() -> Dictionary:
	var loot_type: LootType = _get_random_loot_type()
	
	match loot_type:
		LootType.WEAPON:
			return generate_weapon()
		LootType.ARMOR:
			return generate_armor()
		LootType.GEAR:
			return generate_gear()
		LootType.CONSUMABLE:
			return generate_consumable()
		LootType.CREDITS:
			return generate_credits()
		LootType.STORY_POINT:
			return generate_story_point()
		_:
			push_error("Invalid loot type")
			return {}

func _get_random_loot_type() -> LootType:
	var total_weight: int = LOOT_TABLE.values().reduce(func(acc, weight): return acc + weight, 0)
	var roll: int = randi_range(1, total_weight)
	var cumulative_weight: int = 0
	
	for loot_type in LOOT_TABLE:
		cumulative_weight += LOOT_TABLE[loot_type]
		if roll <= cumulative_weight:
			return loot_type
	
	push_error("Failed to determine loot type")
	return LootType.CREDITS

func generate_weapon() -> Dictionary:
	var weapon_types: Array[String] = ["Pistol", "Rifle", "Shotgun", "Sniper", "Heavy"]
	var weapon_name: String = weapon_types[randi() % weapon_types.size()] + " " + _generate_rarity()
	var damage: int = randi_range(1, 5)
	var weapon_type: Weapon.WeaponType = Weapon.WeaponType.values()[randi() % Weapon.WeaponType.size()]
	var weapon_range: int = randi_range(1, 10)
	var shots: int = randi_range(1, 5)
	
	return {
		"type": "Weapon",
		"name": weapon_name,
		"damage": damage,
		"value": randi_range(10, 50) * damage,
		"weapon_type": weapon_type,
		"weapon_range": weapon_range,
		"shots": shots,
		"traits": []
	}

func generate_armor() -> Dictionary:
	var armor_types: Array[String] = ["Light", "Medium", "Heavy"]
	var armor_name: String = armor_types[randi() % armor_types.size()] + " Armor " + _generate_rarity()
	var armor_save: int = randi_range(1, 3)
	
	return {
		"type": "Armor",
		"name": armor_name,
		"armor_save": armor_save,
		"value": randi_range(15, 60) * armor_save,
		"level": 1
	}

func generate_gear() -> Dictionary:
	var gear_types: Array[String] = ["Medkit", "Grenade", "Scope", "Utility Belt", "Stealth Device"]
	var gear_name: String = gear_types[randi() % gear_types.size()] + " " + _generate_rarity()
	
	return {
		"type": "Gear",
		"name": gear_name,
		"effect": _generate_gear_effect(),
		"value": randi_range(20, 100),
		"weight": randi_range(1, 5)
	}

func generate_consumable() -> Dictionary:
	var consumable_types: Array[String] = ["Health Potion", "Energy Drink", "Stim Pack", "Antidote", "Booster"]
	var consumable_name: String = consumable_types[randi() % consumable_types.size()]
	
	return {
		"type": "Consumable",
		"name": consumable_name,
		"effect": _generate_consumable_effect(),
		"value": randi_range(5, 30),
		"weight": randi_range(1, 3)
	}

func generate_credits() -> Dictionary:
	return {
		"type": "Credits",
		"amount": randi_range(10, 100)
	}

func generate_story_point() -> Dictionary:
	return {
		"type": "Story Point",
		"amount": 1
	}

func _generate_rarity() -> String:
	var rarities: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
	var weights: Array[int] = [50, 30, 15, 4, 1]
	var total_weight: int = weights.reduce(func(acc, weight): return acc + weight, 0)
	var roll: int = randi_range(1, total_weight)
	var cumulative_weight: int = 0
	
	for i in range(rarities.size()):
		cumulative_weight += weights[i]
		if roll <= cumulative_weight:
			return rarities[i]
	
	return "Common"

func _generate_gear_effect() -> String:
	var effects: Array[String] = [
		"Increases accuracy",
		"Boosts damage",
		"Improves stealth",
		"Enhances healing",
		"Grants temporary invulnerability"
	]
	return effects[randi() % effects.size()]

func _generate_consumable_effect() -> String:
	var effects: Array[String] = [
		"Restores health",
		"Increases energy",
		"Boosts all stats temporarily",
		"Cures status effects",
		"Grants temporary immunity"
	]
	return effects[randi() % effects.size()]

func apply_loot(character: Character, loot: Dictionary, ship: Ship) -> void:
	var loot_summary = []
	match loot.type:
		"Weapon":
			var new_weapon = Weapon.new()
			new_weapon.name = loot.name
			new_weapon.weapon_type = loot.weapon_type
			new_weapon.weapon_range = loot.weapon_range
			new_weapon.shots = loot.shots
			new_weapon.damage = loot.damage
			new_weapon.traits = loot.traits
			new_weapon.value = loot.value
			if ship.add_to_ship_stash(new_weapon):
				loot_summary.append("%s found %s" % [character.name, loot.name])
			else:
				loot_summary.append("Ship stash is full, couldn't store %s" % loot.name)
		
		"Armor":
			var new_armor = Armor.new()
			new_armor.name = loot.name
			new_armor.armor_save = loot.armor_save
			new_armor.level = loot.level
			new_armor.value = loot.value
			if ship.add_to_ship_stash(new_armor):
				loot_summary.append("%s found %s" % [character.name, loot.name])
			else:
				loot_summary.append("Ship stash is full, couldn't store %s" % loot.name)
		
		"Gear", "Consumable":
			var new_gear = Gear.new()
			new_gear.name = loot.name
			new_gear.type = loot.type
			new_gear.effect = loot.effect
			new_gear.value = loot.value
			new_gear.weight = loot.weight
			if ship.add_to_ship_stash(new_gear):
				loot_summary.append("%s found %s" % [character.name, loot.name])
			else:
				loot_summary.append("Ship stash is full, couldn't store %s" % loot.name)
		
		"Credits":
			ship.debt -= loot.amount  # Assuming credits reduce ship debt
			loot_summary.append("%s found %d credits" % [character.name, loot.amount])
		
		"Story Point":
			game_state.add_story_points(loot.amount)
			loot_summary.append("%s discovered %d story point(s)" % [character.name, loot.amount])
		
		_:
			push_error("Invalid loot type: %s" % loot.type)
	
	# Store loot summary for mission recap
	if not game_state.has("mission_loot_summary"):
		game_state.mission_loot_summary = []
	game_state.mission_loot_summary.append_array(loot_summary)
