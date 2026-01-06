@tool
extends Resource
class_name GamePlanet

# GlobalEnums available as autoload singleton

signal planet_updated(property, _value)

# Core properties
@export var planet_id: String = ""
@export var planet_name: String = ""
@export var sector: String = ""
@export var coordinates: Vector2 = Vector2.ZERO
@export var planet_type: int = GlobalEnums.PlanetType.NONE
@export var description: String = ""
@export var faction_type: int = GlobalEnums.FactionType.NEUTRAL
@export var environment_type: int = GlobalEnums.PlanetEnvironment.NONE
@export var world_traits: Array = []
@export var resources: Dictionary = {} # ResourceType: amount
@export var threats: Array[int] = [] # Using EnemyType for threats since ThreatType doesn't exist

# State tracking
@export var strife_level: int = GlobalEnums.StrifeType.NONE
@export var instability: int = GlobalEnums.StrifeType.NONE
@export var unity_progress: int = 0
@export var market_prices: Dictionary = {} # ItemType: price
@export var faction_control: int = GlobalEnums.FactionType.NONE
@export var locations: Array = []
@export var visited: bool = false
@export var discovered: bool = false

# Data manager for loading traits
var _data_manager: Object = null

func _init() -> void:
	clear_planet_state()

func clear_planet_state() -> void:
	resources.clear()
	threats.clear()
	world_traits.clear()
	market_prices.clear()
	strife_level = GlobalEnums.StrifeType.NONE
	instability = GlobalEnums.StrifeType.NONE
	unity_progress = 0

## Add a world trait to this planet by ID
func add_world_trait_by_id(trait_id: String) -> bool:
	# Check if we already have this trait
	for trait_item in world_traits:
		if trait_item.trait_id == trait_id:
			return false

	# Create and initialize the new trait
	var new_trait = {}
	new_trait.trait_id = trait_id
	world_traits.append(new_trait)

	# Apply trait effects to planet
	_apply_trait_effects(new_trait)

	planet_updated.emit("world_traits", world_traits)
	return true

## Remove a world trait from this planet by ID
func remove_world_trait_by_id(trait_id: String) -> bool:
	for i: int in range(world_traits.size()):
		if world_traits[i].trait_id == trait_id:
			var removed_trait = world_traits[i]
			world_traits.remove_at(i)

			# Remove trait effects from planet
			_remove_trait_effects(removed_trait)

			planet_updated.emit("world_traits", world_traits)
			return true

	return false

## Apply the effects of a world trait to this planet
func _apply_trait_effects(world_trait: Dictionary) -> void:
	# Apply resource modifiers
	if world_trait.has("resource_modifiers"):
		for resource_key in world_trait.resource_modifiers:
			var resource_type = _get_resource_type_from_key(resource_key)
			if resource_type >= 0:
				var modifier = world_trait.resource_modifiers[resource_key]
				if not resources.has(resource_type):
					resources[resource_type] = 0
				resources[resource_type] += modifier

## Remove the effects of a world _trait from this planet
func _remove_trait_effects(world_trait: Dictionary) -> void:
	# Remove resource modifiers
	if world_trait.has("resource_modifiers"):
		for resource_key in world_trait.resource_modifiers:
			var resource_type = _get_resource_type_from_key(resource_key)
			if resource_type >= 0 and resources.has(resource_type):
				var modifier = world_trait.resource_modifiers[resource_key]
				resources[resource_type] -= modifier
				if resources[resource_type] <= 0:
					resources.erase(resource_type)

## Convert a string resource key to a resource type enum _value
func _get_resource_type_from_key(key: String) -> int:
	match key:
		"water": return 1
		"fuel": return GlobalEnums.ResourceType.FUEL
		"food": return 2
		"minerals": return 3
		"technology": return 4
		"medicine": return 5
		"exotic_materials": return 6
		_: return -1

func add_resource(resource_type: int, amount: int = 1) -> void:
	if not resource_type in range(GlobalEnums.ResourceType.size()):
		push_error("Invalid resource _type provided")
		return

	if not resources.has(resource_type):
		resources[resource_type] = 0
	resources[resource_type] += amount

	planet_updated.emit("resources", resources)

