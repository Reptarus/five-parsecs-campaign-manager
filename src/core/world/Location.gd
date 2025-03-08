extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GameLocation = preload("res://src/game/world/GameLocation.gd")

# Resource type constants
const RESOURCE_CREDITS = 0
const RESOURCE_SUPPLIES = 1
const RESOURCE_MINERALS = 2
const RESOURCE_TECHNOLOGY = 3
const RESOURCE_MEDICAL_SUPPLIES = 4
const RESOURCE_WEAPONS = 5
const RESOURCE_RARE_MATERIALS = 6
const RESOURCE_LUXURY_GOODS = 7
const RESOURCE_FUEL = 8

# Market state constants
const MARKET_NORMAL = 0
const MARKET_CRISIS = 1
const MARKET_BOOM = 2
const MARKET_RESTRICTED = 3

@export var name: String = ""
@export var coordinates: Vector2 = Vector2.ZERO
@export var type: String = ""
@export var description: String = ""
@export var faction: String = ""
@export var danger_level: int = 1
@export var resources: Dictionary = {}
@export var connected_locations: Array[String] = []
@export var available_missions: Array[Dictionary] = []
@export var local_events: Array[Dictionary] = []
@export var market_modifiers: Dictionary = {}
@export var special_features: Array[String] = []

# Economy and trade
@export var market_state: int = MARKET_NORMAL
@export var trade_goods: Array[Dictionary] = []
@export var black_market_active: bool = false
@export var price_modifiers: Dictionary = {}

# Status and conditions
@export var is_discovered: bool = false
@export var is_accessible: bool = true
@export var current_threats: Array[Dictionary] = []
@export var active_effects: Array[Dictionary] = []

var _patron_name: String
var _location: Resource
var _relationship: int
var _faction_type: GameEnums.FactionType

# The wrapped GameLocation instance
var _game_location: GameLocation

func _init() -> void:
	_game_location = GameLocation.new()
	
	if not resources.is_empty():
		return
		
	resources = {
		RESOURCE_CREDITS: 0,
		RESOURCE_SUPPLIES: 0,
		RESOURCE_MINERALS: 0,
		RESOURCE_TECHNOLOGY: 0,
		RESOURCE_MEDICAL_SUPPLIES: 0,
		RESOURCE_WEAPONS: 0,
		RESOURCE_RARE_MATERIALS: 0,
		RESOURCE_LUXURY_GOODS: 0,
		RESOURCE_FUEL: 0
	}
	
	# Sync with GameLocation
	_sync_to_game_location()

func add_connected_location(location_name: String) -> void:
	if not connected_locations.has(location_name):
		connected_locations.append(location_name)
	
	# Update wrapped GameLocation
	_game_location.add_connected_location(location_name)

func remove_connected_location(location_name: String) -> void:
	connected_locations.erase(location_name)
	
	# Update wrapped GameLocation
	_game_location.remove_connected_location(location_name)

func is_connected_to(location_name: String) -> bool:
	return connected_locations.has(location_name)

func add_mission(mission_data: Dictionary) -> void:
	if not available_missions.has(mission_data):
		available_missions.append(mission_data)
	
	# Update wrapped GameLocation
	# Note: GameLocation expects a mission object, not a dictionary
	# This would need to be converted in a real implementation
	# _game_location.add_mission(convert_mission_data_to_object(mission_data))

func remove_mission(mission_data: Dictionary) -> void:
	available_missions.erase(mission_data)
	
	# Update wrapped GameLocation
	# Note: GameLocation expects a mission ID, not a dictionary
	# This would need to be converted in a real implementation
	# var mission_id = mission_data.get("id", "")
	# _game_location.remove_mission(mission_id)

func add_event(event_data: Dictionary) -> void:
	if not local_events.has(event_data):
		local_events.append(event_data)
	
	# GameLocation doesn't have direct event support, would need custom implementation

func clear_expired_events() -> void:
	var current_events: Array[Dictionary] = []
	for event in local_events:
		if not event.get("expired", false):
			current_events.append(event)
	local_events = current_events
	
	# GameLocation doesn't have direct event support, would need custom implementation

