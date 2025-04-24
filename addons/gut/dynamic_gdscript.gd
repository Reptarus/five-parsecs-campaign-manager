@tool
extends RefCounted

var default_script_name_no_extension = 'gut_dynamic_script'
var default_script_resource_path = 'res://addons/gut/not_a_real_file/'
var default_script_extension = "gd"

var _created_script_count = 0

# Creates a loaded script from the passed in source. This loaded script is
# returned unless there is an error. When an error occurs the error number
# is returned instead.
func create_script_from_source(source, override_path = null):
	_created_script_count += 1
	var r_path = str(default_script_resource_path,
		default_script_name_no_extension, '_', _created_script_count, ".",
		default_script_extension)

	if override_path != null:
		r_path = override_path

	# Use the empty template if it exists
	var DynamicScript
	if ResourceLoader.exists("res://addons/gut/temp/__empty.gd"):
		DynamicScript = load("res://addons/gut/temp/__empty.gd").duplicate()
	else:
		# In 4.4 we can't use GDScript.new() anymore, so try to work with dummy script
		push_warning("Could not find empty script template - dynamic scripting may be limited")
		return null
	
	if DynamicScript:
		DynamicScript.source_code = source.dedent()
		DynamicScript.resource_path = r_path
		var result = DynamicScript.reload()
		if result != OK:
			DynamicScript = result

	return DynamicScript
