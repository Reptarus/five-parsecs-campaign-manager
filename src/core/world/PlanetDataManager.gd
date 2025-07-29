@tool
extends Node
class_name PlanetDataManager

## Planet Data Persistence Manager for Five Parsecs Campaign Manager  
## Handles world data storage, progression tracking, and cross-turn persistence

# Safe imports
# GlobalEnums available as autoload singleton
const WorldGenerator = preload("res://src/core/campaign/WorldGenerator.gd")

## Planet data structure for persistence
class PlanetData:
	var id: String
	var name: String
	var type: String
	var type_name: String
	var danger_level: int
	var traits: Array[String] = []
	var locations: Array[Dictionary] = []
	var special_features: Array[String] = []
	
	# Progression tracking
	var discovered_on_turn: int = 0
	var last_visited_turn: int = 0
	var visit_count: int = 0
	var missions_completed: int = 0
	var resources_extracted: int = 0
	var exploration_progress: float = 0.0
	
	# Dynamic state
	var active_modifiers: Array[Dictionary] = []
	var temporary_effects: Array[Dictionary] = []
	var world_events: Array[Dictionary] = []
	var contact_ids: Array[String] = []
	
	# Economic data
	var market_conditions: Dictionary = {}
	var trade_opportunities: Array[Dictionary] = []
	var price_modifiers: Dictionary = {}
	
	func _init(planet_id: String = ""):
		id = planet_id if planet_id != "" else "planet_" + str(Time.get_unix_time_from_system())
		
	func serialize() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"type": type,
			"type_name": type_name,
			"danger_level": danger_level,
			"traits": traits,
			"locations": locations,
			"special_features": special_features,
			"discovered_on_turn": discovered_on_turn,
			"last_visited_turn": last_visited_turn,
			"visit_count": visit_count,
			"missions_completed": missions_completed,
			"resources_extracted": resources_extracted,
			"exploration_progress": exploration_progress,
			"active_modifiers": active_modifiers,
			"temporary_effects": temporary_effects,
			"world_events": world_events,
			"contact_ids": contact_ids,
			"market_conditions": market_conditions,
			"trade_opportunities": trade_opportunities,
			"price_modifiers": price_modifiers
		}
	
	func deserialize(data: Dictionary) -> void:
		id = data.get("id", "")
		name = data.get("name", "")
		type = data.get("type", "")
		type_name = data.get("type_name", "")
		danger_level = data.get("danger_level", 1)
		traits = data.get("traits", [])
		locations = data.get("locations", [])
		special_features = data.get("special_features", [])
		discovered_on_turn = data.get("discovered_on_turn", 0)
		last_visited_turn = data.get("last_visited_turn", 0)
		visit_count = data.get("visit_count", 0)
		missions_completed = data.get("missions_completed", 0)
		resources_extracted = data.get("resources_extracted", 0)
		exploration_progress = data.get("exploration_progress", 0.0)
		active_modifiers = data.get("active_modifiers", [])
		temporary_effects = data.get("temporary_effects", [])
		world_events = data.get("world_events", [])
		contact_ids = data.get("contact_ids", [])
		market_conditions = data.get("market_conditions", {})
		trade_opportunities = data.get("trade_opportunities", [])
		price_modifiers = data.get("price_modifiers", {})

## Planet Data Manager Signals
signal planet_discovered(planet_data: PlanetData)
signal planet_visited(planet_id: String, visit_count: int)
signal planet_data_updated(planet_id: String, update_type: String)
signal world_event_occurred(planet_id: String, event: Dictionary)
signal exploration_progress_updated(planet_id: String, progress: float)

## Data storage
var visited_planets: Dictionary = {} # planet_id -> PlanetData
var current_planet_id: String = ""
var travel_history: Array[Dictionary] = []
var world_generator: WorldGenerator = null

func _ready() -> void:
	world_generator = WorldGenerator.new()
	print("PlanetDataManager: Initialized successfully")

## Generate or retrieve planet data
func get_or_generate_planet(planet_id: String = "", campaign_turn: int = 0) -> PlanetData:
	# If no ID provided, generate new planet
	if planet_id == "":
		return _generate_new_planet(campaign_turn)
	
	# Return existing planet if already visited
	if visited_planets.has(planet_id):
		var planet = visited_planets[planet_id]
		_update_planet_visit(planet, campaign_turn)
		return planet
	
	# Generate planet with specific ID (for testing/forced generation)
	return _generate_new_planet(campaign_turn, planet_id)

