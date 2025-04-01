class_name GutStringUtils

# NOTE: This file has been completely rewritten from the original GUT implementation
# to prevent "Not based on a resource file" errors by eliminating inst_to_dict calls.
# The original approach relied on inst_to_dict which fails for objects that are not
# based on resource files or have dynamically created scripts.

# Hash containing all the built in types in Godot. This provides an English
# name for the types that corresponds with the type constants defined in the
# engine.
var types = {}

# Types to not be formatted when using _str
var _str_ignore_types = [
	TYPE_INT, TYPE_FLOAT, TYPE_STRING,
	TYPE_NIL, TYPE_BOOL
]

func _init():
	_init_types_dictionary()

func _init_types_dictionary():
	types[TYPE_NIL] = 'NIL'
	types[TYPE_AABB] = 'AABB'
	types[TYPE_ARRAY] = 'ARRAY'
	types[TYPE_BASIS] = 'BASIS'
	types[TYPE_BOOL] = 'BOOL'
	types[TYPE_CALLABLE] = 'CALLABLE'
	types[TYPE_COLOR] = 'COLOR'
	types[TYPE_DICTIONARY] = 'DICTIONARY'
	types[TYPE_FLOAT] = 'FLOAT'
	types[TYPE_INT] = 'INT'
	types[TYPE_MAX] = 'MAX'
	types[TYPE_NODE_PATH] = 'NODE_PATH'
	types[TYPE_OBJECT] = 'OBJECT'
	types[TYPE_PACKED_BYTE_ARRAY] = 'PACKED_BYTE_ARRAY'
	types[TYPE_PACKED_COLOR_ARRAY] = 'PACKED_COLOR_ARRAY'
	types[TYPE_PACKED_FLOAT32_ARRAY] = 'PACKED_FLOAT32_ARRAY'
	types[TYPE_PACKED_FLOAT64_ARRAY] = 'PACKED_FLOAT64_ARRAY'
	types[TYPE_PACKED_INT32_ARRAY] = 'PACKED_INT32_ARRAY'
	types[TYPE_PACKED_INT64_ARRAY] = 'PACKED_INT64_ARRAY'
	types[TYPE_PACKED_STRING_ARRAY] = 'PACKED_STRING_ARRAY'
	types[TYPE_PACKED_VECTOR2_ARRAY] = 'PACKED_VECTOR2_ARRAY'
	types[TYPE_PACKED_VECTOR3_ARRAY] = 'PACKED_VECTOR3_ARRAY'
	types[TYPE_PLANE] = 'PLANE'
	types[TYPE_PROJECTION] = 'PROJECTION'
	types[TYPE_QUATERNION] = 'QUATERNION'
	types[TYPE_RECT2] = 'RECT2'
	types[TYPE_RECT2I] = 'RECT2I'
	types[TYPE_RID] = 'RID'
	types[TYPE_SIGNAL] = 'SIGNAL'
	types[TYPE_STRING_NAME] = 'STRING_NAME'
	types[TYPE_STRING] = 'STRING'
	types[TYPE_TRANSFORM2D] = 'TRANSFORM2D'
	types[TYPE_TRANSFORM3D] = 'TRANSFORM3D'
	types[TYPE_VECTOR2] = 'VECTOR2'
	types[TYPE_VECTOR2I] = 'VECTOR2I'
	types[TYPE_VECTOR3] = 'VECTOR3'
	types[TYPE_VECTOR3I] = 'VECTOR3I'
	types[TYPE_VECTOR4] = 'VECTOR4'
	types[TYPE_VECTOR4I] = 'VECTOR4I'

# ------------------------------------------------------------------------------
# Extracts the filename from a path
# ------------------------------------------------------------------------------
func _get_filename(path: String) -> String:
	if path == null or path.is_empty():
		return ""
	
	var parts = path.split('/')
	if parts.size() > 0:
		return parts[parts.size() - 1]
	return path