func update_market_state() -> void:
	# Update prices based on market state and modifiers
	for resource in resources.keys():
		var base_price: float = resources[resource]
		var modifier: float = 1.0
		
		# Apply market state modifier
		match market_state:
			MARKET_CRISIS:
				modifier *= 2.0
			MARKET_BOOM:
				modifier *= 0.5
			MARKET_RESTRICTED:
				modifier *= 1.5
		
		# Apply local modifiers
		if resource in market_modifiers:
			modifier *= market_modifiers[resource]
			
		# Update price
		price_modifiers[resource] = modifier
	
	# Update wrapped GameLocation
	# Convert market state to GameLocation market state
	var game_market_state = _convert_market_state(market_state)
	_game_location.market_state = game_market_state
	_game_location.update_market_state()

func _convert_market_state(old_state: int) -> int:
	match old_state:
		MARKET_NORMAL: return GameLocation.MARKET_STATE_NORMAL
		MARKET_CRISIS: return GameLocation.MARKET_STATE_SHORTAGE
		MARKET_BOOM: return GameLocation.MARKET_STATE_BOOM
		MARKET_RESTRICTED: return GameLocation.MARKET_STATE_BLOCKADE
		_: return GameLocation.MARKET_STATE_NORMAL

func get_travel_cost_to(destination: Resource) -> float:
	var base_cost: float = 10.0
	var distance: float = coordinates.distance_to(destination.coordinates)
	var danger_modifier: float = (danger_level + destination.danger_level) * 0.1
	
	return base_cost + (distance * 2) + (base_cost * danger_modifier)

func get_resource_price(resource_type: GameEnums.ResourceType) -> float:
	var base_price: float = resources.get(resource_type, 0)
	var modifier: float = price_modifiers.get(resource_type, 1.0)
	return base_price * modifier

func add_threat(threat_data: Dictionary) -> void:
	if not current_threats.has(threat_data):
		current_threats.append(threat_data)
		# Update danger level based on threats
		danger_level = maxi(danger_level, threat_data.get("threat_level", 1))
	
	# GameLocation doesn't have direct threat support in the same way
	# Would need custom implementation

func remove_threat(threat_data: Dictionary) -> void:
	current_threats.erase(threat_data)
	# Recalculate danger level
	danger_level = 1
	for threat in current_threats:
		danger_level = maxi(danger_level, threat.get("threat_level", 1))
	
	# GameLocation doesn't have direct threat support in the same way
	# Would need custom implementation

func add_special_feature(feature: String) -> void:
	if not special_features.has(feature):
		special_features.append(feature)
	
	# Map to GameLocation world traits
	var trait_id = _convert_feature_to_trait_id(feature)
	if trait_id:
		_game_location.add_world_trait_by_id(trait_id)

func _convert_feature_to_trait_id(feature: String) -> String:
	# Map special features to world trait IDs
	match feature:
		"industrial": return "industrial_hub"
		"frontier": return "frontier_world"
		"trade": return "trade_center"
		"mining": return "mining_world"
		"pirate": return "pirate_haven"
		"free_port": return "free_port"
		"corporate": return "corporate_world"
		_: return ""

func has_special_feature(feature: String) -> bool:
	return special_features.has(feature)

# Sync our state to the wrapped GameLocation
func _sync_to_game_location() -> void:
	_game_location.location_name = name
	_game_location.description = description
	_game_location.coordinates = coordinates
	_game_location.connected_locations = connected_locations
	_game_location.danger_level = danger_level
	_game_location.discovered = is_discovered
	_game_location.black_market_active = black_market_active
	
	# Convert faction to faction_control
	match faction:
		"empire": _game_location.faction_control = GameEnums.FactionType.IMPERIAL
		"rebels": _game_location.faction_control = GameEnums.FactionType.REBEL
		"pirates": _game_location.faction_control = GameEnums.FactionType.PIRATE
		"corporate": _game_location.faction_control = GameEnums.FactionType.CORPORATE
		_: _game_location.faction_control = GameEnums.FactionType.NEUTRAL
	
	# Convert market state
	_game_location.market_state = _convert_market_state(market_state)
	
	# Convert resources
	for resource_type in resources:
		_game_location.resources[resource_type] = resources[resource_type]
	
	# Convert special features to world traits
	for feature in special_features:
		var trait_id = _convert_feature_to_trait_id(feature)
		if trait_id and not _game_location.has_tag(trait_id):
			_game_location.add_world_trait_by_id(trait_id)

## Get the wrapped GameLocation instance
## This allows direct access to the new implementation when needed
func get_game_location() -> GameLocation:
	_sync_to_game_location() # Ensure the GameLocation is up to date
	return _game_location

