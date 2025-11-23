extends Node
class_name EquipmentComparisonTool

## Equipment Comparison Tool - Side-by-side weapon/armor stat analysis
## Static utility class (no autoload needed)

## Compare weapons
static func compare_weapons(weapons: Array) -> Dictionary:
	"""Compare up to 3 weapons side-by-side"""
	var comparison = {
		"items": [],
		"stats": [],
		"best_for": "",
		"budget_pick": ""
	}
	
	for weapon in weapons:
		comparison.items.append({
			"name": weapon.name if weapon.has("name") else "Unknown",
			"cost": weapon.cost if weapon.has("cost") else 0,
			"range": weapon.range if weapon.has("range") else 0,
			"shots": weapon.shots if weapon.has("shots") else 1,
			"damage": weapon.damage if weapon.has("damage") else 0,
			"traits": weapon.traits if weapon.has("traits") else []
		})
	
	# Determine best overall and budget pick
	if weapons.size() > 0:
		comparison.best_for = _find_best_weapon(weapons)
		comparison.budget_pick = _find_budget_weapon(weapons)
	
	return comparison

static func compare_armor(armor_pieces: Array) -> Dictionary:
	"""Compare armor pieces"""
	var comparison = {
		"items": [],
		"recommendation": ""
	}
	
	for armor in armor_pieces:
		comparison.items.append({
			"name": armor.name if armor.has("name") else "Unknown",
			"cost": armor.cost if armor.has("cost") else 0,
			"toughness_bonus": armor.toughness_bonus if armor.has("toughness_bonus") else 0,
			"speed_penalty": armor.speed_penalty if armor.has("speed_penalty") else 0,
			"traits": armor.traits if armor.has("traits") else []
		})
	
	return comparison

static func get_recommendation(items: Array, character: Variant) -> String:
	"""Get character-specific recommendation"""
	# TODO: Analyze character stats and recommend best item
	if items.is_empty():
		return "No items to compare"
	
	return "Recommended: " + (items[0].name if items[0].has("name") else "Item 1")

static func calculate_cost_benefit(item: Variant, current_item: Variant) -> float:
	"""Calculate cost/benefit ratio for upgrade decision"""
	if current_item == null:
		return 1.0
	
	var cost_diff = item.get("cost", 0) - current_item.get("cost", 0)
	if cost_diff <= 0:
		return 999.0  # Free upgrade
	
	# Simple benefit calculation (extend with actual stat comparison)
	var benefit = 0.0
	if item.has("damage") and current_item.has("damage"):
		benefit += (item.damage - current_item.damage) * 10
	
	return benefit / cost_diff if cost_diff > 0 else 0.0

## Internal helpers
static func _find_best_weapon(weapons: Array) -> String:
	"""Find highest-value weapon"""
	var best = weapons[0]
	for weapon in weapons:
		if weapon.get("damage", 0) > best.get("damage", 0):
			best = weapon
	return best.get("name", "Unknown")

static func _find_budget_weapon(weapons: Array) -> String:
	"""Find lowest-cost weapon"""
	var cheapest = weapons[0]
	for weapon in weapons:
		if weapon.get("cost", 999) < cheapest.get("cost", 999):
			cheapest = weapon
	return cheapest.get("name", "Unknown")
