class_name GameWorld
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var name: String = ""
@export var environment_type: GameEnums.BattleEnvironment = GameEnums.BattleEnvironment.URBAN
@export var faction_type: GameEnums.FactionType = GameEnums.FactionType.NONE
@export var strife_level: GameEnums.StrifeType = GameEnums.StrifeType.NONE
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
        GameEnums.BattleEnvironment.keys()[environment_type],
        GameEnums.FactionType.keys()[faction_type],
        GameEnums.StrifeType.keys()[strife_level]
    ]