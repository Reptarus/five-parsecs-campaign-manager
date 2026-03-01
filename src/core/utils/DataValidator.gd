class_name DataValidator
extends RefCounted

## Data Structure Validation Utility
## Ensures consistent data structures across campaign creation panels
## Prevents dictionary key access violations and type mismatches

static func validate_crew_member(data: Dictionary) -> Dictionary:
	## Ensures crew member has all required fields
	return {
		"name": data.get("name", data.get("character_name", "Unknown")),
		"character_name": data.get("character_name", data.get("name", "Unknown")),
		"background": data.get("background", "unknown"),
		"class": data.get("class", data.get("character_class", "soldier")),
		"character_class": data.get("character_class", data.get("class", "soldier")),
		"motivation": data.get("motivation", "survival"),
		"equipment": data.get("equipment", []),
		"stats": data.get("stats", {}),
		"is_captain": data.get("is_captain", false),
		"tech": data.get("tech", 0),
		"reactions": data.get("reactions", 0),
		"luck": data.get("luck", 0),
		"savvy": data.get("savvy", 0),
		"combat_skill": data.get("combat_skill", 0),
		"toughness": data.get("toughness", 0),
		"speed": data.get("speed", 0),
		"id": data.get("id", "crew_%d" % randi())
	}

static func validate_equipment(data) -> Dictionary:
	## Ensures equipment has all required fields
	if data is String:
		# Handle simple string equipment names
		return {
			"name": data,
			"type": "gear",
			"category": "misc",
			"assigned_to": "",
			"condition": "standard"
		}
	
	return {
		"name": data.get("name", "Unknown Equipment"),
		"type": data.get("type", "gear"),
		"category": data.get("category", "misc"),
		"assigned_to": data.get("assigned_to", ""),
		"condition": data.get("condition", "standard"),
		"quality_modifier": data.get("quality_modifier", 0),
		"owner": data.get("owner", "")
	}

static func validate_ship_data(data: Dictionary) -> Dictionary:
	## Ensures ship data has all required fields
	return {
		"name": data.get("name", "Unknown Vessel"),
		"type": data.get("type", "standard"),
		"hull_points": data.get("hull_points", 10),
		"debt": data.get("debt", 0),
		"traits": data.get("traits", []),
		"modifications": data.get("modifications", [])
	}

static func validate_campaign_config(data: Dictionary) -> Dictionary:
	## Ensures campaign config has all required fields
	return {
		"name": data.get("name", "New Campaign"),
		"difficulty": data.get("difficulty", "standard"),
		"victory_condition": data.get("victory_condition", "default"),
		"use_story_track": data.get("use_story_track", true),
		"starting_location": data.get("starting_location", "frontier"),
		"custom_rules": data.get("custom_rules", [])
	}

static func safe_get_name(data) -> String:
	## Safely extract a name from various data types
	if data is String:
		return data
	elif data is Dictionary:
		return data.get("name", data.get("character_name", "Unknown"))
	else:
		return "Unknown"

static func safe_get_class(data) -> String:
	## Safely extract a class from various data types
	if data is Dictionary:
		return data.get("class", data.get("character_class", "soldier"))
	else:
		return "soldier"

static func safe_get_string(data: Dictionary, key: String, default: String = "") -> String:
	## Safely get a string value from dictionary
	var value = data.get(key, default)
	if value is String:
		return value
	else:
		return str(value) if value != null else default

static func safe_get_int(data: Dictionary, key: String, default: int = 0) -> int:
	## Safely get an integer value from dictionary
	var value = data.get(key, default)
	if value is int:
		return value
	elif value is float:
		return int(value)
	elif value is String and value.is_valid_int():
		return value.to_int()
	else:
		return default

static func safe_get_array(data: Dictionary, key: String, default: Array = []) -> Array:
	## Safely get an array value from dictionary
	var value = data.get(key, default)
	if value is Array:
		return value
	else:
		return default

static func safe_get_dict(data: Dictionary, key: String, default: Dictionary = {}) -> Dictionary:
	## Safely get a dictionary value from dictionary
	var value = data.get(key, default)
	if value is Dictionary:
		return value
	else:
		return default

static func normalize_crew_array(crew_array: Array) -> Array:
	## Normalize an array of crew members
	# Sprint 26.3: Character-Everywhere - handle Character objects first
	var normalized = []
	for member in crew_array:
		if member is Object and member.has_method("to_dictionary"):
			# Character or similar Resource - convert to dictionary for validation
			normalized.append(validate_crew_member(member.to_dictionary()))
		elif member is Dictionary:
			normalized.append(validate_crew_member(member))
		else:
			push_warning("DataValidator: Invalid crew member type: %s" % typeof(member))
			# Create a fallback crew member
			normalized.append(validate_crew_member({"name": "Invalid Crew Member"}))
	return normalized

static func debug_data_structure(data, label: String = "Data") -> void:
	## Debug helper to print data structure safely
	print("DataValidator: %s structure:" % label)
	if data is Dictionary:
		print("  Dictionary with keys: %s" % str(data.keys()))
		for key in data.keys():
			var value = data[key]
			if value is Array:
				print("    %s: Array[%d]" % [key, value.size()])
			elif value is Dictionary:
				print("    %s: Dictionary[%s]" % [key, str(value.keys())])
			else:
				print("    %s: %s" % [key, typeof(value)])
	elif data is Array:
		print("  Array with %d elements" % data.size())
		for i in range(min(3, data.size())):  # Show first 3 elements
			print("    [%d]: %s" % [i, typeof(data[i])])
	else:
		print("  Type: %s, Value: %s" % [typeof(data), str(data)])