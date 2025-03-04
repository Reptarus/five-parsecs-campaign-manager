@tool
extends Resource
class_name GameArmor

# Import necessary classes
const GameDataManager = preload("res://src/core/managers/GameDataManager.gd")

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var armor_id: String = ""
@export var armor_name: String = ""
@export var armor_category: String = ""
@export var armor_description: String = ""
@export var armor_save: int = 0
@export var armor_encumbrance: int = 0
@export var armor_coverage: Array[String] = []
@export var armor_traits: Array[String] = []
@export var armor_special_rules: Array[Dictionary] = []
@export var armor_cost: Dictionary = {"credits": 0, "rarity": "Common"}
@export var armor_tags: Array[String] = []

var _data_manager: GameDataManager = null

func _init() -> void:
	if Engine.is_editor_hint():
		return
		
	# Create the data manager instance if needed
	if _data_manager == null:
		_data_manager = GameDataManager.new()
		_data_manager.load_armor_database()

func initialize_from_id(id: String) -> bool:
	if _data_manager == null:
		_data_manager = GameDataManager.new()
		_data_manager.load_armor_database()
		
	var armor_data = _data_manager.get_armor(id)
	if armor_data.is_empty():
		push_error("Failed to find armor with ID: " + id)
		return false
		
	return initialize_from_data(armor_data)

func initialize_from_data(data: Dictionary) -> bool:
	if data.is_empty():
		return false
		
	armor_id = data.get("id", "")
	armor_name = data.get("name", "")
	armor_category = data.get("category", "")
	armor_description = data.get("description", "")
	armor_save = data.get("armor_save", 0)
	armor_encumbrance = data.get("encumbrance", 0)
	
	# Handle coverage
	if data.has("coverage") and data.coverage is Array:
		armor_coverage = data.coverage
	else:
		armor_coverage = []
		
		# If there's a single coverage area, convert it to our format
		if data.has("covers"):
			var covers = data.get("covers", "")
			if covers is String and not covers.is_empty():
				armor_coverage = covers.split(",")
	
	# Handle traits
	if data.has("traits") and data.traits is Array:
		armor_traits = data.traits
	else:
		armor_traits = []
	
	# Handle special rules
	if data.has("special_rules") and data.special_rules is Array:
		armor_special_rules = data.special_rules
	else:
		armor_special_rules = []
		
		# If there's a single special rule, convert it to our format
		if data.has("special_rule"):
			armor_special_rules.append({
				"name": data.get("special_rule", ""),
				"description": data.get("special_rule_description", ""),
				"effect": data.get("special_rule_effect", {})
			})
	
	# Handle cost data
	if data.has("cost") and data.cost is Dictionary:
		armor_cost = data.cost
	else:
		armor_cost = {"credits": data.get("cost", 0), "rarity": data.get("rarity", "Common")}
	
	armor_tags = data.get("tags", [])
	
	return true

func get_id() -> String:
	return armor_id

func get_armor_name() -> String:
	return armor_name

func get_category() -> String:
	return armor_category

func get_description() -> String:
	return armor_description

func get_armor_save() -> int:
	return armor_save

func get_encumbrance() -> int:
	return armor_encumbrance

func get_coverage() -> Array[String]:
	return armor_coverage

func covers_location(location: String) -> bool:
	return armor_coverage.has(location)

func get_traits() -> Array[String]:
	return armor_traits

func has_trait(trait_name: String) -> bool:
	return armor_traits.has(trait_name)

func get_special_rules() -> Array[Dictionary]:
	return armor_special_rules

func get_cost() -> int:
	return armor_cost.get("credits", 0)

func get_rarity() -> String:
	return armor_cost.get("rarity", "Common")

func get_tags() -> Array[String]:
	return armor_tags

func has_tag(tag: String) -> bool:
	return armor_tags.has(tag)

func is_sealed() -> bool:
	return has_trait("Sealed")