# ------------------------------------------------------------------------------
# Gets the filename of an object passed in. This does not return the
# full path to the object, just the filename.
# ------------------------------------------------------------------------------
func _get_obj_filename(thing) -> String:
	# Early exits for cases where we don't want/need a filename
	if thing == null:
		return ""
		
	if typeof(thing) != TYPE_OBJECT:
		return ""
		
	if not is_instance_valid(thing):
		return ""
		
	if GutUtils.is_native_class(thing):
		return ""
		
	if GutUtils.is_double(thing):
		return ""
	
	# For PackedScenes, we can use resource_path directly
	if thing is PackedScene and thing.resource_path:
		return _get_filename(thing.resource_path)
	
	# No script case
	var script = thing.get_script()
	if script == null:
		return ""
	
	# Handle different script types
	if script is GDScript:
		# For GDScript, we can use resource_path directly
		if script.resource_path and not script.resource_path.is_empty():
			var filename = _get_filename(script.resource_path)
			
			# Try to get subpath info if available
			var subpath = ""
			
			# Method 1: Using get_script_subpath method if it exists
			if thing.has_method("get_script_subpath"):
				subpath = thing.get_script_subpath()
			
			# Method 2: Using script_subpath property if it exists
			elif "script_subpath" in thing:
				subpath = thing.get("script_subpath")
			
			# If we have a subpath, add it to the filename
			if subpath != null and not str(subpath).is_empty():
				filename += str("/", subpath)
				
			return filename
		else:
			# For in-memory scripts
			return "gdscript_memory"
	else:
		# For C# scripts and others with resource_path
		if script.resource_path and not script.resource_path.is_empty():
			return _get_filename(script.resource_path)
		else:
			# For other script types without resource_path
			return "non_gdscript"
	
	return ""

# ------------------------------------------------------------------------------
# Better object/thing to string conversion. Includes extra details about
# whatever is passed in when it can/should.
# ------------------------------------------------------------------------------
func type2str(thing) -> String:
	# Handle null explicitly
	if thing == null:
		return str(null)
	
	var str_thing = str(thing)
	var filename = null
	
	# Handle basic types with type-specific formatting
	match typeof(thing):
		TYPE_FLOAT:
			if not '.' in str_thing:
				str_thing += '.0'
		TYPE_STRING:
			str_thing = str('"', thing, '"')
		TYPE_OBJECT:
			if GutUtils.is_native_class(thing):
				str_thing = GutUtils.get_native_class_name(thing)
			elif GutUtils.is_double(thing):
				var double_path = ""
				if thing.__gutdbl.thepath != "":
					double_path = _get_filename(thing.__gutdbl.thepath)
					if thing.__gutdbl.subpath != "":
						double_path += str("/", thing.__gutdbl.subpath)
				elif thing.__gutdbl.from_singleton != "":
					double_path = thing.__gutdbl.from_singleton + " Singleton"
				
				var double_type = "partial-double" if thing.__gutdbl.is_partial else "double"
				str_thing += str("(", double_type, " of ", double_path, ")")
			else:
				# Only get the filename for non-null, valid Object instances
				# that are not native classes or doubles
				filename = _get_obj_filename(thing)
		_: # For other types not in _str_ignore_types
			if not typeof(thing) in _str_ignore_types and types.has(typeof(thing)):
				if not str_thing.begins_with('('):
					str_thing = '(' + str_thing + ')'
				str_thing = str(types[typeof(thing)], str_thing)
	
	# Add filename if available and not already accounted for
	if filename != null and not filename.is_empty():
		str_thing += str('(', filename, ')')
	
	return str_thing

# ------------------------------------------------------------------------------
# Returns the string truncated with an '...' in it. Shows the start and last
# 10 chars. If the string is smaller than max_size the entire string is
# returned. If max_size is -1 then truncation is skipped.
# ------------------------------------------------------------------------------
func truncate_string(src: String, max_size: int) -> String:
	if src.length() <= max_size or max_size == -1:
		return src
	
	var to_return = str(
		src.substr(0, max_size - 10),
		'...',
		src.substr(src.length() - 10, src.length())
	)
	
	return to_return

# ------------------------------------------------------------------------------
# Generate indentation text
# ------------------------------------------------------------------------------
func _get_indent_text(times: int, pad: String) -> String:
	var to_return = ""
	for i in range(times):
		to_return += pad
	return to_return

# ------------------------------------------------------------------------------
# Indent all lines in text by a specified amount
# ------------------------------------------------------------------------------
func indent_text(text: String, times: int, pad: String) -> String:
	if times == 0:
		return text
	
	var to_return = text
	var ending_newline = ""
	
	if text.ends_with("\n"):
		ending_newline = "\n"
		to_return = to_return.left(to_return.length() - 1)
	
	var padding = _get_indent_text(times, pad)
	to_return = padding + to_return.replace("\n", "\n" + padding)
	to_return += ending_newline
	
	return to_return
