@tool
extends RefCounted

## Helper functions for Godot 4.4 compatibility
##
## This script provides standardized functions to ensure compatibility
## with Godot 4.4, particularly for dictionary access, resource safety,
## and property existence checks.

## Ensures a resource has a valid resource path to prevent inst_to_dict errors
##
## @param {Resource} resource - The resource to check and update
## @param {String} prefix - Prefix for the generated resource path
## @return {Resource} The resource with a valid path
static func ensure_resource_path(resource: Resource, prefix: String = "test_resource") -> Resource:
	if resource and resource.resource_path.is_empty():
		resource.resource_path = "res://tests/generated/%s_%d.tres" % [prefix, Time.get_unix_time_from_system()]
	return resource

## Safe property access with default value
##
## @param {Object} obj - The object to access
## @param {String} property - The property name to access
## @param {Variant} default_value - Default value if property doesn't exist
## @return {Variant} The property value or default
static func safe_get_property(obj: Object, property: String, default_value = null):
	if obj == null or not obj.has_property(property):
		return default_value
	return obj.get(property)

## Safe method call with default value
##
## @param {Object} obj - The object to call method on
## @param {String} method - The method name to call
## @param {Array} args - Arguments to pass to the method
## @param {Variant} default_value - Default value if method doesn't exist
## @return {Variant} The method return value or default
static func safe_call_method(obj: Object, method: String, args: Array = [], default_value = null):
	if obj == null or not obj.has_method(method):
		return default_value
	return obj.callv(method, args)

## Safe dictionary access with default value
##
## @param {Dictionary} dict - The dictionary to access
## @param {Variant} key - The key to access
## @param {Variant} default_value - Default value if key doesn't exist
## @return {Variant} The value at key or default
static func safe_dict_get(dict: Dictionary, key, default_value = null):
	if key in dict:
		return dict[key]
	return default_value

## Safe array append that doesn't duplicate entries
##
## @param {Array} arr - The array to append to
## @param {Variant} value - The value to append
## @return {Array} The modified array
static func safe_array_append(arr: Array, value) -> Array:
	if not arr.has(value):
		arr.append(value)
	return arr

## Safe signal connection that checks if signal exists
##
## @param {Object} obj - The object to connect to
## @param {String} signal_name - The signal name
## @param {Callable} callable - The callable to connect
## @return {bool} Whether connection was successful
static func safe_connect_signal(obj: Object, signal_name: String, callable: Callable) -> bool:
	if obj == null or not obj.has_signal(signal_name):
		return false
	if obj.is_connected(signal_name, callable):
		return true
	obj.connect(signal_name, callable)
	return true

## Safe resource tracking that checks resource validity
##
## @param {Resource} resource - The resource to track
## @param {Object} tracker - The object with track_test_resource method
## @return {bool} Whether tracking was successful
static func safe_track_resource(resource: Resource, tracker: Object) -> bool:
	if resource == null:
		return false
	
	# Ensure resource has valid path
	ensure_resource_path(resource)
	
	# Track the resource if tracker has the method
	if tracker and tracker.has_method("track_test_resource"):
		tracker.track_test_resource(resource)
		return true
	return false

## Call a method on a node with error handling
##
## @param {Object} obj - The object to call method on
## @param {String} method - The method name to call
## @param {Array} args - Arguments to pass to the method
## @return {Variant} The method return value or null
static func call_node_method(obj: Object, method: String, args: Array = []) -> Variant:
	if obj == null:
		push_warning("Object is null for method " + method)
		return null
		
	if not is_instance_valid(obj):
		push_warning("Object is not valid for method " + method)
		return null
	
	if method.is_empty():
		push_warning("Invalid method name when calling on " + str(obj))
		return null
	
	if not obj.has_method(method):
		push_warning("Method '" + method + "' not found in object " + str(obj))
		return null
	
	# Validate arguments to prevent errors
	for i in range(args.size()):
		if args[i] is Object and not is_instance_valid(args[i]):
			push_warning("Argument %d for method '%s' is an invalid object - replacing with null" % [i, method])
			args[i] = null
	
	return obj.callv(method, args)

## Call a method on a node with bool return type
##
## @param {Object} obj - The object to call method on
## @param {String} method - The method name to call
## @param {Array} args - Arguments to pass to the method
## @param {bool} default - Default value if method fails
## @return {bool} The method return value as bool
static func call_node_method_bool(obj: Object, method: String, args: Array = [], default: bool = false) -> bool:
	var result = call_node_method(obj, method, args)
	
	if result == null:
		return default
	if result is bool:
		return result
	if result is int:
		return result != 0
	return bool(result)

## Call a method on a node with int return type
##
## @param {Object} obj - The object to call method on
## @param {String} method - The method name to call
## @param {Array} args - Arguments to pass to the method
## @param {int} default - Default value if method fails
## @return {int} The method return value as integer
static func call_node_method_int(obj: Object, method: String, args: Array = [], default: int = 0) -> int:
	var result = call_node_method(obj, method, args)
	
	if result == null:
		return default
	if result is int:
		return result
	if result is float:
		return int(result)
	if result is String and result.is_valid_int():
		return result.to_int()
	return default

## Call a method on a node with array return type
##
## @param {Object} obj - The object to call method on
## @param {String} method - The method name to call
## @param {Array} args - Arguments to pass to the method
## @param {Array} default - Default value if method fails
## @return {Array} The method return value as array
static func call_node_method_array(obj: Object, method: String, args: Array = [], default: Array = []) -> Array:
	var result = call_node_method(obj, method, args)
	
	if result == null:
		return default
	if result is Array:
		return result
	return default

## Call a method on a node with dictionary return type
##
## @param {Object} obj - The object to call method on
## @param {String} method - The method name to call
## @param {Array} args - Arguments to pass to the method
## @param {Dictionary} default - Default value if method fails
## @return {Dictionary} The method return value as dictionary
static func call_node_method_dict(obj: Object, method: String, args: Array = [], default: Dictionary = {}) -> Dictionary:
	var result = call_node_method(obj, method, args)
	
	if result == null:
		return default
	if result is Dictionary:
		return result
	return default

## Call a method on a node with resource return type
##
## @param {Object} obj - The object to call method on
## @param {String} method - The method name to call
## @param {Array} args - Arguments to pass to the method
## @param {Resource} default - Default value if method fails
## @return {Resource} The method return value as resource
static func call_node_method_resource(obj: Object, method: String, args: Array = [], default: Resource = null) -> Resource:
	var result = call_node_method(obj, method, args)
	
	if result == null:
		return default
	if result is Resource:
		return result
	return default

## Safely cast a value to string with error handling
##
## @param {Variant} value - The value to cast to string
## @param {String} error_message - Optional error message
## @return {String} The value as string or empty string
static func safe_cast_to_string(value: Variant, error_message: String = "") -> String:
	if value == null:
		if not error_message.is_empty():
			push_warning("Cannot cast null to String: " + error_message)
		return ""
	if value is String:
		return value
	if value is StringName:
		return String(value)
	return str(value)