## Generate a new planet using WorldGenerator
func _generate_new_planet(campaign_turn: int, forced_id: String = "") -> PlanetData:
	var world_data = world_generator.generate_world(campaign_turn)
	
	var planet = PlanetData.new(forced_id if forced_id != "" else world_data.id)
	planet.name = world_data.name
	planet.type = world_data.type
	planet.type_name = world_data.type_name
	planet.danger_level = world_data.danger_level
	planet.traits = world_data.traits
	planet.locations = world_data.locations
	planet.special_features = world_data.special_features
	planet.discovered_on_turn = campaign_turn
	planet.last_visited_turn = campaign_turn
	planet.visit_count = 1
	
	# Initialize economic data
	_initialize_planet_economy(planet)
	
	# Store planet
	visited_planets[planet.id] = planet
	
	print("PlanetDataManager: Generated new planet %s (Type: %s, Danger: %d)" % [planet.name, planet.type_name, planet.danger_level])
	self.planet_discovered.emit(planet)
	
	return planet

## Initialize planet economic data
func _initialize_planet_economy(planet: PlanetData) -> void:
	# Generate market conditions based on planet type and traits
	planet.market_conditions = {
		"stability": randi_range(1, 6),
		"demand_weapons": _calculate_demand(planet, "weapons"),
		"demand_equipment": _calculate_demand(planet, "equipment"),
		"demand_consumables": _calculate_demand(planet, "consumables"),
		"supply_raw_materials": _calculate_supply(planet, "raw_materials")
	}
	
	# Generate trade opportunities
	_generate_trade_opportunities(planet)

## Calculate demand for specific goods
func _calculate_demand(planet: PlanetData, good_type: String) -> int:
	var base_demand = 3
	
	# Modify based on planet type
	match planet.type:
		"FRONTIER_WORLD":
			if good_type == "weapons": base_demand += 2
			if good_type == "equipment": base_demand += 1
		"INDUSTRIAL_WORLD":
			if good_type == "raw_materials": base_demand += 2
		"TRADE_HUB":
			base_demand += 1 # All goods in higher demand
	
	# Modify based on planet characteristics
	for characteristic in planet.traits:
		match characteristic:
			"DANGEROUS":
				if good_type == "weapons":
					base_demand += 1
			"WEALTHY":
				base_demand += 1
			"POOR":
				base_demand -= 1
	
	return clamp(base_demand, 1, 6)

## Calculate supply for specific goods  
func _calculate_supply(planet: PlanetData, good_type: String) -> int:
	var base_supply = 3
	
	# Modify based on planet type and characteristics
	for characteristic in planet.traits:
		match characteristic:
			"MINING":
				if good_type == "raw_materials":
					base_supply += 2
			"AGRICULTURAL":
				if good_type == "consumables":
					base_supply += 2
	
	return clamp(base_supply, 1, 6)

## Generate trade opportunities for planet
func _generate_trade_opportunities(planet: PlanetData) -> void:
	planet.trade_opportunities.clear()
	
	# Generate 1-3 trade opportunities based on planet characteristics
	var opportunity_count = 1 + randi_range(0, 2)
	
	for i in range(opportunity_count):
		var opportunity = {
			"id": "trade_" + str(Time.get_unix_time_from_system()) + "_" + str(i),
			"type": ["bulk_goods", "rare_items", "contracts", "information"][randi() % 4],
			"profit_potential": randi_range(1, 5),
			"risk_level": randi_range(1, 3),
			"duration": randi_range(1, 3), # Campaign turns
			"requirements": _generate_trade_requirements()
		}
		planet.trade_opportunities.append(opportunity)

## Generate requirements for trade opportunities
func _generate_trade_requirements() -> Dictionary:
	var requirements = {}
	
	if randi_range(1, 6) >= 4: # 50% chance of credit requirement
		requirements["credits"] = randi_range(5, 20)
	
	if randi_range(1, 6) >= 5: # 33% chance of reputation requirement
		requirements["reputation"] = randi_range(1, 3)
	
	if randi_range(1, 6) == 6: # 16% chance of special item requirement
		requirements["special_item"] = "trade_license"
	
	return requirements

