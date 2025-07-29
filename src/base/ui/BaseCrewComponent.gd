extends Control
class_name BaseCrewComponent

## Shared Base Component for Crew Management
## Provides common crew data handling and display logic for all crew panel implementations
## Part of the crew panel consolidation strategy

const Character = preload("res://src/core/character/Character.gd")
const DataManager = preload("res://src/core/data/DataManager.gd")
# GlobalEnums available as autoload singleton
const FiveParsecsCharacterGeneration = preload("res://src/core/character/CharacterGeneration.gd")
const SafeDataAccess = preload("res://src/utils/SafeDataAccess.gd")

# Common signals for all crew components
signal crew_updated(crew: Array)
signal crew_member_selected(member: Character)
signal crew_validation_changed(is_valid: bool, errors: Array[String])

# Common crew data
var crew_members: Array[Character] = []
var current_captain: Character = null
var is_initialized: bool = false

# Shared validation constants
const MIN_CREW_SIZE: int = 1
const MAX_CREW_SIZE: int = 8

func _ready() -> void:
	_initialize_base_component()

func _initialize_base_component() -> void:
	"""Initialize base component systems"""
	# Initialize data system if not already loaded using public API
	if not DataManager.is_system_ready():
		var success = DataManager.initialize_data_system()
		if not success:
			push_warning("BaseCrewComponent: DataManager initialization failed, using fallback mode")
	
	is_initialized = true
	print("BaseCrewComponent: Base initialization complete")

## Common Crew Data Management

func add_crew_member(character: Character) -> bool:
	"""Add a crew member with validation"""
	if not character or not is_instance_valid(character):
		push_error("BaseCrewComponent: Cannot add invalid character")
		return false
	
	if crew_members.size() >= MAX_CREW_SIZE:
		push_warning("BaseCrewComponent: Cannot add crew member - maximum size reached")
		return false
	
	# Check for duplicate names
	if _is_duplicate_name(character.character_name):
		character.character_name += " " + str(randi_range(1, 99))
		print("BaseCrewComponent: Renamed duplicate character to: ", character.character_name)
	
	crew_members.append(character)
	
	# Auto-assign first member as captain if none assigned
	if not current_captain and crew_members.size() == 1:
		_assign_captain(character)
	
	_emit_crew_updated()
	return true

func remove_crew_member(character: Character) -> bool:
	"""Remove a crew member with validation"""
	if not character or not is_instance_valid(character):
		return false
	
	var index = crew_members.find(character)
	if index == -1:
		return false
	
	crew_members.remove_at(index)
	
	# If removed character was captain, assign new captain
	if character == current_captain and crew_members.size() > 0:
		_assign_captain(crew_members[0])
	elif character == current_captain:
		current_captain = null
	
	_emit_crew_updated()
	return true

func clear_crew() -> void:
	"""Clear all crew members"""
	crew_members.clear()
	current_captain = null
	_emit_crew_updated()

func get_crew_size() -> int:
	"""Get current crew size"""
	return crew_members.size()

func get_crew_members() -> Array[Character]:
	"""Get copy of crew members array"""
	return crew_members.duplicate()

func get_captain() -> Character:
	"""Get current captain"""
	return current_captain

func set_captain(character: Character) -> bool:
	"""Set a crew member as captain"""
	if not character or not is_instance_valid(character):
		return false
	
	if not crew_members.has(character):
		push_error("BaseCrewComponent: Cannot assign captain - character not in crew")
		return false
	
	return _assign_captain(character)

## Common Crew Validation

func validate_crew() -> Dictionary:
	"""Validate crew composition and return validation result"""
	var errors: Array[String] = []
	var warnings: Array[String] = []
	
	# Check crew size
	if crew_members.is_empty():
		errors.append("At least one crew member is required")
	
	if crew_members.size() > MAX_CREW_SIZE:
		errors.append("Maximum %d crew members allowed" % MAX_CREW_SIZE)
	
	# Check captain assignment
	if not current_captain and crew_members.size() > 0:
		errors.append("A captain must be assigned")
	
	# Check for invalid characters
	for member in crew_members:
		if not is_instance_valid(member):
			errors.append("Invalid crew member found")
			break
	
	# Check for duplicate names
	var names_seen = {}
	for member in crew_members:
		var name = member.character_name if member.character_name else "Unnamed"
		if names_seen.has(name):
			warnings.append("Duplicate character names found")
			break
		names_seen[name] = true
	
	var is_valid = errors.is_empty()
	crew_validation_changed.emit(is_valid, errors)
	
	return {
		"valid": is_valid,
		"errors": errors,
		"warnings": warnings
	}

## Common Character Generation

