@tool
class_name ResourceCompatibilityMixin
extends Resource

## Mixin to add Godot 4.4 compatibility methods for Resources
## Extend this class or copy its methods to add Godot 4.4 compatibility to your Resources

## Checks if this resource has a property with the given name
## This replaces the removed 'has(property)' functionality in Godot 4.4
func has(property_name: String) -> bool:
	# Check using property list first (most reliable)
	for prop in get_property_list():
		if prop.name == property_name:
			return true
			
	# Try direct property access with the 'in' operator (Godot 4.4 way)
	if property_name in self:
		return true
	
	# Try getter methods for common patterns
	if has_method("get_" + property_name):
		return true
		
	if has_method("is_" + property_name):
		return true
	
	return false

## Gets a property value safely with a default fallback
## Use this instead of direct property access for better compatibility
func get_property(property_name: String, default_value = null) -> Variant:
	if not has(property_name):
		return default_value
		
	return get(property_name)

## Sets a property value safely
## Use this instead of direct property access for better compatibility
func set_property(property_name: String, value: Variant) -> bool:
	if not has(property_name):
		return false
		
	set(property_name, value)
	return true