func remove_resource(resource_type: int, amount: int = 1) -> bool:
	if not resource_type in range(GlobalEnums.ResourceType.size()):
		push_error("Invalid resource _type provided")
		return false

	if not resources.has(resource_type) or resources[resource_type] < amount:
		return false
	resources[resource_type] -= amount
	if resources[resource_type] <= 0:
		resources.erase(resource_type)

	planet_updated.emit("resources", resources)
	return true

func add_threat(threat: int) -> void:
	if not threat in range(GlobalEnums.EnemyType.size()):
		push_error("Invalid threat type provided")
		return

	if not threat in threats:
		threats.append(threat)
		planet_updated.emit("threats", threats)

func remove_threat(threat: int) -> void:
	# Threats can be either EnemyType (for roving threats) or StrifeType.INVASION (for invasion threats)
	if not threat in range(GlobalEnums.EnemyType.size()) and threat != GlobalEnums.StrifeType.INVASION:
		push_error("Invalid threat type provided")
		return

	var idx := threats.find(threat)
	if idx != -1:
		threats.remove_at(idx)
		planet_updated.emit("threats", threats)

func increase_strife() -> void:
	var current_index := strife_level
	if current_index < GlobalEnums.StrifeType.size() - 1:
		strife_level = current_index + 1
		planet_updated.emit("strife_level", strife_level)

func decrease_strife() -> void:
	if strife_level > GlobalEnums.StrifeType.NONE:
		strife_level -= 1
		planet_updated.emit("strife_level", strife_level)

func increase_instability() -> void:
	var current_index := instability
	if current_index < GlobalEnums.StrifeType.size() - 1:
		instability = current_index + 1
		planet_updated.emit("instability", instability)

func decrease_instability() -> void:
	if instability > GlobalEnums.StrifeType.NONE:
		instability -= 1
		planet_updated.emit("instability", instability)

func update_market_price(item_type: int, price: float) -> void:
	if not item_type in range(GlobalEnums.ItemType.size()):
		push_error("Invalid item _type provided")
		return

	market_prices[item_type] = price
	planet_updated.emit("market_prices", market_prices)

func get_market_price(item_type: int) -> float:
	if not item_type in range(GlobalEnums.ItemType.size()):
		push_error("Invalid item _type provided")
		return 0.0

	return market_prices.get(item_type, 0.0)

func has_trait(trait_id: String) -> bool:
	for t in world_traits:
		var typed_t: Variant = t
		if t.trait_id == trait_id:
			return true
	return false

func has_threat(threat: int) -> bool:
	# Threats can be either EnemyType (for roving threats) or StrifeType.INVASION (for invasion threats)
	if not threat in range(GlobalEnums.EnemyType.size()) and threat != GlobalEnums.StrifeType.INVASION:
		push_error("Invalid threat type provided")
		return false

	return threat in threats

func get_resource_amount(resource_type: int) -> int:
	if not resource_type in range(GlobalEnums.ResourceType.size()):
		push_error("Invalid resource type provided")
		return 0

	return resources.get(resource_type, 0)

func add_location(location: Dictionary) -> void:
	if not location in locations:
		locations.append(location)
		planet_updated.emit("locations", locations)

func remove_location(location: Dictionary) -> void:
	var idx = locations.find(location)
	if idx != -1:
		locations.remove_at(idx)
		planet_updated.emit("locations", locations)

func get_location_by_id(location_id: String) -> Dictionary:
	for location in locations:
		var typed_location: Variant = location
		if location.location_id == location_id:
			return location
	return {}

