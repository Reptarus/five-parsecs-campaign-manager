class_name Rival
extends Resource

@export var name: String
@export var location: Location
@export var strength: int = 1  # 1 to 5, 1 is weakest
@export var hostility: int = 0  # 0 to 100, 0 is least hostile
@export var economic_impact: float = 1.0  # New field for economic impact

func _init(_name: String = "", _location: Location = null, _strength: int = 1):
	name = _name
	location = _location
	strength = _strength
	economic_impact = 1.0 + (strength * 0.1)  # Stronger rivals have more economic impact

func increase_strength():
	strength = min(strength + 1, 5)
	economic_impact = 1.0 + (strength * 0.1)

func decrease_strength():
	strength = max(strength - 1, 1)
	economic_impact = 1.0 + (strength * 0.1)

func change_hostility(amount: int):
	hostility = clamp(hostility + amount, 0, 100)

func apply_economic_impact(economy_manager: EconomyManager):
	if location.name in economy_manager.location_price_modifiers:
		economy_manager.location_price_modifiers[location.name] *= economic_impact

func serialize() -> Dictionary:
	return {
		"name": name,
		"location": location.serialize(),
		"strength": strength,
		"hostility": hostility,
		"economic_impact": economic_impact
	}

static func deserialize(data: Dictionary) -> Rival:
	var rival = Rival.new(
		data["name"],
		Location.deserialize(data["location"]),
		data["strength"]
	)
	rival.hostility = data["hostility"]
	rival.economic_impact = data["economic_impact"]
	return rival
