extends Resource
class_name FiveParsecsCampaignDataResource

## Five Parsecs Campaign Data Resource
## Consolidated world, mission, and campaign progression data using Godot Resources
## Framework Bible compliant: Simple campaign management data
## Replaces complex JSON loading with type-safe resources

## Schema version for save file migration (CRITICAL for data integrity)
@export var schema_version: int = 1

# World and location data
@export var world_traits: Array[Dictionary] = []
@export var planet_types: Array[Dictionary] = []
@export var location_types: Array[Dictionary] = []

# Campaign progression data
@export var victory_conditions: Array[Dictionary] = []
@export var campaign_events: Array[Dictionary] = []
@export var character_events: Array[Dictionary] = []

# Faction and relationship data
@export var patron_types: Array[Dictionary] = []
@export var rival_types: Array[Dictionary] = []
@export var faction_data: Array[Dictionary] = []

# Economy and trading data
@export var trade_goods: Array[Dictionary] = []
@export var market_conditions: Array[Dictionary] = []
@export var upkeep_costs: Dictionary = {}

# Story and quest data
@export var story_tracks: Array[Dictionary] = []
@export var quest_templates: Array[QuestTemplate] = []

## World Trait Resource
class WorldTrait extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var effects: Dictionary = {} # effect_type: value
	@export var trade_modifiers: Dictionary = {}
	@export var mission_modifiers: Dictionary = {}
	@export var special_rules: Array[String] = []

## Planet Type Resource
class PlanetType extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var common_traits: Array[String] = []
	@export var environment_type: String = ""
	@export var tech_level: int = 3 # 1-5 scale
	@export var population_density: String = "moderate"

## Location Data Resource
class LocationData extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var location_type: String = ""
	@export var description: String = ""
	@export var services: Array[String] = []
	@export var shop_inventory: Dictionary = {}
	@export var special_rules: Array[String] = []

## Victory Condition Resource
class VictoryCondition extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var requirements: Dictionary = {} # requirement_type: value
	@export var difficulty_modifier: int = 0
	@export var story_implications: Array[String] = []

## Campaign Event Resource
class CampaignEvent extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var probability: float = 0.1 # 0.0 to 1.0
	@export var effects: Dictionary = {}
	@export var choices: Array[EventChoice] = []
	@export var prerequisites: Array[String] = []

class EventChoice extends Resource:
	@export var choice_text: String = ""
	@export var outcome: String = ""
	@export var effects: Dictionary = {}

## Character Event Resource
class CharacterEvent extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var character_requirements: Dictionary = {}
	@export var effects: Dictionary = {}
	@export var one_time_only: bool = false

## Patron Type Resource
class PatronType extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var patron_type: String = "" # "corporate", "government", "criminal"
	@export var mission_types: Array[String] = []
	@export var payment_modifier: float = 1.0
	@export var relationship_effects: Dictionary = {}

## Rival Type Resource
class RivalType extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var rival_type: String = ""
	@export var escalation_pattern: Array[String] = []
	@export var combat_modifiers: Dictionary = {}

## Faction Data Resource
class FactionData extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var faction_type: String = ""
	@export var influence_areas: Array[String] = []
	@export var relationships: Dictionary = {} # faction_id: relationship_value
	@export var special_rules: Array[String] = []

## Trade Good Resource
class TradeGood extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var base_value: int = 1
	@export var volatility: float = 0.2 # How much price varies
	@export var legality: String = "legal" # "legal", "restricted", "illegal"
	@export var availability: String = "common"

## Market Condition Resource
class MarketCondition extends Resource:
	@export var name: String = ""
	@export var description: String = ""
	@export var price_modifiers: Dictionary = {} # trade_good_type: modifier
	@export var availability_modifiers: Dictionary = {}
	@export var duration: int = 1 # Campaign turns

## Upkeep Costs Resource
class UpkeepCosts extends Resource:
	@export var ship_maintenance: int = 1
	@export var crew_wages: int = 1
	@export var fuel_costs: int = 1
	@export var medical_costs: int = 1
	@export var equipment_maintenance: int = 1

