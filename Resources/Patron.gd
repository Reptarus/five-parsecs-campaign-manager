class_name Patron
extends Resource

enum Type { CORPORATION, LOCAL_GOVERNMENT, SECTOR_GOVERNMENT, WEALTHY_INDIVIDUAL, PRIVATE_ORGANIZATION, SECRETIVE_GROUP }

@export var name: String
@export var location: Location
@export var relationship: int = 0  # -100 to 100, 0 is neutral
@export var missions: Array[Mission] = []
@export var type: Type = Type.CORPORATION
@export var economic_influence: float = 1.0  # New field for economic influence

func _init(_name: String = "", _location: Location = null, _type: Type = Type.CORPORATION):
	name = _name
	location = _location
	type = _type
	economic_influence = randf_range(0.8, 1.2)  # Random economic influence

func add_mission(mission: Mission):
	missions.append(mission)

func remove_mission(mission: Mission):
	missions.erase(mission)

func change_relationship(amount: int):
	relationship = clamp(relationship + amount, -100, 100)

func generate_job(economy_manager: EconomyManager) -> Mission:
	var mission_template = MissionTemplate.new()  # You might want to use a more sophisticated method to select a template
	var reward = mission_template.calculate_reward(economy_manager) * economic_influence
	# Implementation of job generation using the mission template
	var mission = Mission.new()  # Placeholder
	mission.reward = int(reward)
	return mission

func apply_economic_influence(economy_manager: EconomyManager):
	if location.name in economy_manager.location_price_modifiers:
		economy_manager.location_price_modifiers[location.name] *= economic_influence

func serialize() -> Dictionary:
	return {
		"name": name,
		"location": location.serialize() if location else null,
		"relationship": relationship,
		"missions": missions.map(func(m): return m.serialize()),
		"type": Type.keys()[type],
		"economic_influence": economic_influence
	}

static func deserialize(data: Dictionary) -> Patron:
	var patron = Patron.new(
		data["name"],
		Location.deserialize(data["location"]) if data["location"] else null,
		Type[data["type"]]
	)
	patron.relationship = data["relationship"]
	patron.missions = data["missions"].map(func(m): return Mission.deserialize(m))
	patron.economic_influence = data["economic_influence"]
	return patron
