# Don't use class_name to avoid global class conflicts
# Use explicit preloads instead
extends Area3D

const Self = preload("res://src/data/resources/Deployment/ObjectiveMarker.gd")
const Character = preload("res://src/base/character/character_base.gd")

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
    add_to_group("objectives")
    area_entered.connect(_on_area_entered)
    area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area3D) -> void:
    if area.is_in_group("units"):
        var node = area.get_parent()
        if node is Character:
            capturing_unit = node
            if fail_on_enemy_capture and capturing_unit.is_enemy():
                objective_failed.emit()
            objective_reached.emit(capturing_unit)

func _on_area_exited(area: Area3D) -> void:
    if area == capturing_unit:
        capturing_unit = null
        turns_held = 0

func process_turn() -> void:
    if capturing_unit:
        turns_held += 1
        if turns_held >= required_turns:
            objective_completed.emit()