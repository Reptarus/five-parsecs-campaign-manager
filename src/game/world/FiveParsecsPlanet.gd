@tool
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var name: String = ""
@export var description: String = ""
@export var planet_type: GameEnums.PlanetType = GameEnums.PlanetType.TEMPERATE
@export var tech_level: int = 1
@export var population: int = 1000000
@export var faction_influence: Dictionary = {}
@export var resources: Dictionary = {}
@export var locations: Array[Resource] = [] 