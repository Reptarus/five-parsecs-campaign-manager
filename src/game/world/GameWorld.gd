extends Resource

const GameEnums = preload("res://src/core/enums/GameEnums.gd")
const GamePlanet = preload("res://src/game/world/GamePlanet.gd")

@export var name: String = ""
@export var environment_type: GameEnums.PlanetEnvironment = GameEnums.PlanetEnvironment.URBAN
@export var faction_type: GameEnums.FactionType = GameEnums.FactionType.NONE
@export var strife_level: int = GameEnums.ThreatType.NONE
@export var world_features: Array[int] = []
@export var resources: Dictionary = {}
@export var market_prices: Dictionary = {}
@export var unity_progress: float = 0.0

func _init() -> void:
    world_features = []
    resources = {}
    market_prices = {}

func get_info() -> String:
    return "World: %s\nEnvironment: %s\nFaction: %s\nStrife Level: %s" % [
        name,
        GameEnums.PlanetEnvironment.keys()[environment_type],
        GameEnums.FactionType.keys()[faction_type],
        GameEnums.ThreatType.keys()[strife_level]
    ]