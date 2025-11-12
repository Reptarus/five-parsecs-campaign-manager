@tool
class_name CampaignSerializer
extends RefCounted

## Complete Campaign Serialization System
## Handles complex object serialization for characters, patrons, rivals, equipment
## Provides versioned save format with migration support

const CURRENT_VERSION = "1.2.0"

# Serialization type constants
enum SerializationType {
	CHARACTER,
	PATRON,
	RIVAL,
	EQUIPMENT,
	CAMPAIGN_STATE,
	VICTORY_CONDITIONS,
	WORLD_DATA
}

## Serialize complete character with all relationships and equipment
static func serialize_character(character: Character) -> Dictionary:
	if not character:
		return {}
	
	print("CampaignSerializer: Serializing character %s" % character.character_name)
	
	return {
		"type": SerializationType.CHARACTER,
		"version": CURRENT_VERSION,
		"id": character.get_instance_id(),
		"name": character.character_name,
		"class_name": character.get_class(),
		
		# Character class and background - enhanced with string values and migration compatibility
		"class": _serialize_character_property("character_class", character.character_class),
		"background": _serialize_character_property("background", character.background),
		"origin": _serialize_character_property("origin", character.origin),
		"motivation": _serialize_character_property("motivation", character.motivation),
		
		# Character attributes
		"stats": {
			"combat": character.combat,
			"reactions": character.reactions,  # Note: property name difference
			"toughness": character.toughness,
			"savvy": character.savvy,
			"tech": character.tech,
			"speed": character.speed,
			"luck": character.luck
		},
		
		# Equipment and relationships
		"equipment": _serialize_character_equipment(character),
		"patron_links": character.get_meta("patron_links", []),
		"rival_links": character.get_meta("rival_links", []),
		
		# Additional Five Parsecs data
		"personal_equipment": character.get_meta("personal_equipment", {}),
		"generated_patrons": character.get_meta("generated_patrons", []),
		"generated_rivals": character.get_meta("generated_rivals", []),
		"character_bonuses": character.get_meta("character_bonuses", {}),
		
		# Timestamps for debugging
		"created_timestamp": Time.get_ticks_msec(),
		"serialization_timestamp": Time.get_ticks_msec()
	}

## Deserialize character from dictionary
static func deserialize_character(data: Dictionary) -> Character:
	if data.is_empty() or data.get("type") != SerializationType.CHARACTER:
		push_error("CampaignSerializer: Invalid character data for deserialization")
		return null
	
	print("CampaignSerializer: Deserializing character %s" % data.get("name", "Unknown"))
	
	var character = Character.new()
	
	# Basic properties
	character.character_name = data.get("name", "Unknown")
	
	# Character properties with enhanced validation and auto-migration
	character.character_class = _deserialize_character_property("character_class", data.get("class", "SOLDIER"))
	character.background = _deserialize_character_property("background", data.get("background", "MILITARY"))
	character.origin = _deserialize_character_property("origin", data.get("origin", "HUMAN"))
	character.motivation = _deserialize_character_property("motivation", data.get("motivation", "SURVIVAL"))
	
	# Character stats
	var stats = data.get("stats", {})
	character.combat = stats.get("combat", 0)
	character.reactions = stats.get("reactions", 1)  # Note: property name mapping
	character.toughness = stats.get("toughness", 3)
	character.savvy = stats.get("savvy", 0)
	character.tech = stats.get("tech", 0)
	character.speed = stats.get("speed", 4)
	character.luck = stats.get("luck", 0)
	
	# Restore equipment
	if data.has("equipment"):
		_deserialize_character_equipment(character, data.equipment)
	
	# Restore meta data
	character.set_meta("patron_links", data.get("patron_links", []))
	character.set_meta("rival_links", data.get("rival_links", []))
	character.set_meta("personal_equipment", data.get("personal_equipment", {}))
	character.set_meta("generated_patrons", data.get("generated_patrons", []))
	character.set_meta("generated_rivals", data.get("generated_rivals", []))
	character.set_meta("character_bonuses", data.get("character_bonuses", {}))
	
	return character

