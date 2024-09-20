class_name Patron
extends Resource

enum Type { CORPORATION, LOCAL_GOVERNMENT, SECTOR_GOVERNMENT, WEALTHY_INDIVIDUAL, PRIVATE_ORGANIZATION, SECRETIVE_GROUP }

@export var name: String
@export var location: Location
@export var relationship: int = 0  # -100 to 100, 0 is neutral
@export var missions: Array[Mission] = []
@export var type: Type = Type.CORPORATION
@export var economic_influence: float = 1.0

func _init(_name: String = "", _location: Location = null, _type: Type = Type.CORPORATION):
	name = _name
	location = _location
	type = _type
	economic_influence = randf_range(0.8, 1.2)

func add_mission(mission: Mission):
	missions.append(mission)

func remove_mission(mission: Mission):
	missions.erase(mission)

func change_relationship(amount: int):
	relationship = clamp(relationship + amount, -100, 100)

func serialize() -> Dictionary:
	return {
		"name": name,
		"location": location.serialize() as Variant if location else null,
		"relationship": relationship,
		"missions": missions.map(func(m): return m.serialize()),
		"type": Type.keys()[type],
		"economic_influence": economic_influence
	}

static func deserialize(data: Dictionary) -> Patron:
	var patron = Patron.new(
		data["name"],
		data["location"]["data"] if data["location"] else null,
		Type[data["type"]]
	)
	patron.relationship = data["relationship"]
	patron.missions = data["missions"].map(func(m): return Mission.deserialize(m))
	patron.economic_influence = data["economic_influence"]
	
	# Deserialize location if it exists
	if data["location"]:
		patron.location = Location.deserialize(data["location"]["data"])
	
	return patron
