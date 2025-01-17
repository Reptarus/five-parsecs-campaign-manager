extends Control

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal resources_updated(resources: Dictionary)

@onready var credits_label = $Content/Resources/Credits/Value
@onready var supplies_label = $Content/Resources/Supplies/Value
@onready var tech_parts_label = $Content/Resources/TechParts/Value
@onready var patron_label = $Content/Resources/Patron/Value

var current_resources: Dictionary = {
	GameEnums.ResourceType.CREDITS: 1000,
	GameEnums.ResourceType.SUPPLIES: 5,
	GameEnums.ResourceType.TECH_PARTS: 0,
	GameEnums.ResourceType.PATRON: 0
}

func _ready() -> void:
	_update_ui()

func set_resources(resources: Dictionary) -> void:
	current_resources = resources.duplicate()
	_update_ui()
	resources_updated.emit(current_resources)

func _update_ui() -> void:
	credits_label.text = str(current_resources[GameEnums.ResourceType.CREDITS])
	supplies_label.text = str(current_resources[GameEnums.ResourceType.SUPPLIES])
	tech_parts_label.text = str(current_resources[GameEnums.ResourceType.TECH_PARTS])
	patron_label.text = str(current_resources[GameEnums.ResourceType.PATRON])

func get_resources() -> Dictionary:
	return current_resources.duplicate()

func is_valid() -> bool:
	return true # Resources are always valid as they're pre-calculated based on difficulty