func is_powered() -> bool:
	return has_trait("Powered")

func is_shield() -> bool:
	return armor_category == "shield"

func is_specialized() -> bool:
	return armor_category == "specialized"

func get_armor_profile() -> Dictionary:
	return {
		"id": armor_id,
		"name": armor_name,
		"category": armor_category,
		"description": armor_description,
		"armor_save": armor_save,
		"encumbrance": armor_encumbrance,
		"coverage": armor_coverage,
		"traits": armor_traits,
		"special_rules": armor_special_rules,
		"cost": armor_cost,
		"tags": armor_tags
	}

static func create_from_profile(profile: Dictionary) -> GameArmor:
	var armor = GameArmor.new()
	armor.initialize_from_data(profile)
	return armor

func serialize() -> Dictionary:
	return get_armor_profile()

func deserialize(data: Dictionary) -> void:
	initialize_from_data(data)

func apply_effects(character) -> void:
	# Apply any special effects from the armor
	for rule in armor_special_rules:
		var effect = rule.get("effect", {})
		var effect_type = effect.get("type", "")
		
		match effect_type:
			"stat_boost":
				var stat = effect.get("stat", "")
				var value = effect.get("value", 0)
				
				if stat and value != 0:
					character.modify_stat(stat, value)
					
			"skill_boost":
				var skill = effect.get("skill", "")
				var value = effect.get("value", 0)
				
				if skill and value != 0:
					character.modify_skill(skill, value)
					
			"environmental_protection":
				var protection_type = effect.get("protection_type", "")
				
				if protection_type:
					character.add_environmental_protection(protection_type)
					
			"special_ability":
				var ability = effect.get("ability", "")
				
				if ability:
					character.add_special_ability(ability)

func remove_effects(character) -> void:
	# Remove any special effects from the armor
	for rule in armor_special_rules:
		var effect = rule.get("effect", {})
		var effect_type = effect.get("type", "")
		
		match effect_type:
			"stat_boost":
				var stat = effect.get("stat", "")
				var value = effect.get("value", 0)
				
				if stat and value != 0:
					character.modify_stat(stat, - value)
					
			"skill_boost":
				var skill = effect.get("skill", "")
				var value = effect.get("value", 0)
				
				if skill and value != 0:
					character.modify_skill(skill, - value)
					
			"environmental_protection":
				var protection_type = effect.get("protection_type", "")
				
				if protection_type:
					character.remove_environmental_protection(protection_type)
					
			"special_ability":
				var ability = effect.get("ability", "")
				
				if ability:
					character.remove_special_ability(ability)

func can_equip(character) -> bool:
	# Check if the character meets any requirements for this armor
	# Check if the armor is too heavy
	if has_trait("Heavy") and not character.has_trait("Strong"):
		return false
		
	# Check if the armor requires special training
	if has_trait("Complex") and not character.has_skill("Armor Training"):
		return false
		
	# Check if powered armor requires power armor training
	if is_powered() and not character.has_skill("Power Armor Training"):
		return false
		
	return true

func get_protection_value() -> int:
	var value := armor_save * 10
	
	# Adjust for coverage
	value += armor_coverage.size() * 5
	
	# Adjust for encumbrance (negative)
	value -= armor_encumbrance * 3
	
	# Adjust for traits
	for trait_name in armor_traits:
		match trait_name:
			"Sealed":
				value += 15
			"Lightweight":
				value += 10
			"Heavy":
				value += 5
			"Powered":
				value += 20
			"Strength Enhancing":
				value += 15
			"Stealth":
				value += 10
			"Thermal Regulating":
				value += 8
			"Radiation Resistant":
				value += 12
			"Psionic Dampening":
				value += 15
			"Reactive":
				value += 18
			"Ablative":
				value += 8
			"Integrated HUD":
				value += 10
			"Camouflage":
				value += 7
			"Reinforced":
				value += 12
	
	return value