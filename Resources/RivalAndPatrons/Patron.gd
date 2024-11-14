class_name Patron
extends Resource

signal relationship_changed(new_value: int)
signal missions_updated

@export var patron_name: String:
	get: return patron_name
	set(value): 
		if value.strip_edges().is_empty():
			push_error("Patron name cannot be empty")
			return
		patron_name = value

@export var location: Location:
	get: return location
	set(value): 
		if not value:
			push_error("Location cannot be null")
			return
		location = value
		notify_property_list_changed()

@export var relationship: int = 0:
	get: return relationship
	set(value): 
		relationship = clamp(value, -100, 100)
		relationship_changed.emit(relationship)

@export var missions: Array[Mission] = []:
	get: return missions
	set(value): 
		missions = value
		missions_updated.emit()

@export var faction_type: GlobalEnums.FactionType = GlobalEnums.FactionType.CORPORATE:
	get: return faction_type
	set(value): 
		faction_type = value
		notify_property_list_changed()

@export var economic_influence: float = 1.0:
	get: return economic_influence
	set(value): 
		economic_influence = clamp(value, 0.1, 5.0)

func _init(_name: String = "", 
		   _location: Location = null, 
		   _faction: GlobalEnums.FactionType = GlobalEnums.FactionType.CORPORATE) -> void:
	patron_name = _name
	location = _location
	faction_type = _faction
	economic_influence = randf_range(0.8, 1.2)

func add_mission(mission: Mission) -> void:
	missions.append(mission)

func remove_mission(mission: Mission) -> void:
	missions.erase(mission)

func change_relationship(amount: int) -> void:
	relationship = clamp(relationship + amount, -100, 100)

func serialize() -> Dictionary:
	return {
		"name": patron_name,
		"location": location.serialize() if location else {} as Dictionary,
		"relationship": relationship,
		"missions": missions.map(func(m): return m.serialize()),
		"type": faction_type,
		"economic_influence": economic_influence
	}

# Add a static method for deserialization
static func deserialize(data: Dictionary) -> Patron:
	var patron = Patron.new()
	patron.patron_name = data.get("name", "")
	patron.location = Location.deserialize(data.get("location", {}))
	patron.relationship = data.get("relationship", 0)
	patron.missions = data.get("missions", []).map(func(m): return Mission.deserialize(m))
	patron.faction_type = data.get("type", GlobalEnums.FactionType.CORPORATE)
	patron.economic_influence = data.get("economic_influence", 1.0)
	return patron
