class_name Godot4Utils
extends RefCounted

## Godot 4 compatibility utilities for common patterns that changed from Godot 3

## Safe property access for objects that may not have the property
## Use this instead of obj.has("property") which doesn't exist in Godot 4 Resources
static func safe_get_property(obj: Variant, property_name: String, default_value = null):
	if obj == null:
		return default_value
		
	# For Dictionaries, use the 'in' operator
	if obj is Dictionary:
		var dict = obj as Dictionary
		if property_name in dict:
			return dict[property_name]
		return default_value
	
	# For other objects, use get() if available or fallback to default
	if obj is Object and obj.has_method("get"):
		# For Resources, we need to handle the case where get() only accepts one argument
		var value = obj.get(property_name)
		return value if value != null else default_value
	
	# Last resort: try to access the property directly
	if obj is Object:
		if obj.has_signal(property_name) or obj.has_method(property_name):
			return default_value
			
		# Use get_property_list to check if property exists
		var property_list = obj.get_property_list()
		for property in property_list:
			if property.name == property_name:
				return obj.get(property_name)
			
	return default_value

## Check if an object has a property (replacement for .has() on Resources)
static func has_property(obj: Variant, property_name: String) -> bool:
	if obj == null:
		return false
		
	# For Dictionaries, use the 'in' operator
	if obj is Dictionary:
		return property_name in (obj as Dictionary)
	
	# For other objects, check property list
	if obj is Object:
		var property_list = obj.get_property_list()
		for property in property_list:
			if property.name == property_name:
				return true
			
	return false

## Safe dictionary access using 'in' operator (Godot 4 best practice)
static func dict_has_key(dict: Dictionary, key: String) -> bool:
	return key in dict

## Safe dictionary get with default
static func dict_get_safe(dict: Dictionary, key: String, default_value = null):
	if key in dict:
		return dict[key]
	return default_value