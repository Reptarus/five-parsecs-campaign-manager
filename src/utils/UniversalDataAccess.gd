# Universal Safe Dictionary Access - Apply to ALL files
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
# Removed class_name UniversalDataAccess to fix SHADOWED_GLOBAL_IDENTIFIER warnings
extends RefCounted

static func get_dict_value_safe(dict: Dictionary, key: String, default_value: Variant = null, context: String = "") -> Variant:
	if not dict:
		push_error("CRASH PREVENTION: Dictionary is null for key '%s' - %s" % [key, context])
		return default_value

	if not dict.has(key):
		push_warning("Dictionary key missing: '%s' - %s (using default: %s)" % [key, context, default_value])
		return default_value

	var value: Variant = dict[key]
	if value == null and default_value != null:
		push_warning("Dictionary value is null for key '%s' - %s (using default: %s)" % [key, context, default_value])
		return default_value

	return value

static func set_dict_value_safe(dict: Dictionary, key: String, value: Variant, context: String = "") -> bool:
	if not dict:
		push_error("CRASH PREVENTION: Cannot set value in null dictionary - %s" % context)
		return false

	dict[key] = value
	return true

static func get_array_value_safe(array: Array, index: int, default_value: Variant = null, context: String = "") -> Variant:
	if not array:
		push_error("CRASH PREVENTION: Array is null for index %d - %s" % [index, context])
		return default_value

	if index < 0 or index >= array.size():
		push_warning("Array index out of bounds: %d (size: %d) - %s (using default: %s)" % [index, array.size(), context, default_value])
		return default_value

	var value: Variant = array[index]
	if value == null and default_value != null:
		push_warning("Array value is null at index %d - %s (using default: %s)" % [index, context, default_value])
		return default_value

	return value

static func set_array_value_safe(array: Array, index: int, value: Variant, context: String = "") -> bool:
	if not array:
		push_error("CRASH PREVENTION: Cannot set value in null array - %s" % context)
		return false

	if index < 0:
		push_error("CRASH PREVENTION: Negative array index not allowed: %d - %s" % [index, context])
		return false

	# Extend array if necessary
	while array.size() <= index:
		array.append(null)

	array[index] = value
	return true

static func merge_dict_safe(target: Dictionary, source: Dictionary, overwrite: bool = true, context: String = "") -> bool:
	if not target:
		push_error("CRASH PREVENTION: Target dictionary is null for merge - %s" % context)
		return false

	if not source:
		push_error("CRASH PREVENTION: Source dictionary is null for merge - %s" % context)
		return false

	for key in source.keys():
		if overwrite or not target.has(key):
			target[key] = source[key]

	return true

static func get_nested_value_safe(dict: Dictionary, key_path: String, default_value: Variant = null, separator: String = ".", context: String = "") -> Variant:
	if not dict:
		push_error("CRASH PREVENTION: Dictionary is null for nested access - %s" % context)
		return default_value

	if key_path.is_empty():
		push_error("CRASH PREVENTION: Empty key path for nested access - %s" % context)
		return default_value

	var keys = key_path.split(separator)
	var current_value = dict

	for key in keys:
		var typed_key: Variant = key
		if not current_value is Dictionary:
			push_warning("Nested value is not a dictionary at key '%s' - %s (using default: %s)" % [key, context, default_value])
			return default_value

		var current_dict = current_value as Dictionary
		if not current_dict.has(key):
			push_warning("Nested key missing: '%s' in path '%s' - %s (using default: %s)" % [key, key_path, context, default_value])
			return default_value

		current_value = current_dict[key]

	return current_value

static func set_nested_value_safe(dict: Dictionary, key_path: String, value: Variant, separator: String = ".", context: String = "") -> bool:
	if not dict:
		push_error("CRASH PREVENTION: Dictionary is null for nested set - %s" % context)
		return false

	if key_path.is_empty():
		push_error("CRASH PREVENTION: Empty key path for nested set - %s" % context)
		return false

	var keys = key_path.split(separator)
	var current_dict = dict

	# Navigate to the parent of the final key
	for i: int in range(keys.size() - 1):
		var key = keys[i]
		if not current_dict.has(key):
			current_dict[key] = {}

		if not current_dict[key] is Dictionary:
			push_error("CRASH PREVENTION: Cannot create nested path, value at '%s' is not a dictionary - %s" % [key, context])
			return false

		current_dict = current_dict[key]

	# Set the final value
	current_dict[keys[-1]] = value
	return true

static func validate_dict_structure(dict: Dictionary, required_keys: Array, context: String = "") -> bool:
	if not dict:
		push_error("CRASH PREVENTION: Dictionary is null for structure validation - %s" % context)
		return false

	var missing_keys: Array = []
	for key in required_keys:
		var typed_key: Variant = key
		if not dict.has(key):
			missing_keys.append(key)

	if not missing_keys.is_empty():
		push_error("CRASH PREVENTION: Dictionary missing required keys: %s - %s" % [missing_keys, context])
		return false

	return true

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
static func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null