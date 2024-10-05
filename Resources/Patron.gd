class_name Patron
extends Resource

var name: String:
	get: return name
	set(value): name = value

var location: Location:
	get: return location
	set(value): location = value

var relationship: int = 0:  # -100 to 100, 0 is neutral
	get: return relationship
	set(value): relationship = value

var missions: Array[Mission] = []:
	get: return missions
	set(value): missions = value

var type: GlobalEnums.Faction = GlobalEnums.Faction.CORPORATE:
	get: return type
	set(value): type = value

var economic_influence: float = 1.0:
	get: return economic_influence
	set(value): economic_influence = value

func _init(_name: String = "", _location: Location = null, _type: GlobalEnums.Faction = GlobalEnums.Faction.CORPORATE):
	name = _name
	location = _location
	type = _type
	economic_influence = randf_range(0.8, 1.2)

func add_mission(mission: Mission) -> void:
	missions.append(mission)

func remove_mission(mission: Mission) -> void:
	missions.erase(mission)

func change_relationship(amount: int) -> void:
	relationship = clamp(relationship + amount, -100, 100)

func serialize() -> Dictionary:
	return {
		"name": name,
		"location": location.serialize() if location else {} as Dictionary,
		"relationship": relationship,
		"missions": missions.map(func(m): return m.serialize()),
		"type": type,
		"economic_influence": economic_influence
	}

# Add a static method for deserialization
static func deserialize(data: Dictionary) -> Patron:
	var patron = Patron.new()
	patron.name = data.get("name", "")
	patron.location = Location.deserialize(data.get("location", {}))
	patron.relationship = data.get("relationship", 0)
	patron.missions = data.get("missions", []).map(func(m): return Mission.deserialize(m))
	patron.type = data.get("type", GlobalEnums.Faction.CORPORATE)
	patron.economic_influence = data.get("economic_influence", 1.0)
	return patron
