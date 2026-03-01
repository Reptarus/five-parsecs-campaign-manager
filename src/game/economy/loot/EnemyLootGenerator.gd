@tool
class_name EnemyLootGenerator
extends RefCounted

## Enemy Loot Generation System for Five Parsecs Campaign Manager
##
## Centralized system for generating loot from defeated enemies, integrating
## with the existing economy framework and all enemy type loot tables.

const GameItem = preload("res://src/core/economy/loot/GameItem.gd")
# GlobalEnums available as autoload singleton

# Enemy type classes for loot generation
const CorporateSecurity = preload("res://src/game/enemy/types/CorporateSecurity.gd")
const Pirates = preload("res://src/game/enemy/types/Pirates.gd")
const Cultists = preload("res://src/game/enemy/types/Cultists.gd")
const Wildlife = preload("res://src/game/enemy/types/Wildlife.gd")
const RivalGang = preload("res://src/game/enemy/types/RivalGang.gd")
const Mercenaries = preload("res://src/game/enemy/types/Mercenaries.gd")
const Enforcers = preload("res://src/game/enemy/types/Enforcers.gd")
const Raiders = preload("res://src/game/enemy/types/Raiders.gd")

# Define Enemy base class for type safety
class Enemy:
	extends RefCounted
	var _max_health: int = 10
	var _enemy_type: String = "generic"
	
	func get_enemy_type() -> String:
		return _enemy_type
	
	func get_corporate_loot_table() -> Dictionary:
		return {}
	
	func get_pirate_loot_table() -> Dictionary:
		return {}
	
	func get_cultist_loot_table() -> Dictionary:
		return {}
	
	func get_wildlife_loot_table() -> Dictionary:
		return {}
	
	func get_gang_loot_table() -> Dictionary:
		return {}
	
	func get_mercenary_loot_table() -> Dictionary:
		return {}
	
	func get_enforcer_loot_table() -> Dictionary:
		return {}
	
	func get_raider_loot_table() -> Dictionary:
		return {}

# Loot generation configuration
@export var base_loot_chance: float = 0.7 # Base chance for any loot to drop
@export var rare_loot_multiplier: float = 0.3 # Multiplier for rare loot chances
@export var mission_difficulty_modifier: float = 1.0 # Mission difficulty affects loot quality
@export var crew_luck_bonus: float = 0.0 # Player crew luck affects loot generation

# Economy integration
signal loot_generated(loot_items: Array[GameItem], total_value: int)
signal rare_loot_found(item: GameItem, enemy_type: String)

## Generate loot from a defeated enemy
func generate_enemy_loot(enemy: Enemy, context: Dictionary = {}) -> Array[GameItem]:
	var generated_loot: Array[GameItem] = []
	
	# Get enemy-specific loot table
	var loot_table: Dictionary = _get_enemy_loot_table(enemy)
	if loot_table.is_empty():
		return generated_loot
	
	# Apply context modifiers
	var loot_context: Dictionary = _build_loot_context(enemy, context)
	
	# Generate loot from each category
	for category in loot_table.keys():
		var category_items: Array[GameItem] = _generate_category_loot(
			loot_table[category],
			category,
			loot_context
		)
		generated_loot.append_array(category_items)
	
	# Calculate total value and emit signals
	var total_value: int = _calculate_total_loot_value(generated_loot)
	loot_generated.emit(generated_loot, total_value)
	
	return generated_loot

## Generate loot for multiple enemies (battle aftermath)
func generate_battle_loot(defeated_enemies: Array, battle_context: Dictionary = {}) -> Dictionary:
	var battle_loot: Dictionary = {
		"individual_loot": {},
		"combined_items": [],
		"total_credits": 0,
		"rare_items": []
	}
	
	var total_credits: int = 0
	
	# Generate loot from each enemy
	for i in range(defeated_enemies.size()):
		var enemy: Enemy = defeated_enemies[i]
		var enemy_loot: Array[GameItem] = generate_enemy_loot(enemy, battle_context)
		
		battle_loot.individual_loot[i] = enemy_loot
		battle_loot.combined_items.append_array(enemy_loot)
		
		# Track credits separately
		for item in enemy_loot:
			if item.item_type == 0: # CREDITS type
				total_credits += item.value
	
	# Apply battle-wide bonuses
	var battle_bonus: Dictionary = _calculate_battle_bonus(defeated_enemies, battle_context)
	if not battle_bonus.is_empty():
		battle_loot.combined_items.append_array(battle_bonus.get("bonus_items", []))
		total_credits += battle_bonus.get("bonus_credits", 0)
	
	# Consolidate and categorize loot
	battle_loot.combined_items = _consolidate_loot_items(battle_loot.combined_items)
	battle_loot.rare_items = _extract_rare_items(battle_loot.combined_items)
	battle_loot.total_credits = total_credits
	
	return battle_loot

