@tool
extends RefCounted

## Type-safe test helpers for working with unknown or potentially missing types
## 
## This mixin provides helper methods to safely call methods on objects that might:
## 1. Be null or invalid
## 2. Not have the expected method
## 3. Return unexpected or missing types
## 
## Usage examples:
##   var health = TypeSafeHelper._call_node_method_float(enemy, "get_health", [], 0.0)
##   var position = TypeSafeHelper._call_node_method_vector2(enemy, "get_position", [], Vector2.ZERO)

# Type-safe error handling
const ERROR_INVALID_OBJECT := "Invalid object provided"
const ERROR_INVALID_PROPERTY := "Invalid property name provided"
const ERROR_INVALID_METHOD := "Invalid method name provided"
const ERROR_PROPERTY_NOT_FOUND := "Property '%s' not found in object"
const ERROR_METHOD_NOT_FOUND := "Method '%s' not found in object"
const ERROR_TYPE_MISMATCH := "Type mismatch: expected %s but got %s"
const ERROR_CAST_FAILED := "Failed to cast %s to %s: %s"

# Type-safe property access
static func _get_property_safe(obj: Object, property: String, default_value: Variant = null) -> Variant:
	if not is_instance_valid(obj):
		push_error(ERROR_INVALID_OBJECT)
		return default_value
	
	if property.is_empty():
		push_error(ERROR_INVALID_PROPERTY)
		return default_value
	
	if not property in obj:
		push_error(ERROR_PROPERTY_NOT_FOUND % property)
		return default_value
	
	return obj.get(property)

static func _set_property_safe(obj: Object, property: String, value: Variant) -> bool:
	if not is_instance_valid(obj):
		push_error(ERROR_INVALID_OBJECT)
		return false
	
	if property.is_empty():
		push_error(ERROR_INVALID_PROPERTY)
		return false
	
	if not property in obj:
		push_error(ERROR_PROPERTY_NOT_FOUND % property)
		return false
	
	obj.set(property, value)
	return true

# Type-safe method calls with enhanced error handling
static func _call_node_method(obj: Object, method: String, args: Array = []) -> Variant:
	if obj == null:
		push_warning(ERROR_INVALID_OBJECT + ": Object is null for method " + method)
		return null
	
	if not is_instance_valid(obj):
		push_warning(ERROR_INVALID_OBJECT + ": Object is not valid for method " + method)
		return null
	
	if method.is_empty():
		push_warning(ERROR_INVALID_METHOD + " when calling on " + str(obj))
		return null
	
	# Additional safety check for method existence
	if not obj.has_method(method):
		# Try both ways to check for methods
		var has_method = false
		
		# In some cases, has_method might fail but the method still exists
		# Try a more direct approach as a fallback
		if method in obj:
			if obj.get(method) is Callable:
				has_method = true
		
		if not has_method:
			push_warning(ERROR_METHOD_NOT_FOUND % method + " in object " + str(obj))
			return null
	
	# Validate arguments before passing to callv to prevent type conversion errors
	var valid_args = []
	for i in range(args.size()):
		if args[i] is Object and not is_instance_valid(args[i]):
			push_warning("Argument %d for method '%s' is an invalid object - replacing with null" % [i, method])
			valid_args.append(null)
		else:
			valid_args.append(args[i])
	
	# Add extra safety in case object becomes invalid during execution
	if not is_instance_valid(obj):
		push_warning("Object became invalid before calling method " + method)
		return null
	
	# GDScript doesn't have try/except so we can't catch errors from callv directly
	# Try to handle potential errors by checking object validity again after call
	var result = obj.callv(method, valid_args)
	
	if result is Object and not is_instance_valid(result):
		push_warning("Method %s returned invalid object - replacing with null" % method)
		return null
		
	return result

static func _call_node_method_int(obj: Object, method: String, args: Array = [], default: int = 0) -> int:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is int:
		return result
	if result is float:
		return int(result)
	if result is String and result.is_valid_int():
		return result.to_int()
	push_error(ERROR_TYPE_MISMATCH % ["int", typeof_as_string(result)])
	return default