## Update planet visit data
func _update_planet_visit(planet: PlanetData, campaign_turn: int) -> void:
	planet.last_visited_turn = campaign_turn
	planet.visit_count += 1
	
	# Record travel history
	var travel_record = {
		"planet_id": planet.id,
		"planet_name": planet.name,
		"turn": campaign_turn,
		"visit_number": planet.visit_count
	}
	travel_history.append(travel_record)
	
	print("PlanetDataManager: Visited %s (Visit #%d)" % [planet.name, planet.visit_count])
	self.planet_visited.emit(planet.id, planet.visit_count)

## Set current planet
func set_current_planet(planet_id: String) -> void:
	current_planet_id = planet_id
	print("PlanetDataManager: Current planet set to %s" % planet_id)

## Get current planet data
func get_current_planet() -> PlanetData:
	if current_planet_id != "" and visited_planets.has(current_planet_id):
		return visited_planets[current_planet_id]
	return null

## Complete mission on planet
func complete_mission(planet_id: String, mission_data: Dictionary) -> void:
	if not visited_planets.has(planet_id):
		return
	
	var planet = visited_planets[planet_id]
	planet.missions_completed += 1
	
	# Update exploration progress
	var exploration_gain = mission_data.get("exploration_value", 0.1)
	planet.exploration_progress = min(1.0, planet.exploration_progress + exploration_gain)
	
	# Award resources if applicable
	var resources_gained = mission_data.get("resources_gained", 0)
	planet.resources_extracted += resources_gained
	
	print("PlanetDataManager: Mission completed on %s (Total: %d)" % [planet.name, planet.missions_completed])
	self.planet_data_updated.emit(planet_id, "mission_completed")
	
	if exploration_gain > 0:
		self.exploration_progress_updated.emit(planet_id, planet.exploration_progress)

## Add world event to planet
func add_world_event(planet_id: String, event: Dictionary) -> void:
	if not visited_planets.has(planet_id):
		return
	
	var planet = visited_planets[planet_id]
	event["timestamp"] = Time.get_unix_time_from_system()
	planet.world_events.append(event)
	
	print("PlanetDataManager: World event on %s: %s" % [planet.name, event.get("type", "unknown")])
	self.world_event_occurred.emit(planet_id, event)

## Apply temporary effect to planet
func apply_temporary_effect(planet_id: String, effect: Dictionary, duration_turns: int) -> void:
	if not visited_planets.has(planet_id):
		return
	
	var planet = visited_planets[planet_id]
	effect["duration"] = duration_turns
	effect["applied_turn"] = planet.last_visited_turn
	planet.temporary_effects.append(effect)
	
	print("PlanetDataManager: Applied temporary effect to %s: %s" % [planet.name, effect.get("type", "unknown")])

## Process turn effects on all planets
func process_turn_effects(current_turn: int) -> void:
	for planet_id in visited_planets:
		var planet = visited_planets[planet_id]
		
		# Remove expired temporary effects
		for i in range(planet.temporary_effects.size() - 1, -1, -1):
			var effect = planet.temporary_effects[i]
			var effect_age = current_turn - effect.get("applied_turn", 0)
			if effect_age >= effect.get("duration", 1):
				planet.temporary_effects.remove_at(i)
				print("PlanetDataManager: Temporary effect expired on %s" % planet.name)
		
		# Update market conditions
		_update_market_conditions(planet)

## Update market conditions for planet
func _update_market_conditions(planet: PlanetData) -> void:
	# Small random fluctuations in market conditions
	for condition in planet.market_conditions:
		var current_value = planet.market_conditions[condition]
		var change = randi_range(-1, 1)
		planet.market_conditions[condition] = clamp(current_value + change, 1, 6)

## Get planet modifier for specific effect
func get_planet_modifier(planet_id: String, effect_type: String) -> float:
	if not visited_planets.has(planet_id):
		return 1.0
	
	var planet = visited_planets[planet_id]
	var modifier = 1.0
	
	# Apply characteristic modifiers
	for characteristic in planet.traits:
		match characteristic:
			"DANGEROUS":
				if effect_type == "danger_level":
					modifier += 0.2
			"WEALTHY":
				if effect_type == "payment":
					modifier += 0.3
			"POOR":
				if effect_type == "payment":
					modifier -= 0.2
			"HIGH_TECH":
				if effect_type == "equipment_cost":
					modifier -= 0.1
			"LOW_TECH":
				if effect_type == "equipment_cost":
					modifier += 0.1
	
	# Apply temporary effects
	for effect in planet.temporary_effects:
		if effect.get("effect_type") == effect_type:
			modifier += effect.get("modifier", 0.0)
	
	return modifier