## Story Track Resource
class StoryTrack extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var track_type: String = ""
	@export var steps: Array[StoryStep] = []
	@export var rewards: Dictionary = {}

class StoryStep extends Resource:
	@export var step_number: int = 0
	@export var description: String = ""
	@export var requirements: Dictionary = {}
	@export var effects: Dictionary = {}

## Quest Template Resource
class QuestTemplate extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var quest_type: String = ""
	@export var objectives: Array[String] = []
	@export var rewards: Dictionary = {}
	@export var time_limit: int = -1 # -1 for no limit

## Data Access Methods

func get_world_trait_by_name(trait_name: String) -> Dictionary:
	## Get world trait by name
	for world_trait in world_traits:
		if world_trait.get("name") == trait_name:
			return world_trait
	return {}

func get_planet_type_by_name(planet_name: String) -> Dictionary:
	## Get planet type by name
	for planet in planet_types:
		if planet.get("name") == planet_name:
			return planet
	return {}

func get_victory_condition_by_id(condition_id: int) -> Dictionary:
	## Get victory condition by ID
	for condition in victory_conditions:
		if condition.get("id") == condition_id:
			return condition
	return {}

func get_patron_type_by_name(patron_name: String) -> Dictionary:
	## Get patron type by name
	for patron in patron_types:
		if patron.get("name") == patron_name:
			return patron
	return {}

func get_random_campaign_event() -> Dictionary:
	## Get random campaign event based on probability
	var total_weight = 0.0
	for event in campaign_events:
		total_weight += event.get("probability", 0.0)
	
	if total_weight <= 0:
		return {}
	
	var roll = randf() * total_weight
	var current_weight = 0.0
	
	for event in campaign_events:
		current_weight += event.get("probability", 0.0)
		if roll <= current_weight:
			return event
	
	return {}

func get_random_character_event(character_data: Dictionary = {}) -> Dictionary:
	## Get random character event matching requirements
	var eligible_events: Array[Dictionary] = []
	
	for event in character_events:
		if _meets_character_requirements(event, character_data):
			eligible_events.append(event)
	
	if eligible_events.is_empty():
		return {}
	
	return eligible_events[randi() % eligible_events.size()]

func get_trade_good_by_name(good_name: String) -> Dictionary:
	## Get trade good by name
	for good in trade_goods:
		if good.name == good_name:
			return good
	return {}

func get_current_market_price(good_name: String, world_conditions: Array = []) -> int:
	## Calculate current market price for trade good
	var good = get_trade_good_by_name(good_name)
	if not good:
		return 0
	
	var price = good.base_value
	var variation = randf_range(-good.volatility, good.volatility)
	price = int(price * (1.0 + variation))
	
	# Apply world condition modifiers
	for condition_name in world_conditions:
		var condition = get_market_condition_by_name(condition_name)
		if condition and condition.price_modifiers.has(good_name):
			price = int(price * condition.price_modifiers[good_name])
	
	return max(1, price)

func get_market_condition_by_name(condition_name: String) -> Dictionary:
	## Get market condition by name
	for condition in market_conditions:
		if condition.name == condition_name:
			return condition
	return {}

func get_story_track_by_name(track_name: String) -> Dictionary:
	## Get story track by name
	for track in story_tracks:
		if track.get("name") == track_name:
			return track
	return {}

func get_faction_by_name(faction_name: String) -> Dictionary:
	## Get faction data by name
	for faction in faction_data:
		if faction.get("name") == faction_name:
			return faction
	return {}

## Helper Methods

func _meets_character_requirements(event: Dictionary, character_data: Dictionary) -> bool:
	## Check if character meets event requirements
	for requirement in event.character_requirements:
		var req_type = requirement
		var req_value = event.character_requirements[requirement]
		
		match req_type:
			"background":
				if character_data.get("background", "") != req_value:
					return false
			"motivation":
				if character_data.get("motivation", "") != req_value:
					return false
			"min_combat":
				if character_data.get("combat", 0) < req_value:
					return false
			"has_trait":
				var traits = character_data.get("traits", [])
				if not req_value in traits:
					return false
	
	return true

