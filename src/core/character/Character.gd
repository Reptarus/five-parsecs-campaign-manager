extends Resource
class_name Character
"""
Consolidated character system following Framework Bible principles.
Replaces CharacterManager with direct static methods and resource-based state.

This consolidation eliminates Manager pattern violations while maintaining all functionality.
All character generation logic now lives here instead of scattered across 15+ files.
"""

# Character Attributes
@export var name: String = ""

# Smart properties with migration validation and performance tracking
var _background: String = ""
var _motivation: String = ""
var _origin: String = ""
var _character_class: String = ""

# Performance optimization: Cache GlobalEnums singleton reference
var _cached_global_enums = null

@export var background: String:
	get:
		return _background
	set(value):
		_background = _get_validated_enum_string(value, "background", "COLONIST")

@export var motivation: String:
	get:
		return _motivation
	set(value):
		_motivation = _get_validated_enum_string(value, "motivation", "SURVIVAL")

@export var origin: String:
	get:
		return _origin
	set(value):
		_origin = _get_validated_enum_string(value, "origin", "HUMAN")

@export var character_class: String:
	get:
		return _character_class
	set(value):
		_character_class = _get_validated_enum_string(value, "character_class", "BASELINE")

# Helper method for validated enum string conversion
func _get_validated_enum_string(value: Variant, enum_type: String, default: String) -> String:
	"""Production-safe enum validation with defensive GlobalEnums access"""
	# Try cached reference first (fastest path)
	if _cached_global_enums != null:
		if _cached_global_enums.has_method("to_string_value"):
			return _cached_global_enums.to_string_value(enum_type, value)
	
	# Try runtime autoload access (works when game is running)
	if Engine.has_singleton("GlobalEnums"):
		_cached_global_enums = Engine.get_singleton("GlobalEnums")
		if _cached_global_enums and _cached_global_enums.has_method("to_string_value"):
			return _cached_global_enums.to_string_value(enum_type, value)
	
	# Fallback for development/testing
	return value if value is String else default

# Initialize smart properties with validated defaults
func _init():
	_background = "COLONIST"
	_motivation = "SURVIVAL"
	_origin = "HUMAN"
	_character_class = "BASELINE"

# Compatibility property for character_name (many files use this)
var character_name: String:
	get:
		return name
	set(value):
		name = value

# Core Stats  
@export var combat: int = 0
@export var reactions: int = 0
@export var toughness: int = 0
@export var savvy: int = 0
@export var tech: int = 0
@export var move: int = 0
@export var speed: int = 4  # Movement speed in grid units
@export var luck: int = 0    # Luck modifier for rolls

# Character State
@export var experience: int = 0
@export var credits: int = 0
@export var equipment: Array[String] = []
@export var is_captain: bool = false
@export var created_at: String = ""

# Character Generation - Direct static methods replace CharacterManager
static func generate_character(background_type: String = "") -> Character:
	"""Production-ready character generation with comprehensive validation"""
	var character = Character.new()
	
	# Safe random generation using Framework Bible patterns
	character.name = _generate_name()
	character.background = background_type if not background_type.is_empty() else _generate_background()
	character.motivation = _generate_motivation()
	
	# Generate stats with proper bounds checking
	character.combat = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 1)
	character.reactions = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 1)
	character.toughness = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 1)
	character.savvy = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 1)
	character.tech = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 1)
	character.move = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 1)
	character.speed = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 4)
	character.luck = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 0)
	
	# Initial equipment and state
	character.credits = SafeTypeConverter.safe_int(_roll_dice_safe(2, 6) * 10, 20)
	character.equipment = _generate_starting_equipment(character.background)
	character.created_at = Time.get_datetime_string_from_system()
	
	print("Character generated: %s (%s)" % [character.name, character.background])
	return character

static func generate_crew_members(count: int) -> Array[Character]:
	"""Generate multiple crew members for initial crew creation"""
	var crew: Array[Character] = []
	count = SafeTypeConverter.safe_int(count, 4)  # Default to 4 crew members
	
	for i in range(count):
		var member = generate_character()
		crew.append(member)
	
	return crew

