class_name SafeDataAccess
extends RefCounted

## Safe Data Access Utility
## Provides type-safe methods for accessing data to prevent String.get() errors

## Safe dictionary access with type validation
static func safe_get(obj: Variant, key: String, default_value: Variant = null, context: String = "") -> Variant:
	if obj is Dictionary:
		return obj.get(key, default_value)
	
	var context_msg = " in " + context if context != "" else ""
	push_warning("SafeDataAccess: Expected Dictionary for key '%s'%s, got %s. Using default value." % [key, context_msg, type_string(typeof(obj))])
	return default_value

## Safe dictionary conversion with validation
static func safe_dict_access(obj: Variant, operation_name: String = "data access") -> Dictionary:
	if obj is Dictionary:
		return obj
	
	push_warning("SafeDataAccess: %s - Expected Dictionary, got %s. Using empty dictionary." % [operation_name, type_string(typeof(obj))])
	return {}

## Safe array access with type validation
static func safe_array_access(obj: Variant, operation_name: String = "array access") -> Array:
	if obj is Array:
		return obj
	
	push_warning("SafeDataAccess: %s - Expected Array, got %s. Using empty array." % [operation_name, type_string(typeof(obj))])
	return []

## Safe string access with type validation
static func safe_string_access(obj: Variant, default_value: String = "", operation_name: String = "string access") -> String:
	if obj is String:
		return obj
	
	push_warning("SafeDataAccess: %s - Expected String, got %s. Using default value." % [operation_name, type_string(typeof(obj))])
	return default_value

## Safe integer access with type validation
static func safe_int_access(obj: Variant, default_value: int = 0, operation_name: String = "integer access") -> int:
	if obj is int:
		return obj
	
	push_warning("SafeDataAccess: %s - Expected int, got %s. Using default value." % [operation_name, type_string(typeof(obj))])
	return default_value

## Safe float access with type validation
static func safe_float_access(obj: Variant, default_value: float = 0.0, operation_name: String = "float access") -> float:
	if obj is float:
		return obj
	
	push_warning("SafeDataAccess: %s - Expected float, got %s. Using default value." % [operation_name, type_string(typeof(obj))])
	return default_value

## Safe boolean access with type validation
static func safe_bool_access(obj: Variant, default_value: bool = false, operation_name: String = "boolean access") -> bool:
	if obj is bool:
		return obj
	
	push_warning("SafeDataAccess: %s - Expected bool, got %s. Using default value." % [operation_name, type_string(typeof(obj))])
	return default_value

## Validate data structure and log detailed information
static func validate_data_structure(data: Variant, expected_keys: Array, context: String = "") -> Dictionary:
	var result = {
		"valid": false,
		"missing_keys": [],
		"type_errors": [],
		"data": {}
	}
	
	if not data is Dictionary:
		result.type_errors.append("Expected Dictionary, got %s" % type_string(typeof(data)))
		push_error("SafeDataAccess: %s - Data structure validation failed. Expected Dictionary." % context)
		return result
	
	var data_dict = data as Dictionary
	result.data = data_dict
	
	# Check for missing keys
	for key in expected_keys:
		if not data_dict.has(key):
			result.missing_keys.append(key)
	
	result.valid = result.missing_keys.is_empty() and result.type_errors.is_empty()
	
	if not result.valid:
		var error_msg = "SafeDataAccess: %s - Data validation failed:" % context
		if not result.missing_keys.is_empty():
			error_msg += " Missing keys: [%s]" % ", ".join(result.missing_keys)
		if not result.type_errors.is_empty():
			error_msg += " Type errors: [%s]" % ", ".join(result.type_errors)
		push_warning(error_msg)
	
	return result

## Enhanced safe get with multiple fallback strategies
static func enhanced_safe_get(obj: Variant, key: String, default_value: Variant = null, context: String = "") -> Variant:
	# First check if it's a dictionary
	if obj is Dictionary:
		return obj.get(key, default_value)
	
	# If it's an object with properties, try to access the property
	if obj is Object and obj.has_method("get"):
		var value = obj.get(key)
		if value != null:
			return value
		return default_value
	
	# If it's an object with the property directly
	if obj is Object and obj.has_method("has_method") and obj.has_method("get_property_list"):
		var property_list = obj.get_property_list()
		for property in property_list:
			if property.name == key:
				return obj.get(key)
		return default_value
	
	# Log warning and return default
	var context_msg = " in " + context if context != "" else ""
	push_warning("SafeDataAccess: Enhanced access failed for key '%s'%s. Object type: %s. Using default value." % [key, context_msg, type_string(typeof(obj))])
	return default_value

## Batch safe get for multiple keys
static func batch_safe_get(obj: Variant, keys: Dictionary, context: String = "") -> Dictionary:
	var result = {}
	var validated_obj = safe_dict_access(obj, context + " (batch access)")
	
	for key in keys:
		var default_value = keys[key]
		result[key] = safe_get(validated_obj, key, default_value, context)
	
	return result

## Deep safe get for nested dictionary access
static func deep_safe_get(obj: Variant, key_path: Array, default_value: Variant = null, context: String = "") -> Variant:
	var current_obj = obj
	
	for i in range(key_path.size()):
		var key = key_path[i]
		var path_context = context + " (path: %s)" % "/".join(key_path.slice(0, i + 1))
		
		if not current_obj is Dictionary:
			push_warning("SafeDataAccess: Deep access failed at key '%s' in %s. Expected Dictionary, got %s." % [key, path_context, type_string(typeof(current_obj))])
			return default_value
		
		if not current_obj.has(key):
			push_warning("SafeDataAccess: Deep access failed - missing key '%s' in %s." % [key, path_context])
			return default_value
		
		current_obj = current_obj[key]
	
	return current_obj
