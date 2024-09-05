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
	
	return {
		"type": "Weapon",
		"name": weapon_name,
		"damage": damage,
		"value": randi_range(10, 50) * damage
	}

func generate_armor() -> Dictionary:
	var armor_types: Array[String] = ["Light", "Medium", "Heavy"]
	var armor_name: String = armor_types[randi() % armor_types.size()] + " Armor " + _generate_rarity()
	var defense: int = randi_range(1, 3)
	
	return {
		"type": "Armor",
		"name": armor_name,
		"defense": defense,
		"value": randi_range(15, 60) * defense
	}

func generate_gear() -> Dictionary:
	var gear_types: Array[String] = ["Medkit", "Grenade", "Scope", "Utility Belt", "Stealth Device"]
	var gear_name: String = gear_types[randi() % gear_types.size()] + " " + _generate_rarity()
	
	return {
		"type": "Gear",
		"name": gear_name,
		"effect": _generate_gear_effect(),
		"value": randi_range(20, 100)
	}

func generate_consumable() -> Dictionary:
	var consumable_types: Array[String] = ["Health Potion", "Energy Drink", "Stim Pack", "Antidote", "Booster"]
	var consumable_name: String = consumable_types[randi() % consumable_types.size()]
	
	return {
		"type": "Consumable",
		"name": consumable_name,
		"effect": _generate_consumable_effect(),
		"value": randi_range(5, 30)
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

func apply_loot(character: Character, loot: Dictionary) -> void:
	match loot.type:
		"Weapon", "Armor", "Gear", "Consumable":
			var equipment_type: Equipment.Type
			match loot.type:
				"Weapon":
					equipment_type = Equipment.Type.WEAPON
				"Armor":
					equipment_type = Equipment.Type.ARMOR
				"Gear":
					equipment_type = Equipment.Type.GEAR
				"Consumable":
					equipment_type = Equipment.Type.GEAR  # Assuming consumables are treated as gear
			
			var new_equipment = Equipment.new(loot.name, equipment_type, loot.get("value", 0), loot.get("description", ""))
			character.inventory.add_item(new_equipment)
		
		"Credits":
			game_state.add_credits(loot.amount)
		"Story Point":
			game_state.add_story_points(loot.amount)
		_:
			push_error("Invalid loot type: " + loot.type)
	
	print(character.name + " received " + (loot.name if "name" in loot else loot.type))
