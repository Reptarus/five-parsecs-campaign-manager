@tool
extends BaseEquipment

## Additional Five Parsecs specific equipment functionality
var quality_level: int = 0
var is_unique: bool = false
var tags: Array[String] = []

func _init() -> void:
	super._init()
func add_tag(tag: String) -> void:
	if not tag in tags:
		tags.append(tag) # warning: return value discarded (intentional)

func remove_tag(tag: String) -> void:
	tags.erase(tag)
func has_tag(tag: String) -> bool:
	return tag in tags

func get_quality_modifier() -> float:
	return 1.0 + (quality_level * 0.1)

func get_display_name() -> String:
	var display = "Equipment" # Fallback display name
	if quality_level > 0:
		display = "Quality %d %s" % [quality_level, display]
	if is_unique:
		display = "Unique " + display
	return display

func get_description() -> String:
	var desc = "Five Parsecs Equipment" # Fallback description
	if tags.size() > 0:
		desc += "\nTags: " + ", ".join(tags)
	return desc

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null