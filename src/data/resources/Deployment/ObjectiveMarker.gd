# Universal Connection Validation Applied
# Based on proven patterns: Universal Mock Strategy + 7-Stage Methodology
class_name ObjectiveMarker
extends Area3D

# Safe imports
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class
# # Universal framework import removed to fix SHADOWED_GLOBAL_IDENTIFIER # Removed to fix SHADOWED_GLOBAL_IDENTIFIER - using global class

# Safe dependency loading
var Character: Variant = null

signal objective_reached(by_unit: Node)
signal objective_completed
signal objective_failed
signal objective_progress_updated(progress: float)

@export var objective_type: String
@export var required_turns := 0
@export var capture_radius := 2.0
@export var fail_on_enemy_capture := false

var capturing_unit: Node = null
var turns_held := 0

func _ready() -> void:
	# Load dependencies safely at runtime
	Character = load("res://src/core/character/Character.gd")

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
	self.area_entered.connect(_on_area_entered)
	self.area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area3D) -> void:
	if not area:
		push_warning("ObjectiveMarker: null area entered signal")
		return

	if area.is_in_group("units"):
		var node: Node = area.get_parent()
		if not node:
			push_warning("ObjectiveMarker: unit area has no parent node")
			return

		if Character and node.get_script() == Character:
			capturing_unit = node
			if fail_on_enemy_capture and capturing_unit.has_method("is_enemy") and capturing_unit.is_enemy():
				self.objective_failed.emit()
			self.objective_reached.emit(capturing_unit)

func _on_area_exited(area: Area3D) -> void:
	if area == capturing_unit:
		capturing_unit = null
		turns_held = 0

func process_turn() -> void:
	if capturing_unit:
		turns_held += 1
		if turns_held >= required_turns:
			self.objective_completed.emit()

## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null