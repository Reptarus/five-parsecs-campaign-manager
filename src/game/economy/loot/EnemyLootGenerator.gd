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
			if item.item_category == "credits":
				if item.item_cost is Dictionary:
					total_credits += item.item_cost.get("credits", 0)
				else:
					total_credits += int(str(item.item_cost))
	
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
	loot_context["enemy_level"] = 1 # Default level
	loot_context["base_loot_chance"] = base_loot_chance
	loot_context["rare_multiplier"] = rare_loot_multiplier
	
	# Apply difficulty modifier
	loot_context["difficulty_modifier"] = mission_difficulty_modifier
	loot_context["luck_bonus"] = crew_luck_bonus
	
	return loot_context

func _generate_category_loot(loot_data: Array, category: String, _context: Dictionary) -> Array[GameItem]:
	var items: Array[GameItem] = []
	for loot_entry in loot_data:
		var chance: float = loot_entry.get("chance", 0.5)
		if randf() <= chance:
			var item: GameItem = _create_item_from_loot_data(loot_entry, category)
			items.append(item)
	return items

func _create_item_from_loot_data(loot_data: Dictionary, category: String) -> GameItem:
	var item: GameItem = GameItem.new()
	var item_type_str: String = loot_data.get("type", category).to_lower()

	# For weapons: resolve to a canonical weapon from weapons.json
	if item_type_str == "weapon" or category == "weapons":
		var weapon_data: Dictionary = _pick_random_canonical_weapon()
		if not weapon_data.is_empty():
			item.initialize_from_data(weapon_data)
			return item

	# For other item types: use the loot_data as-is via initialize_from_data
	var init_data: Dictionary = {
		"id": loot_data.get("id", "loot_%s" % str(randi())),
		"name": loot_data.get("name", "Unknown Item"),
		"category": item_type_str,
		"description": loot_data.get("description", ""),
		"cost": loot_data.get("value", 1),
		"tags": loot_data.get("tags", []),
	}
	item.initialize_from_data(init_data)
	return item


## Cached canonical weapon data from weapons.json
static var _weapons_cache: Array = []
static var _weapons_loaded: bool = false

static func _load_weapons_cache() -> void:
	if _weapons_loaded:
		return
	var path := "res://data/weapons.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		_weapons_loaded = true
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_weapons_loaded = true
		return
	if json.data is Dictionary and json.data.has("weapons"):
		_weapons_cache = json.data["weapons"]
	_weapons_loaded = true

static func _pick_random_canonical_weapon() -> Dictionary:
	_load_weapons_cache()
	if _weapons_cache.is_empty():
		return {}
	var weapon: Dictionary = _weapons_cache[randi() % _weapons_cache.size()]
	# Convert weapons.json format to GameItem.initialize_from_data format
	return {
		"id": weapon.get("id", "unknown_weapon"),
		"name": weapon.get("name", "Unknown Weapon"),
		"category": "weapon",
		"description": "Range: %d\", Shots: %d, Damage: +%d. Traits: %s" % [
			weapon.get("range", 0),
			weapon.get("shots", 0),
			weapon.get("damage", 0),
			", ".join(weapon.get("traits", [])) if weapon.get("traits", []) else "None"
		],
		"cost": weapon.get("damage", 0) + weapon.get("shots", 1),
		"tags": weapon.get("traits", []),
		"effect": "Range %d\", Shots %d, Damage +%d" % [
			weapon.get("range", 0), weapon.get("shots", 0), weapon.get("damage", 0)
		],
	}

func _calculate_battle_bonus(defeated_enemies: Array, _context: Dictionary) -> Dictionary:
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
		bonus_item.initialize_from_data({
			"id": "combat_experience_data",
			"name": "Combat Experience Data",
			"category": "special",
			"description": "Tactical data from engaging diverse enemy types",
			"cost": 1,
			"tags": ["tactical_data", "bonus_loot"],
		})
		return {"bonus_items": [bonus_item], "bonus_credits": 0}
	
	return {}

func _consolidate_loot_items(loot_items: Array) -> Array[GameItem]:
	var consolidated: Dictionary = {}
	for item in loot_items:
		# Keep unique items by name + category
		var key: String = item.item_name + "_" + item.item_category
		if not consolidated.has(key):
			consolidated[key] = item
	return consolidated.values()

func _extract_rare_items(loot_items: Array) -> Array[GameItem]:
	var rare_items: Array[GameItem] = []
	for item in loot_items:
		if item.item_tags.has("rare") or item.item_tags.has("Piercing") or item.item_tags.has("Critical"):
			rare_items.append(item)
	return rare_items

func _calculate_total_loot_value(loot_items: Array) -> int:
	var total: int = 0
	for item in loot_items:
		if item.item_cost is Dictionary:
			total += item.item_cost.get("credits", 0)
		elif item.item_cost is int:
			total += item.item_cost
	return total

func _generate_generic_loot_table(_enemy: Enemy) -> Dictionary:
	# Fallback loot table for enemies without specific tables
	return {
		"credits": [
			{"name": "Credits", "chance": 0.8, "value": 50, "quality": "standard"}
		],
		"equipment": [
			{"name": "Basic Equipment", "chance": 0.3, "value": 25, "quality": "standard"}
		]
	}