## Calculate loot value modifiers based on circumstances
func calculate_loot_modifiers(circumstances: Dictionary) -> Dictionary:
	var modifiers: Dictionary = {
		"chance_multiplier": 1.0,
		"quality_bonus": 0,
		"rarity_bonus": 0.0,
		"credits_multiplier": 1.0
	}
	
	# Mission difficulty affects loot quality
	var difficulty: int = circumstances.get("mission_difficulty", 3)
	modifiers.quality_bonus = (difficulty - 3)
	modifiers.chance_multiplier *= 1.0 + (difficulty - 3) * 0.1
	
	# Victory conditions affect loot quantity
	var victory_type: String = circumstances.get("victory_type", "standard")
	match victory_type:
		"decisive":
			modifiers.chance_multiplier *= 1.3
			modifiers.rarity_bonus += 0.2
		"pyrrhic":
			modifiers.chance_multiplier *= 0.8
		"perfect":
			modifiers.chance_multiplier *= 1.5
			modifiers.rarity_bonus += 0.3
			modifiers.quality_bonus += 1
	
	# Environmental factors
	var environment: String = circumstances.get("environment", "standard")
	match environment:
		"harsh":
			modifiers.quality_bonus += 1 # Harsh environments have better preserved equipment
		"rich":
			modifiers.credits_multiplier *= 1.2
		"dangerous":
			modifiers.rarity_bonus += 0.1
	
	# Crew abilities and equipment
	var luck_factor: float = circumstances.get("crew_luck", 0.0)
	modifiers.rarity_bonus += luck_factor * 0.1
	
	return modifiers

## Private Methods

func _get_enemy_loot_table(enemy: Enemy) -> Dictionary:
	# Get the appropriate loot table based on enemy type
	var enemy_type: String = enemy.get_enemy_type()
	
	match enemy_type.to_lower():
		"corporate_security":
			return enemy.get_corporate_loot_table()
		"pirates":
			return enemy.get_pirate_loot_table()
		"cultists":
			return enemy.get_cultist_loot_table()
		"wildlife":
			return enemy.get_wildlife_loot_table()
		"rival_gang":
			return enemy.get_gang_loot_table()
		"mercenaries":
			return enemy.get_mercenary_loot_table()
		"enforcers":
			return enemy.get_enforcer_loot_table()
		"raiders":
			return enemy.get_raider_loot_table()
		_:
			# Fallback for generic enemies
			return _generate_generic_loot_table(enemy)

func _build_loot_context(enemy: Enemy, context: Dictionary) -> Dictionary:
	var loot_context: Dictionary = context.duplicate()
	
	# Add enemy-specific context
	loot_context["enemy_type"] = enemy.get_enemy_type()
	loot_context["enemy_level"] = enemy._max_health / 10 # Rough level estimate
	loot_context["base_loot_chance"] = base_loot_chance
	loot_context["rare_multiplier"] = rare_loot_multiplier
	
	# Apply difficulty modifier
	loot_context["difficulty_modifier"] = mission_difficulty_modifier
	loot_context["luck_bonus"] = crew_luck_bonus
	
	return loot_context

func _generate_category_loot(loot_data: Array, category: String, context: Dictionary) -> Array[GameItem]:
	var items: Array[GameItem] = []
	
	for loot_entry in loot_data:
		var chance: float = loot_entry.get("chance", 0.5)
		var base_value: int = loot_entry.get("value", 10)
		var quality_tier: int = loot_entry.get("quality", 2)
		
		# Apply context modifiers
		chance *= context.get("chance_multiplier", 1.0)
		quality_tier += context.get("quality_bonus", 0)
		
		# Roll for loot
		if randf() <= chance:
			var item: GameItem = _create_item_from_loot_data(loot_entry, category)
			_apply_context_modifiers(item, context)
			items.append(item)
	
	return items

func _create_item_from_loot_data(loot_data: Dictionary, category: String) -> GameItem:
	var item: GameItem = GameItem.new()
	
	# Set basic properties
	item.item_name = loot_data.get("name", "Unknown Item")
	item.item_description = loot_data.get("description", "")
	item.value = loot_data.get("value", 10)
	
	# Set item type based on category
	item.item_type = _determine_item_type(loot_data, category)
	
	# Set quality and condition
	item.quality = _parse_quality_enum(loot_data.get("quality", "standard"))
	item.condition = _parse_condition_enum(loot_data.get("condition", "good"))
	
	# Set specialized properties
	_set_specialized_properties(item, loot_data, category)
	
	return item

func _determine_item_type(loot_data: Dictionary, category: String) -> int:
	var item_type: String = loot_data.get("type", category)
	
	match item_type.to_lower():
		"weapon": return 1 # WEAPON
		"armor": return 2 # ARMOR
		"equipment": return 3 # EQUIPMENT
		"consumable": return 4 # CONSUMABLE
		"trade_good": return 5 # TRADE_GOOD
		"data": return 6 # DATA
		"credits": return 0 # CREDITS
		"contraband": return 7 # CONTRABAND
		"biological": return 8 # BIOLOGICAL
		_: return 3 # EQUIPMENT