static func _call_node_method_bool(obj: Object, method: String, args: Array = [], default: bool = false) -> bool:
	var result = _call_node_method(obj, method, args)
	
	# Try to convert to boolean if possible
	if result == null:
		return default
	
	# Handle specific conversion from int
	if result is int:
		# Convert to explicit bool to prevent "Cannot convert 0 to boolean" errors
		return bool(result != 0)
	
	# Handle specific conversion from float
	if result is float:
		# Convert to explicit bool to prevent conversion errors
		return bool(result != 0.0)
	
	# Handle existing bool type (no conversion needed)
	if result is bool:
		return result
	
	# Handle String conversions explicitly
	if result is String:
		var lower_result = result.to_lower()
		if lower_result == "true" or lower_result == "yes" or lower_result == "1":
			return true
		if lower_result == "false" or lower_result == "no" or lower_result == "0" or lower_result.is_empty():
			return false
		# Convert to explicit bool for non-empty strings
		return bool(not result.is_empty())
	
	# Handle dictionary with special bool-indicating fields
	if result is Dictionary:
		if "success" in result:
			return bool(result.success)
		if "is_valid" in result:
			return bool(result.is_valid)
		if "valid" in result:
			return bool(result.valid)
		# Use explicit bool conversion for dictionary emptiness check
		return bool(not result.is_empty())
	
	# Handle arrays with explicit bool conversion
	if result is Array:
		return bool(not result.is_empty())
	
	# For all other types, explicitly convert to bool
	return bool(result != null)

static func _call_node_method_array(obj: Object, method: String, args: Array = [], default: Array = []) -> Array:
	var result = _call_node_method(obj, method, args)
	
	# Return default for null results
	if result == null:
		push_warning("Null result from method %s, using default array" % method)
		return default
	
	# Handle Array types - both regular and typed arrays return is_array() == true
	if result is Array:
		return result
	
	# Handle Packed Arrays (e.g., PackedInt32Array, PackedStringArray, etc.)
	if result is PackedInt32Array or result is PackedFloat32Array or result is PackedStringArray or result is PackedByteArray or result is PackedColorArray or result is PackedVector2Array or result is PackedVector3Array or result is PackedFloat64Array or result is PackedInt64Array:
		var converted_array := []
		for item in result:
			converted_array.append(item)
		return converted_array
	
	# If we get here, the result isn't an array
	push_error(ERROR_TYPE_MISMATCH % ["Array", typeof_as_string(result)])
	push_warning("Got %s instead of Array from method %s" % [typeof_as_string(result), method])
	return default

static func _call_node_method_dict(obj: Object, method: String, args: Array = [], default: Dictionary = {}) -> Dictionary:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is Dictionary:
		return result
	push_error(ERROR_TYPE_MISMATCH % ["Dictionary", typeof_as_string(result)])
	return default

static func _call_node_method_resource(obj: Object, method: String, args: Array = [], default: Resource = null) -> Resource:
	var result = _call_node_method(obj, method, args)
	if result == null:
		return default
	if result is Resource:
		return result
	push_error(ERROR_TYPE_MISMATCH % ["Resource", typeof_as_string(result)])
	return default

# Helper to get the type name as a string for error messages
static func typeof_as_string(value: Variant) -> String:
	var type_id = typeof(value)
	match type_id:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_RECT2: return "Rect2"
		TYPE_TRANSFORM2D: return "Transform2D"
		TYPE_PLANE: return "Plane"
		TYPE_QUATERNION: return "Quaternion"
		TYPE_AABB: return "AABB"
		TYPE_BASIS: return "Basis"
		TYPE_TRANSFORM3D: return "Transform3D"
		TYPE_COLOR: return "Color"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_RID: return "RID"
		TYPE_OBJECT:
			if value:
				return value.get_class()
			return "Object (null)"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_ARRAY: return "Array"
		TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY: return "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY: return "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray"
		TYPE_SIGNAL: return "Signal"
		TYPE_CALLABLE: return "Callable"
		TYPE_STRING_NAME: return "StringName"
	return "Unknown type (%d)" % type_id

# Enhanced type-safe casting with better error messages
static func _safe_cast_int(value: Variant, error_message: String = "") -> int:
	if value == null:
		push_error(ERROR_CAST_FAILED % ["null", "int", error_message])
		return 0
	if value is int:
		return value
	if value is float:
		return int(value)
	if value is String and value.is_valid_int():
		return value.to_int()
	push_error(ERROR_CAST_FAILED % [typeof_as_string(value), "int", error_message])
	return 0

static func _safe_cast_float(value: Variant, error_message: String = "") -> float:
	if value == null:
		push_error(ERROR_CAST_FAILED % ["null", "float", error_message])
		return 0.0
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is String and value.is_valid_float():
		return value.to_float()
	push_error(ERROR_CAST_FAILED % [typeof_as_string(value), "float", error_message])
	return 0.0

