class_name Planet
extends Resource

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

# Core properties
@export var planet_name: String = ""
@export var planet_type: int = GameEnums.PlanetType.TEMPERATE
@export var faction_type: int = GameEnums.FactionType.NEUTRAL
@export var environment_type: int = GameEnums.PlanetEnvironment.NONE
@export var world_features: Array[int] = []
@export var resources: Dictionary = {} # ResourceType: amount
@export var threats: Array[int] = []

# State tracking
@export var strife_level: int = GameEnums.StrifeType.NONE
@export var instability: int = GameEnums.StrifeType.NONE
@export var unity_progress: int = 0
@export var market_prices: Dictionary = {} # ItemType: price

func _init() -> void:
    reset_state()

func reset_state() -> void:
    resources.clear()
    threats.clear()
    world_features.clear()
    market_prices.clear()
    strife_level = GameEnums.StrifeType.NONE
    instability = GameEnums.StrifeType.NONE
    unity_progress = 0

func add_resource(resource_type: int, amount: int = 1) -> void:
    if not resource_type in range(GameEnums.ResourceType.size()):
        push_error("Invalid resource type provided")
        return
        
    if not resources.has(resource_type):
        resources[resource_type] = 0
    resources[resource_type] += amount

func remove_resource(resource_type: int, amount: int = 1) -> bool:
    if not resource_type in range(GameEnums.ResourceType.size()):
        push_error("Invalid resource type provided")
        return false
        
    if not resources.has(resource_type) or resources[resource_type] < amount:
        return false
    resources[resource_type] -= amount
    if resources[resource_type] <= 0:
        resources.erase(resource_type)
    return true

func add_threat(threat: int) -> void:
    if not threat in range(GameEnums.ThreatType.size()):
        push_error("Invalid threat type provided")
        return
        
    if not threat in threats:
        threats.append(threat)

func remove_threat(threat: int) -> void:
    if not threat in range(GameEnums.ThreatType.size()):
        push_error("Invalid threat type provided")
        return
        
    var idx := threats.find(threat)
    if idx != -1:
        threats.remove_at(idx)

func add_world_feature(feature: int) -> void:
    if not feature in range(GameEnums.WorldTrait.size()):
        push_error("Invalid world feature provided")
        return
        
    if not feature in world_features:
        world_features.append(feature)

func remove_world_feature(feature: int) -> void:
    if not feature in range(GameEnums.WorldTrait.size()):
        push_error("Invalid world feature provided")
        return
        
    var idx := world_features.find(feature)
    if idx != -1:
        world_features.remove_at(idx)

func increase_strife() -> void:
    var current_index := strife_level
    if current_index < GameEnums.StrifeType.size() - 1:
        strife_level = current_index + 1

func decrease_strife() -> void:
    if strife_level > GameEnums.StrifeType.NONE:
        strife_level -= 1

func increase_instability() -> void:
    var current_index := instability
    if current_index < GameEnums.StrifeType.size() - 1:
        instability = current_index + 1

func decrease_instability() -> void:
    if instability > GameEnums.StrifeType.NONE:
        instability -= 1

func update_market_price(item_type: int, price: float) -> void:
    if not item_type in range(GameEnums.ItemType.size()):
        push_error("Invalid item type provided")
        return
        
    market_prices[item_type] = price

func get_market_price(item_type: int) -> float:
    if not item_type in range(GameEnums.ItemType.size()):
        push_error("Invalid item type provided")
        return 0.0
        
    return market_prices.get(item_type, 0.0)

func has_feature(feature: int) -> bool:
    if not feature in range(GameEnums.WorldTrait.size()):
        push_error("Invalid world feature provided")
        return false
        
    return feature in world_features

func has_threat(threat: int) -> bool:
    if not threat in range(GameEnums.ThreatType.size()):
        push_error("Invalid threat type provided")
        return false
        
    return threat in threats

func get_resource_amount(resource_type: int) -> int:
    if not resource_type in range(GameEnums.ResourceType.size()):
        push_error("Invalid resource type provided")
        return 0
        
    return resources.get(resource_type, 0)

# Serialization
func serialize() -> Dictionary:
    var feature_keys: Array[String] = []
    for f in world_features:
        feature_keys.append(GameEnums.WorldTrait.keys()[f])
        
    var threat_keys: Array[String] = []
    for t in threats:
        threat_keys.append(GameEnums.ThreatType.keys()[t])
        
    return {
        "planet_name": planet_name,
        "planet_type": GameEnums.PlanetType.keys()[planet_type],
        "faction_type": GameEnums.FactionType.keys()[faction_type],
        "environment_type": GameEnums.PlanetEnvironment.keys()[environment_type],
        "world_features": feature_keys,
        "resources": resources,
        "threats": threat_keys,
        "strife_level": GameEnums.StrifeType.keys()[strife_level],
        "instability": GameEnums.StrifeType.keys()[instability],
        "unity_progress": unity_progress,
        "market_prices": market_prices
    }

static func deserialize(data: Dictionary) -> Planet:
    var planet := Planet.new()
    
    planet.planet_name = data.get("planet_name", "") as String
    
    # Validate and convert enum values
    var planet_type_str: String = data.get("planet_type", "TEMPERATE")
    if planet_type_str in GameEnums.PlanetType.keys():
        planet.planet_type = GameEnums.PlanetType[planet_type_str]
        
    var faction_type_str: String = data.get("faction_type", "NEUTRAL")
    if faction_type_str in GameEnums.FactionType.keys():
        planet.faction_type = GameEnums.FactionType[faction_type_str]
        
    var environment_type_str: String = data.get("environment_type", "NONE")
    if environment_type_str in GameEnums.PlanetEnvironment.keys():
        planet.environment_type = GameEnums.PlanetEnvironment[environment_type_str]
    
    # Convert and validate feature strings back to enum values
    var features: Array = data.get("world_features", [])
    for feature in features:
        if feature in GameEnums.WorldTrait.keys():
            planet.world_features.append(GameEnums.WorldTrait[feature])
    
    planet.resources = data.get("resources", {})
    
    # Convert and validate threat strings back to enum values
    var threats: Array = data.get("threats", [])
    for threat in threats:
        if threat in GameEnums.ThreatType.keys():
            planet.threats.append(GameEnums.ThreatType[threat])
    
    var strife_level_str: String = data.get("strife_level", "NONE")
    if strife_level_str in GameEnums.StrifeType.keys():
        planet.strife_level = GameEnums.StrifeType[strife_level_str]
        
    var instability_str: String = data.get("instability", "NONE")
    if instability_str in GameEnums.StrifeType.keys():
        planet.instability = GameEnums.StrifeType[instability_str]
        
    planet.unity_progress = data.get("unity_progress", 0) as int
    planet.market_prices = data.get("market_prices", {})
    
    return planet