func _parse_quality_enum(quality: String) -> int:
	match quality.to_lower():
		"poor": return 1 # POOR
		"standard": return 2 # STANDARD
		"good": return 3 # GOOD
		"excellent": return 4 # EXCELLENT
		"masterwork": return 5 # MASTERWORK
		_: return 2 # STANDARD

func _parse_condition_enum(condition: String) -> int:
	match condition.to_lower():
		"broken": return 1 # BROKEN
		"poor": return 2 # POOR
		"damaged": return 3 # DAMAGED
		"good": return 4 # GOOD
		"excellent": return 5 # EXCELLENT
		_: return 4 # GOOD

func _apply_context_modifiers(item: GameItem, context: Dictionary) -> void:
	# Apply difficulty-based value modifications
	var difficulty_modifier: float = context.get("difficulty_modifier", 1.0)
	item.value = int(item.value * difficulty_modifier)
	
	# Apply luck-based quality improvements
	var luck_bonus: float = context.get("luck_bonus", 0.0)
	if randf() < luck_bonus:
		# Potentially upgrade quality
		if randf() < 0.3:
			item.quality = mini(item.quality + 1, 5) # MASTERWORK

func _set_specialized_properties(item: GameItem, loot_data: Dictionary, category: String) -> void:
	# Set category-specific properties
	if category == "weapons":
		item.tags.append("combat")
		if loot_data.has("range"):
			item.tags.append("range_" + str(loot_data.range))
	
	elif category == "armor":
		item.tags.append("protection")
		if loot_data.has("armor_value"):
			item.tags.append("armor_" + str(loot_data.armor_value))
	
	elif category == "equipment":
		item.tags.append("utility")
		if loot_data.has("specialization"):
			item.tags.append("spec_" + loot_data.specialization)
	
	# Add source information
	if loot_data.has("source"):
		item.tags.append("source_" + loot_data.source)

func _calculate_battle_bonus(defeated_enemies: Array, context: Dictionary) -> Dictionary:
	var bonus: Dictionary = {}

	var enemy_count: int = defeated_enemies.size()
	var enemy_types: Array[String] = []
	
	# Collect unique enemy types
	for enemy in defeated_enemies:
		var enemy_type: String = enemy.get_enemy_type()
		if not enemy_types.has(enemy_type):
			enemy_types.append(enemy_type)
	
	# Bonus for diverse enemy types
	if enemy_types.size() >= 3:
		var bonus_item: GameItem = GameItem.new()
		bonus_item.item_name = "Combat Experience Data"
		bonus_item.item_description = "Valuable tactical data from engaging diverse enemy types"
		bonus_item.item_type = 6 # DATA
		bonus_item.value = 500
		bonus_item.quality = 3 # GOOD
		bonus_item.tags.append("tactical_data")
		bonus_item.tags.append("bonus_loot")
		return {"bonus_items": [bonus_item], "bonus_credits": 0}
	
	return {}

func _consolidate_loot_items(loot_items: Array) -> Array[GameItem]:
	var consolidated: Dictionary = {}
	
	for item in loot_items:
		if item.item_type == 0: # CREDITS
			# Consolidate credits
			if consolidated.has("credits"):
				consolidated["credits"].value += item.value
			else:
				consolidated["credits"] = item
		else:
			# Keep unique items
			var key: String = item.item_name + "_" + str(item.item_type)
			if not consolidated.has(key):
				consolidated[key] = item
	
	return consolidated.values()

func _extract_rare_items(loot_items: Array) -> Array[GameItem]:
	var rare_items: Array[GameItem] = []
	
	for item in loot_items:
		if item.quality >= 4 or item.tags.has("rare"): # EXCELLENT or higher
			rare_items.append(item)
	
	return rare_items

func _calculate_total_loot_value(loot_items: Array) -> int:
	var total: int = 0
	
	for item in loot_items:
		total += item.value
	
	return total

func _generate_generic_loot_table(enemy: Enemy) -> Dictionary:
	# Fallback loot table for enemies without specific tables
	return {
		"credits": [
			{"name": "Credits", "chance": 0.8, "value": 50, "quality": "standard"}
		],
		"equipment": [
			{"name": "Basic Equipment", "chance": 0.3, "value": 25, "quality": "standard"}
		]
	}

func _create_item(name: String, type: int, base_value: int, quality_tier: int) -> GameItem:
	var item: GameItem = GameItem.new()
	item.item_name = name
	item.item_type = type
	item.value = base_value
	
	# Set quality based on tier
	match quality_tier:
		1: item.quality = 1 # POOR
		2: item.quality = 2 # STANDARD
		3: item.quality = 3 # GOOD
		4: item.quality = 4 # EXCELLENT
		5: item.quality = 5 # MASTERWORK
		_: item.quality = 2 # STANDARD
	
	item.condition = 4 # GOOD
	return item