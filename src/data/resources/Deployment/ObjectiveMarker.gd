# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
class_name ObjectiveMarker
extends Area3D

# Safe imports
const UniversalNodeAccess = preload("res://src/utils/UniversalNodeAccess.gd")
const UniversalResourceLoader = preload("res://src/utils/UniversalResourceLoader.gd") 
const UniversalSignalManager = preload("res://src/utils/UniversalSignalManager.gd")
const UniversalDataAccess = preload("res://src/utils/UniversalDataAccess.gd")
const UniversalSceneManager = preload("res://src/utils/UniversalSceneManager.gd")

# Safe dependency loading
var Character = null

signal objective_reached(by_unit: Character)
signal objective_completed
signal objective_failed
signal objective_progress_updated(progress: float)

@export var objective_type: String
@export var required_turns := 0
@export var capture_radius := 2.0
@export var fail_on_enemy_capture := false

var capturing_unit: Character = null
var turns_held := 0

func _ready() -> void:
	# Load dependencies safely at runtime
	Character = UniversalResourceLoader.load_script_safe("res://src/core/character/Base/Character.gd", "ObjectiveMarker Character")
	
	_validate_universal_connections()
	add_to_group("objectives")
	_setup_signal_connections()

func _validate_universal_connections() -> void:
	# Validate data dependencies
	_validate_data_connections()

func _validate_data_connections() -> void:
	# Validate Character class dependency
	if not Character:
		push_error("DATA SYSTEM FAILURE: Character class not loaded in ObjectiveMarker")

func _setup_signal_connections() -> void:
	# Connect area signals safely
	UniversalSignalManager.connect_signal_safe(self, "area_entered", _on_area_entered, "ObjectiveMarker area_entered")
	UniversalSignalManager.connect_signal_safe(self, "area_exited", _on_area_exited, "ObjectiveMarker area_exited")

func _on_area_entered(area: Area3D) -> void:
	if not area:
		push_warning("ObjectiveMarker: null area entered signal")
		return
		
	if area.is_in_group("units"):
		var node = area.get_parent()
		if not node:
			push_warning("ObjectiveMarker: unit area has no parent node")
			return
			
		if Character and node is Character:
			capturing_unit = node
			if fail_on_enemy_capture and capturing_unit.has_method("is_enemy") and capturing_unit.is_enemy():
				UniversalSignalManager.emit_signal_safe(self, "objective_failed", [], "ObjectiveMarker objective_failed")
			UniversalSignalManager.emit_signal_safe(self, "objective_reached", [capturing_unit], "ObjectiveMarker objective_reached")

func _on_area_exited(area: Area3D) -> void:
	if area == capturing_unit:
		capturing_unit = null
		turns_held = 0

func process_turn() -> void:
	if capturing_unit:
		turns_held += 1
		if turns_held >= required_turns:
			UniversalSignalManager.emit_signal_safe(self, "objective_completed", [], "ObjectiveMarker objective_completed")
