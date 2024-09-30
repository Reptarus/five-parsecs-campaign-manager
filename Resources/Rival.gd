class_name Rival
extends Resource

@export var name: String
@export var location: Location = null
@export var strength: int = 1  # Ranges from 1 (weakest) to 5 (strongest)
@export var hostility: int = 0  # Ranges from 0 (least hostile) to 100 (most hostile)
@export var economic_impact: float = 1.0  # Calculated based on strength

func _init(_name: String = "", _location: Location = null, _strength: int = 1):
	name = _name
	location = _location
	set_strength(_strength)
	hostility = 0
	calculate_economic_impact()

func set_strength(value: int) -> void:
	strength = clamp(value, 1, 5)
	calculate_economic_impact()

func increase_strength() -> void:
	set_strength(strength + 1)

func decrease_strength() -> void:
	set_strength(strength - 1)

func change_hostility(amount: int) -> void:
	hostility = clamp(hostility + amount, 0, 100)

func calculate_economic_impact() -> void:
	economic_impact = 1.0 + (strength * 0.1)

func serialize() -> Dictionary:
	return {
		"name": name,
		"location": location.serialize() if location else null,
		"strength": strength,
		"hostility": hostility,
		"economic_impact": economic_impact
	}

static func deserialize(data: Dictionary) -> Rival:
	var rival = Rival.new(
		data.get("name", ""),
		data.get("location", null),
		data.get("strength", 1)
	)
	rival.hostility = data.get("hostility", 0)
	rival.economic_impact = data.get("economic_impact", 1.0)
	
	if data.get("location"):
		rival.location = Location.deserialize(data["location"])
	
	return rival