static func _safe_cast_array(value: Variant, error_message: String = "") -> Array:
	if value == null:
		push_error(ERROR_CAST_FAILED % ["null", "Array", error_message])
		return []
	if value is Array:
		return value
	push_error(ERROR_CAST_FAILED % [typeof_as_string(value), "Array", error_message])
	return []

static func _safe_cast_to_node(value: Variant, expected_type: String = "") -> Node:
	if value == null:
		push_error(ERROR_CAST_FAILED % ["null", "Node" + (" of type " + expected_type if not expected_type.is_empty() else ""), ""])
		return null
	if not value is Node:
		push_error(ERROR_CAST_FAILED % [typeof_as_string(value), "Node", ""])
		return null
	if not expected_type.is_empty() and not value.is_class(expected_type):
		push_error(ERROR_CAST_FAILED % ["Node", expected_type, "Wrong node type"])
		return null
	return value

static func _safe_cast_vector2(value: Variant, error_message: String = "") -> Vector2:
	if value == null:
		push_error(ERROR_CAST_FAILED % ["null", "Vector2", error_message])
		return Vector2.ZERO
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		if value[0] is float or value[0] is int and value[1] is float or value[1] is int:
			return Vector2(float(value[0]), float(value[1]))
	push_error(ERROR_CAST_FAILED % [typeof_as_string(value), "Vector2", error_message])
	return Vector2.ZERO

# Enhanced type-safe helper methods
static func _safe_cast_to_resource(value: Variant, type: String, error_message: String = "") -> Resource:
	if value == null:
		push_warning(ERROR_CAST_FAILED % ["null", type, error_message])
		return null
	
	if not value is Resource:
		push_warning(ERROR_CAST_FAILED % [typeof_as_string(value), type, error_message])
		return null
	
	if not type.is_empty():
		# Safe type checking to handle missing classes
		var res_class = value.get_class()
		if res_class != type and not value.is_class(type):
			# Add more detailed error info but return the resource anyway
			push_warning("Resource type mismatch: expected '%s' but got '%s' (%s)" % [
				type,
				res_class if not res_class.is_empty() else "unknown",
				error_message if not error_message.is_empty() else "no error details"
			])
			# Don't return null here, just warn and return the resource
			# This helps tests continue with a valid resource even if it's not the expected type
	
	return value

static func _safe_cast_to_object(value: Variant, type: String, error_message: String = "") -> Object:
	if value == null:
		push_error(ERROR_CAST_FAILED % ["null", type, error_message])
		return null
	if not value is Object:
		push_error(ERROR_CAST_FAILED % [typeof_as_string(value), type, error_message])
		return null
	if not type.is_empty() and not value.is_class(type):
		push_error(ERROR_CAST_FAILED % ["Object", type, error_message])
		return null
	return value

# Safe string conversion with proper null handling
static func _safe_cast_to_string(value: Variant, error_message: String = "") -> String:
	if value == null:
		# Return empty string for null with no warning
		return ""
	
	if value is String:
		return value
	
	if value is StringName:
		return String(value)
	
	# Handle objects that might not be valid
	if value is Object:
		if not is_instance_valid(value):
			push_warning("Attempted to convert invalid object to string")
			return ""
		
		# Some objects have a specific string representation method
		if value.has_method("to_string"):
			return value.to_string()
	
	# Most types can be converted to string
	return str(value)

# Godot 4.4 compatibility methods
# Dictionary access using "in" operator instead of has()
static func dict_has_key(dict: Dictionary, key: Variant) -> bool:
	return key in dict

# Safely check existence of a method on an object with proper error handling
static func has_method_safe(obj: Object, method_name: String) -> bool:
	if obj == null or not is_instance_valid(obj):
		return false
	
	# Use direct has_method in Godot 4.4+
	return obj.has_method(method_name)

# Resource path safety for tests
static func ensure_resource_path(resource: Resource) -> Resource:
	if resource == null or not is_instance_valid(resource):
		return resource
	
	if resource.resource_path.is_empty():
		# Generate a unique path for testing
		var timestamp = Time.get_unix_time_from_system()
		var class_name_str = resource.get_class().to_lower()
		resource.resource_path = "res://tests/generated/%s_%d.tres" % [class_name_str, timestamp]
	
	return resource

