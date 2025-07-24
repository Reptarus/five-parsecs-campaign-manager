@tool
extends Node
class_name FPCM_MissionGenerator

## Mission generator for Five Parsecs campaign
## Now uses BaseMissionGenerationSystem for unified mission generation logic
## Part of Phase 3A Mission Generation Consolidation

const BaseMissionGenerationSystem = preload("res://src/base/mission/BaseMissionGenerationSystem.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Mission = preload("res://src/core/systems/Mission.gd")

signal mission_generated(mission_data: Dictionary)
signal generation_failed(error: String)

# Mission generation system (handles all logic)
var generation_system: BaseMissionGenerationSystem = null

# Legacy compatibility
var mission_templates: Array[Dictionary] = []
var current_difficulty: int = 1
var mission_count: int = 0

func _ready() -> void:
	# Initialize mission generation system
	generation_system = BaseMissionGenerationSystem.new()
	_connect_generation_system_signals()
	_setup_generation_system()
	
	# Legacy initialization for compatibility
	_initialize_templates()

func _connect_generation_system_signals() -> void:
	"""Connect to generation system signals"""
	if generation_system:
		generation_system.mission_generated.connect(_on_system_mission_generated)
		generation_system.mission_batch_generated.connect(_on_system_mission_batch_generated)
		generation_system.generation_failed.connect(_on_system_generation_failed)

func _setup_generation_system() -> void:
	"""Setup generation system in basic mode"""
	if generation_system:
		generation_system.setup_mission_generator(BaseMissionGenerationSystem.GenerationMode.BASIC)

func _initialize_templates() -> void:
	# Legacy templates for compatibility
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
	"""Generate a mission using the generation system"""
	if generation_system:
		var mission = generation_system.generate_mission(mission_type)
		var mission_data = mission.serialize()
		mission_generated.emit(mission_data)
		return mission_data
	else:
		# Fallback to legacy generation
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
	if generation_system:
		generation_system.set_difficulty(current_difficulty)

func get_available_missions(count: int = 3) -> Array[Dictionary]:
	"""Get multiple missions using generation system"""
	if generation_system:
		var missions = generation_system.generate_mission_batch(count)
		var mission_data_array: Array[Dictionary] = []
		for mission in missions:
			mission_data_array.append(mission.serialize())
		return mission_data_array
	else:
		# Fallback to legacy generation
		var missions: Array[Dictionary] = []
		for i: int in range(count):
			missions.append(generate_mission())
		return missions

## Generation system signal handlers
func _on_system_mission_generated(mission: Mission) -> void:
	"""Handle mission generated from generation system"""
	# Convert to legacy format for compatibility
	var mission_data = mission.serialize()
	mission_generated.emit(mission_data)

func _on_system_mission_batch_generated(missions: Array[Mission]) -> void:
	"""Handle mission batch generated from generation system"""
	# Could emit individual signals or batch signal
	for mission in missions:
		_on_system_mission_generated(mission)

func _on_system_generation_failed(error: String) -> void:
	"""Handle generation failure from generation system"""
	generation_failed.emit(error)

## Public API for enhanced mission generation
func enable_five_parsecs_mode() -> void:
	"""Enable Five Parsecs mission generation mode"""
	if generation_system:
		generation_system.setup_mission_generator(BaseMissionGenerationSystem.GenerationMode.FIVE_PARSECS)

func enable_enhanced_mode() -> void:
	"""Enable enhanced mission generation mode"""
	if generation_system:
		generation_system.setup_mission_generator(BaseMissionGenerationSystem.GenerationMode.ENHANCED)

func get_generation_system() -> BaseMissionGenerationSystem:
	"""Get generation system for direct access"""
	return generation_system

func get_available_mission_types() -> Array[String]:
	"""Get available mission types from generation system"""
	if generation_system:
		return generation_system.get_available_mission_types()
	else:
		return ["patrol", "rescue"]  # fallback

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null