func roll_world_traits(count: int = 2) -> Array[Dictionary]:
	## Roll random world traits
	if world_traits.is_empty():
		return []
	
	var rolled_traits: Array[Dictionary] = []
	var available_traits = world_traits.duplicate()
	
	for i in range(min(count, available_traits.size())):
		var index = randi() % available_traits.size()
		rolled_traits.append(available_traits[index])
		available_traits.remove_at(index)
	
	return rolled_traits

func calculate_upkeep_cost(crew_size: int, ship_data: Dictionary = {}) -> int:
	## Calculate total upkeep cost
	if not upkeep_costs:
		return crew_size # Fallback
	
	var total = 0
	total += upkeep_costs.ship_maintenance
	total += upkeep_costs.crew_wages * crew_size
	total += upkeep_costs.fuel_costs
	total += upkeep_costs.medical_costs
	total += upkeep_costs.equipment_maintenance
	
	return total

## Validation Methods

func validate_data() -> Array[String]:
	## Validate campaign data integrity
	var errors: Array[String] = []
	
	if world_traits.is_empty():
		errors.append("No world traits defined")
	
	if planet_types.is_empty():
		errors.append("No planet types defined")
	
	if victory_conditions.is_empty():
		errors.append("No victory conditions defined")
	
	if patron_types.is_empty():
		errors.append("No patron types defined")
	
	if trade_goods.is_empty():
		errors.append("No trade goods defined")
	
	if not upkeep_costs:
		errors.append("No upkeep costs defined")
	
	# Validate probabilities for campaign events
	for event in campaign_events:
		if event.probability < 0 or event.probability > 1:
			errors.append("Campaign event %s has invalid probability" % event.name)
	
	return errors

func is_valid() -> bool:
	## Check if campaign data is valid
	return validate_data().is_empty()

## Factory Methods for Default Data

static func create_default_campaign_data() -> Resource:
	## Create campaign data with Five Parsecs defaults
	var DataScript = load("res://src/data/resources/FiveParsecsCampaignData.gd")
	var data = DataScript.new()
	
	data.world_traits = _create_default_world_traits()
	data.planet_types = _create_default_planet_types()
	data.victory_conditions = _create_default_victory_conditions()
	data.patron_types = _create_default_patron_types()
	data.rival_types = _create_default_rival_types()
	data.trade_goods = _create_default_trade_goods()
	data.upkeep_costs = _create_default_upkeep_costs()
	data.story_tracks = _create_default_story_tracks()
	
	return data

static func _create_default_world_traits() -> Array[WorldTrait]:
	## Create Five Parsecs default world traits
	var traits: Array[WorldTrait] = []
	
	var busy_markets = WorldTrait.new()
	busy_markets.id = 0
	busy_markets.name = "Busy Markets"
	busy_markets.description = "Active trading hub"
	busy_markets.trade_modifiers = {"all": 1.2}
	traits.append(busy_markets)
	
	var dangerous = WorldTrait.new()
	dangerous.id = 1
	dangerous.name = "Dangerous"
	dangerous.description = "High crime and conflict"
	dangerous.mission_modifiers = {"payment": 1.5, "danger": 2.0}
	traits.append(dangerous)
	
	var restricted = WorldTrait.new()
	restricted.id = 2
	restricted.name = "Restricted"
	restricted.description = "Heavy government control"
	restricted.effects = {"licensing_required": true}
	traits.append(restricted)
	
	return traits

