extends Resource

signal mission_completed

# Basic properties with defaults
var _completed = false
var _mission_id = ""
var _mission_name = "Test Mission"
var _mission_description = "This is a test mission"

# Handle complete method if not available
func complete():
	_completed = true
	# Use direct property setting for this common case
	set("_completed", true)
	emit_signal("mission_completed")
	return true

# Handle is_completed method if not available
func is_completed():
	# Direct property check - safer than has()
	return _completed

# Convert mission to dictionary for storage
func to_dict():
	var result = {
		"id": _mission_id,
		"name": _mission_name,
		"description": _mission_description,
		"completed": _completed
	}
	
	# Copy any existing properties
	var props = get_property_list()
	for prop in props:
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not prop.name in result:
			result[prop.name] = get(prop.name)
			
	return result