static func create_captain_from_crew(crew_member: Character) -> Character:
	"""Promote crew member to captain with appropriate bonuses"""
	if crew_member == null:
		push_error("Cannot create captain from null crew member")
		return generate_character()  # Fallback
	
	crew_member.is_captain = true
	# Captain gets slight stat bonus
	crew_member.combat = min(crew_member.combat + 1, 6)
	crew_member.reactions = min(crew_member.reactions + 1, 6)
	
	print("Captain created: %s" % crew_member.name)
	return crew_member

# Safe dice rolling with fallback for headless mode
static func _roll_dice_safe(num_dice: int, sides: int) -> int:
	"""Safe dice rolling with DiceManager fallback"""
	if Engine.has_singleton("DiceManager"):
		var dice_manager = Engine.get_singleton("DiceManager")
		if dice_manager and dice_manager.has_method("roll_dice"):
			return dice_manager.roll_dice(num_dice, sides)
	
	# Fallback for headless mode or missing DiceManager
	var total = 0
	for i in range(num_dice):
		total += randi_range(1, sides)
	return total

# Private generation methods - all logic consolidated here
static func _generate_name(existing_names: Array = []) -> String:
	# Expanded first names (30 names) - diverse, sci-fi appropriate
	var first_names = [
		# Original 8
		"Alex", "Morgan", "River", "Casey", "Taylor", "Jordan", "Avery", "Riley",
		# Added 22 more diverse names
		"Sam", "Blake", "Quinn", "Drew", "Kai", "Nova", "Zara", "Rex",
		"Sky", "Vale", "Ash", "Sage", "Jax", "Luna", "Max", "Rae",
		"Phoenix", "Storm", "Ember", "Finn", "Iris", "Leo", "Mira", "Orion",
		"Piper", "Raven", "Soren", "Tara", "Vega", "Winter"
	]
	
	# Expanded last names (50 names) - using Five Parsecs JSON data
	var last_names = [
		# Original 8
		"Smith", "Chen", "Garcia", "Okafor", "Johansson", "Singh", "Kowalski", "Martinez",
		# From colony names (NameGenerationTables.json)
		"Ingram", "Larsen", "Greenway", "Mustaine", "Kevill", "Duplantier", 
		"Sattler", "Hetfield", "Friden", "Ryan", "Gossow", "Parkes", "Hegg",
		"Dickinson", "Shelton", "Scalzi", "Lindberg", "Willet", "Halford",
		"Baker", "Lee", "Cavalera", "Plant", "Nasic", "Bryntse",
		# From world names (NameGenerationTables.json) 
		"Samsonov", "Foch", "Pershing", "Cadorna", "Monash", "Mackensen",
		"Falkenhayn", "Byng", "Lanrezac", "Allenby", "Gough", "Currie",
		"Danilov", "Joffre", "Petain", "Brusilov", "Fuller", "Birdwood"
	]
	
	# Try to generate unique name (up to 20 attempts)
	var attempts = 0
	var name = ""
	
	while attempts < 20:
		var first = SafeTypeConverter.safe_array_get(first_names, randi() % first_names.size(), "Unknown")
		var last = SafeTypeConverter.safe_array_get(last_names, randi() % last_names.size(), "Spacer")
		name = "%s %s" % [first, last]
		
		# Check if name is unique
		if not name in existing_names:
			return name
		
		attempts += 1
	
	# Fallback: add number suffix if still duplicate after 20 attempts
	return name + " " + str(randi() % 100 + 1)

static func _generate_background() -> String:
	var backgrounds = ["Military", "Trader", "Explorer", "Engineer", "Medic", "Pilot", "Criminal", "Scholar"]
	return SafeTypeConverter.safe_array_get(backgrounds, randi() % backgrounds.size(), "Civilian")

static func _generate_motivation() -> String:
	var motivations = ["Wealth", "Fame", "Revenge", "Family", "Adventure", "Knowledge", "Justice", "Survival"]
	return SafeTypeConverter.safe_array_get(motivations, randi() % motivations.size(), "Unknown")

static func _generate_starting_equipment(background: String) -> Array[String]:
	"""Generate starting equipment based on character background"""
	var equipment: Array[String] = []
	
	# Base equipment for all characters
	equipment.append("Basic Kit")
	equipment.append("Clothing")
	
	# Background-specific equipment
	match background:
		"Military":
			equipment.append("Combat Rifle")
			equipment.append("Body Armor")
		"Trader":
			equipment.append("Hand Weapon")
			equipment.append("Trade Goods")
		"Engineer":
			equipment.append("Tool Kit")
			equipment.append("Repair Kit")
		"Medic":
			equipment.append("Medical Kit")
			equipment.append("Stimms")
		"Pilot":
			equipment.append("Hand Weapon")
			equipment.append("Navigation Kit")
		_:
			equipment.append("Hand Weapon")
			equipment.append("Basic Gear")
	
	return equipment

