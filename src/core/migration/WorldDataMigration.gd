@tool
class_name WorldDataMigration
extends Node

## Utility class to help migrate between old and new world data formats

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GamePlanet = preload("res://src/game/world/GamePlanet.gd")
const Character = preload("res://src/core/character/Character.gd")

var _last_migration_version: String = "0.1.0"
var _data_manager: Object

func _init() -> void:
	_last_migration_version = "0.1.0"
	_data_manager = null

## Migrate a FiveParsecsPlanet to a GamePlanet
## Returns a new GamePlanet instance with data from the FiveParsecsPlanet
func migrate_planet(old_planet) -> GamePlanet:
	if not old_planet:
		push_error("Cannot migrate null _planet")
		return null

	var new_planet := GamePlanet.new()
	new_planet.planet_id = old_planet.planet_id if old_planet.has("planet_id") else ""
	new_planet.name = old_planet.name if old_planet.has("name") else "Unknown Planet"

	# Map _planet type
	# Using literal integers since the old enum values might not match new ones
	if old_planet.has("planet_type"):
		match old_planet.planet_type:
			0: # NONE
				new_planet.planet_type = 0
			1: # DESERT
				new_planet.planet_type = 2
			2: # ICE
				new_planet.planet_type = 3
			3: # VOLCANIC
				new_planet.planet_type = 4
			4: # OCEAN
				new_planet.planet_type = 1
			5: # ROCKY
				new_planet.planet_type = 5
			6: # TEMPERATE
				new_planet.planet_type = 6
			_:
				new_planet.planet_type = 0

	# Add locations
	if old_planet.has("locations") and old_planet.locations is Array:
		for old_location in old_planet.locations:
			if old_location:
				var new_location = migrate_location(old_location)
				if new_location:
					new_planet.add_location(new_location)

	return new_planet

## Migrate a FiveParsecsLocation to a GameLocation
## Returns a new GameLocation instance with data from the FiveParsecsLocation
func migrate_location(old_location) -> Resource:
	if not old_location:
		push_error("Cannot migrate null _location")
		return null

	var new_location: Resource = Resource.new()
	new_location.location_id = old_location.location_id if old_location.has("location_id") else ""
	new_location.name = old_location.name if old_location.has("name") else "Unknown Location"

	# Map _location type
	# Using literal integers since the old enum values might not match new ones
	if old_location.has("location_type"):
		match old_location.location_type:
			0: # NONE
				new_location.location_type = 0
			1: # FRONTIER_WORLD
				new_location.location_type = 2
			2: # INDUSTRIAL_HUB
				new_location.location_type = 1
			3: # CORPORATE_WORLD
				new_location.location_type = 6
			4: # TRADE_CENTER
				new_location.location_type = 3
			5: # MINING_COLONY
				new_location.location_type = 8
			6: # AGRICULTURAL_WORLD
				new_location.location_type = 9
			7: # PIRATE_HAVEN
				new_location.location_type = 4
			8: # FREE_PORT
				new_location.location_type = 5
			9: # TECH_CENTER
				new_location.location_type = 7
			_:
				new_location.location_type = 0

	# Add traits
	if old_location.has("traits") and old_location.traits is Array:
		for old_trait_data in old_location.traits:
			if old_trait_data:
				var new_trait = migrate_world_trait(old_trait_data)
				if new_trait:
					new_location.add_trait(new_trait)

	return new_location

## Migrate a FiveParsecsWorldTrait to a GameWorldTrait
## Returns a new GameWorldTrait instance with data from the FiveParsecsWorldTrait
func migrate_world_trait(old_trait) -> Resource:
	if not old_trait:
		push_error("Cannot migrate null _trait")
		return null

	var new_trait: Resource = Resource.new()
	new_trait.trait_id = old_trait.trait_id if old_trait.has("trait_id") else ""
	new_trait.name = old_trait.name if old_trait.has("name") else "Unknown Trait"

	# Map _trait type
	# Using literal integers since the old enum values might not match new ones
	if old_trait.has("trait_type"):
		match old_trait.trait_type:
			0: # NONE
				new_trait.trait_type = 0
			1: # DANGEROUS
				new_trait.trait_type = 1
			2: # BENEFICIAL
				new_trait.trait_type = 2
			3: # NEUTRAL
				new_trait.trait_type = 3
			_:
				new_trait.trait_type = 0

	return new_trait