func generate_random_character() -> Character:
	"""Generate a random character using Five Parsecs rules"""
	var character = FiveParsecsCharacterGeneration.generate_random_character()
	
	if not character:
		# Fallback character creation
		character = _create_fallback_character()
	
	print("BaseCrewComponent: Generated character: ", character.character_name if character else "Failed")
	return character

func _create_fallback_character() -> Character:
	"""Create a basic fallback character when generation fails"""
	var character = Character.new()
	
	character.character_name = _generate_fallback_name()
	character.origin = GlobalEnums.Origin.HUMAN
	character.background = GlobalEnums.Background.MILITARY
	character.character_class = GlobalEnums.CharacterClass.SOLDIER
	character.motivation = GlobalEnums.Motivation.SURVIVAL
	
	# Basic Five Parsecs attributes
	character.reaction = _generate_five_parsecs_attribute()
	character.combat = _generate_five_parsecs_attribute()
	character.toughness = _generate_five_parsecs_attribute()
	character.savvy = _generate_five_parsecs_attribute()
	character.tech = _generate_five_parsecs_attribute()
	character.speed = _generate_five_parsecs_attribute()
	character.luck = 1
	
	# Set health based on toughness
	character.max_health = character.toughness + 2
	character.health = character.max_health
	
	return character

func _generate_five_parsecs_attribute() -> int:
	"""Generate Five Parsecs attribute (2d6/3 rounded up)"""
	var roll = (randi() % 6 + 1) + (randi() % 6 + 1)  # 2d6
	return int(ceil(float(roll) / 3.0))

func _generate_fallback_name() -> String:
	"""Generate a simple fallback name"""
	var first_names = ["Alex", "Jordan", "Morgan", "Casey", "Riley", "Sam", "Avery", "Quinn"]
	var last_names = ["Steel", "Cross", "Vale", "Stone", "Reed", "Storm", "Blake", "Swift"]
	
	var first = first_names[randi() % first_names.size()]
	var last = last_names[randi() % last_names.size()]
	return first + " " + last

## Common Crew Statistics

func calculate_crew_statistics() -> Dictionary:
	"""Calculate comprehensive crew statistics"""
	if crew_members.is_empty():
		return {}
	
	var stats = {
		"total_members": crew_members.size(),
		"captain": _get_captain_summary(),
		"average_stats": {},
		"total_health": 0,
		"background_distribution": {},
		"origin_distribution": {},
		"class_distribution": {}
	}
	
	# Calculate averages and totals
	var stat_totals = {"reaction": 0, "combat": 0, "toughness": 0, "savvy": 0, "tech": 0, "speed": 0}
	
	for member in crew_members:
		# Stat totals
		stat_totals.reaction += member.reaction
		stat_totals.combat += member.combat
		stat_totals.toughness += member.toughness
		stat_totals.savvy += member.savvy
		stat_totals.tech += member.tech
		stat_totals.speed += member.speed
		
		# Health total
		stats.total_health += member.health
		
		# Distribution tracking with safe enum access
		var bg_key = "UNKNOWN"
		var origin_key = "UNKNOWN"  
		var class_key = "UNKNOWN"
		
		# Safely get background key
		if member.background >= 0 and member.background < GlobalEnums.Background.size():
			bg_key = GlobalEnums.Background.keys()[member.background]
			
		# Safely get origin key
		if member.origin >= 0 and member.origin < GlobalEnums.Origin.size():
			origin_key = GlobalEnums.Origin.keys()[member.origin]
			
		# Safely get class key
		if member.character_class >= 0 and member.character_class < GlobalEnums.CharacterClass.size():
			class_key = GlobalEnums.CharacterClass.keys()[member.character_class]
		
		stats.background_distribution[bg_key] = SafeDataAccess.safe_get(stats.background_distribution, bg_key, 0, "background distribution lookup") + 1
		stats.origin_distribution[origin_key] = SafeDataAccess.safe_get(stats.origin_distribution, origin_key, 0, "origin distribution lookup") + 1
		stats.class_distribution[class_key] = SafeDataAccess.safe_get(stats.class_distribution, class_key, 0, "class distribution lookup") + 1
	
	# Calculate averages
	var crew_size = crew_members.size()
	for stat_name in stat_totals.keys():
		stats.average_stats[stat_name] = float(stat_totals[stat_name]) / crew_size
	
	return stats

## Common Data Export/Import

func export_crew_data() -> Dictionary:
	"""Export crew data for saving"""
	var crew_data = {
		"crew_members": [],
		"captain_name": current_captain.character_name if current_captain else "",
		"crew_size": crew_members.size(),
		"creation_timestamp": Time.get_datetime_string_from_system()
	}
	
	for member in crew_members:
		if member.has_method("serialize"):
			crew_data.crew_members.append(member.serialize())
		else:
			# Fallback serialization
			crew_data.crew_members.append(_serialize_character_fallback(member))
	
	return crew_data

