extends RefCounted
class_name FiveParsecsCharacterCreationSystem

## Base Character Creation System
## Unified character creation logic without UI dependencies
## Consolidates functionality from BaseCharacterCreator, CharacterCreatorUI, and CharacterCreatorEnhanced
## Part of Phase 2B Character Creator Consolidation

# Safe imports
# GlobalEnums available as autoload singleton
const Character = preload("res://src/core/character/Character.gd")
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")
const CharacterCreationTables = preload("res://src/core/character/tables/CharacterCreationTables.gd")
const DataManager = preload("res://src/core/data/DataManager.gd")

# Character creation modes
enum CreationMode {
	STANDARD,
	CAPTAIN,
	CREW_MEMBER,
	QUICK_GENERATION,
	ENHANCED_DATA
}

# Character creation signals (to be connected by UI components)
signal character_created(character: Character)
signal character_updated(character: Character)
signal creation_cancelled()
signal validation_failed(errors: Array[String])
signal generation_completed(character: Character)

# Core character creation data
var current_character: Character = null
var original_character: Character = null # For editing mode
var current_mode: CreationMode = CreationMode.STANDARD
var is_editing_mode: bool = false
var character_equipment: Dictionary = {}

# Data system integration
var is_data_system_available: bool = false
var character_data_cache: Dictionary = {}

func _init() -> void:
	_initialize_data_system()
	current_character = Character.new()

func _initialize_data_system() -> void:
	"""Initialize data system integration"""
	if not DataManager._is_data_loaded:
		var success = DataManager.initialize_data_system()
		is_data_system_available = success
		if not success:
			push_warning("BaseCharacterCreationSystem: DataManager not available, using fallback mode")
	else:
		is_data_system_available = true
	
	if is_data_system_available:
		_cache_character_data()

func _cache_character_data() -> void:
	"""Cache character data for faster access"""
	if DataManager._character_data.has("origins"):
		character_data_cache["origins"] = DataManager._character_data["origins"]
	if DataManager._character_data.has("backgrounds"):
		character_data_cache["backgrounds"] = DataManager._character_data["backgrounds"]
	if DataManager._character_data.has("classes"):
		character_data_cache["classes"] = DataManager._character_data["classes"]
	if DataManager._character_data.has("motivations"):
		character_data_cache["motivations"] = DataManager._character_data["motivations"]

## Core Character Creation Methods

func start_creation(mode: CreationMode = CreationMode.STANDARD, existing_character: Character = null) -> Character:
	"""Start character creation with specified mode"""
	current_mode = mode
	
	if existing_character:
		# Editing mode
		is_editing_mode = true
		original_character = existing_character.duplicate() if existing_character.has_method("duplicate") else existing_character
		current_character = existing_character
	else:
		# Creation mode
		is_editing_mode = false
		current_character = Character.new()
		original_character = null
		_apply_mode_defaults()
	
	return current_character

func _apply_mode_defaults() -> void:
	"""Apply default values based on creation mode"""
	match current_mode:
		CreationMode.CAPTAIN:
			current_character.character_name = "Captain"
			# Apply captain-specific defaults if available
		CreationMode.CREW_MEMBER:
			current_character.character_name = "Crew Member"
			# Apply crew member defaults
		CreationMode.QUICK_GENERATION:
			generate_random_character()
		CreationMode.ENHANCED_DATA:
			# Use enhanced data features if available
			if is_data_system_available:
				_apply_enhanced_defaults()

func _apply_enhanced_defaults() -> void:
	"""Apply enhanced defaults using data system"""
	# Set default values from JSON data if available
	var origins_data = character_data_cache.get("origins", {})
	if not origins_data.is_empty():
		var first_origin_key = origins_data.keys()[0]
		var origin_enum_id = GlobalEnums.Origin.get(first_origin_key, GlobalEnums.Origin.HUMAN)
		current_character.origin = origin_enum_id

## Character Generation Methods

func generate_random_character() -> Character:
	"""Generate a random character using Five Parsecs rules"""
	current_character = FiveParsecsCharacterGeneration.generate_random_character()
	
	if not current_character:
		# Fallback character creation
		current_character = _create_fallback_character()
	
	generation_completed.emit(current_character)
	return current_character

