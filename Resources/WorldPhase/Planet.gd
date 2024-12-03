class_name Planet
extends Resource

signal traits_changed
signal economy_updated
signal threat_level_changed

# Basic planet info
@export var name: String
@export var sector: String
@export var coordinates: Vector2
@export var planet_type: int  # GlobalEnums.PlanetType
@export var tech_level: int  # GlobalEnums.TechLevel
@export var population_level: int  # GlobalEnums.PopulationLevel
@export var government_type: int  # GlobalEnums.GovernmentType

# Planet traits and conditions
@export var traits: Array = []  # Array of GlobalEnums.PlanetTrait
@export var current_threats: Array = []  # Array of GlobalEnums.ThreatType
@export var local_factions: Array[String] = []
@export var threat_level: int = 0

# Economy and trade
@export var market_prices: Dictionary = {}  # item_id: price_modifier
@export var available_resources: Array[String] = []
@export var restricted_goods: Array[String] = []
@export var local_specialties: Array[String] = []

# Mission and event tracking
var visited_times: int = 0
var last_visit_turn: int = -1
var active_missions: Array[Mission] = []
var historical_events: Array[Dictionary] = []

# Cache for revisits
var cached_npcs: Array[Character] = []
var cached_shops: Array[Dictionary] = []
var cached_quests: Array[Mission] = []

# Add at the top of the file with other constants
var _mission_generator: MissionGenerator

# At the top of the file, add game_state variable
var game_state: GameState

func _init(_game_state: GameState = null) -> void:
    game_state = _game_state
    _initialize_traits()

func _initialize_traits() -> void:
    # Generate random traits based on planet type
    match planet_type:
        GlobalEnums.PlanetType.CORE_WORLD:
            _add_core_world_traits()
        GlobalEnums.PlanetType.FRONTIER:
            _add_frontier_traits()
        GlobalEnums.PlanetType.COLONY:
            _add_colony_traits()
        GlobalEnums.PlanetType.MINING:
            _add_mining_traits()
        GlobalEnums.PlanetType.INDUSTRIAL:
            _add_industrial_traits()
        GlobalEnums.PlanetType.AGRICULTURAL:
            _add_agricultural_traits()

func update_for_visit(current_turn: int) -> void:
    visited_times += 1
    var turns_since_last_visit = current_turn - last_visit_turn if last_visit_turn != -1 else 999
    last_visit_turn = current_turn
    
    if turns_since_last_visit > 0:
        _update_economy(turns_since_last_visit)
        _update_threats(turns_since_last_visit)
        _update_missions(turns_since_last_visit)
        _generate_new_events(turns_since_last_visit)

func _update_economy(turns_passed: int) -> void:
    # Update market prices based on time passed and events
    for item_id in market_prices:
        var base_modifier = market_prices[item_id]
        var random_drift = (randf() - 0.5) * 0.1 * turns_passed
        market_prices[item_id] = clampf(base_modifier + random_drift, 0.5, 2.0)
    
    # Generate new trade opportunities
    if randf() < 0.3 * turns_passed:
        _generate_trade_opportunity()
    
    economy_updated.emit()

func _update_threats(turns_passed: int) -> void:
    # Remove old threats
    current_threats = current_threats.filter(func(threat): 
        return randf() > 0.2 * turns_passed
    )
    
    # Add new threats
    var new_threat_chance = 0.1 * turns_passed
    if randf() < new_threat_chance:
        _add_random_threat()
    
    # Update overall threat level
    threat_level = current_threats.size()
    threat_level_changed.emit()

func _update_missions(turns_passed: int) -> void:
    # Update or remove existing missions
    active_missions = active_missions.filter(func(mission): 
        return not mission.is_expired(turns_passed)
    )
    
    # Generate new missions if needed
    while active_missions.size() < 3:
        var new_mission = _generate_mission()
        if new_mission:
            active_missions.append(new_mission)

func _generate_new_events(turns_passed: int) -> void:
    var event_chance = 0.2 * turns_passed
    if randf() < event_chance:
        var event = _generate_random_event()
        historical_events.append(event)
        _apply_event_effects(event)

func get_available_missions() -> Array[Mission]:
    return active_missions.filter(func(mission): 
        return not mission.is_completed and not mission.is_failed
    )

func get_market_price(item_id: String) -> float:
    return market_prices.get(item_id, 1.0)

func add_trait(new_trait: int) -> void:  # GlobalEnums.PlanetTrait
    if not new_trait in traits:
        traits.append(new_trait)
        traits_changed.emit()

func remove_trait(old_trait: int) -> void:  # GlobalEnums.PlanetTrait
    traits.erase(old_trait)
    traits_changed.emit()

