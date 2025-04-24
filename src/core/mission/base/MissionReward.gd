@tool
extends Resource

## Mission reward system for Five Parsecs
## Defines rewards for mission completion including credits, items, and reputation

signal reward_updated

## Basic reward properties
@export var credits: int = 0
@export var reputation: int = 0
@export var items: Array = []

## Multipliers based on mission difficulty
var difficulty_multiplier: float = 1.0

func _init(p_credits: int = 0) -> void:
	credits = p_credits

## Getter/setter methods for test compatibility
func get_credits() -> int:
	return credits
	
func set_credits(value: int) -> void:
	credits = value
	reward_updated.emit()
	
func get_reputation() -> int:
	return reputation
	
func set_reputation(value: int) -> void:
	reputation = value
	reward_updated.emit()
	
func get_items() -> Array:
	return items
	
func set_items(value: Array) -> void:
	items = value
	reward_updated.emit()

## Calculate final reward with multipliers
func calculate_final_reward(success_level: float = 1.0) -> Dictionary:
	var final_credits = int(credits * difficulty_multiplier * success_level)
	var final_reputation = int(reputation * difficulty_multiplier * success_level)
	
	return {
		"credits": final_credits,
		"reputation": final_reputation,
		"items": items.duplicate()
	}

## Apply difficulty scaling
func apply_difficulty_scaling(difficulty: int) -> void:
	difficulty_multiplier = 1.0 + (difficulty * 0.2) # 20% increase per difficulty level
	credits = int(credits * difficulty_multiplier)
	reputation = int(reputation * difficulty_multiplier)
	reward_updated.emit()

## Compatibility method for applying difficulty scaling to reward
func scale_by_difficulty(difficulty: int) -> void:
	apply_difficulty_scaling(difficulty)

## Generate random bonus items based on difficulty
func generate_random_bonus_items(difficulty: int, count: int = 1) -> Array:
	var bonus_items = []
	var possible_items = [
		{"name": "Medkit", "value": 50, "type": "consumable"},
		{"name": "Ammo Pack", "value": 30, "type": "consumable"},
		{"name": "Shield Booster", "value": 75, "type": "gear"},
		{"name": "Targeting System", "value": 100, "type": "upgrade"},
		{"name": "Weapon Mod", "value": 125, "type": "upgrade"}
	]
	
	# Higher difficulty means better chance for valuable items
	for i in range(count):
		var item_index = min(randi() % possible_items.size(), difficulty - 1)
		if item_index < 0:
			item_index = 0
		bonus_items.append(possible_items[item_index].duplicate())
	
	return bonus_items

## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"credits": credits,
		"reputation": reputation,
		"items": items,
		"difficulty_multiplier": difficulty_multiplier
	}
	
## Deserialize from dictionary
func from_dict(data: Dictionary) -> Resource:
	credits = data.get("credits", 0)
	reputation = data.get("reputation", 0)
	items = data.get("items", [])
	difficulty_multiplier = data.get("difficulty_multiplier", 1.0)
	return self