## Serialize patron with all relationships
static func serialize_patron(patron: Dictionary) -> Dictionary:
	return {
		"type": SerializationType.PATRON,
		"version": CURRENT_VERSION,
		"id": patron.get("id", ""),
		"name": patron.get("name", "Unknown Patron"),
		"patron_type": patron.get("type", "Independent"),
		"reputation": patron.get("reputation", 0),
		"job_rate": patron.get("job_rate", 50),
		"linked_character_id": patron.get("linked_character_id", 0),
		"faction": patron.get("faction", ""),
		"specialization": patron.get("specialization", ""),
		"contact_method": patron.get("contact_method", "Standard"),
		"jobs_completed": patron.get("jobs_completed", 0),
		"jobs_failed": patron.get("jobs_failed", 0),
		"last_contact": patron.get("last_contact", ""),
		"serialization_timestamp": Time.get_ticks_msec()
	}

## Deserialize patron from dictionary
static func deserialize_patron(data: Dictionary) -> Dictionary:
	if data.get("type") != SerializationType.PATRON:
		push_error("CampaignSerializer: Invalid patron data")
		return {}
	
	return {
		"id": data.get("id", ""),
		"name": data.get("name", "Unknown Patron"),
		"type": data.get("patron_type", "Independent"),
		"reputation": data.get("reputation", 0),
		"job_rate": data.get("job_rate", 50),
		"linked_character_id": data.get("linked_character_id", 0),
		"faction": data.get("faction", ""),
		"specialization": data.get("specialization", ""),
		"contact_method": data.get("contact_method", "Standard"),
		"jobs_completed": data.get("jobs_completed", 0),
		"jobs_failed": data.get("jobs_failed", 0),
		"last_contact": data.get("last_contact", "")
	}

## Serialize rival with threat information
static func serialize_rival(rival: Dictionary) -> Dictionary:
	return {
		"type": SerializationType.RIVAL,
		"version": CURRENT_VERSION,
		"id": rival.get("id", ""),
		"name": rival.get("name", "Unknown Rival"),
		"rival_type": _serialize_enum_value("EnemyType", rival.get("type", 0)),
		"level": rival.get("level", 1),
		"reputation": rival.get("reputation", 0),
		"active": rival.get("active", true),
		"encounters": rival.get("encounters", 0),
		"last_seen": rival.get("last_seen", ""),
		"traits": rival.get("traits", []),
		"equipment": rival.get("equipment", []),
		"crew": rival.get("crew", []),
		"status_effects": rival.get("status_effects", []),
		"defeat_condition": rival.get("defeat_condition", ""),
		"serialization_timestamp": Time.get_ticks_msec()
	}

## Deserialize rival from dictionary  
static func deserialize_rival(data: Dictionary) -> Dictionary:
	if data.get("type") != SerializationType.RIVAL:
		push_error("CampaignSerializer: Invalid rival data")
		return {}
	
	return {
		"id": data.get("id", ""),
		"name": data.get("name", "Unknown Rival"),
		"type": _deserialize_enum_value("EnemyType", data.get("rival_type", 0)),
		"level": data.get("level", 1),
		"reputation": data.get("reputation", 0),
		"active": data.get("active", true),
		"encounters": data.get("encounters", 0),
		"last_seen": data.get("last_seen", ""),
		"traits": data.get("traits", []),
		"equipment": data.get("equipment", []),
		"crew": data.get("crew", []),
		"status_effects": data.get("status_effects", []),
		"defeat_condition": data.get("defeat_condition", "")
	}

## Serialize complete campaign state
static func serialize_campaign_state(campaign_state: Dictionary) -> Dictionary:
	print("CampaignSerializer: Serializing complete campaign state")
	
	var serialized = {
		"type": SerializationType.CAMPAIGN_STATE,
		"version": CURRENT_VERSION,
		"serialization_timestamp": Time.get_ticks_msec(),
		"crew": _serialize_crew_data(campaign_state.get("crew", {})),
		"equipment": campaign_state.get("equipment", {}),
		"ship": campaign_state.get("ship", {}),
		"world": campaign_state.get("world", {}),
		"victory_conditions": campaign_state.get("victory_conditions", {}),
		"campaign_config": campaign_state.get("campaign_config", {}),
		"phase_completion": campaign_state.get("phase_completion", {}),
		"is_complete": campaign_state.get("is_complete", false)
	}
	
	print("CampaignSerializer: Campaign state serialization complete")
	return serialized

