## EnemyTablePreset - Defines filtering rules for enemy generation
## Used to create thematic campaigns (Pirate Hunting, Xenos Extermination, etc.)
## and to future-proof for Bug Hunt DLC integration.
class_name EnemyTablePreset
extends Resource

@export var id: String = ""
@export var preset_name: String = ""  # Named to avoid shadowing Resource.name
@export var description: String = ""
@export var is_default: bool = false
@export var category_weights: Dictionary = {}
@export var required_tags: Array[String] = []
@export var excluded_tags: Array[String] = []
@export var excluded_categories: Array[String] = []
@export var dlc_required: String = ""
@export var special_rules: Dictionary = {}


static func from_dict(data: Dictionary) -> Resource:
	# Use Resource type to avoid self-reference issue in static functions
	var script := load("res://src/core/systems/EnemyTablePreset.gd")
	var preset = script.new()
	preset.id = data.get("id", "")
	preset.preset_name = data.get("name", "")
	preset.description = data.get("description", "")
	preset.is_default = data.get("is_default", false)
	preset.category_weights = data.get("category_weights", {})

	# Convert arrays properly
	var req_tags = data.get("required_tags", [])
	for tag in req_tags:
		preset.required_tags.append(str(tag))

	var excl_tags = data.get("excluded_tags", [])
	for tag in excl_tags:
		preset.excluded_tags.append(str(tag))

	var excl_cats = data.get("excluded_categories", [])
	for cat in excl_cats:
		preset.excluded_categories.append(str(cat))

	var dlc = data.get("dlc_required")
	preset.dlc_required = str(dlc) if dlc != null else ""
	preset.special_rules = data.get("special_rules", {})

	return preset


func is_available() -> bool:
	if dlc_required.is_empty():
		return true
	# Check DLC ownership via GameStateManager
	if Engine.has_singleton("GameStateManager"):
		var gsm = Engine.get_singleton("GameStateManager")
		if gsm.has_method("has_dlc"):
			return gsm.has_dlc(dlc_required)
	# Fallback: check if autoload exists
	var gsm_node = Engine.get_main_loop().root.get_node_or_null("/root/GameStateManager")
	if gsm_node and gsm_node.has_method("has_dlc"):
		return gsm_node.has_dlc(dlc_required)
	# Default to unavailable if DLC required but no way to check
	return false


func has_special_rule(rule_name: String) -> bool:
	return special_rules.has(rule_name) and special_rules[rule_name] == true


func get_display_name() -> String:
	return preset_name if not preset_name.is_empty() else id
