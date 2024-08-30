class_name Rival
extends Resource

@export var name: String
@export var location: Location
@export var strength: int = 1  # 1 to 5, 1 is weakest
@export var hostility: int = 0  # 0 to 100, 0 is least hostile

func _init(_name: String = "", _location: Location = null, _strength: int = 1):
	name = _name
	location = _location
	strength = _strength

func increase_strength():
	strength = min(strength + 1, 5)

func decrease_strength():
	strength = max(strength - 1, 1)

func change_hostility(amount: int):
	hostility = clamp(hostility + amount, 0, 100)

func serialize() -> Dictionary:
	return {
		"name": name,
		"location": location.serialize(),
		"strength": strength,
		"hostility": hostility
	}

static func deserialize(data: Dictionary) -> Rival:
	var rival = Rival.new(
		data["name"],
		Location.deserialize(data["location"]),
		data["strength"]
	)
	rival.hostility = data["hostility"]
	return rival