# Helper methods for initialization
func _add_core_world_traits() -> void:
    add_trait(GlobalEnums.PlanetTrait.HIGH_TECH)
    add_trait(GlobalEnums.PlanetTrait.DENSE_POPULATION)
    if randf() < 0.5:
        add_trait(GlobalEnums.PlanetTrait.TRADE_HUB)

func _add_frontier_traits() -> void:
    add_trait(GlobalEnums.PlanetTrait.LAWLESS)
    add_trait(GlobalEnums.PlanetTrait.SPARSE_POPULATION)
    if randf() < 0.5:
        add_trait(GlobalEnums.PlanetTrait.DANGEROUS_WILDLIFE)

# Colony type trait initialization
func _add_colony_traits() -> void:
    add_trait(GlobalEnums.PlanetTrait.SPARSE_POPULATION)
    if randf() < 0.3:
        add_trait(GlobalEnums.PlanetTrait.RESEARCH_STATION)
    if randf() < 0.4:
        add_trait(GlobalEnums.PlanetTrait.AGRICULTURAL_CENTER)

func _add_mining_traits() -> void:
    add_trait(GlobalEnums.PlanetTrait.MINING_COLONY)
    if randf() < 0.4:
        add_trait(GlobalEnums.PlanetTrait.INDUSTRIAL_HUB)
    if randf() < 0.3:
        add_trait(GlobalEnums.PlanetTrait.DANGEROUS_WILDLIFE)

func _add_industrial_traits() -> void:
    add_trait(GlobalEnums.PlanetTrait.INDUSTRIAL_HUB)
    if randf() < 0.4:
        add_trait(GlobalEnums.PlanetTrait.DENSE_POPULATION)
    if randf() < 0.3:
        add_trait(GlobalEnums.PlanetTrait.TRADE_HUB)

func _add_agricultural_traits() -> void:
    add_trait(GlobalEnums.PlanetTrait.AGRICULTURAL_CENTER)
    if randf() < 0.3:
        add_trait(GlobalEnums.PlanetTrait.SPARSE_POPULATION)
    if randf() < 0.2:
        add_trait(GlobalEnums.PlanetTrait.RESEARCH_STATION)

func _generate_trade_opportunity() -> void:
    var possible_resources = ["minerals", "food", "technology", "medicine", "luxury_goods"]
    var resource = possible_resources[randi() % possible_resources.size()]
    
    if not resource in available_resources:
        available_resources.append(resource)
        market_prices[resource] = randf_range(0.8, 1.2)

func _add_random_threat() -> void:
    var possible_threats = GlobalEnums.ThreatType.values()
    var new_threat = possible_threats[randi() % possible_threats.size()]
    
    if not new_threat in current_threats:
        current_threats.append(new_threat)
        threat_level = current_threats.size()

func _generate_mission() -> Mission:
    if not game_state:
        push_error("Cannot generate mission: game_state not initialized")
        return null
        
    if not _mission_generator:
        _mission_generator = MissionGenerator.new(game_state)
    return _mission_generator.generate_mission_for_planet(self)

func _generate_random_event() -> Dictionary:
    var possible_events = [
        _generate_market_event(),
        _generate_political_event(),
        _generate_social_event(),
        _generate_disaster_event()
    ]
    return possible_events[randi() % possible_events.size()]

func _apply_event_effects(event: Dictionary) -> void:
    match event.type:
        "market":
            _apply_market_event(event)
        "political":
            _apply_political_event(event)
        "social":
            _apply_social_event(event)
        "disaster":
            _apply_disaster_event(event)

# Event generation helpers
func _generate_market_event() -> Dictionary:
    var events = [
        {
            "type": "market",
            "name": "Market Boom",
            "description": "Local market experiences sudden growth",
            "effect": "price_decrease",
            "magnitude": randf_range(0.1, 0.3)
        },
        {
            "type": "market",
            "name": "Resource Shortage",
            "description": "Critical resources become scarce",
            "effect": "price_increase",
            "magnitude": randf_range(0.2, 0.4)
        }
    ]
    return events[randi() % events.size()]

func _generate_political_event() -> Dictionary:
    var events = [
        {
            "type": "political",
            "name": "Change in Leadership",
            "description": "New local government takes power",
            "effect": "government_change",
            "new_government": GlobalEnums.GovernmentType.values()[randi() % GlobalEnums.GovernmentType.size()]
        },
        {
            "type": "political",
            "name": "Trade Agreement",
            "description": "New trade routes established",
            "effect": "trade_boost",
            "magnitude": randf_range(0.1, 0.3)
        }
    ]
    return events[randi() % events.size()]