# Validation methods
func is_valid() -> bool:
	"""Validate character data integrity"""
	return not name.is_empty() and combat > 0 and reactions > 0 and toughness > 0

func get_display_name() -> String:
	"""Safe display name with fallback"""
	return name if not name.is_empty() else "Unnamed Character"

func get_total_stats() -> int:
	"""Calculate total stat value for balance checking"""
	return combat + reactions + toughness + savvy + tech + move

# ========== COMPREHENSIVE COMPATIBILITY LAYER ==========
# These methods provide compatibility for FiveParsecsCharacterGeneration calls
# Found in: CharacterCreator.gd, CharacterCustomizationScreen.gd, etc.

# Enhanced generation method - supports all creation modes
static func generate_character_enhanced(config: Dictionary = {}) -> Character:
	"""Enhanced character generation with full configuration support"""
	var character = Character.new()
	
	# Extract config safely using SafeTypeConverter
	var mode = SafeTypeConverter.safe_string(config.get("creation_mode", ""), "standard")
	var background = SafeTypeConverter.safe_string(config.get("background", ""), "")
	var name_override = SafeTypeConverter.safe_string(config.get("name", ""), "")
	var existing_names = config.get("existing_names", []) if config.get("existing_names") is Array else []
	
	# Generate using Five Parsecs formula (2d6/3 rounded up)
	character.reactions = ceili(randf_range(2, 12) / 3.0)
	character.combat = ceili(randf_range(2, 12) / 3.0)
	character.toughness = ceili(randf_range(2, 12) / 3.0)
	character.savvy = ceili(randf_range(2, 12) / 3.0)
	character.tech = ceili(randf_range(2, 12) / 3.0)
	character.move = ceili(randf_range(2, 12) / 3.0)
	character.speed = ceili(randf_range(2, 12) / 3.0)
	character.luck = randi_range(0, 2)  # Five Parsecs starting luck: 0-2
	
	# Apply mode-specific bonuses
	if mode == "captain":
		character.is_captain = true
		character.combat += 1
		character.reactions += 1
	elif mode == "veteran":
		character.experience = 10
		character.combat += 1
	
	# Set identity
	character.name = name_override if not name_override.is_empty() else _generate_name(existing_names)
	character.background = background if not background.is_empty() else _generate_background()
	character.motivation = _generate_motivation()
	character.credits = SafeTypeConverter.safe_int(config.get("credits", 0), randi_range(20, 120))
	character.created_at = Time.get_datetime_string_from_system()
	
	return character

# Compatibility methods for gradual migration
static func generate_complete_character(config: Dictionary = {}) -> Character:
	"""Compatibility: FiveParsecsCharacterGeneration.generate_complete_character()"""
	push_warning("Deprecated: Use Character.generate_character_enhanced() instead")
	return generate_character_enhanced(config)

static func create_character(config: Dictionary = {}) -> Character:
	"""Compatibility: FiveParsecsCharacterGeneration.create_character()"""
	push_warning("Deprecated: Use Character.generate_character_enhanced() instead") 
	return generate_character_enhanced(config)

static func generate_random_character() -> Character:
	"""Compatibility: Random character generation"""
	return generate_character_enhanced({"creation_mode": "random"})

# Character modification methods - found in CharacterCreator.gd
static func generate_character_attributes(character: Character) -> void:
	"""Compatibility: Regenerate character attributes using Five Parsecs formula"""
	if character:
		character.reactions = ceili(randf_range(2, 12) / 3.0)
		character.combat = ceili(randf_range(2, 12) / 3.0) 
		character.toughness = ceili(randf_range(2, 12) / 3.0)
		character.savvy = ceili(randf_range(2, 12) / 3.0)
		character.tech = ceili(randf_range(2, 12) / 3.0)
		character.move = ceili(randf_range(2, 12) / 3.0)
		character.speed = ceili(randf_range(2, 12) / 3.0)
		character.luck = randi_range(0, 2)

