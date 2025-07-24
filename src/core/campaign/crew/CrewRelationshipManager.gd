@tool
extends Node
class_name CrewRelationshipManager

## Crew Relationship Manager stub
## Manages relationships between crew members

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal relationship_changed(character_a: String, character_b: String, relationship_type: String)
signal crew_morale_changed(new_morale: int)

var relationships: Dictionary = {}
var crew_morale: int = 50

func _ready() -> void:
	pass

func add_relationship(character_a: String, character_b: String, relationship_type: String) -> void:
	var key = _get_relationship_key(character_a, character_b)
	relationships[key] = relationship_type
	relationship_changed.emit(character_a, character_b, relationship_type)

func get_relationship(character_a: String, character_b: String) -> String:
	var key = _get_relationship_key(character_a, character_b)
	return relationships.get(key, "neutral")

func update_crew_morale(change: int) -> void:
	crew_morale = clamp(crew_morale + change, 0, 100)
	crew_morale_changed.emit(crew_morale)

func get_crew_morale() -> int:
	return crew_morale

func _get_relationship_key(character_a: String, character_b: String) -> String:
	# Ensure consistent key regardless of order
	var sorted_chars = [character_a, character_b]
	sorted_chars.sort()
	return sorted_chars[0] + "_" + sorted_chars[1]
