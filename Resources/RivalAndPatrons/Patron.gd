class_name Patron
extends Resource

signal relationship_changed(new_value: int)
signal missions_updated

var _patron_name: String
var _location: Location
var _relationship: int = 0
var _missions: Array[Mission] = []
var _faction_type: GlobalEnums.FactionType = GlobalEnums.FactionType.CORPORATE
var _economic_influence: float = 1.0

@export var patron_name: String:
	get: return _patron_name
	set(value): 
		if value.strip_edges().is_empty():
			push_error("Patron name cannot be empty")
			return
		_patron_name = value

@export var location: Location:
	get: return _location
	set(value): 
		if not value:
			push_error("Location cannot be null")
			return
		_location = value
		notify_property_list_changed()

@export var relationship: int:
	get: return _relationship
	set(value): 
		_relationship = clamp(value, -100, 100)
		relationship_changed.emit(_relationship)

@export var missions: Array[Mission]:
	get: return _missions
	set(value): 
		_missions = value
		missions_updated.emit()

@export var faction_type: GlobalEnums.FactionType:
	get: return _faction_type
	set(value): 
		_faction_type = value
		notify_property_list_changed()

@export var economic_influence: float:
	get: return _economic_influence
	set(value): 
		_economic_influence = clamp(value, 0.1, 5.0)

func _init(_name: String = "", 
		   init_location: Location = null, 
		   init_faction: GlobalEnums.FactionType = GlobalEnums.FactionType.CORPORATE) -> void:
	patron_name = _name
	location = init_location
	faction_type = init_faction
	economic_influence = randf_range(0.8, 1.2)

func add_mission(mission: Mission) -> void:
	_missions.append(mission)
	missions_updated.emit()

func remove_mission(mission: Mission) -> void:
	_missions.erase(mission)
	missions_updated.emit()

func change_relationship(amount: int) -> void:
	relationship = clamp(_relationship + amount, -100, 100)

func serialize() -> Dictionary:
	return {
		"name": _patron_name,
		"location": _location.serialize() if _location else {} as Dictionary,
		"relationship": _relationship,
		"missions": _missions.map(func(m): return m.serialize()),
		"type": _faction_type,
		"economic_influence": _economic_influence
	}

static func deserialize(data: Dictionary) -> Patron:
	var patron = Patron.new()
	patron.patron_name = data.get("name", "")
	patron.location = Location.deserialize(data.get("location", {})) if data.has("location") else null
	patron.relationship = data.get("relationship", 0)
	patron.missions = []
	for mission_data in data.get("missions", []):
		if mission_data is Dictionary:
			var mission = Mission.new()
			patron.missions.append(mission.deserialize(mission_data))
	patron.faction_type = data.get("type", GlobalEnums.FactionType.CORPORATE)
	patron.economic_influence = data.get("economic_influence", 1.0)
	return patron
