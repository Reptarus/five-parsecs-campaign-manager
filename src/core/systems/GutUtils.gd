extends Node

const DOUBLE_STRATEGY = {
	INCLUDE_NATIVE = 0,
	SCRIPT_ONLY = 1
}

static var _instance = null

static func get_instance():
	if _instance == null:
		_instance = load("res://src/core/systems/GutUtils.gd").new()
	return _instance

func get_enum_value(value, enum_dict, default_value):
	if typeof(value) == TYPE_INT:
		return value
	elif typeof(value) == TYPE_STRING:
		if value.is_valid_int():
			return value.to_int()
		else:
			var upper = value.to_upper()
			if enum_dict.has(upper):
				return enum_dict[upper]
			else:
				var spaced = value.replace(" ", "_").to_upper()
				if enum_dict.has(spaced):
					return enum_dict[spaced]
	return default_value 