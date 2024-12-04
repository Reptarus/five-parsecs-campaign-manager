class_name ObjectiveMarker
extends Area3D

signal objective_reached(by_unit: Node)
signal objective_completed

@export var objective_type: String
@export var required_turns := 0
@export var capture_radius := 2.0

var turns_held := 0
var capturing_unit: Node

func _ready() -> void:
    add_to_group("objectives")
    area_entered.connect(_on_area_entered)
    area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area3D) -> void:
    if area.is_in_group("units"):
        capturing_unit = area
        objective_reached.emit(area)

func _on_area_exited(area: Area3D) -> void:
    if area == capturing_unit:
        capturing_unit = null
        turns_held = 0

func process_turn() -> void:
    if capturing_unit:
        turns_held += 1
        if turns_held >= required_turns:
            objective_completed.emit() 