## Get available contacts on planet
func get_planet_contacts(planet_id: String) -> Array[String]:
	if not visited_planets.has(planet_id):
		return []
	
	return visited_planets[planet_id].contact_ids.duplicate()

## Add contact to planet
func add_contact_to_planet(planet_id: String, contact_id: String) -> void:
	if not visited_planets.has(planet_id):
		return
	
	var planet = visited_planets[planet_id]
	if contact_id not in planet.contact_ids:
		planet.contact_ids.append(contact_id)
		print("PlanetDataManager: Added contact to %s" % planet.name)

## Get exploration opportunities on planet
func get_exploration_opportunities(planet_id: String) -> Array[Dictionary]:
	if not visited_planets.has(planet_id):
		return []
	
	var planet = visited_planets[planet_id]
	var opportunities = []
	
	# Generate opportunities based on unexplored locations
	for location in planet.locations:
		if not location.get("explored", false):
			opportunities.append({
				"location_id": location.get("id", ""),
				"location_name": location.get("name", "Unknown Location"),
				"difficulty": location.get("danger_mod", 0) + planet.danger_level,
				"potential_rewards": _calculate_exploration_rewards(location, planet)
			})
	
	return opportunities

## Calculate potential exploration rewards
func _calculate_exploration_rewards(location: Dictionary, planet: PlanetData) -> Dictionary:
	var rewards = {
		"credits": randi_range(1, 3) * planet.danger_level,
		"equipment_chance": 25 + (planet.danger_level * 5),
		"story_points": 0
	}
	
	# Special location types provide bonuses
	var location_type = location.get("type", "")
	match location_type:
		"RESEARCH_FACILITY":
			rewards.story_points = 1
		"RUINS":
			rewards.equipment_chance += 15
		"MINING_SITE":
			rewards.credits *= 2
	
	return rewards

## Get planet statistics
func get_planet_stats(planet_id: String) -> Dictionary:
	if not visited_planets.has(planet_id):
		return {}
	
	var planet = visited_planets[planet_id]
	return {
		"visit_count": planet.visit_count,
		"missions_completed": planet.missions_completed,
		"resources_extracted": planet.resources_extracted,
		"exploration_progress": planet.exploration_progress,
		"contact_count": planet.contact_ids.size(),
		"active_effects": planet.temporary_effects.size(),
		"trade_opportunities": planet.trade_opportunities.size()
	}

## Serialize all planet data
func serialize_all() -> Dictionary:
	var serialized_planets = {}
	for planet_id in visited_planets:
		serialized_planets[planet_id] = visited_planets[planet_id].serialize()
	
	return {
		"visited_planets": serialized_planets,
		"current_planet_id": current_planet_id,
		"travel_history": travel_history
	}

## Deserialize planet data
func deserialize_all(data: Dictionary) -> void:
	visited_planets.clear()
	travel_history.clear()
	
	var planets_data = data.get("visited_planets", {})
	for planet_id in planets_data:
		var planet = PlanetData.new()
		planet.deserialize(planets_data[planet_id])
		visited_planets[planet_id] = planet
	
	current_planet_id = data.get("current_planet_id", "")
	travel_history = data.get("travel_history", [])

## Get debug info
func get_debug_info() -> Dictionary:
	return {
		"total_planets": visited_planets.size(),
		"current_planet": current_planet_id,
		"travel_history_length": travel_history.size(),
		"total_missions_completed": _calculate_total_missions(),
		"most_visited_planet": _get_most_visited_planet()
	}

func _calculate_total_missions() -> int:
	var total = 0
	for planet in visited_planets.values():
		total += planet.missions_completed
	return total

func _get_most_visited_planet() -> String:
	var max_visits = 0
	var most_visited = ""
	
	for planet in visited_planets.values():
		if planet.visit_count > max_visits:
			max_visits = planet.visit_count
			most_visited = planet.name
	
	return most_visited

## Safe method call helper
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null