## Deserialize complete campaign state
static func deserialize_campaign_state(data: Dictionary) -> Dictionary:
	if data.get("type") != SerializationType.CAMPAIGN_STATE:
		push_error("CampaignSerializer: Invalid campaign state data")
		return {}
	
	print("CampaignSerializer: Deserializing campaign state version %s" % data.get("version", "unknown"))
	
	var campaign_state = {
		"crew": _deserialize_crew_data(data.get("crew", {})),
		"equipment": data.get("equipment", {}),
		"ship": data.get("ship", {}),
		"world": data.get("world", {}),
		"victory_conditions": data.get("victory_conditions", {}),
		"campaign_config": data.get("campaign_config", {}),
		"phase_completion": data.get("phase_completion", {}),
		"is_complete": data.get("is_complete", false)
	}
	
	return campaign_state

## Serialize crew data with all characters, patrons, and rivals
static func _serialize_crew_data(crew_data: Dictionary) -> Dictionary:
	var serialized = {
		"members": [],
		"captain": null,
		"patrons": [],
		"rivals": [],
		"starting_equipment": crew_data.get("starting_equipment", []),
		"is_complete": crew_data.get("is_complete", false)
	}
	
	# Serialize crew members
	for member in crew_data.get("members", []):
		if member is Character:
			serialized.members.append(serialize_character(member))
		else:
			# Handle dictionary format
			serialized.members.append(member)
	
	# Serialize captain
	var captain = crew_data.get("captain")
	if captain and captain is Character:
		serialized.captain = serialize_character(captain)
	elif captain:
		serialized.captain = captain
	
	# Serialize patrons
	for patron in crew_data.get("patrons", []):
		serialized.patrons.append(serialize_patron(patron))
	
	# Serialize rivals
	for rival in crew_data.get("rivals", []):
		serialized.rivals.append(serialize_rival(rival))
	
	return serialized

## Deserialize crew data with all characters, patrons, and rivals
static func _deserialize_crew_data(crew_data: Dictionary) -> Dictionary:
	var deserialized = {
		"members": [],
		"captain": null,
		"patrons": [],
		"rivals": [],
		"starting_equipment": crew_data.get("starting_equipment", []),
		"is_complete": crew_data.get("is_complete", false)
	}
	
	# Deserialize crew members
	for member_data in crew_data.get("members", []):
		if member_data.get("type") == SerializationType.CHARACTER:
			var character = deserialize_character(member_data)
			if character:
				deserialized.members.append(character)
		else:
			# Handle raw dictionary data
			deserialized.members.append(member_data)
	
	# Deserialize captain
	var captain_data = crew_data.get("captain")
	if captain_data and captain_data.get("type") == SerializationType.CHARACTER:
		deserialized.captain = deserialize_character(captain_data)
	elif captain_data:
		deserialized.captain = captain_data
	
	# Deserialize patrons
	for patron_data in crew_data.get("patrons", []):
		deserialized.patrons.append(deserialize_patron(patron_data))
	
	# Deserialize rivals
	for rival_data in crew_data.get("rivals", []):
		deserialized.rivals.append(deserialize_rival(rival_data))
	
	return deserialized

## Helper: Serialize character equipment
static func _serialize_character_equipment(character: Character) -> Dictionary:
	var equipment = {
		"weapons": [],
		"armor": [],
		"gear": [],
		"credits": 0
	}
	
	# Extract equipment from character properties/meta
	if character.has_method("get_equipment"):
		var char_equipment = character.get_equipment()
		if char_equipment:
			equipment = char_equipment
	
	# Also check meta data
	var personal_equipment = character.get_meta("personal_equipment", {})
	if not personal_equipment.is_empty():
		for key in ["weapons", "armor", "gear", "credits"]:
			if personal_equipment.has(key):
				equipment[key] = personal_equipment[key]
	
	return equipment

## Helper: Deserialize character equipment
static func _deserialize_character_equipment(character: Character, equipment_data: Dictionary) -> void:
	if equipment_data.is_empty():
		return
	
	# Set equipment through meta data
	character.set_meta("personal_equipment", equipment_data)
	
	# Also set through character method if available
	if character.has_method("set_equipment"):
		character.set_equipment(equipment_data)

