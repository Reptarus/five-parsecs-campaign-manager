@tool
extends Resource

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

@export var name: String = ""
@export var description: String = ""
@export var location_type: GameEnums.LocationType = GameEnums.LocationType.SETTLEMENT
@export var size: int = 1
@export var population: int = 1000
@export var faction_presence: Dictionary = {}
@export var available_services: Array[int] = []
@export var trade_goods: Array[int] = [] 