static func apply_background_bonuses(character: Character) -> void:
	"""Compatibility: Apply background-specific stat bonuses"""
	if not character:
		return
	
	match character.background:
		"MILITARY":
			character.combat += 1
			character.toughness += 1
		"TRADER":
			character.savvy += 1
			character.tech += 1
		"ENGINEER":
			character.tech += 2
		"MEDIC":
			character.savvy += 1
			character.toughness += 1
		"PILOT":
			character.reactions += 1
			character.move += 1
		"SCHOLAR":
			character.savvy += 2
		"CRIMINAL":
			character.reactions += 1
			character.combat += 1
		_:
			# Generic background bonus
			character.combat += 1

static func apply_class_bonuses(character: Character) -> void:
	"""Compatibility: Apply character class bonuses"""
	if not character:
		return
	# Minimal implementation for emergency fix
	character.experience += 5

static func set_character_flags(character: Character) -> void:
	"""Compatibility: Set character flags and status"""
	if not character:
		return
	# Minimal implementation - just ensure valid state
	if character.name.is_empty():
		character.name = _generate_name()

static func validate_character(character: Character) -> Dictionary:
	"""Compatibility: Character validation"""
	var result = {"valid": true, "errors": []}
	
	if not character:
		result.valid = false
		result.errors.append("Character is null")
		return result
	
	if character.name.is_empty():
		result.valid = false
		result.errors.append("Character needs a name")
	
	if character.combat <= 0 or character.reactions <= 0 or character.toughness <= 0:
		result.valid = false
		result.errors.append("Character has invalid stats")
	
	return result

static func create_enhanced_character(params: Dictionary) -> Character:
	"""Compatibility: Enhanced character creation"""
	return generate_character_enhanced(params)

# Stub methods for complex features - minimal implementation for emergency fix
static func generate_patrons(character: Character) -> Array:
	"""Compatibility: Patron generation stub"""
	if not character:
		return []
	# Return empty array for now - prevents crashes
	return []

static func generate_rivals(character: Character) -> Array:
	"""Compatibility: Rival generation stub"""
	if not character:
		return []
	# Return empty array for now - prevents crashes  
	return []

static func generate_starting_equipment_enhanced(character: Character) -> Dictionary:
	"""Compatibility: Enhanced equipment generation stub"""
	if not character:
		return {}
	# Return character's equipment as dictionary
	var equipment_dict = {}
	for i in range(character.equipment.size()):
		equipment_dict["item_%d" % i] = character.equipment[i]
	return equipment_dict

static func apply_background_effects(character: Character) -> void:
	"""Compatibility: Background effects application"""
	if not character:
		return
	# For emergency fix, just apply bonuses
	apply_background_bonuses(character)

static func apply_motivation_effects(character: Character) -> void:
	"""Compatibility: Motivation effects application"""
	if not character:
		return
	# Minimal implementation - add motivation-based credit bonus
	match character.motivation:
		"WEALTH":
			character.credits += 20
		"ADVENTURE":
			character.experience += 5
		_:
			pass

# ====================== CHARACTER PROPERTY MIGRATION HELPERS ======================
# Production-ready validation and compatibility methods for character properties

func validate_character_properties() -> Dictionary:
	"""Comprehensive validation of all character properties with detailed feedback"""
	var result = {
		"valid": true,
		"errors": [],
		"warnings": [],
		"property_status": {}
	}
	
	# Validate background with defensive GlobalEnums access
	var global_enums = null
	if Engine.has_singleton("GlobalEnums"):
		global_enums = Engine.get_singleton("GlobalEnums")
	if global_enums and global_enums.is_valid_background_string(_background):
		result.property_status["background"] = "valid"
	else:
		result.valid = false
		result.errors.append("Invalid background: %s" % _background)
		result.property_status["background"] = "invalid"
	
	# Validate motivation
	if global_enums and global_enums.is_valid_motivation_string(_motivation):
		result.property_status["motivation"] = "valid"
	else:
		result.valid = false
		result.errors.append("Invalid motivation: %s" % _motivation)
		result.property_status["motivation"] = "invalid"
	
	# Validate origin
	if global_enums and global_enums.is_valid_origin_string(_origin):
		result.property_status["origin"] = "valid"
	else:
		result.valid = false
		result.errors.append("Invalid origin: %s" % _origin)
		result.property_status["origin"] = "invalid"
	
	# Validate character class
	if global_enums and global_enums.is_valid_character_class_string(_character_class):
		result.property_status["character_class"] = "valid"
	else:
		result.valid = false
		result.errors.append("Invalid character class: %s" % _character_class)
		result.property_status["character_class"] = "invalid"
	
	# Check for empty name
	if name.is_empty():
		result.warnings.append("Character has no name")
		result.property_status["name"] = "warning"
	else:
		result.property_status["name"] = "valid"
	
	return result

