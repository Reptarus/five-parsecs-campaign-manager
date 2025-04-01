@tool
var default_script_name_no_extension = 'gut_dynamic_script'
var default_script_resource_path = 'res://addons/gut/not_a_real_file/'
var default_script_extension = "gd"

var _created_script_count = 0
const Compatibility = preload("res://addons/gut/compatibility.gd")

# Creates a loaded script from the passed in source.  This loaded script is
# returned unless there is an error.  When an error occcurs the error number
# is returned instead.
func create_script_from_source(source, override_path = null) -> Variant:
	_created_script_count += 1
	var r_path = str(default_script_resource_path,
		default_script_name_no_extension, '_', _created_script_count, ".",
		default_script_extension)

	if (override_path != null):
		r_path = override_path

	# Create script with proper Godot 4.4 method
	var DynamicScript = Compatibility.create_gdscript()
	DynamicScript.source_code = source.dedent()
	DynamicScript.resource_path = r_path
	var result = DynamicScript.reload()
	if (result != OK):
		DynamicScript = result

	return DynamicScript

# This is a compatibility method for creating scripts
# that works in both Godot 4.3 and 4.4
func create_compatible_script():
	# In Godot 4.4, GDScript.new() was removed
	return Compatibility.create_gdscript()

# Helper that creates a GDScript in a way that works in both Godot 4.3 and 4.4
static func create_gdscript():
	return Compatibility.create_gdscript()