# ====================== ENHANCED CHARACTER PROPERTY SERIALIZATION ======================
# Production-ready serialization with backward compatibility and auto-migration

## Enhanced: Serialize character property with full compatibility
static func _serialize_character_property(property_name: String, value: Variant) -> Dictionary:
	"""
	Enhanced serialization supporting both old int enums and new string values
	Provides future-proof format with backward compatibility and performance tracking
	"""
	var global_enums = Engine.get_singleton("GlobalEnums") if Engine.has_singleton("GlobalEnums") else null
	if not global_enums:
		# Fallback when GlobalEnums not available
		return {
			"format": "raw",
			"value": value,
			"type": typeof(value),
			"fallback": true
		}
	
	# Performance tracking
	var start_time = Time.get_ticks_usec()
	
	# Use GlobalEnums validation system for dual-format support
	var validated_string = ""
	var validated_int = -1
	var is_valid = false
	
	match property_name:
		"character_class":
			validated_string = global_enums.to_string_value("character_class", value) 
			validated_int = global_enums.from_string_value("character_class", validated_string)
			is_valid = not validated_string.is_empty() and validated_string != "UNKNOWN"
		"background":
			validated_string = global_enums.to_string_value("background", value)
			validated_int = global_enums.from_string_value("background", validated_string)
			is_valid = not validated_string.is_empty() and validated_string != "UNKNOWN"
		"origin":
			validated_string = global_enums.to_string_value("origin", value)
			validated_int = global_enums.from_string_value("origin", validated_string)
			is_valid = not validated_string.is_empty() and validated_string != "UNKNOWN"
		"motivation":
			validated_string = global_enums.to_string_value("motivation", value)
			validated_int = global_enums.from_string_value("motivation", validated_string)
			is_valid = not validated_string.is_empty() and validated_string != "UNKNOWN"
		_:
			push_warning("CampaignSerializer: Unknown property %s, using raw serialization" % property_name)
			return {"format": "raw", "value": value, "type": typeof(value)}
	
	# Performance tracking
	var end_time = Time.get_ticks_usec()
	var duration = end_time - start_time
	
	# Log performance for monitoring
	if OS.is_debug_build() and global_enums.MIGRATION_FLAGS.get("log_performance", false):
		print("[SERIALIZER] %s serialization: %d μs" % [property_name, duration])
	
	# Return future-proof format with dual values for maximum compatibility
	return {
		"format": "enhanced_v2",
		"string_value": validated_string,
		"int_value": validated_int, 
		"is_valid": is_valid,
		"property": property_name,
		"original_value": value,
		"original_type": typeof(value),
		"serialization_time_us": duration,
		"version": "2.0"
	}

## Enhanced: Deserialize character property with auto-migration
static func _deserialize_character_property(property_name: String, serialized_data: Variant) -> String:
	"""
	Enhanced deserialization with automatic migration from old formats
	Handles legacy int values, dictionary formats, and direct string values
	Returns validated string that works with the new Character smart properties
	"""
	var global_enums = Engine.get_singleton("GlobalEnums") if Engine.has_singleton("GlobalEnums") else null
	if not global_enums:
		# Fallback when GlobalEnums not available - return safe defaults
		match property_name:
			"character_class": return "SOLDIER"
			"background": return "MILITARY" 
			"origin": return "HUMAN"
			"motivation": return "SURVIVAL"
			_: return "UNKNOWN"
	
	# Performance tracking
	var start_time = Time.get_ticks_usec()
	var result = ""
	var migration_occurred = false
	
	# Handle different serialization formats
	if serialized_data is Dictionary:
		var format = serialized_data.get("format", "legacy")
		match format:
			"enhanced_v2":
				# Latest format - prefer string value
				result = serialized_data.get("string_value", "")
				if result.is_empty() or result == "UNKNOWN":
					# Fallback to int value and convert
					var int_val = serialized_data.get("int_value", -1)
					if int_val >= 0:
						result = global_enums.to_string_value(property_name, int_val)
						migration_occurred = true
			"legacy", "raw", _:
				# Old formats - extract value and convert
				var old_value = serialized_data.get("value", 0)
				result = global_enums.to_string_value(property_name, old_value)
				migration_occurred = true
	elif serialized_data is int:
		# Direct integer value (legacy saves)
		result = global_enums.to_string_value(property_name, serialized_data)
		migration_occurred = true
	elif serialized_data is String:
		# Direct string value (validate it)
		result = global_enums.to_string_value(property_name, serialized_data)
	else:
		# Unknown format - use safe default
		push_warning("CampaignSerializer: Unknown format for %s: %s" % [property_name, serialized_data])
		match property_name:
			"character_class": result = "SOLDIER"
			"background": result = "MILITARY"
			"origin": result = "HUMAN"
			"motivation": result = "SURVIVAL"
			_: result = "UNKNOWN"
		migration_occurred = true
	
	# Final validation
	if result.is_empty() or result == "UNKNOWN":
		match property_name:
			"character_class": result = "SOLDIER"
			"background": result = "MILITARY"
			"origin": result = "HUMAN"
			"motivation": result = "SURVIVAL"
			_: result = "UNKNOWN"
		migration_occurred = true
	
	# Performance tracking
	var end_time = Time.get_ticks_usec()
	var duration = end_time - start_time
	
	# Log performance and migration events
	if OS.is_debug_build():
		if global_enums.MIGRATION_FLAGS.get("log_performance", false):
			print("[SERIALIZER] %s deserialization: %d μs" % [property_name, duration])
		if migration_occurred and global_enums.MIGRATION_FLAGS.get("log_migrations", false):
			print("[SERIALIZER] Migrated %s: %s -> %s" % [property_name, serialized_data, result])
	
	return result