func migrate_legacy_properties(legacy_data: Dictionary) -> bool:
	"""Migrate character from legacy enum-based format to string-based format"""
	var migration_successful = true
	var migration_log = []
	
	# Migrate background
	if legacy_data.has("background"):
		var old_background = legacy_data.background
		background = old_background  # This will trigger the smart setter
		migration_log.append("Background: %s -> %s" % [old_background, _background])
	
	# Migrate motivation
	if legacy_data.has("motivation"):
		var old_motivation = legacy_data.motivation
		motivation = old_motivation  # This will trigger the smart setter
		migration_log.append("Motivation: %s -> %s" % [old_motivation, _motivation])
	
	# Migrate origin
	if legacy_data.has("origin"):
		var old_origin = legacy_data.origin
		origin = old_origin  # This will trigger the smart setter
		migration_log.append("Origin: %s -> %s" % [old_origin, _origin])
	
	# Migrate character class
	if legacy_data.has("character_class"):
		var old_character_class = legacy_data.character_class
		character_class = old_character_class  # This will trigger the smart setter
		migration_log.append("Character class: %s -> %s" % [old_character_class, _character_class])
	
	# Validate after migration
	var validation = validate_character_properties()
	if not validation.valid:
		push_error("[CHARACTER] Migration validation failed: %s" % validation.errors)
		migration_successful = false
	
	if OS.is_debug_build():
		print("[CHARACTER] Migration for %s: %s" % [name, "SUCCESS" if migration_successful else "FAILED"])
		for log_entry in migration_log:
			print("  %s" % log_entry)
	
	return migration_successful

func get_property_health() -> Dictionary:
	"""Get health status of character properties for monitoring"""
	var global_enums = null
	if Engine.has_singleton("GlobalEnums"):
		global_enums = Engine.get_singleton("GlobalEnums")
	var health = {
		"status": "healthy",
		"properties": {
			"background": {"value": _background, "valid": global_enums and global_enums.is_valid_background_string(_background)},
			"motivation": {"value": _motivation, "valid": global_enums and global_enums.is_valid_motivation_string(_motivation)},
			"origin": {"value": _origin, "valid": global_enums and global_enums.is_valid_origin_string(_origin)},
			"character_class": {"value": _character_class, "valid": global_enums and global_enums.is_valid_character_class_string(_character_class)}
		},
		"character_name": name
	}
	
	# Check if any property is invalid
	for prop_name in health.properties:
		if not health.properties[prop_name].valid:
			health.status = "degraded"
			break
	
	return health

# Emergency rollback methods
func rollback_to_defaults():
	"""Emergency rollback to safe default values"""
	push_warning("[CHARACTER] Rolling back %s to default values" % name)
	
	_background = "COLONIST" 
	_motivation = "SURVIVAL"
	_origin = "HUMAN"
	_character_class = "BASELINE"
	
	print("[CHARACTER] %s rolled back to defaults" % name)

func force_property_validation():
	"""Force re-validation of all properties through smart setters"""
	var temp_background = _background
	var temp_motivation = _motivation
	var temp_origin = _origin
	var temp_character_class = _character_class
	
	# Trigger smart setters to re-validate
	background = temp_background
	motivation = temp_motivation
	origin = temp_origin
	character_class = temp_character_class
	
	print("[CHARACTER] Forced validation completed for %s" % name)

# Legacy compatibility methods for gradual migration
func get_background_enum() -> int:
	"""Get background as enum value for legacy compatibility"""
	var global_enums = null
	if Engine.has_singleton("GlobalEnums"):
		global_enums = Engine.get_singleton("GlobalEnums")
	return global_enums.from_string_value("background", _background) if global_enums else 0

