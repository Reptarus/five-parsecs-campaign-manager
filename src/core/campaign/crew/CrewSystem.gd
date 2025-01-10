class_name CrewSystem
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

signal crew_changed(crew_data: Dictionary)

var current_crew: Dictionary = {}

func _ready() -> void:
	_initialize_crew()

func _initialize_crew() -> void:
	current_crew = {
		"captain": null,
		"crew_members": [],
		"connections": [],
		"ship": null,
		"resources": 0,
		"experience": 0,
		"reputation": 0
	}
	crew_changed.emit(current_crew)