func import_crew_data(data: Dictionary) -> bool:
	"""Import crew data from save"""
	if data.is_empty():
		return false
	
	clear_crew()
	
	var data_dict = SafeDataAccess.safe_dict_access(data, "crew data loading")
	var crew_data = SafeDataAccess.safe_get(data_dict, "crew_members", [], "crew members lookup")
	var captain_name = SafeDataAccess.safe_get(data_dict, "captain_name", "", "captain name lookup")
	
	for member_data in crew_data:
		var character = Character.new()
		
		if character.has_method("deserialize"):
			character.deserialize(member_data)
		else:
			# Fallback deserialization
			_deserialize_character_fallback(character, member_data)
		
		add_crew_member(character)
		
		# Restore captain
		if character.character_name == captain_name:
			_assign_captain(character)
	
	return true

## Private Helper Methods

func _assign_captain(character: Character) -> bool:
	"""Internal captain assignment with title management"""
	if current_captain:
		_remove_captain_title(current_captain)
	
	current_captain = character
	_assign_captain_title(character)
	
	print("BaseCrewComponent: Assigned captain: ", character.character_name)
	return true

func _assign_captain_title(character: Character) -> void:
	"""Add captain title to character name"""
	if not character.character_name.contains("(Captain)"):
		character.character_name += " (Captain)"

func _remove_captain_title(character: Character) -> void:
	"""Remove captain title from character name"""
	character.character_name = character.character_name.replace(" (Captain)", "")

func _is_duplicate_name(name: String) -> bool:
	"""Check if character name already exists in crew"""
	for member in crew_members:
		if member.character_name == name:
			return true
	return false

func _get_captain_summary() -> Dictionary:
	"""Get captain summary for statistics"""
	if not current_captain:
		return {}
	
	# Safely get enum keys with fallbacks
	var origin_key = "UNKNOWN"
	var background_key = "UNKNOWN"
	var class_key = "UNKNOWN"
	
	if current_captain.origin >= 0 and current_captain.origin < GlobalEnums.Origin.size():
		origin_key = GlobalEnums.Origin.keys()[current_captain.origin]
		
	if current_captain.background >= 0 and current_captain.background < GlobalEnums.Background.size():
		background_key = GlobalEnums.Background.keys()[current_captain.background]
		
	if current_captain.character_class >= 0 and current_captain.character_class < GlobalEnums.CharacterClass.size():
		class_key = GlobalEnums.CharacterClass.keys()[current_captain.character_class]
	
	return {
		"name": current_captain.character_name,
		"origin": origin_key,
		"background": background_key,
		"class": class_key,
		"health": current_captain.health,
		"max_health": current_captain.max_health
	}

func _emit_crew_updated() -> void:
	"""Emit crew updated signal with validation"""
	crew_updated.emit(crew_members)
	validate_crew()  # This will emit validation_changed

func _serialize_character_fallback(character: Character) -> Dictionary:
	"""Fallback character serialization"""
	return {
		"name": character.character_name,
		"origin": character.origin,
		"background": character.background,
		"character_class": character.character_class,
		"motivation": character.motivation,
		"reaction": character.reaction,
		"combat": character.combat,
		"toughness": character.toughness,
		"savvy": character.savvy,
		"tech": character.tech,
		"speed": character.speed,
		"luck": character.luck,
		"health": character.health,
		"max_health": character.max_health
	}

func _deserialize_character_fallback(character: Character, data: Dictionary) -> void:
	"""Fallback character deserialization"""
	var character_data = SafeDataAccess.safe_dict_access(data, "character data creation")
	character.character_name = SafeDataAccess.safe_get(character_data, "name", "Unknown", "character name lookup")
	character.origin = SafeDataAccess.safe_get(character_data, "origin", GlobalEnums.Origin.HUMAN, "character origin lookup")
	character.background = SafeDataAccess.safe_get(character_data, "background", GlobalEnums.Background.MILITARY, "character background lookup")
	character.character_class = SafeDataAccess.safe_get(character_data, "character_class", GlobalEnums.CharacterClass.SOLDIER, "character class lookup")
	character.motivation = SafeDataAccess.safe_get(character_data, "motivation", GlobalEnums.Motivation.SURVIVAL, "character motivation lookup")
	character.reaction = data.get("reaction", 2)
	character.combat = data.get("combat", 1)
	character.toughness = data.get("toughness", 3)
	character.savvy = data.get("savvy", 1)
	character.tech = data.get("tech", 1)
	character.speed = data.get("speed", 4)
	character.luck = data.get("luck", 1)
	character.health = data.get("health", 5)
	character.max_health = data.get("max_health", 5)

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