func get_motivation_enum() -> int:
	"""Get motivation as enum value for legacy compatibility"""
	var global_enums = null
	if Engine.has_singleton("GlobalEnums"):
		global_enums = Engine.get_singleton("GlobalEnums")
	return global_enums.from_string_value("motivation", _motivation) if global_enums else 0

func get_origin_enum() -> int:
	"""Get origin as enum value for legacy compatibility"""
	var global_enums = null
	if Engine.has_singleton("GlobalEnums"):
		global_enums = Engine.get_singleton("GlobalEnums")
	return global_enums.from_string_value("origin", _origin) if global_enums else 0

func get_character_class_enum() -> int:
	"""Get character class as enum value for legacy compatibility"""
	var global_enums = null
	if Engine.has_singleton("GlobalEnums"):
		global_enums = Engine.get_singleton("GlobalEnums")
	return global_enums.from_string_value("character_class", _character_class) if global_enums else 0

# ====================== NATIVE SERIALIZATION METHODS ======================
# Production-ready serialization with enhanced CampaignSerializer integration

func serialize() -> Dictionary:
	"""
	Native character serialization using enhanced serialization system
	Provides full compatibility with CampaignSerializer format and migration support
	"""
	var global_enums = null
	if Engine.has_singleton("GlobalEnums"):
		global_enums = Engine.get_singleton("GlobalEnums")
	var start_time = Time.get_ticks_usec()
	
	# Use CampaignSerializer for enhanced property serialization
	var serialized_data = {
		"type": "Character", # Match CampaignSerializer.SerializationType.CHARACTER
		"version": "2.0",
		"id": get_instance_id(),
		"name": name,
		"character_name": name, # Compatibility alias
		"class_name": get_class(),
		
		# Enhanced property serialization with dual-value support
		"character_class": _serialize_enhanced_property("character_class", _character_class),
		"background": _serialize_enhanced_property("background", _background),
		"origin": _serialize_enhanced_property("origin", _origin),
		"motivation": _serialize_enhanced_property("motivation", _motivation),
		
		# Core stats
		"stats": {
			"combat": combat,
			"reactions": reactions,
			"toughness": toughness,
			"savvy": savvy,
			"tech": tech,
			"move": move
		},
		
		# Character state and progression
		"experience": experience,
		"credits": credits,
		"equipment": equipment.duplicate(),
		"is_captain": is_captain,
		"created_at": created_at,
		
		# Serialization metadata
		"serialization_timestamp": Time.get_ticks_msec(),
		"serialization_version": "enhanced_v2"
	}
	
	# Performance tracking
	var end_time = Time.get_ticks_usec()
	var duration = end_time - start_time
	
	if OS.is_debug_build() and global_enums and global_enums.MIGRATION_FLAGS.get("log_performance", false):
		print("[CHARACTER] Serialization for %s: %d μs" % [name, duration])
	
	return serialized_data

static func deserialize(data: Dictionary) -> Character:
	"""
	Native character deserialization with enhanced migration support
	Handles all legacy formats and provides automatic property migration
	"""
	if data.is_empty():
		push_error("[CHARACTER] Cannot deserialize empty data")
		return null
	
	var global_enums = null
	if Engine.has_singleton("GlobalEnums"):
		global_enums = Engine.get_singleton("GlobalEnums")
	var start_time = Time.get_ticks_usec()
	
	var character = Character.new()
	
	# Basic properties with safe fallbacks
	character.name = data.get("name", data.get("character_name", "Unknown Character"))
	
	# Enhanced property deserialization with auto-migration
	character._character_class = _deserialize_enhanced_property("character_class", data.get("character_class", data.get("class", "BASELINE")))
	character._background = _deserialize_enhanced_property("background", data.get("background", "COLONIST"))
	character._origin = _deserialize_enhanced_property("origin", data.get("origin", "HUMAN"))
	character._motivation = _deserialize_enhanced_property("motivation", data.get("motivation", "SURVIVAL"))
	
	# Stats with safe defaults
	var stats = data.get("stats", {})
	character.combat = stats.get("combat", 1)
	character.reactions = stats.get("reactions", stats.get("reaction", 1)) # Handle both formats
	character.toughness = stats.get("toughness", 3)
	character.savvy = stats.get("savvy", 1)
	character.tech = stats.get("tech", 1)
	character.move = stats.get("move", stats.get("speed", 4)) # Handle both formats
	character.speed = stats.get("speed", stats.get("move", 4)) # Handle both formats
	character.luck = stats.get("luck", 0)
	
	# Character state
	character.experience = data.get("experience", 0)
	character.credits = data.get("credits", 0)
	character.equipment = data.get("equipment", []).duplicate()
	character.is_captain = data.get("is_captain", false)
	character.created_at = data.get("created_at", Time.get_datetime_string_from_system())
	
	# Performance tracking
	var end_time = Time.get_ticks_usec()
	var duration = end_time - start_time
	
	if OS.is_debug_build() and global_enums and global_enums.MIGRATION_FLAGS.get("log_performance", false):
		print("[CHARACTER] Deserialization for %s: %d μs" % [character.name, duration])
	
	return character