func _create_fallback_character() -> Character:
	"""Create a basic fallback character when generation fails"""
	var character = Character.new()
	
	character.character_name = _generate_fallback_name()
	character.origin = GlobalEnums.Origin.HUMAN
	character.background = GlobalEnums.Background.MILITARY
	character.character_class = GlobalEnums.CharacterClass.SOLDIER
	character.motivation = GlobalEnums.Motivation.SURVIVAL
	
	# Generate Five Parsecs attributes (2d6/3 rounded up)
	character.reaction = _generate_five_parsecs_attribute()
	character.combat = _generate_five_parsecs_attribute()
	character.toughness = _generate_five_parsecs_attribute()
	character.savvy = _generate_five_parsecs_attribute()
	character.tech = _generate_five_parsecs_attribute()
	character.speed = _generate_five_parsecs_attribute()
	character.luck = 1
	
	# Set health based on toughness (Five Parsecs rules)
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	return character

func _generate_five_parsecs_attribute() -> int:
	"""Generate Five Parsecs attribute (2d6/3 rounded up)"""
	var roll = (randi() % 6 + 1) + (randi() % 6 + 1) # 2d6
	return int(ceil(float(roll) / 3.0))

func _generate_fallback_name() -> String:
	"""Generate a simple fallback name"""
	var first_names = ["Alex", "Jordan", "Morgan", "Casey", "Riley", "Sam", "Avery", "Quinn"]
	var last_names = ["Steel", "Cross", "Vale", "Stone", "Reed", "Storm", "Blake", "Swift"]
	
	var first = first_names[randi() % first_names.size()]
	var last = last_names[randi() % last_names.size()]
	return first + " " + last

## Data Access Methods (for UI components)

func get_available_origins() -> Array[Dictionary]:
	"""Get all available origins with rich data"""
	var origins: Array[Dictionary] = []
	
	if is_data_system_available and character_data_cache.has("origins"):
		var origins_data = character_data_cache["origins"]
		for origin_key in origins_data.keys():
			var enum_id = GlobalEnums.Origin.get(origin_key, -1)
			if enum_id == -1:
				continue
			
			var origin_data = origins_data[origin_key]
			origins.append({
				"id": enum_id,
				"key": origin_key,
				"name": origin_data.get("name", origin_key.capitalize()),
				"description": origin_data.get("description", ""),
				"traits": origin_data.get("traits", [])
			})
	else:
		# Fallback to enum-only data
		for origin_name in GlobalEnums.Origin.keys():
			var enum_id = GlobalEnums.Origin[origin_name]
			origins.append({
				"id": enum_id,
				"key": origin_name.to_lower(),
				"name": origin_name.capitalize().replace("_", " "),
				"description": "",
				"traits": []
			})
	
	return origins

func get_available_backgrounds() -> Array[Dictionary]:
	"""Get all available backgrounds with rich data"""
	var backgrounds: Array[Dictionary] = []
	
	if is_data_system_available and character_data_cache.has("backgrounds"):
		var backgrounds_data = character_data_cache["backgrounds"]
		for background_key in backgrounds_data.keys():
			var enum_id = GlobalEnums.Background.get(background_key, -1)
			if enum_id == -1:
				continue
			
			var background_data = backgrounds_data[background_key]
			backgrounds.append({
				"id": enum_id,
				"key": background_key,
				"name": background_data.get("name", background_key.capitalize()),
				"description": background_data.get("description", ""),
				"traits": background_data.get("traits", [])
			})
	else:
		# Fallback to enum-only data
		for background_name in GlobalEnums.Background.keys():
			var enum_id = GlobalEnums.Background[background_name]
			backgrounds.append({
				"id": enum_id,
				"key": background_name.to_lower(),
				"name": background_name.capitalize().replace("_", " "),
				"description": "",
				"traits": []
			})
	
	return backgrounds

