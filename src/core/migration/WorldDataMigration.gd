@tool
class_name WorldDataMigration
extends Node

## Utility class to help migrate between old and new world data formats

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GamePlanet = preload("res://src/game/world/GamePlanet.gd")
const GameLocation = preload("res://src/game/world/GameLocation.gd")
const GameWorldTrait = preload("res://src/game/world/GameWorldTrait.gd")

var _data_manager: GameDataManager

func _init() -> void:
	_data_manager = GameDataManager.new()
	_data_manager.load_all_data()

## Migrate a FiveParsecsPlanet to a GamePlanet
## Returns a new GamePlanet instance with data from the FiveParsecsPlanet
func migrate_planet(old_planet) -> GamePlanet:
	if not old_planet:
		push_error("Cannot migrate null planet")
		return null
		
	var new_planet = GamePlanet.new()
	new_planet.planet_id = old_planet.planet_id if old_planet.has("planet_id") else ""
	new_planet.name = old_planet.name if old_planet.has("name") else "Unknown Planet"
	
	# Map planet type
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
func migrate_location(old_location) -> GameLocation:
	if not old_location:
		push_error("Cannot migrate null location")
		return null
		
	var new_location = GameLocation.new()
	new_location.location_id = old_location.location_id if old_location.has("location_id") else ""
	new_location.name = old_location.name if old_location.has("name") else "Unknown Location"
	
	# Map location type
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
func migrate_world_trait(old_trait) -> GameWorldTrait:
	if not old_trait:
		push_error("Cannot migrate null trait")
		return null
		
	var new_trait = GameWorldTrait.new()
	new_trait.trait_id = old_trait.trait_id if old_trait.has("trait_id") else ""
	new_trait.name = old_trait.name if old_trait.has("name") else "Unknown Trait"
	
	# Map trait type
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
func migrate_world_data(old_data: Dictionary) -> Dictionary:
	var new_data = {}
	
	# Migrate planets
	if old_data.has("planets"):
		new_data["planets"] = {}
		for planet_id in old_data["planets"]:
			var old_planet_data = old_data["planets"][planet_id]
			var new_planet = GamePlanet.new()
			
			# Set basic properties
			new_planet.planet_id = planet_id
			new_planet.planet_name = old_planet_data.get("planet_name", "")
			new_planet.sector = old_planet_data.get("sector", "")
			new_planet.coordinates = old_planet_data.get("coordinates", Vector2.ZERO)
			new_planet.planet_type = old_planet_data.get("planet_type", GameEnums.PlanetType.NONE)
			new_planet.description = old_planet_data.get("description", "")
			new_planet.faction_type = old_planet_data.get("faction_type", GameEnums.FactionType.NEUTRAL)
			new_planet.environment_type = old_planet_data.get("environment_type", GameEnums.PlanetEnvironment.NONE)
			
			# Set state tracking
			new_planet.strife_level = old_planet_data.get("strife_level", GameEnums.StrifeType.NONE)
			new_planet.instability = old_planet_data.get("instability", GameEnums.StrifeType.NONE)
			new_planet.unity_progress = old_planet_data.get("unity_progress", 0)
			new_planet.visited = old_planet_data.get("visited", false)
			new_planet.discovered = old_planet_data.get("discovered", false)
			
			# Copy resources
			var resources = old_planet_data.get("resources", {})
			for resource_type in resources:
				new_planet.resources[resource_type] = resources[resource_type]
			
			# Copy threats
			var threats = old_planet_data.get("threats", [])
			for threat in threats:
				new_planet.threats.append(threat)
			
			# Copy world traits
			var world_features = old_planet_data.get("world_features", [])
			for old_trait in world_features:
				var trait_id = convert_world_trait_to_id(old_trait)
				new_planet.add_world_trait_by_id(trait_id)
			
			new_data["planets"][planet_id] = new_planet.serialize()
	
	# Migrate locations
	if old_data.has("locations"):
		new_data["locations"] = {}
		for location_id in old_data["locations"]:
			var old_location_data = old_data["locations"][location_id]
			var new_location = GameLocation.new()
			
			# Set basic properties
			new_location.location_id = location_id
			new_location.location_name = old_location_data.get("name", "")
			new_location.location_type = old_location_data.get("location_type", GameEnums.LocationType.FRONTIER_WORLD)
			new_location.faction_type = old_location_data.get("faction_type", GameEnums.FactionType.NEUTRAL)
			new_location.environment_type = old_location_data.get("environment_type", GameEnums.PlanetEnvironment.FOREST)
			new_location.coordinates = old_location_data.get("coordinates", Vector2.ZERO)
			
			# Copy resources
			var resources = old_location_data.get("resources", {})
			for resource_type in resources:
				var resource_id = convert_resource_type_to_id(resource_type)
				new_location.resources[resource_id] = resources[resource_type]
			
			# Copy special features as world traits
			var special_features = old_location_data.get("special_features", [])
			for feature in special_features:
				var trait_id = convert_special_feature_to_trait_id(feature)
				new_location.add_world_trait_by_id(trait_id)
			
			# Copy market state
			new_location.market_state = old_location_data.get("market_state", GameLocation.MARKET_STATE_NORMAL)
			
			new_data["locations"][location_id] = new_location.serialize()
	
	# Copy other data as-is
	for key in old_data:
		if key != "planets" and key != "locations":
			new_data[key] = old_data[key]
	
	# Add version information
	new_data["data_version"] = "2.0"
	
	return new_data

