@tool
class_name EnemyLootGenerator
extends RefCounted

## Enemy Loot Generation System for Five Parsecs Campaign Manager
##
## Centralized system for generating loot from defeated enemies, integrating
## with the existing economy framework and all enemy type loot tables.

const GameItem = preload("res://src/core/economy/loot/GameItem.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Enemy type classes for loot generation
const CorporateSecurity = preload("res://src/game/enemy/types/CorporateSecurity.gd")
const Pirates = preload("res://src/game/enemy/types/Pirates.gd")
const Cultists = preload("res://src/game/enemy/types/Cultists.gd")
const Wildlife = preload("res://src/game/enemy/types/Wildlife.gd")
const RivalGang = preload("res://src/game/enemy/types/RivalGang.gd")
const Mercenaries = preload("res://src/game/enemy/types/Mercenaries.gd")
const Enforcers = preload("res://src/game/enemy/types/Enforcers.gd")
const Raiders = preload("res://src/game/enemy/types/Raiders.gd")

# Loot generation configuration
@export var base_loot_chance: float = 0.7  # Base chance for any loot to drop
@export var rare_loot_multiplier: float = 0.3  # Multiplier for rare loot chances
@export var mission_difficulty_modifier: float = 1.0  # Mission difficulty affects loot quality
@export var crew_luck_bonus: float = 0.0  # Player crew luck affects loot generation

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
func generate_battle_loot(defeated_enemies: Array[Enemy], battle_context: Dictionary = {}) -> Dictionary:
	var battle_loot: Dictionary = {
		"individual_loot": {},
		"combined_items": [],
		"total_credits": 0,
		"rare_items": [],
		"battle_bonus": {}
	}
	
	var all_loot: Array[GameItem] = []
	var total_credits: int = 0
	
	# Generate loot from each enemy
	for i in range(defeated_enemies.size()):
		var enemy: Enemy = defeated_enemies[i]
		var enemy_loot: Array[GameItem] = generate_enemy_loot(enemy, battle_context)
		
		battle_loot.individual_loot[i] = enemy_loot
		all_loot.append_array(enemy_loot)
		
		# Track credits separately
		for item in enemy_loot:
			if item.item_type == GameItem.ItemType.CREDITS:
				total_credits += item.value
	
	# Apply battle-wide bonuses
	var battle_bonus: Dictionary = _calculate_battle_bonus(defeated_enemies, battle_context)
	if not battle_bonus.is_empty():
		battle_loot.battle_bonus = battle_bonus
		
		# Add bonus loot
		if battle_bonus.has("bonus_credits"):
			total_credits += battle_bonus.bonus_credits
		
		if battle_bonus.has("bonus_items"):
			all_loot.append_array(battle_bonus.bonus_items)
	
	# Consolidate similar items
	battle_loot.combined_items = _consolidate_loot(all_loot)
	battle_loot.total_credits = total_credits
	battle_loot.rare_items = _extract_rare_items(all_loot)
	
	return battle_loot

## Generate loot based on enemy type and specialization
func generate_specialized_loot(enemy_type: String, specialization: String, quality_tier: int = 2) -> Array[GameItem]:
	var specialized_loot: Array[GameItem] = []
	
	match enemy_type.to_lower():
		"corporate_security":
			specialized_loot = _generate_corporate_specialized_loot(specialization, quality_tier)
		"pirates":
			specialized_loot = _generate_pirate_specialized_loot(specialization, quality_tier)
		"cultists":
			specialized_loot = _generate_cultist_specialized_loot(specialization, quality_tier)
		"wildlife":
			specialized_loot = _generate_wildlife_specialized_loot(specialization, quality_tier)
		"rival_gang":
			specialized_loot = _generate_gang_specialized_loot(specialization, quality_tier)
		"mercenaries":
			specialized_loot = _generate_mercenary_specialized_loot(specialization, quality_tier)
		"enforcers":
			specialized_loot = _generate_enforcer_specialized_loot(specialization, quality_tier)
		"raiders":
			specialized_loot = _generate_raider_specialized_loot(specialization, quality_tier)
	
	return specialized_loot

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
			modifiers.quality_bonus += 1  # Harsh environments have better preserved equipment
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
	if enemy is CorporateSecurity:
		return enemy.get_corporate_loot_table()
	elif enemy is Pirates:
		return enemy.get_pirate_loot_table()
	elif enemy is Cultists:
		return enemy.get_cultist_loot_table()
	elif enemy is Wildlife:
		return enemy.get_wildlife_loot_table()
	elif enemy is RivalGang:
		return enemy.get_gang_loot_table()
	elif enemy is Mercenaries:
		return enemy.get_mercenary_loot_table()
	elif enemy is Enforcers:
		return enemy.get_enforcer_loot_table()
	elif enemy is Raiders:
		return enemy.get_raider_loot_table()
	else:
		# Fallback for generic enemies
		return _generate_generic_loot_table(enemy)

func _build_loot_context(enemy: Enemy, context: Dictionary) -> Dictionary:
	var loot_context: Dictionary = context.duplicate()
	
	# Add enemy-specific context
	loot_context["enemy_type"] = enemy.get_script().get_global_name()
	loot_context["enemy_level"] = enemy._max_health / 10  # Rough level estimate
	loot_context["base_loot_chance"] = base_loot_chance
	loot_context["rare_multiplier"] = rare_loot_multiplier
	
	# Apply difficulty modifier
	loot_context["difficulty_modifier"] = mission_difficulty_modifier
	loot_context["luck_bonus"] = crew_luck_bonus
	
	return loot_context

func _generate_category_loot(category_data: Array, category: String, context: Dictionary) -> Array[GameItem]:
	var category_loot: Array[GameItem] = []
	
	for loot_entry in category_data:
		if not loot_entry is Dictionary:
			continue
		
		var base_chance: float = loot_entry.get("chance", 0.5)
		var adjusted_chance: float = base_chance * context.get("base_loot_chance", 1.0)
		
		# Apply rarity adjustments
		if loot_entry.has("rarity") and loot_entry.rarity in ["rare", "epic", "legendary"]:
			adjusted_chance *= context.get("rare_multiplier", 1.0)
		
		# Roll for loot generation
		if randf() <= adjusted_chance:
			var loot_item: GameItem = _create_loot_item(loot_entry, category, context)
			if loot_item != null:
				category_loot.append(loot_item)
				
				# Check for rare item notification
				if loot_entry.get("rarity", "common") in ["rare", "epic", "legendary"]:
					rare_loot_found.emit(loot_item, context.get("enemy_type", "Unknown"))
	
	return category_loot

func _create_loot_item(loot_data: Dictionary, category: String, context: Dictionary) -> GameItem:
	var item: GameItem = GameItem.new()
	
	# Set basic item properties
	item.item_name = loot_data.get("name", "Unknown Item")
	item.item_description = loot_data.get("description", "")
	item.value = loot_data.get("value", 10)
	
	# Determine item type based on category and data
	item.item_type = _determine_item_type(loot_data, category)
	
	# Set quality and condition
	var quality: String = loot_data.get("quality", "standard")
	item.quality = _parse_quality_enum(quality)
	
	var condition: String = loot_data.get("condition", "good")
	item.condition = _parse_condition_enum(condition)
	
	# Apply context modifiers
	_apply_context_modifiers(item, context)
	
	# Set specialized properties
	_set_specialized_properties(item, loot_data, category)
	
	return item

func _determine_item_type(loot_data: Dictionary, category: String) -> GameItem.ItemType:
	var item_type: String = loot_data.get("type", category)
	
	match item_type.to_lower():
		"weapon": return GameItem.ItemType.WEAPON
		"armor": return GameItem.ItemType.ARMOR
		"equipment": return GameItem.ItemType.EQUIPMENT
		"consumable": return GameItem.ItemType.CONSUMABLE
		"trade_good": return GameItem.ItemType.TRADE_GOOD
		"data": return GameItem.ItemType.DATA
		"credits": return GameItem.ItemType.CREDITS
		"contraband": return GameItem.ItemType.CONTRABAND
		"biological": return GameItem.ItemType.BIOLOGICAL
		_: return GameItem.ItemType.EQUIPMENT

func _parse_quality_enum(quality: String) -> GameItem.Quality:
	match quality.to_lower():
		"poor": return GameItem.Quality.POOR
		"standard": return GameItem.Quality.STANDARD
		"good": return GameItem.Quality.GOOD
		"excellent": return GameItem.Quality.EXCELLENT
		"masterwork": return GameItem.Quality.MASTERWORK
		_: return GameItem.Quality.STANDARD

func _parse_condition_enum(condition: String) -> GameItem.Condition:
	match condition.to_lower():
		"broken": return GameItem.Condition.BROKEN
		"poor": return GameItem.Condition.POOR
		"damaged": return GameItem.Condition.DAMAGED
		"good": return GameItem.Condition.GOOD
		"excellent": return GameItem.Condition.EXCELLENT
		_: return GameItem.Condition.GOOD

func _apply_context_modifiers(item: GameItem, context: Dictionary) -> void:
	# Apply difficulty-based value modifications
	var difficulty_modifier: float = context.get("difficulty_modifier", 1.0)
	item.value = roundi(item.value * difficulty_modifier)
	
	# Apply luck bonuses
	var luck_bonus: float = context.get("luck_bonus", 0.0)
	if luck_bonus > 0.0 and randf() < luck_bonus:
		item.value = roundi(item.value * 1.2)
		# Potentially upgrade quality
		if randf() < 0.3:
			item.quality = mini(item.quality + 1, GameItem.Quality.MASTERWORK)

func _set_specialized_properties(item: GameItem, loot_data: Dictionary, category: String) -> void:
	# Set category-specific properties
	match category:
		"weapons", "military_equipment":
			item.tags.append("military")
			if loot_data.has("illegal") and loot_data.illegal:
				item.tags.append("illegal")
		
		"contraband":
			item.tags.append("illegal")
			item.tags.append("contraband")
			if loot_data.has("danger_level"):
				item.tags.append("danger_" + str(loot_data.danger_level))
		
		"biological_materials":
			item.tags.append("biological")
			if loot_data.has("environmental_type"):
				item.tags.append("environment_" + loot_data.environmental_type)
		
		"intelligence", "evidence_data":
			item.tags.append("data")
			if loot_data.has("classification"):
				item.tags.append("classified_" + loot_data.classification)
	
	# Add source tags
	if loot_data.has("source"):
		item.tags.append("source_" + loot_data.source)

func _calculate_battle_bonus(defeated_enemies: Array[Enemy], context: Dictionary) -> Dictionary:
	var bonus: Dictionary = {}
	
	var enemy_count: int = defeated_enemies.size()
	var total_enemy_level: int = 0
	var enemy_variety: int = 0
	var enemy_types: Array[String] = []
	
	# Analyze defeated enemies
	for enemy in defeated_enemies:
		total_enemy_level += enemy._max_health / 10
		var enemy_type: String = enemy.get_script().get_global_name()
		if enemy_type not in enemy_types:
			enemy_types.append(enemy_type)
			enemy_variety += 1
	
	# Multi-enemy bonus
	if enemy_count >= 5:
		bonus["bonus_credits"] = enemy_count * 25
		bonus["description"] = "Large battle bonus"
	
	# Variety bonus (fighting different enemy types)
	if enemy_variety >= 3:
		bonus["variety_bonus"] = true
		bonus["bonus_items"] = [_create_variety_bonus_item()]
	
	# High-level enemy bonus
	var average_level: float = float(total_enemy_level) / enemy_count
	if average_level >= 8:
		bonus["elite_bonus"] = true
		bonus["bonus_credits"] = bonus.get("bonus_credits", 0) + roundi(average_level * 50)
	
	return bonus

func _create_variety_bonus_item() -> GameItem:
	var bonus_item: GameItem = GameItem.new()
	bonus_item.item_name = "Combat Experience Data"
	bonus_item.item_description = "Valuable tactical data from engaging diverse enemy types"
	bonus_item.item_type = GameItem.ItemType.DATA
	bonus_item.value = 500
	bonus_item.quality = GameItem.Quality.GOOD
	bonus_item.tags.append("tactical_data")
	bonus_item.tags.append("bonus_loot")
	return bonus_item

func _consolidate_loot(loot_items: Array[GameItem]) -> Array[GameItem]:
	var consolidated: Dictionary = {}
	var unique_items: Array[GameItem] = []
	
	for item in loot_items:
		if item.item_type == GameItem.ItemType.CREDITS:
			# Consolidate credits
			if consolidated.has("credits"):
				consolidated["credits"].value += item.value
			else:
				consolidated["credits"] = item
		elif item.tags.has("stackable"):
			# Consolidate stackable items
			var stack_key: String = item.item_name + "_" + str(item.quality)
			if consolidated.has(stack_key):
				consolidated[stack_key].quantity += item.quantity
			else:
				consolidated[stack_key] = item
		else:
			# Keep unique items separate
			unique_items.append(item)
	
	# Combine consolidated and unique items
	var result: Array[GameItem] = []
	for key in consolidated.keys():
		result.append(consolidated[key])
	result.append_array(unique_items)
	
	return result

func _extract_rare_items(loot_items: Array[GameItem]) -> Array[GameItem]:
	var rare_items: Array[GameItem] = []
	
	for item in loot_items:
		if item.quality >= GameItem.Quality.EXCELLENT or item.tags.has("rare"):
			rare_items.append(item)
	
	return rare_items

func _calculate_total_loot_value(loot_items: Array[GameItem]) -> int:
	var total: int = 0
	for item in loot_items:
		total += item.value
	return total

func _generate_generic_loot_table(enemy: Enemy) -> Dictionary:
	# Fallback loot table for enemies without specific tables
	return {
		"credits": [
			{
				"type": "credits",
				"name": "Credits",
				"value": 50,
				"chance": 0.6
			}
		],
		"equipment": [
			{
				"type": "equipment",
				"name": "Basic Equipment",
				"value": 100,
				"quality": "standard",
				"chance": 0.3
			}
		]
	}

# Specialized loot generation methods for each enemy type

func _generate_corporate_specialized_loot(specialization: String, quality_tier: int) -> Array[GameItem]:
	var items: Array[GameItem] = []
	
	match specialization:
		"executive_protection":
			items.append(_create_item("Executive Security Badge", GameItem.ItemType.EQUIPMENT, 300, quality_tier))
		"facility_security":
			items.append(_create_item("Access Control System", GameItem.ItemType.EQUIPMENT, 500, quality_tier))
		"data_security":
			items.append(_create_item("Encryption Module", GameItem.ItemType.EQUIPMENT, 800, quality_tier))
	
	return items

func _generate_pirate_specialized_loot(specialization: String, quality_tier: int) -> Array[GameItem]:
	var items: Array[GameItem] = []
	
	match specialization:
		"ship_raider":
			items.append(_create_item("Boarding Equipment", GameItem.ItemType.EQUIPMENT, 400, quality_tier))
		"treasure_hunter":
			items.append(_create_item("Treasure Map Fragment", GameItem.ItemType.DATA, 600, quality_tier))
		"smuggler":
			items.append(_create_item("Hidden Compartment Kit", GameItem.ItemType.EQUIPMENT, 350, quality_tier))
	
	return items

func _generate_cultist_specialized_loot(specialization: String, quality_tier: int) -> Array[GameItem]:
	var items: Array[GameItem] = []
	
	match specialization:
		"ritual_specialist":
			items.append(_create_item("Ritual Components", GameItem.ItemType.CONSUMABLE, 500, quality_tier))
		"mind_controller":
			items.append(_create_item("Psionic Amplifier", GameItem.ItemType.EQUIPMENT, 1000, quality_tier))
		"zealot":
			items.append(_create_item("Fanatical Writings", GameItem.ItemType.DATA, 200, quality_tier))
	
	return items

func _generate_wildlife_specialized_loot(specialization: String, quality_tier: int) -> Array[GameItem]:
	var items: Array[GameItem] = []
	
	match specialization:
		"apex_predator":
			items.append(_create_item("Apex Predator Gland", GameItem.ItemType.BIOLOGICAL, 1200, quality_tier))
		"pack_hunter":
			items.append(_create_item("Pack Coordination Pheromones", GameItem.ItemType.BIOLOGICAL, 400, quality_tier))
		"environmental_specialist":
			items.append(_create_item("Environmental Adaptation Sample", GameItem.ItemType.BIOLOGICAL, 600, quality_tier))
	
	return items

func _generate_gang_specialized_loot(specialization: String, quality_tier: int) -> Array[GameItem]:
	var items: Array[GameItem] = []
	
	match specialization:
		"tech":
			items.append(_create_item("Hacking Tools", GameItem.ItemType.EQUIPMENT, 700, quality_tier))
		"enforcement":
			items.append(_create_item("Intimidation Gear", GameItem.ItemType.EQUIPMENT, 300, quality_tier))
		"smuggling":
			items.append(_create_item("Contraband Cache", GameItem.ItemType.CONTRABAND, 800, quality_tier))
	
	return items

func _generate_mercenary_specialized_loot(specialization: String, quality_tier: int) -> Array[GameItem]:
	var items: Array[GameItem] = []
	
	match specialization:
		"heavy_weapons":
			items.append(_create_item("Heavy Weapon Components", GameItem.ItemType.EQUIPMENT, 900, quality_tier))
		"recon":
			items.append(_create_item("Reconnaissance Gear", GameItem.ItemType.EQUIPMENT, 600, quality_tier))
		"support":
			items.append(_create_item("Medical Supplies", GameItem.ItemType.CONSUMABLE, 400, quality_tier))
	
	return items

func _generate_enforcer_specialized_loot(specialization: String, quality_tier: int) -> Array[GameItem]:
	var items: Array[GameItem] = []
	
	match specialization:
		"special_forces":
			items.append(_create_item("Special Operations Equipment", GameItem.ItemType.EQUIPMENT, 1200, quality_tier))
		"marshal":
			items.append(_create_item("Frontier Marshal Badge", GameItem.ItemType.EQUIPMENT, 500, quality_tier))
		"security":
			items.append(_create_item("Security Protocols", GameItem.ItemType.DATA, 300, quality_tier))
	
	return items

func _generate_raider_specialized_loot(specialization: String, quality_tier: int) -> Array[GameItem]:
	var items: Array[GameItem] = []
	
	match specialization:
		"scavenger_clan":
			items.append(_create_item("Scavenging Tools", GameItem.ItemType.EQUIPMENT, 350, quality_tier))
		"wasteland_tribe":
			items.append(_create_item("Tribal Artifacts", GameItem.ItemType.TRADE_GOOD, 400, quality_tier))
		"nomad_band":
			items.append(_create_item("Navigation Equipment", GameItem.ItemType.EQUIPMENT, 500, quality_tier))
	
	return items

func _create_item(name: String, type: GameItem.ItemType, base_value: int, quality_tier: int) -> GameItem:
	var item: GameItem = GameItem.new()
	item.item_name = name
	item.item_type = type
	item.value = base_value
	
	# Set quality based on tier
	match quality_tier:
		1: item.quality = GameItem.Quality.POOR
		2: item.quality = GameItem.Quality.STANDARD
		3: item.quality = GameItem.Quality.GOOD
		4: item.quality = GameItem.Quality.EXCELLENT
		5: item.quality = GameItem.Quality.MASTERWORK
		_: item.quality = GameItem.Quality.STANDARD
	
	item.condition = GameItem.Condition.GOOD
	return item