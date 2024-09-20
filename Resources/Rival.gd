class_name Rival
extends Resource  # Keeping Resource as the base class for data-driven design

# Rival properties
@export var name: String
@export var location: Location = null
@export var strength: int = 1  # Ranges from 1 (weakest) to 5 (strongest)
@export var hostility: int = 0  # Ranges from 0 (least hostile) to 100 (most hostile)
@export var economic_impact: float = 1.0  # Calculated based on strength

# Constructor to initialize a new Rival instance
func _init(_name: String = "", _location: Location = null, _strength: int = 1):
	name = _name
	location = _location
	set_strength(_strength)  # Use the setter method to initialize strength
	hostility = 0  # Default hostility
	calculate_economic_impact()

# Sets strength while ensuring it remains within valid range
func set_strength(value: int) -> void:
	strength = clamp(value, 1, 5)
	calculate_economic_impact()

# Increases strength by 1, up to a maximum of 5
func increase_strength() -> void:
	set_strength(strength + 1)

# Decreases strength by 1, down to a minimum of 1
func decrease_strength() -> void:
	set_strength(strength - 1)

# Modifies hostility by a given amount, clamping it between 0 and 100
func change_hostility(amount: int) -> void:
	hostility = clamp(hostility + amount, 0, 100)

# Recalculates the economic impact based on the strength
func calculate_economic_impact() -> void:
	economic_impact = 1.0 + (strength * 0.1)

# Serializes the Rival object to a Dictionary for easy storage or transfer
func serialize() -> Dictionary:
	return {
		"name": name,
		"location": location.serialize() if location else {},
		"strength": strength,
		"hostility": hostility,
		"economic_impact": economic_impact
	}

# Deserializes a Dictionary back into a Rival object
static func deserialize(data: Dictionary) -> Rival:
	var _name = data.get("name", "")
	var _location = null
	if data.get("location") != null:
		_location = Location.deserialize(data["location"]["data"])
	var _strength = data.get("strength", 1)

	var rival = Rival.new(_name, _location, _strength)
	rival.hostility = data.get("hostility", 0)
	rival.calculate_economic_impact()  # Ensure economic impact is recalculated
	return rival