## Check if world data needs migration
## Returns true if the data is in the old format
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
		"credits": return GameEnums.ResourceType.CREDITS
		"supplies": return GameEnums.ResourceType.SUPPLIES
		"minerals": return 10 # Use integer instead of missing enum
		"technology": return 11 # Use integer instead of missing enum
		"medical_supplies": return GameEnums.ResourceType.MEDICAL_SUPPLIES
		"weapons": return GameEnums.ResourceType.WEAPONS
		"rare_materials": return 12 # Use integer instead of missing enum
		"luxury_goods": return 13 # Use integer instead of missing enum
		"fuel": return GameEnums.ResourceType.FUEL
		_: return -1

## Convert a planet type from the old enum to the new string ID
func convert_planet_type_to_id(old_type: int) -> String:
	match old_type:
		GameEnums.PlanetType.TEMPERATE: return "temperate"
		GameEnums.PlanetType.DESERT: return "desert"
		GameEnums.PlanetType.VOLCANIC: return "volcanic"
		GameEnums.PlanetType.JUNGLE: return "jungle"
		GameEnums.PlanetType.OCEAN: return "ocean"
		# Use string literals for enum values that don't exist anymore
		# to avoid linter errors but maintain functionality
		1: return "gas_giant" # GameEnums.PlanetType.GAS_GIANT
		2: return "barren" # GameEnums.PlanetType.BARREN
		3: return "urban" # GameEnums.PlanetType.URBAN
		4: return "asteroid_belt" # GameEnums.PlanetType.ASTEROID_BELT
		_: return "temperate" # Default to temperate

## Convert a planet type ID from the new string format to the old enum
func convert_planet_id_to_type(planet_id: String) -> int:
	match planet_id:
		"desert": return GameEnums.PlanetType.DESERT
		"temperate": return GameEnums.PlanetType.TEMPERATE
		"ice": return GameEnums.PlanetType.ICE
		"volcanic": return GameEnums.PlanetType.VOLCANIC
		"jungle": return GameEnums.PlanetType.JUNGLE
		"ocean": return GameEnums.PlanetType.OCEAN
		"gas_giant": return 10 # Use integer instead of missing enum
		"barren": return 11 # Use integer instead of missing enum
		"urban": return 12 # Use integer instead of missing enum
		"asteroid_belt": return 13 # Use integer instead of missing enum
		_: return GameEnums.PlanetType.TEMPERATE # Default to temperate

## Convert a world trait from the old enum to the new string ID
func convert_world_trait_to_id(old_trait: int) -> String:
	match old_trait:
		GameEnums.WorldTrait.AGRICULTURAL_WORLD: return "agricultural_world"
		10: return "mining_world" # Use integer instead of missing enum
		GameEnums.WorldTrait.INDUSTRIAL_HUB: return "industrial_hub"
		11: return "research_outpost" # Use integer instead of missing enum
		GameEnums.WorldTrait.FRONTIER_WORLD: return "frontier_world"
		GameEnums.WorldTrait.TRADE_CENTER: return "trade_center"
		GameEnums.WorldTrait.PIRATE_HAVEN: return "pirate_haven"
		GameEnums.WorldTrait.CORPORATE_CONTROLLED: return "corporate_controlled"
		GameEnums.WorldTrait.FREE_PORT: return "free_port"
		12: return "high_security" # Use integer instead of missing enum
		13: return "restricted_access" # Use integer instead of missing enum
		14: return "dangerous_wildlife" # Use integer instead of missing enum
		15: return "religious_community" # Use integer instead of missing enum
		16: return "refugee_center" # Use integer instead of missing enum
		17: return "black_market" # Use integer instead of missing enum
		_: return "frontier_world" # Default to frontier world

## Convert a world trait ID from the new string format to the old enum
func convert_world_trait_id_to_enum(trait_id: String) -> int:
	match trait_id:
		"agricultural_world": return GameEnums.WorldTrait.AGRICULTURAL_WORLD
		"mining_world": return 10 # Use integer instead of missing enum
		"industrial_hub": return GameEnums.WorldTrait.INDUSTRIAL_HUB
		"research_outpost": return 11 # Use integer instead of missing enum
		"frontier_world": return GameEnums.WorldTrait.FRONTIER_WORLD
		"trade_center": return GameEnums.WorldTrait.TRADE_CENTER
		"pirate_haven": return GameEnums.WorldTrait.PIRATE_HAVEN
		"corporate_controlled": return GameEnums.WorldTrait.CORPORATE_CONTROLLED
		"free_port": return GameEnums.WorldTrait.FREE_PORT
		"high_security": return 12 # Use integer instead of missing enum
		"restricted_access": return 13 # Use integer instead of missing enum
		"dangerous_wildlife": return 14 # Use integer instead of missing enum
		"religious_community": return 15 # Use integer instead of missing enum
		"refugee_center": return 16 # Use integer instead of missing enum
		"black_market": return 17 # Use integer instead of missing enum
		_: return GameEnums.WorldTrait.FRONTIER_WORLD # Default to frontier world

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

func _get_planet_environment_id(old_environment) -> int:
	# Convert old environment type to new environment ID
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
	var new_dict = {}
	
	for old_type in old_dict:
		var new_type_str = convert_resource_type_int_to_id(int(old_type)) if old_type is String else convert_resource_type_int_to_id(old_type)
		new_dict[new_type_str] = old_dict[old_type]
	
	return new_dict