## Helper: Serialize enum value with name lookup
static func _serialize_enum_value(enum_name: String, value: int) -> Dictionary:
	var global_enums = AutoloadManager.get_autoload_safe("GlobalEnums")
	if not global_enums:
		return {"value": value, "name": "UNKNOWN"}
	
	# Check if the enum exists as a property/constant on GlobalEnums
	if not global_enums.has(enum_name):
		return {"value": value, "name": "UNKNOWN"}
	
	# Get the enum constant - for Node properties, just use single parameter
	var enum_dict = global_enums.get(enum_name)
	var keys = enum_dict.keys() if enum_dict is Dictionary else []
	
	if value >= 0 and value < keys.size():
		return {"value": value, "name": keys[value]}
	else:
		return {"value": value, "name": "UNKNOWN"}

## Helper: Deserialize enum value with validation
static func _deserialize_enum_value(enum_name: String, serialized_value) -> int:
	# Handle both old integer format and new dictionary format
	if serialized_value is int:
		return serialized_value
	elif serialized_value is Dictionary:
		return serialized_value.get("value", 0)
	else:
		push_warning("CampaignSerializer: Invalid enum value for %s: %s" % [enum_name, serialized_value])
		return 0

## Check if data needs migration
static func needs_migration(data: Dictionary) -> bool:
	var data_version = data.get("version", "0.0.0")
	return data_version != CURRENT_VERSION

## Migrate data from old version to current
static func migrate_data(data: Dictionary) -> Dictionary:
	var data_version = data.get("version", "0.0.0")
	
	print("CampaignSerializer: Migrating data from version %s to %s" % [data_version, CURRENT_VERSION])
	
	var migrated_data = data.duplicate(true)
	
	# Version-specific migrations
	match data_version:
		"1.0.0":
			migrated_data = _migrate_from_1_0_0(migrated_data)
		"1.1.0":
			migrated_data = _migrate_from_1_1_0(migrated_data)
		_:
			push_warning("CampaignSerializer: Unknown version %s, attempting best-effort migration" % data_version)
	
	migrated_data.version = CURRENT_VERSION
	return migrated_data

## Migration from version 1.0.0
static func _migrate_from_1_0_0(data: Dictionary) -> Dictionary:
	# Add new fields that didn't exist in 1.0.0
	if data.has("crew"):
		for member_data in data.crew.get("members", []):
			if not member_data.has("character_bonuses"):
				member_data.character_bonuses = {}
	
	return data

## Migration from version 1.1.0  
static func _migrate_from_1_1_0(data: Dictionary) -> Dictionary:
	# Add new victory conditions format
	if data.has("victory_conditions") and not data.victory_conditions.has("tracker_state"):
		data.victory_conditions.tracker_state = {}
	
	return data