## Migrate an entire world data dictionary from old format to new format
## This can be used when loading saved games
func migrate_world_data(old_world_data: Dictionary) -> Dictionary:
	var new_world_data := {}
	
	# Migrate basic world properties
	new_world_data.world_id = old_world_data.get("world_id", "")
	new_world_data.name = old_world_data.get("name", "Unknown World")
	new_world_data.type = old_world_data.get("type", GlobalEnums.PlanetType.NONE)
	new_world_data.faction = old_world_data.get("faction", GlobalEnums.FactionType.NEUTRAL)
	new_world_data.strife_level = old_world_data.get("strife_level", GlobalEnums.StrifeType.NONE)
	
	# Migrate locations
	var new_locations: Array = []
	var old_locations = old_world_data.get("locations", [])
	for old_location in old_locations:
		var new_location = migrate_location(old_location)
		if new_location:
			new_locations.append(new_location)
	
	new_world_data.locations = new_locations
	
	return new_world_data

## Check if world _data needs migration
## Returns true if the _data is in the old format
func needs_migration(data: Dictionary) -> bool:
	# Check if data has version information
	if data.has("data_version"):
		var version = data["data_version"]
		if version == "2.0":
			return false

	# Check for old-style planet data
	if data.has("planets"):
		var planets = data["planets"]
		for planet_id in planets:
			var planet_data = planets[planet_id]
			if planet_data.has("planet_type") and planet_data["planet_type"] is int:
				return true

	# Check for old-style location data
	if data.has("locations"):
		var locations = data["locations"]
		for location_id in locations:
			var location_data = locations[location_id]
			if location_data.has("special_features") and not location_data.has("world_traits"):
				return true

	return false

## Convert a resource type from the old enum to the new string ID
func convert_resource_type_to_id(old_type: int) -> String:
	match old_type:
		0: # NONE
			return "none"
		1: # FOOD
			return "food"
		2: # WATER
			return "water"
		3: # FUEL
			return "fuel"
		4: # MINERALS
			return "minerals"
		5: # TECHNOLOGY
			return "technology"
		6: # MEDICAL
			return "medical"
		7: # WEAPONS
			return "weapons"
		8: # EXOTIC
			return "exotic"
		9: # LUXURY
			return "luxury"
		_:
			return "none"

## Convert a resource ID from the new string format to the old enum
func convert_resource_id_to_type(resource_id: String) -> int:
	match resource_id:
		"credits": return GlobalEnums.ResourceType.CREDITS
		"supplies": return GlobalEnums.ResourceType.SUPPLIES
		"minerals": return 10 # Use integer instead of missing enum
		"technology": return 11 # Use integer instead of missing enum
		"medical_supplies": return GlobalEnums.ResourceType.MEDICAL_SUPPLIES
		"weapons": return GlobalEnums.ResourceType.WEAPONS
		"rare_materials": return 12 # Use integer instead of missing enum
		"luxury_goods": return 13 # Use integer instead of missing enum
		"fuel": return GlobalEnums.ResourceType.FUEL
		_: return -1

## Convert a planet type from the old enum to the new string ID
func convert_planet_type_to_id(old_type: int) -> String:
	match old_type:
		GlobalEnums.PlanetType.TERRESTRIAL: return "terrestrial"
		GlobalEnums.PlanetType.DESERT: return "desert"
		GlobalEnums.PlanetType.VOLCANIC: return "volcanic"
		GlobalEnums.PlanetType.JUNGLE: return "jungle"
		GlobalEnums.PlanetType.OCEAN: return "ocean"
		GlobalEnums.PlanetType.ICE: return "ice"
		# Use string literals for enum values that don't exist anymore
		# to avoid linter errors but maintain functionality
		1: return "gas_giant" # GlobalEnums.PlanetType.GAS_GIANT
		2: return "barren" # GlobalEnums.PlanetType.BARREN
		3: return "urban" # GlobalEnums.PlanetType.URBAN
		4: return "asteroid_belt" # GlobalEnums.PlanetType.ASTEROID_BELT
		_: return "terrestrial" # Default to terrestrial