func get_available_classes() -> Array[Dictionary]:
	"""Get all available character classes with rich data"""
	var classes: Array[Dictionary] = []
	
	if is_data_system_available and character_data_cache.has("classes"):
		var classes_data = character_data_cache["classes"]
		for class_key in classes_data.keys():
			var enum_id = GlobalEnums.CharacterClass.get(class_key, -1)
			if enum_id == -1:
				continue
			
			var class_data = classes_data[class_key]
			classes.append({
				"id": enum_id,
				"key": class_key,
				"name": class_data.get("name", class_key.capitalize()),
				"description": class_data.get("description", ""),
				"traits": class_data.get("traits", [])
			})
	else:
		# Fallback to hardcoded class data
		var fallback_classes = [
			{"id": 1, "key": "soldier", "name": "Soldier", "description": "Military trained combat specialist", "traits": []},
			{"id": 2, "key": "scout", "name": "Scout", "description": "Reconnaissance and stealth specialist", "traits": []},
			{"id": 3, "key": "medic", "name": "Medic", "description": "Medical and healing specialist", "traits": []},
			{"id": 4, "key": "engineer", "name": "Engineer", "description": "Technical and repair specialist", "traits": []},
			{"id": 5, "key": "pilot", "name": "Pilot", "description": "Vehicle and starship pilot", "traits": []},
			{"id": 6, "key": "merchant", "name": "Merchant", "description": "Trade and commerce specialist", "traits": []},
			{"id": 7, "key": "security", "name": "Security", "description": "Protection and defense specialist", "traits": []},
			{"id": 8, "key": "broker", "name": "Broker", "description": "Information and negotiation specialist", "traits": []},
			{"id": 9, "key": "bot_tech", "name": "Bot Tech", "description": "Robot and automation specialist", "traits": []},
			{"id": 10, "key": "rogue", "name": "Rogue", "description": "Stealth and infiltration specialist", "traits": []},
			{"id": 11, "key": "psionicist", "name": "Psionicist", "description": "Mental and psychic specialist", "traits": []},
			{"id": 12, "key": "tech", "name": "Tech", "description": "Technology and hacking specialist", "traits": []},
			{"id": 13, "key": "brute", "name": "Brute", "description": "Physical combat specialist", "traits": []},
			{"id": 14, "key": "gunslinger", "name": "Gunslinger", "description": "Ranged combat specialist", "traits": []},
			{"id": 15, "key": "academic", "name": "Academic", "description": "Knowledge and research specialist", "traits": []}
		]
		classes = fallback_classes
	
	return classes

func get_available_motivations() -> Array[Dictionary]:
	"""Get all available motivations with rich data"""
	var motivations: Array[Dictionary] = []
	
	if is_data_system_available and character_data_cache.has("motivations"):
		var motivations_data = character_data_cache["motivations"]
		for motivation_key in motivations_data.keys():
			var enum_id = GlobalEnums.Motivation.get(motivation_key, -1)
			if enum_id == -1:
				continue
			
			var motivation_data = motivations_data[motivation_key]
			motivations.append({
				"id": enum_id,
				"key": motivation_key,
				"name": motivation_data.get("name", motivation_key.capitalize()),
				"description": motivation_data.get("description", ""),
				"traits": motivation_data.get("traits", [])
			})
	else:
		# Fallback to hardcoded motivation data
		var fallback_motivations = [
			{"id": 1, "key": "wealth", "name": "Wealth", "description": "Driven by material gain and profit", "traits": []},
			{"id": 2, "key": "revenge", "name": "Revenge", "description": "Seeking retribution for past wrongs", "traits": []},
			{"id": 3, "key": "glory", "name": "Glory", "description": "Pursuing fame and recognition", "traits": []},
			{"id": 4, "key": "knowledge", "name": "Knowledge", "description": "Seeking understanding and discovery", "traits": []},
			{"id": 5, "key": "power", "name": "Power", "description": "Desiring control and influence", "traits": []},
			{"id": 6, "key": "justice", "name": "Justice", "description": "Fighting for what is right", "traits": []},
			{"id": 7, "key": "survival", "name": "Survival", "description": "Simply trying to stay alive", "traits": []},
			{"id": 8, "key": "loyalty", "name": "Loyalty", "description": "Devoted to a cause or person", "traits": []},
			{"id": 9, "key": "freedom", "name": "Freedom", "description": "Seeking independence and liberty", "traits": []},
			{"id": 10, "key": "discovery", "name": "Discovery", "description": "Exploring the unknown", "traits": []},
			{"id": 11, "key": "redemption", "name": "Redemption", "description": "Seeking to atone for past deeds", "traits": []},
			{"id": 12, "key": "duty", "name": "Duty", "description": "Fulfilling obligations and responsibilities", "traits": []}
		]
		motivations = fallback_motivations
	
	return motivations

## Character Validation

