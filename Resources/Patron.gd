class_name Patron
extends Resource

enum Type { CORPORATION, LOCAL_GOVERNMENT, SECTOR_GOVERNMENT, WEALTHY_INDIVIDUAL, PRIVATE_ORGANIZATION, SECRETIVE_GROUP }

@export var name: String
@export var location: Location
@export var relationship: int = 0  # -100 to 100, 0 is neutral
@export var missions: Array[Mission] = []
@export var type: Type = Type.CORPORATION

func _init(_name: String = "", _location: Location = null, _type: Type = Type.CORPORATION):
	name = _name
	location = _location
	type = _type

func add_mission(mission: Mission):
	missions.append(mission)

func remove_mission(mission: Mission):
	missions.erase(mission)

func change_relationship(amount: int):
	relationship = clamp(relationship + amount, -100, 100)

func serialize() -> Dictionary:
	return {
		"name": name,
		"location": location.serialize() if location else null,
		"relationship": relationship,
		"missions": missions.map(func(m): return m.serialize()),
		"type": type
	}

static func deserialize(data: Dictionary) -> Patron:
	var patron = Patron.new(
		data["name"],
		Location.deserialize(data["location"]) if data["location"] else null,
		data["type"]
	)
	patron.relationship = data["relationship"]
	patron.missions = data["missions"].map(func(m): return Mission.deserialize(m))
	return patron
