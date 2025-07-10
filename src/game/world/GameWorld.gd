extends Resource

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const GamePlanet = preload("res://src/game/world/GamePlanet.gd")

@export var node_name: String = ""
@export var environment_type: GlobalEnums.PlanetEnvironment = GlobalEnums.PlanetEnvironment.URBAN
@export var faction_type: GlobalEnums.FactionType = GlobalEnums.FactionType.NONE
@export var strife_level: GlobalEnums.StrifeType = GlobalEnums.StrifeType.NONE
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
		node_name,
		GlobalEnums.PlanetEnvironment.keys()[environment_type],
		GlobalEnums.FactionType.keys()[faction_type],
		GlobalEnums.StrifeType.keys()[strife_level]
	]