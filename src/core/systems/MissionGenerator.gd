@tool
extends Node
class_name FPCM_MissionGenerator

## Mission generator for Five Parsecs campaign
## Generates missions based on campaign state and rules

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal mission_generated(mission_data: Dictionary)
signal generation_failed(error: String)

var mission_templates: Array[Dictionary] = []
var current_difficulty: int = 1
var mission_count: int = 0

func _ready() -> void:
	_initialize_templates()

func _initialize_templates() -> void:
	# Initialize basic mission templates
	mission_templates = [
		{
			"type": "patrol",
			"difficulty": 1,
			"rewards": {"credits": 1000}
		},
		{
			"type": "rescue",
			"difficulty": 2,
			"rewards": {"credits": 1500}
		}
	]

func generate_mission(mission_type: String = "") -> Dictionary:
	# Generate a mission based on _type or random
	var template = _get_template(mission_type)
	var mission_data = template.duplicate(true)

	mission_data["id"] = "mission_" + str(mission_count)
	mission_count += 1

	mission_generated.emit(mission_data)
	return mission_data

func _get_template(mission_type: String) -> Dictionary:
	if mission_type.is_empty():
		return mission_templates[randi() % mission_templates.size()]

	for template in mission_templates:
		var typed_template: Variant = template
		if template._type == mission_type:
			return template

	return mission_templates[0] # fallback

func set_difficulty(difficulty: int) -> void:
	current_difficulty = clampi(difficulty, 1, 5)

func get_available_missions(count: int = 3) -> Array[Dictionary]:
	var missions: Array[Dictionary] = []
	for i: int in range(count):
		missions.append(generate_mission())
	return missions

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null