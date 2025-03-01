class_name CoreWorld
extends BaseWorld

## Core implementation of BaseWorld for Five Parsecs From Home
##
## Adds game-specific features like terrain types, factions, resources, etc.

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Core-specific properties
var terrain_type: int = GameEnums.TerrainType.CITY
var faction_type: int = GameEnums.FactionType.NEUTRAL
var strife_level: int = GameEnums.StrifeType.NONE
var world_features: Array[int] = []
var resources: Dictionary = {}
var market_prices: Dictionary = {}

# Resource Types
const RESOURCE_TYPES := {
	"fuel": GameEnums.ResourceType.FUEL,
	"supplies": GameEnums.ResourceType.FOOD,
	"medical": GameEnums.ResourceType.MEDICAL,
	"ammo": GameEnums.ResourceType.AMMO,
	"spare_parts": GameEnums.ResourceType.PARTS
}

# Economy Constants
const BASE_PRICES := {
	"fuel": 50,
	"supplies": 75,
	"medical": 100,
	"ammo": 125,
	"spare_parts": 150
}

# --- Core-specific functionality ---

## Initialize the world with Five Parsecs-specific properties
func initialize_world(name: String, terrain: int, faction: int) -> void:
	super.initialize(name)
	terrain_type = terrain
	faction_type = faction
	_initialize_resources()
	_initialize_market()

## Set the world's terrain type
func set_terrain_type(type: int) -> void:
	terrain_type = type
	set_property("terrain_type", type)

## Set the world's faction
func set_faction_type(faction: int) -> void:
	faction_type = faction
	set_property("faction_type", faction)

## Set the world's strife level
func set_strife_level(strife: int) -> void:
	strife_level = strife
	set_property("strife_level", strife)

## Add a world feature
func add_world_feature(feature: int) -> void:
	if not world_features.has(feature):
		world_features.append(feature)
		set_property("world_features", world_features)

## Remove a world feature
func remove_world_feature(feature: int) -> void:
	if world_features.has(feature):
		world_features.erase(feature)
		set_property("world_features", world_features)

## Set the amount of a resource
func set_resource(resource_type: int, amount: int) -> void:
	resources[resource_type] = amount
	set_property("resources", resources)

## Get the amount of a resource, with an optional default value
func get_resource(resource_type: int, default_value: int = 0) -> int:
	return resources.get(resource_type, default_value)

## Set the market price for an item
func set_market_price(item_type: String, price: int) -> void:
	market_prices[item_type] = price
	set_property("market_prices", market_prices)

## Get the market price for an item, with an optional default value
func get_market_price(item_type: String, default_value: int = 0) -> int:
	return market_prices.get(item_type, default_value)

## Get a description of the world including Five Parsecs-specific details
func get_world_info() -> String:
	return "World: %s\nTerrain: %s\nFaction: %s\nStrife Level: %s" % [
		world_name,
		GameEnums.TerrainType.keys()[terrain_type],
		GameEnums.FactionType.keys()[faction_type],
		GameEnums.StrifeType.keys()[strife_level]
	]

## Initialize default resources
func _initialize_resources() -> void:
	for resource_type in RESOURCE_TYPES.values():
		resources[resource_type] = 0

## Initialize default market prices
func _initialize_market() -> void:
	for item_type in BASE_PRICES:
		market_prices[item_type] = BASE_PRICES[item_type]