# Serialization
func serialize() -> Dictionary:
	var trait_data: Array = []
	for t in world_traits:
		var typed_t: Variant = t
		var serialized_trait = {}
		if t and t.has_method("serialize"):
			serialized_trait = t.serialize()
		trait_data.append(serialized_trait)

	var threat_keys: Array[String] = []
	for t in threats:
		var typed_t: Variant = t
		# Handle both EnemyType and StrifeType.INVASION threats
		if t == GlobalEnums.StrifeType.INVASION:
			threat_keys.append("INVASION")
		elif t in range(GlobalEnums.EnemyType.size()):
			threat_keys.append(GlobalEnums.EnemyType.keys()[t])

	var location_data: Array = []
	for location in locations:
		var typed_location: Variant = location
		var serialized_location = {}
		if location and location.has_method("serialize"):
			serialized_location = location.serialize()
		location_data.append(serialized_location)

	return {
		"planet_id": planet_id,
		"planet_name": planet_name,
		"sector": sector,
		"coordinates": {"x": coordinates.x, "y": coordinates.y},
		"planet_type": GlobalEnums.PlanetType.keys()[planet_type],
		"description": description,
		"faction_type": GlobalEnums.FactionType.keys()[faction_type],
		"environment_type": GlobalEnums.PlanetEnvironment.keys()[environment_type],
		"world_traits": trait_data,
		"resources": resources,
		"threats": threat_keys,
		"strife_level": GlobalEnums.StrifeType.keys()[strife_level],
		"instability": GlobalEnums.StrifeType.keys()[instability],
		"unity_progress": unity_progress,
		"market_prices": market_prices,
		"faction_control": GlobalEnums.FactionType.keys()[faction_control],
		"locations": location_data,
		"visited": visited,
		"discovered": discovered
	}

static func deserialize(data: Dictionary) -> GamePlanet:
	var planet := GamePlanet.new()

	planet.planet_id = data.get("planet_id", "") as String
	planet.planet_name = data.get("planet_name", "") as String
	planet.sector = data.get("sector", "") as String

	var coords = data.get("coordinates", {})
	planet.coordinates = Vector2(coords.get("x", 0), coords.get("y", 0))

	# Validate and convert enum values
	var planet_type_str: String = data.get("planet_type", "NONE")
	if planet_type_str in GlobalEnums.PlanetType.keys():
		planet.planet_type = GlobalEnums.PlanetType[planet_type_str]

	var faction_type_str: String = data.get("faction_type", "NEUTRAL")
	if faction_type_str in GlobalEnums.FactionType.keys():
		planet.faction_type = GlobalEnums.FactionType[faction_type_str]

	var environment_type_str: String = data.get("environment_type", "NONE")
	if environment_type_str in GlobalEnums.PlanetEnvironment.keys():
		planet.environment_type = GlobalEnums.PlanetEnvironment[environment_type_str]

	planet.description = data.get("description", "") as String

	# Load world traits
	var traits_data = data.get("world_traits", [])
	for trait_data in traits_data:
		var typed_trait_data: Variant = trait_data
		planet.world_traits.append(trait_data)

	planet.resources = data.get("resources", {})

	# Convert and validate threat strings back to enum values
	var threats_data: Array = data.get("threats", [])
	for threat in threats_data:
		var typed_threat: Variant = threat
		# Handle both EnemyType and StrifeType.INVASION threats
		if threat == "INVASION":
			planet.threats.append(GlobalEnums.StrifeType.INVASION)
		elif threat in GlobalEnums.EnemyType.keys():
			planet.threats.append(GlobalEnums.EnemyType[threat])

	var strife_level_str: String = data.get("strife_level", "NONE")
	if strife_level_str in GlobalEnums.StrifeType.keys():
		planet.strife_level = GlobalEnums.StrifeType[strife_level_str]

	var instability_str: String = data.get("instability", "NONE")
	if instability_str in GlobalEnums.StrifeType.keys():
		planet.instability = GlobalEnums.StrifeType[instability_str]

	planet.unity_progress = data.get("unity_progress", 0) as int
	planet.market_prices = data.get("market_prices", {})

	var faction_control_str: String = data.get("faction_control", "NONE")
	if faction_control_str in GlobalEnums.FactionType.keys():
		planet.faction_control = GlobalEnums.FactionType[faction_control_str]

	# Load locations
	var locations_data = data.get("locations", [])
	for location_data in locations_data:
		var typed_location_data: Variant = location_data
		planet.locations.append(location_data)

	planet.visited = data.get("visited", false)
	planet.discovered = data.get("discovered", false)

	return planet