static func _create_default_planet_types() -> Array[PlanetType]:
	## Create default planet types
	var planets: Array[PlanetType] = []
	
	var colony = PlanetType.new()
	colony.id = 0
	colony.name = "Colony World"
	colony.description = "Frontier settlement"
	colony.tech_level = 3
	colony.population_density = "sparse"
	colony.common_traits = ["Frontier", "Opportunity"]
	planets.append(colony)
	
	var industrial = PlanetType.new()
	industrial.id = 1
	industrial.name = "Industrial World"
	industrial.description = "Manufacturing center"
	industrial.tech_level = 4
	industrial.population_density = "dense"
	industrial.common_traits = ["Busy Markets", "Polluted"]
	planets.append(industrial)
	
	return planets

static func _create_default_victory_conditions() -> Array[VictoryCondition]:
	## Create default victory conditions
	var conditions: Array[VictoryCondition] = []
	
	var wealthy = VictoryCondition.new()
	wealthy.id = 0
	wealthy.name = "Wealthy"
	wealthy.description = "Accumulate 100 credits"
	wealthy.requirements = {"credits": 100}
	conditions.append(wealthy)
	
	var famous = VictoryCondition.new()
	famous.id = 1
	famous.name = "Famous Crew"
	famous.description = "Complete 20 missions"
	famous.requirements = {"missions_completed": 20}
	conditions.append(famous)
	
	return conditions

static func _create_default_patron_types() -> Array[PatronType]:
	## Create default patron types
	var patrons: Array[PatronType] = []
	
	var corporate = PatronType.new()
	corporate.id = 0
	corporate.name = "Corporate Contact"
	corporate.patron_type = "corporate"
	corporate.mission_types = ["delivery", "security", "escort"]
	corporate.payment_modifier = 1.2
	patrons.append(corporate)
	
	var criminal = PatronType.new()
	criminal.id = 1
	criminal.name = "Criminal Contact"
	criminal.patron_type = "criminal"
	criminal.mission_types = ["smuggling", "theft", "enforcement"]
	criminal.payment_modifier = 1.5
	patrons.append(criminal)
	
	return patrons

static func _create_default_rival_types() -> Array[RivalType]:
	## Create default rival types
	var rivals: Array[RivalType] = []
	
	var gang = RivalType.new()
	gang.id = 0
	gang.name = "Criminal Gang"
	gang.rival_type = "criminal"
	gang.escalation_pattern = ["harassment", "ambush", "assault", "war"]
	rivals.append(gang)
	
	var enforcer = RivalType.new()
	enforcer.id = 1
	enforcer.name = "Corporate Enforcer"
	enforcer.rival_type = "corporate"
	enforcer.escalation_pattern = ["investigation", "harassment", "arrest", "elimination"]
	rivals.append(enforcer)
	
	return rivals

static func _create_default_trade_goods() -> Array[TradeGood]:
	## Create default trade goods
	var goods: Array[TradeGood] = []
	
	var food = TradeGood.new()
	food.id = 0
	food.name = "Food"
	food.base_value = 2
	food.volatility = 0.3
	food.availability = "common"
	goods.append(food)
	
	var luxury = TradeGood.new()
	luxury.id = 1
	luxury.name = "Luxury Goods"
	luxury.base_value = 8
	luxury.volatility = 0.5
	luxury.availability = "rare"
	goods.append(luxury)
	
	var contraband = TradeGood.new()
	contraband.id = 2
	contraband.name = "Contraband"
	contraband.base_value = 12
	contraband.volatility = 0.6
	contraband.legality = "illegal"
	contraband.availability = "rare"
	goods.append(contraband)
	
	return goods

static func _create_default_upkeep_costs() -> UpkeepCosts:
	## Create default upkeep costs
	var costs = UpkeepCosts.new()
	costs.ship_maintenance = 1
	costs.crew_wages = 1
	costs.fuel_costs = 1
	costs.medical_costs = 1
	costs.equipment_maintenance = 1
	return costs

static func _create_default_story_tracks() -> Array[StoryTrack]:
	## Create default story tracks
	var tracks: Array[StoryTrack] = []
	
	var main_story = StoryTrack.new()
	main_story.id = 0
	main_story.name = "Main Story"
	main_story.track_type = "main"
	main_story.description = "Your crew's main story arc"
	tracks.append(main_story)
	
	return tracks