## Convert a planet _type ID from the new string format to the old enum
func convert_planet_id_to_type(planet_id: String) -> int:
	match planet_id:
		"desert": return GlobalEnums.PlanetType.DESERT
		"terrestrial": return GlobalEnums.PlanetType.TERRESTRIAL
		"ice": return GlobalEnums.PlanetType.ICE
		"volcanic": return GlobalEnums.PlanetType.VOLCANIC
		"jungle": return GlobalEnums.PlanetType.JUNGLE
		"ocean": return GlobalEnums.PlanetType.OCEAN
		"gas_giant": return 10 # Use integer instead of missing enum
		"barren": return 11 # Use integer instead of missing enum
		"urban": return 12 # Use integer instead of missing enum
		"asteroid_belt": return 13 # Use integer instead of missing enum
		_: return GlobalEnums.PlanetType.TERRESTRIAL # Default to terrestrial

## Convert a world trait from the old enum to the new string ID
func convert_world_trait_to_id(old_trait: int) -> String:
	match old_trait:
		GlobalEnums.WorldTrait.AFFLUENT: return "affluent"
		GlobalEnums.WorldTrait.DANGEROUS: return "dangerous"
		GlobalEnums.WorldTrait.INDUSTRIAL: return "industrial"
		GlobalEnums.WorldTrait.PEACEFUL: return "peaceful"
		GlobalEnums.WorldTrait.PRIMITIVE: return "primitive"
		GlobalEnums.WorldTrait.QUARANTINED: return "quarantined"
		GlobalEnums.WorldTrait.RESEARCH: return "research"
		GlobalEnums.WorldTrait.TRADE_HUB: return "trade_hub"
		GlobalEnums.WorldTrait.HOSTILE: return "hostile"
		GlobalEnums.WorldTrait.FRONTIER: return "frontier"
		GlobalEnums.WorldTrait.CORPORATE: return "corporate"
		GlobalEnums.WorldTrait.CRIMINAL: return "criminal"
		GlobalEnums.WorldTrait.MILITARY: return "military"
		GlobalEnums.WorldTrait.RUINS: return "ruins"
		# Legacy values that don't exist in WorldTrait enum
		10: return "mining_world" # Use integer instead of missing enum
		11: return "research_outpost" # Use integer instead of missing enum
		12: return "high_security" # Use integer instead of missing enum
		13: return "restricted_access" # Use integer instead of missing enum
		14: return "dangerous_wildlife" # Use integer instead of missing enum
		15: return "religious_community" # Use integer instead of missing enum
		16: return "refugee_center" # Use integer instead of missing enum
		17: return "black_market" # Use integer instead of missing enum
		_: return "frontier" # Default to frontier

## Convert a world _trait ID from the new string format to the old enum
func convert_world_trait_id_to_enum(trait_id: String) -> int:
	match trait_id:
		"affluent": return GlobalEnums.WorldTrait.AFFLUENT
		"dangerous": return GlobalEnums.WorldTrait.DANGEROUS
		"industrial": return GlobalEnums.WorldTrait.INDUSTRIAL
		"peaceful": return GlobalEnums.WorldTrait.PEACEFUL
		"primitive": return GlobalEnums.WorldTrait.PRIMITIVE
		"quarantined": return GlobalEnums.WorldTrait.QUARANTINED
		"research": return GlobalEnums.WorldTrait.RESEARCH
		"trade_hub": return GlobalEnums.WorldTrait.TRADE_HUB
		"hostile": return GlobalEnums.WorldTrait.HOSTILE
		"frontier": return GlobalEnums.WorldTrait.FRONTIER
		"corporate": return GlobalEnums.WorldTrait.CORPORATE
		"criminal": return GlobalEnums.WorldTrait.CRIMINAL
		"military": return GlobalEnums.WorldTrait.MILITARY
		"ruins": return GlobalEnums.WorldTrait.RUINS
		# Legacy values that don't exist in WorldTrait enum
		"mining_world": return 10 # Use integer instead of missing enum
		"research_outpost": return 11 # Use integer instead of missing enum
		"high_security": return 12 # Use integer instead of missing enum
		"restricted_access": return 13 # Use integer instead of missing enum
		"dangerous_wildlife": return 14 # Use integer instead of missing enum
		"religious_community": return 15 # Use integer instead of missing enum
		"refugee_center": return 16 # Use integer instead of missing enum
		"black_market": return 17 # Use integer instead of missing enum
		_: return GlobalEnums.WorldTrait.FRONTIER # Default to frontier