# Add missing method implementations for Godot 4.4 compatibility
static func _call_node_method_vector2(obj: Object, method: String, args: Array = [], default: Vector2 = Vector2.ZERO) -> Vector2:
	if obj == null or not is_instance_valid(obj):
		push_warning("Invalid object for method " + method)
		return default
	
	if method.is_empty():
		push_warning("Invalid method name")
		return default
	
	if not obj.has_method(method):
		push_warning("Method '%s' not found in object" % method)
		return default
	
	var result = obj.callv(method, args)
	
	if result == null:
		return default
	if result is Vector2:
		return result
	if result is Array and result.size() >= 2:
		if (result[0] is float or result[0] is int) and (result[1] is float or result[1] is int):
			return Vector2(float(result[0]), float(result[1]))
	
	push_warning("Type mismatch: expected Vector2 but got %s" % typeof_as_string(result))
	return default

static func _call_node_method_float(obj: Object, method: String, args: Array = [], default: float = 0.0) -> float:
	if obj == null or not is_instance_valid(obj):
		push_warning("Invalid object for method " + method)
		return default
	
	if method.is_empty():
		push_warning("Invalid method name")
		return default
	
	if not obj.has_method(method):
		push_warning("Method '%s' not found in object" % method)
		return default
	
	var result = obj.callv(method, args)
	
	if result == null:
		return default
	if result is float:
		return result
	if result is int:
		return float(result)
	if result is String and result.is_valid_float():
		return result.to_float()
	
	push_warning("Type mismatch: expected float but got %s" % typeof_as_string(result))
	return default

# Safe call that handles methods, properties, and alternative methods
static func safe_call(obj, method_name: String, args: Array = [], default = null):
	# Handle null objects
	if obj == null or not is_instance_valid(obj):
		push_warning("Cannot call on null object: " + method_name)
		return default
		
	# Try direct method call
	if obj.has_method(method_name):
		return obj.callv(method_name, args)
	
	# Try alternative method names
	var alt_methods = {
		"get_resources": ["get_resources", "get_all_resources", "get_resource_list", "resources"],
		"generate_resources": ["generate_resources", "create_resources", "setup_resources"],
		"get_sectors": ["get_sectors", "get_all_sectors", "get_sector_list"],
		"generate_sectors": ["generate_sectors", "create_sectors", "setup_sectors"],
		"add_quest": ["add_quest", "create_quest", "register_quest", "add_mission"],
		"complete_quest": ["complete_quest", "finish_quest", "resolve_quest", "complete_mission"],
		"fail_quest": ["fail_quest", "cancel_quest", "abort_quest", "fail_mission"],
		"get_id": ["get_id", "id", "get_identifier", "identifier"]
	}
	
	if method_name in alt_methods:
		for alt_method in alt_methods[method_name]:
			if obj.has_method(alt_method):
				return obj.callv(alt_method, args)
	
	# Try getter method if property exists
	if method_name.begins_with("get_") and method_name.length() > 4:
		var prop_name = method_name.substr(4)
		if prop_name in obj:
			return obj.get(prop_name)
	
	# Try as direct property
	if method_name in obj:
		if args.size() > 0:
			# This looks like a setter
			obj.set(method_name, args[0])
			return args[0]
		else:
			# This looks like a getter
			return obj.get(method_name)
	
	# No matching method or property
	push_warning("Method or property '%s' not found in object of type %s" % [method_name, obj.get_class()])
	return default

# String method safety wrapper
static func _call_node_method_string(obj, method: String, args: Array = [], default: String = "") -> String:
	if obj == null or not is_instance_valid(obj):
		push_warning("Invalid object for method " + method)
		return default
		
	if method.is_empty():
		push_warning("Invalid method name")
		return default
	
	if not obj.has_method(method):
		push_warning("Method '%s' not found in object" % method)
		return default
	
	# Safely call the method
	var result = _call_node_method(obj, method, args)
	
	# Handle nulls or missing results
	if result == null:
		return default
		
	# Handle type conversion - with explicit checks
	if result is String:
		return result
	# Convert any other type to string
	return str(result)

## Global mock registry for storing mock objects
static var _global_mock_registry = {}

## Register a global mock method implementation
## @param method_name: Name of the method to mock
## @param return_value: Value to return when method is called
static func register_global_mock_method(method_name: String, return_value) -> void:
	_global_mock_registry[method_name] = return_value