## Update this location from the wrapped GameLocation
## Call this when you know the GameLocation has been modified externally
func update_from_game_location() -> void:
	name = _game_location.location_name
	description = _game_location.description
	coordinates = _game_location.coordinates
	connected_locations = _game_location.connected_locations
	danger_level = _game_location.danger_level
	is_discovered = _game_location.discovered
	black_market_active = _game_location.black_market_active
	
	# Convert faction_control to faction
	match _game_location.faction_control:
		GameEnums.FactionType.IMPERIAL: faction = "empire"
		GameEnums.FactionType.REBEL: faction = "rebels"
		GameEnums.FactionType.PIRATE: faction = "pirates"
		GameEnums.FactionType.CORPORATE: faction = "corporate"
		_: faction = "neutral"
	
	# Convert market state
	market_state = _convert_game_market_state(_game_location.market_state)
	
	# Update resources
	resources.clear()
	for resource_type in _game_location.resources:
		resources[resource_type] = _game_location.resources[resource_type]
	
	# Update special features based on world traits
	special_features.clear()
	for trait_item in _game_location.world_traits:
		var feature = _convert_trait_id_to_feature(trait_item.trait_id)
		if feature != "" and not feature in special_features:
			special_features.append(feature)

## Convert GameLocation market state to FiveParsecsLocation market state
func _convert_game_market_state(game_state: int) -> int:
	match game_state:
		GameLocation.MARKET_STATE_NORMAL: return MARKET_NORMAL
		GameLocation.MARKET_STATE_SHORTAGE: return MARKET_CRISIS
		GameLocation.MARKET_STATE_BOOM: return MARKET_BOOM
		GameLocation.MARKET_STATE_BLOCKADE: return MARKET_RESTRICTED
		_: return MARKET_NORMAL

## Convert trait ID to feature string
func _convert_trait_id_to_feature(trait_id: String) -> String:
	match trait_id:
		"industrial_hub": return "industrial"
		"frontier_world": return "frontier"
		"trade_center": return "trade"
		"mining_world": return "mining"
		"pirate_haven": return "pirate"
		"free_port": return "free_port"
		"corporate_world": return "corporate"
		_: return ""

func serialize() -> Dictionary:
	# First, sync our state to the GameLocation
	_sync_to_game_location()
	
	# Then serialize using the old format
	var data = {
		"name": name,
		"coordinates": {"x": coordinates.x, "y": coordinates.y},
		"type": type,
		"description": description,
		"faction": faction,
		"danger_level": danger_level,
		"resources": resources,
		"connected_locations": connected_locations,
		"available_missions": available_missions,
		"local_events": local_events,
		"market_modifiers": market_modifiers,
		"special_features": special_features,
		"market_state": market_state,
		"trade_goods": trade_goods,
		"black_market_active": black_market_active,
		"price_modifiers": price_modifiers,
		"is_discovered": is_discovered,
		"is_accessible": is_accessible,
		"current_threats": current_threats,
		"active_effects": active_effects,
		# Include GameLocation data for future compatibility
		"game_location_data": _game_location.serialize()
	}
	
	return data

static func deserialize(data: Dictionary) -> Resource:
	var location = load("res://src/core/world/Location.gd").new()
	location.name = data.get("name", "")
	location.coordinates = Vector2(data.get("coordinates", {}).get("x", 0), data.get("coordinates", {}).get("y", 0))
	location.type = data.get("type", "")
	location.description = data.get("description", "")
	location.faction = data.get("faction", "")
	location.danger_level = data.get("danger_level", 1)
	location.resources = data.get("resources", {})
	location.connected_locations = data.get("connected_locations", [])
	location.available_missions = data.get("available_missions", [])
	location.local_events = data.get("local_events", [])
	location.market_modifiers = data.get("market_modifiers", {})
	location.special_features = data.get("special_features", [])
	location.market_state = data.get("market_state", MARKET_NORMAL)
	location.trade_goods = data.get("trade_goods", [])
	location.black_market_active = data.get("black_market_active", false)
	location.price_modifiers = data.get("price_modifiers", {})
	location.is_discovered = data.get("is_discovered", false)
	location.is_accessible = data.get("is_accessible", true)
	location.current_threats = data.get("current_threats", [])
	location.active_effects = data.get("active_effects", [])
	
	# If there's GameLocation data, deserialize it
	if data.has("game_location_data"):
		location._game_location = preload("res://src/game/world/GameLocation.gd").deserialize(data.get("game_location_data"))
	else:
		# Otherwise, sync our state to the GameLocation
		location._sync_to_game_location()
	
	return location