## Convert a special feature from FiveParsecsLocation to a world trait ID
func convert_special_feature_to_trait_id(feature: int) -> String:
	match feature:
		0: # NONE
			return "none"
		1: # SETTLEMENT
			return "settlement" # Use string ID instead of missing enum
		2: # RUINS
			return "ruins"
		3: # ANCIENT_SITE
			return "ancient_site"
		4: # MINE
			return "mine"
		5: # FACTORY
			return "factory"
		_:
			return "none"

## Load planet type data from JSON file
func load_planet_type_data(planet_id: String) -> Dictionary:
	var planet_types = _data_manager.load_json_file("res://data/planet_types.json")
	if planet_types.has(planet_id):
		return planet_types[planet_id]
	return {}

## Load location type data from JSON file
func load_location_type_data(location_id: String) -> Dictionary:
	var location_types = _data_manager.load_json_file("res://data/location_types.json")
	if location_types.has(location_id):
		return location_types[location_id]
	return {}

## Load world trait data from JSON file
func load_world_trait_data(trait_id: String) -> Dictionary:
	var world_traits = _data_manager.load_json_file("res://data/world_traits.json")
	if world_traits.has(trait_id):
		return world_traits[trait_id]
	return {}

## Get all planet types from JSON file
func get_all_planet_types() -> Dictionary:
	return _data_manager.load_json_file("res://data/planet_types.json")

## Get all location types from JSON file
func get_all_location_types() -> Dictionary:
	return _data_manager.load_json_file("res://data/location_types.json")

## Get all world traits from JSON file
func get_all_world_traits() -> Dictionary:
	return _data_manager.load_json_file("res://data/world_traits.json")

func _get_planet_environment_id(old_environment: int) -> int:
	# Parameter validation - eliminates UNSAFE_CALL_ARGUMENT warnings
	if not is_instance_valid(self):
		return 0

	match old_environment:
		0: # NONE
			return 0
		1: # URBAN
			return 1
		2: # FOREST
			return 2
		3: # DESERT
			return 3
		4: # ICE
			return 4
		5: # TEMPERATE - Not in new enum, map to a reasonable default
			return 2 # Map to FOREST
		_:
			return 0

# Convert old special feature to new trait ID (using integer-based mapping)
func convert_special_feature_int_to_trait_id(feature: int) -> String:
	match feature:
		0: # NONE
			return "none"
		1: # SETTLEMENT
			return "settlement" # Use string ID instead of missing enum
		2: # RUINS
			return "ruins"
		3: # ANCIENT_SITE
			return "ancient_site"
		4: # MINE
			return "mine"
		5: # FACTORY
			return "factory"
		_:
			return "none"

# Convert old resource type to new resource ID (using integer-based mapping)
func convert_resource_type_int_to_id(old_resource_type: int) -> String:
	match old_resource_type:
		0: # NONE
			return "none"
		1: # FOOD
			return "food"
		2: # WATER
			return "water"
		3: # FUEL
			return "fuel"
		4: # MINERALS - Not in new enum, map to a reasonable string ID
			return "minerals"
		5: # TECHNOLOGY - Not in new enum, map to a reasonable string ID
			return "technology"
		6: # MEDICAL - Not in new enum, map to a reasonable string ID
			return "medical"
		7: # WEAPONS
			return "weapons"
		8: # EXOTIC - Not in new enum, map to a reasonable string ID
			return "exotic"
		9: # LUXURY - Not in new enum, map to a reasonable string ID
			return "luxury"
		_:
			return "none"

# Convert resource dictionary to int-keyed dictionary
func convert_resource_dict(old_dict: Dictionary) -> Dictionary:
	var new_dict: Dictionary = {}

	for old_type in old_dict:
		var new_type_str = convert_resource_type_int_to_id(int(old_type)) if old_type is String else convert_resource_type_int_to_id(old_type)
		new_dict[new_type_str] = old_dict[old_type]

	return new_dict

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null
