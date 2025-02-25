@tool
class_name FiveParsecsCrewSystem
extends Node

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Character = preload("res://src/core/character/Base/Character.gd")

signal crew_changed(crew_data: Dictionary)

var current_crew: Dictionary = {
	"captain": null,
	"crew_members": [] as Array[Character],
	"connections": [] as Array[Dictionary],
	"ship": null,
	"resources": 0
}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_initialize_crew()

func _initialize_crew() -> void:
	if current_crew == null:
		push_error("Failed to initialize crew system - current_crew is null")
		return
	
	current_crew = {
		"captain": null,
		"crew_members": [] as Array[Character],
		"connections": [] as Array[Dictionary],
		"ship": null,
		"resources": 0,
	}
