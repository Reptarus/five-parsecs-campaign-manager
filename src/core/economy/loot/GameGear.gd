@tool
extends Resource
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/core/economy/loot/GameGear.gd")

# Import necessary classes
const GameDataManager = preload("res://src/core/managers/GameDataManager.gd")

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var gear_id: String = ""
@export var gear_name: String = ""
@export var gear_category: String = ""
@export var gear_description: String = ""
@export var gear_effects: Array[Dictionary] = []
@export var gear_traits: Array[String] = []
@export var gear_cost: Dictionary = {"credits": 0, "rarity": "Common"}
@export var gear_tags: Array[String] = []
@export var gear_requirements: Dictionary = {}
@export var description: String = ""
@export var special_abilities: Array = []

var _data_manager: Object = null

func _init() -> void:
	if Engine.is_editor_hint():
		return
		
	# Use the singleton instance
	_data_manager = GameDataManager.get_instance()
	GameDataManager.ensure_data_loaded()

func initialize_from_id(id: String) -> bool:
	if _data_manager == null:
		_data_manager = GameDataManager.get_instance()
		GameDataManager.ensure_data_loaded()
		
	var gear_data = _data_manager.get_gear_item(id)
	if gear_data.is_empty():
		push_error("Failed to find gear with ID: " + id)
		return false
		
	return initialize_from_data(gear_data)

func initialize_from_data(data: Dictionary) -> bool:
	if data.is_empty():
		return false
		
	gear_id = data.get("id", "")
	gear_name = data.get("name", "")
	gear_category = data.get("category", "")
	gear_description = data.get("description", "")
	
	# Handle effects data
	if data.has("effects") and data.effects is Array:
		gear_effects = data.effects
	else:
		gear_effects = []
		
		# If there's a single effect, convert it to our format
		if data.has("effect"):
			gear_effects.append({
				"type": "basic",
				"description": data.get("effect", ""),
				"value": data.get("value", 0)
			})
	
	# Handle traits
	if data.has("traits") and data.traits is Array:
		gear_traits = data.traits
	else:
		gear_traits = []
	
	# Handle cost data
	if data.has("cost") and data.cost is Dictionary:
		gear_cost = data.cost
	else:
		gear_cost = {"credits": data.get("cost", 0), "rarity": data.get("rarity", "Common")}
	
	gear_tags = data.get("tags", [])
	
	# Handle requirements
	if data.has("requirements") and data.requirements is Dictionary:
		gear_requirements = data.requirements
	else:
		gear_requirements = {}
	
	return true

func get_id() -> String:
	return gear_id

func get_gear_name() -> String:
	return gear_name

func get_category() -> String:
	return gear_category

func get_description() -> String:
	return gear_description

func get_effects() -> Array[Dictionary]:
	return gear_effects

func get_traits() -> Array[String]:
	return gear_traits

func has_trait(trait_name: String) -> bool:
	return gear_traits.has(trait_name)

func get_cost() -> int:
	return gear_cost.get("credits", 0)

func get_rarity() -> String:
	return gear_cost.get("rarity", "Common")

func get_tags() -> Array[String]:
	return gear_tags

func has_tag(tag: String) -> bool:
	return gear_tags.has(tag)

func get_requirements() -> Dictionary:
	return gear_requirements

func meets_requirements(character) -> bool:
	if gear_requirements.is_empty():
		return true
		
	# Check skill requirements
	if gear_requirements.has("skills"):
		var skill_reqs = gear_requirements.skills
		for skill_name in skill_reqs:
			var required_level = skill_reqs[skill_name]
			if character.get_skill_level(skill_name) < required_level:
				return false
	
	# Check stat requirements
	if gear_requirements.has("stats"):
		var stat_reqs = gear_requirements.stats
		for stat_name in stat_reqs:
			var required_value = stat_reqs[stat_name]
			if character.get_stat(stat_name) < required_value:
				return false
	
	# Check species requirements
	if gear_requirements.has("species"):
		var allowed_species = gear_requirements.species
		if allowed_species is Array and not allowed_species.has(character.get_species()):
			return false
	
	# Check background requirements
	if gear_requirements.has("background"):
		var allowed_backgrounds = gear_requirements.background
		if allowed_backgrounds is Array and not allowed_backgrounds.has(character.get_background()):
			return false
			
	return true

func get_gear_profile() -> Dictionary:
	return {
		"id": gear_id,
		"name": gear_name,
		"category": gear_category,
		"description": gear_description,
		"effects": gear_effects,
		"traits": gear_traits,
		"cost": gear_cost,
		"tags": gear_tags,
		"requirements": gear_requirements
	}

static func create_from_profile(profile: Dictionary) -> Resource:
	var gear = Self.new()
	gear.initialize_from_data(profile)
	return gear

func serialize() -> Dictionary:
	return get_gear_profile()

func deserialize(data: Dictionary) -> void:
	initialize_from_data(data)

func apply_effect(character, effect_index: int = 0) -> bool:
	if effect_index < 0 or effect_index >= gear_effects.size():
		return false
		
	var effect = gear_effects[effect_index]
	var effect_type = effect.get("type", "basic")
	
	match effect_type:
		"stat_boost":
			var stat = effect.get("stat", "")
			var value = effect.get("value", 0)
			
			if stat and value != 0:
				character.modify_stat(stat, value)
				return true
				
		"skill_boost":
			var skill = effect.get("skill", "")
			var value = effect.get("value", 0)
			
			if skill and value != 0:
				character.modify_skill(skill, value)
				return true
				
		"special_ability":
			var ability = effect.get("ability", "")
			
			if ability:
				character.add_special_ability(ability)
				return true
				
		"environmental_protection":
			var protection_type = effect.get("protection_type", "")
			
			if protection_type:
				character.add_environmental_protection(protection_type)
				return true
				
		_: # Basic effect or unknown type
			# Just apply the gear without a specific effect
			return true
			
	return false

func get_value() -> int:
	var value := 15 # Base value
	
	# Add value based on rarity
	match get_rarity():
		"Common":
			value += 0
		"Uncommon":
			value += 25
		"Rare":
			value += 60
		"Very Rare":
			value += 120
		"Legendary":
			value += 250
	
	# Add value for effects
	value += gear_effects.size() * 20
	
	# Add value for traits
	value += gear_traits.size() * 15
	
	return value