func validate_character(character: Character = null) -> Dictionary:
	"""Validate character data and return validation result"""
	var target_character = character if character else current_character
	if not target_character:
		return {"is_valid": false, "errors": ["No character to validate"], "warnings": []}
	
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# Validate name
	if target_character.character_name.strip_edges().is_empty():
		errors.append("Character name cannot be empty")
	
	# Validate origin (must be valid enum value)
	if target_character.origin < 0 or target_character.origin >= GlobalEnums.Origin.size():
		errors.append("Valid origin must be selected")
	
	# Validate background
	if target_character.background < 0 or target_character.background >= GlobalEnums.Background.size():
		errors.append("Valid background must be selected")
	
	# Validate character class
	if target_character.character_class < 0 or target_character.character_class >= GlobalEnums.CharacterClass.size():
		errors.append("Valid character class must be selected")
	
	# Validate stats (Five Parsecs rules)
	var stat_total = target_character.reaction + target_character.combat + target_character.toughness + target_character.savvy + target_character.tech + target_character.speed
	if stat_total < 6:
		errors.append("Character stats are too low (minimum 6 total)")
	elif stat_total > 30:
		warnings.append("Character stats are very high (over 30 total)")
	
	# Validate health based on toughness
	if target_character.max_health != target_character.toughness + 2:
		warnings.append("Health should equal Toughness + 2 per Five Parsecs rules")
	
	var is_valid = errors.is_empty()
	if not is_valid:
		validation_failed.emit(errors)
	
	return {
		"is_valid": is_valid,
		"errors": errors,
		"warnings": warnings
	}

## Character Manipulation Methods

func set_character_name(name: String) -> void:
	"""Set character name with validation"""
	if current_character:
		current_character.character_name = name.strip_edges()

func set_character_origin(origin_id: int) -> void:
	"""Set character origin with validation"""
	if current_character and origin_id >= 0 and origin_id < GlobalEnums.Origin.size():
		current_character.origin = origin_id

func set_character_background(background_id: int) -> void:
	"""Set character background with validation"""
	if current_character and background_id >= 0 and background_id < GlobalEnums.Background.size():
		current_character.background = background_id

func set_character_class(class_id: int) -> void:
	"""Set character class with validation"""
	if current_character and class_id >= 0 and class_id < GlobalEnums.CharacterClass.size():
		current_character.character_class = class_id

func set_character_motivation(motivation_id: int) -> void:
	"""Set character motivation with validation"""
	if current_character and motivation_id >= 0 and motivation_id < GlobalEnums.Motivation.size():
		current_character.motivation = motivation_id

func set_character_stat(stat_name: String, value: int) -> void:
	"""Set character stat with validation"""
	if not current_character:
		return
	
	# Clamp value to reasonable range (1-6 for Five Parsecs)
	var clamped_value = clampi(value, 1, 6)
	
	match stat_name.to_lower():
		"reaction":
			current_character.reaction = clamped_value
		"combat":
			current_character.combat = clamped_value
		"toughness":
			current_character.toughness = clamped_value
			# Update health when toughness changes
			current_character.max_health = clamped_value + 2
			current_character.health = current_character.max_health
		"savvy":
			current_character.savvy = clamped_value
		"tech":
			current_character.tech = clamped_value
		"speed":
			current_character.speed = clamped_value
		"luck":
			current_character.luck = clamped_value

## Character Finalization

func finalize_character() -> Dictionary:
	"""Finalize character creation and return result"""
	var validation = validate_character()
	
	if not validation.is_valid:
		return {
			"success": false,
			"character": null,
			"errors": validation.errors,
			"warnings": validation.warnings
		}
	
	var final_character = current_character.duplicate() if current_character.has_method("duplicate") else current_character
	
	if is_editing_mode:
		character_updated.emit(final_character)
	else:
		character_created.emit(final_character)
	
	return {
		"success": true,
		"character": final_character,
		"errors": [],
		"warnings": validation.warnings
	}

func cancel_creation() -> void:
	"""Cancel character creation and restore original if editing"""
	if is_editing_mode and original_character:
		current_character = original_character
		character_updated.emit(current_character)
	
	creation_cancelled.emit()

## Data Access Getters

func get_current_character() -> Character:
	"""Get current character being created/edited"""
	return current_character

func get_original_character() -> Character:
	"""Get original character (for editing mode)"""
	return original_character

func is_editing() -> bool:
	"""Check if in editing mode"""
	return is_editing_mode

func get_creation_mode() -> CreationMode:
	"""Get current creation mode"""
	return current_mode

func get_character_equipment() -> Dictionary:
	"""Get character equipment data"""
	return character_equipment

func set_character_equipment(equipment: Dictionary) -> void:
	"""Set character equipment data"""
	character_equipment = equipment

## System Information

func get_data_system_status() -> Dictionary:
	"""Get data system availability and status"""
	return {
		"available": is_data_system_available,
		"cached_data_types": character_data_cache.keys(),
		"fallback_mode": not is_data_system_available
	}

## Safe utility methods
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object:
		if obj.has_method("get"):
			var value = obj.get(property)
			return value if value != null else default_value
		else:
			return default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value

func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null