func _generate_social_event() -> Dictionary:
    var events = [
        {
            "type": "social",
            "name": "Cultural Festival",
            "description": "Local celebration attracts visitors",
            "effect": "population_boost",
            "duration": randi_range(1, 3)
        },
        {
            "type": "social",
            "name": "Social Unrest",
            "description": "Population shows signs of discontent",
            "effect": "unrest_increase",
            "magnitude": randf_range(0.1, 0.3)
        }
    ]
    return events[randi() % events.size()]

func _generate_disaster_event() -> Dictionary:
    var events = [
        {
            "type": "disaster",
            "name": "Natural Disaster",
            "description": "Local area affected by catastrophe",
            "effect": "production_decrease",
            "magnitude": randf_range(0.2, 0.4)
        },
        {
            "type": "disaster",
            "name": "Disease Outbreak",
            "description": "Health crisis affects population",
            "effect": "population_decrease",
            "magnitude": randf_range(0.1, 0.3)
        }
    ]
    return events[randi() % events.size()]

# Event application helpers
func _apply_market_event(event: Dictionary) -> void:
    match event.effect:
        "price_decrease":
            for item in market_prices:
                market_prices[item] *= (1.0 - event.magnitude)
        "price_increase":
            for item in market_prices:
                market_prices[item] *= (1.0 + event.magnitude)

func _apply_political_event(event: Dictionary) -> void:
    match event.effect:
        "government_change":
            government_type = event.new_government
        "trade_boost":
            for item in market_prices:
                market_prices[item] *= (1.0 - event.magnitude)

func _apply_social_event(event: Dictionary) -> void:
    match event.effect:
        "population_boost":
            if population_level < GlobalEnums.PopulationLevel.OVERCROWDED:
                population_level += 1
        "unrest_increase":
            add_trait(GlobalEnums.PlanetTrait.LAWLESS)

func _apply_disaster_event(event: Dictionary) -> void:
    match event.effect:
        "production_decrease":
            for item in market_prices:
                market_prices[item] *= (1.0 + event.magnitude)
        "population_decrease":
            if population_level > GlobalEnums.PopulationLevel.UNINHABITED:
                population_level -= 1

func serialize() -> Dictionary:
    return {
        "name": name,
        "sector": sector,
        "coordinates": {"x": coordinates.x, "y": coordinates.y},
        "planet_type": GlobalEnums.PlanetType.keys()[planet_type],
        "tech_level": GlobalEnums.TechLevel.keys()[tech_level],
        "population_level": GlobalEnums.PopulationLevel.keys()[population_level],
        "government_type": GlobalEnums.GovernmentType.keys()[government_type],
        "traits": traits.map(func(t): return GlobalEnums.PlanetTrait.keys()[t]),
        "current_threats": current_threats.map(func(t): return GlobalEnums.ThreatType.keys()[t]),
        "local_factions": local_factions,
        "threat_level": threat_level,
        "market_prices": market_prices,
        "available_resources": available_resources,
        "restricted_goods": restricted_goods,
        "local_specialties": local_specialties,
        "visited_times": visited_times,
        "last_visit_turn": last_visit_turn,
        "historical_events": historical_events
    }

static func deserialize(data: Dictionary) -> Planet:
    var planet = Planet.new()
    planet.name = data.get("name", "")
    planet.sector = data.get("sector", "")
    planet.coordinates = Vector2(data.coordinates.x, data.coordinates.y)
    planet.planet_type = GlobalEnums.PlanetType[data.get("planet_type", "COLONY")]
    planet.tech_level = GlobalEnums.TechLevel[data.get("tech_level", "AVERAGE")]
    planet.population_level = GlobalEnums.PopulationLevel[data.get("population_level", "MEDIUM")]
    planet.government_type = GlobalEnums.GovernmentType[data.get("government_type", "DEMOCRACY")]
    
    # Convert traits from string array to enum array
    planet.traits = data.get("traits", []).map(func(t): return GlobalEnums.PlanetTrait[t])
    planet.current_threats = data.get("current_threats", []).map(func(t): return GlobalEnums.ThreatType[t])
    
    planet.local_factions = data.get("local_factions", [])
    planet.threat_level = data.get("threat_level", 0)
    planet.market_prices = data.get("market_prices", {})
    planet.available_resources = data.get("available_resources", [])
    planet.restricted_goods = data.get("restricted_goods", [])
    planet.local_specialties = data.get("local_specialties", [])
    planet.visited_times = data.get("visited_times", 0)
    planet.last_visit_turn = data.get("last_visit_turn", -1)
    planet.historical_events = data.get("historical_events", [])
    
    return planet 