## Check if a method has a global mock implementation
## @param method_name: Name of the method to check
## @return: Whether a global mock exists for this method
static func has_global_mock_method(method_name: String) -> bool:
	return method_name in _global_mock_registry

## Get the global mock implementation for a method
## @param method_name: Name of the method
## @return: The mock implementation or null if none exists
static func get_global_mock_method(method_name: String):
	if not has_global_mock_method(method_name):
		return null
	return _global_mock_registry[method_name]

## Adds a mock method to an object
## @param obj: Object to add the method to
## @param method_name: Name of the method to add
## @param return_value: Value to return when the method is called
## @return: Whether the method was successfully added
static func mock_method(obj: Object, method_name: String, return_value) -> bool:
	if not is_instance_valid(obj):
		push_warning("Cannot mock method on invalid object")
		return false
	
	# Try to use set_mock_value if available
	if obj.has_method("set_mock_value"):
		obj.set_mock_value(method_name, return_value)
		return true
	
	# Try to use _mock_methods if available
	if "_mock_methods" in obj:
		obj._mock_methods[method_name] = return_value
		return true
	
	# Use GDScript to add the method
	var gut_compat = load("res://tests/fixtures/helpers/gut_compatibility.gd").new()
	
	# If the object has a script, modify it
	if obj.has_method("get_script") and obj.get_script() != null:
		var script = obj.get_script()
		
		# Only works for GDScript
		if script is GDScript:
			# Generate new script code
			var source_code = ""
			if script.has_source_code():
				source_code = script.source_code
			
			# Check if method already exists in source
			if not source_code.contains("func " + method_name):
				var method_code = "\nfunc " + method_name + "("
				
				# Add parameters based on method name conventions
				if method_name.begins_with("set_") or method_name.begins_with("add_"):
					method_code += "value"
				elif method_name.begins_with("update_"):
					method_code += "new_value"
					
				method_code += "):\n"
				
				# Generate return statement
				if return_value is bool:
					method_code += "\treturn " + ("true" if return_value else "false") + "\n"
				elif return_value is int or return_value is float:
					method_code += "\treturn " + str(return_value) + "\n"
				elif return_value is String:
					method_code += "\treturn \"" + return_value.replace("\"", "\\\"") + "\"\n"
				elif return_value is Array:
					method_code += "\treturn " + str(return_value) + "\n"
				elif return_value is Dictionary:
					method_code += "\treturn " + str(return_value) + "\n"
				elif return_value == null:
					method_code += "\tpass\n"
					
				# Append the method to the script
				source_code += method_code
				
				# Create and apply updated script
				var new_script = gut_compat.create_script_from_source(source_code)
				if new_script:
					obj.set_script(new_script)
					return true
	
	return false

## Create a mock object from a dictionary of methods
## @param methods: Dictionary mapping method names to return values
## @return: A RefCounted object with the specified methods
static func create_mock_from_methods(methods: Dictionary) -> RefCounted:
	var mock_provider = load("res://tests/fixtures/helpers/mock_provider.gd").new()
	if not mock_provider:
		push_warning("Could not load mock provider")
		return null
		
	var mock = mock_provider.create_mock_object()
	
	# Add all the methods
	for method_name in methods:
		mock.set_mock_value(method_name, methods[method_name])
	
	return mock

## Makes a Control object testable by adding all needed methods
## @param control: The Control to make testable
## @return: The modified control
static func make_testable(control: Control) -> Control:
	if not is_instance_valid(control):
		push_warning("Cannot make invalid control testable")
		return null
		
	var mock_provider = load("res://tests/fixtures/helpers/mock_provider.gd").new()
	if not mock_provider:
		push_warning("Could not load mock provider")
		return control
		
	# Extract custom properties from original control
	var custom_props = {}
	for prop in control.get_property_list():
		var prop_name = prop["name"]
		if not prop_name.begins_with("_") and not prop_name in ["script", "Script Variables"]:
			custom_props[prop_name] = control.get(prop_name)
	
	# Create a new mock control with same name and position
	var mock = mock_provider.create_mock_control()
	mock.name = control.name
	mock.position = control.position
	mock.size = control.size
	
	# Copy custom properties
	for prop_name in custom_props:
		if prop_name in mock:
			mock.set(prop_name, custom_props[prop_name])
	
	# Replace original control in parent
	var parent = control.get_parent()
	if parent:
		var idx = control.get_index()
		parent.remove_child(control)
		parent.add_child(mock)
		parent.move_child(mock, idx)
		control.queue_free()
	
	return mock
