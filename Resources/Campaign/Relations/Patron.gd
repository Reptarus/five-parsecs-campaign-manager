class_name Patron
extends Resource

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

@export var patron_name: String = ""
@export var _location: Location = null
@export var _faction: GlobalEnums.FactionType = GlobalEnums.FactionType.CORPORATE
@export var economic_influence: float = 1.0:
	get: return economic_influence
	set(value):
		economic_influence = clamp(value, 0.1, 5.0)

var missions: Array[Mission] = []
var relationship: int = 0

func _init(name: String = "", 
		_location: Location = null,
		_faction: GlobalEnums.FactionType = GlobalEnums.FactionType.CORPORATE) -> void:
	patron_name = name
	location = _location
	faction_type = _faction
	economic_influence = randf_range(0.8, 1.2)

func add_mission(mission: Mission) -> void:
	missions.append(mission)

func remove_mission(mission: Mission) -> void:
	missions.erase(mission)

func change_relationship(amount: int) -> void:
	relationship = clamp(relationship + amount, -100, 100)

func get_available_missions() -> Array[Mission]:
	return missions.filter(func(m): return not m.is_completed)

func get_completed_missions() -> Array[Mission]:
	return missions.filter(func(m): return m.is_completed)

func get_mission_count() -> int:
	return missions.size()

func get_active_mission_count() -> int:
	return get_available_missions().size()

func get_completed_mission_count() -> int:
	return get_completed_missions().size()

func get_relationship_status() -> String:
	if relationship <= -75:
		return "Hostile"
	elif relationship <= -25:
		return "Unfriendly"
	elif relationship <= 25:
		return "Neutral"
	elif relationship <= 75:
		return "Friendly"
	else:
		return "Allied"

func get_influence_level() -> String:
	if economic_influence <= 0.5:
		return "Minor"
	elif economic_influence <= 1.0:
		return "Moderate"
	elif economic_influence <= 2.0:
		return "Major"
	else:
		return "Dominant"

func to_dict() -> Dictionary:
	return {
		"name": patron_name,
		"location": location.to_dict() if location else null,
		"faction": _faction,
		"economic_influence": economic_influence,
		"relationship": relationship,
		"missions": missions.map(func(m): return m.to_dict())
	}

static func from_dict(data: Dictionary) -> Patron:
	var patron = Patron.new()
	patron.patron_name = data.get("name", "")
	patron.location = Location.from_dict(data.get("location", {})) if data.get("location") else null
	patron._faction = data.get("faction", GlobalEnums.FactionType.CORPORATE)
	patron.economic_influence = data.get("economic_influence", 1.0)
	patron.relationship = data.get("relationship", 0)
	
	for mission_data in data.get("missions", []):
		patron.missions.append(Mission.from_dict(mission_data))
	
	return patron 