# Enhanced property serialization helpers
func _serialize_enhanced_property(property_name: String, value: String) -> Dictionary:
	"""Serialize character property using enhanced format with dual values"""
	var global_enums = null
	if Engine.has_singleton("GlobalEnums"):
		global_enums = Engine.get_singleton("GlobalEnums")
	if not global_enums:
		return {"format": "raw", "value": value}
	
	var validated_int = global_enums.from_string_value(property_name, value)
	var is_valid = not value.is_empty() and value != "UNKNOWN"
	
	return {
		"format": "enhanced_v2",
		"string_value": value,
		"int_value": validated_int,
		"is_valid": is_valid,
		"property": property_name,
		"version": "2.0"
	}

static func _deserialize_enhanced_property(property_name: String, serialized_data: Variant) -> String:
	"""Deserialize character property with auto-migration from any format"""
	var global_enums = null
	if Engine.has_singleton("GlobalEnums"):
		global_enums = Engine.get_singleton("GlobalEnums")
	if not global_enums:
		# Safe defaults when GlobalEnums not available
		match property_name:
			"character_class": return "BASELINE"
			"background": return "COLONIST" 
			"origin": return "HUMAN"
			"motivation": return "SURVIVAL"
			_: return "UNKNOWN"
	
	var result = ""
	
	# Handle different formats
	if serialized_data is Dictionary:
		var format = serialized_data.get("format", "legacy")
		if format == "enhanced_v2":
			result = serialized_data.get("string_value", "")
			if result.is_empty():
				# Fallback to int value migration
				var int_val = serialized_data.get("int_value", -1)
				if int_val >= 0:
					result = global_enums.to_string_value(property_name, int_val)
		else:
			# Legacy format migration
			var old_value = serialized_data.get("value", 0)
			result = global_enums.to_string_value(property_name, old_value)
	elif serialized_data is int:
		# Direct int migration
		result = global_enums.to_string_value(property_name, serialized_data)
	elif serialized_data is String:
		# Direct string (validate)
		result = global_enums.to_string_value(property_name, serialized_data)
	
	# Final validation with safe defaults
	if result.is_empty() or result == "UNKNOWN":
		match property_name:
			"character_class": return "BASELINE"
			"background": return "COLONIST"
			"origin": return "HUMAN" 
			"motivation": return "SURVIVAL"
			_: return "UNKNOWN"
	
	return result

## FIX 2: Campaign Creation Data Initialization

func initialize_from_creation_data(creation_data: Dictionary) -> void:
	"""Initialize character from campaign creation data structure"""
	print("Character: Initializing from creation data...")
	
	# Basic character info
	name = creation_data.get("character_name", "Unknown")
	
	# Character properties using the validated enum system
	background = creation_data.get("background", "COLONIST")
	motivation = creation_data.get("motivation", "SURVIVAL") 
	origin = creation_data.get("origin", "HUMAN")
	character_class = creation_data.get("character_class", "BASELINE")
	
	# Stats if provided (using correct property names)
	reactions = creation_data.get("reactions", 4)
	speed = creation_data.get("speed", 4)
	combat = creation_data.get("combat_skill", 4)  # Map combat_skill to combat
	toughness = creation_data.get("toughness", 4)
	savvy = creation_data.get("savvy", 4)
	luck = creation_data.get("luck", 4)
	
	# Equipment if provided
	if creation_data.has("equipment"):
		equipment = creation_data.get("equipment", [])
	
	# Experience and status (health is derived from toughness in Five Parsecs)
	experience = creation_data.get("experience", 0)
	
	print("Character: Initialized %s (%s %s)" % [name, background, character_class])
