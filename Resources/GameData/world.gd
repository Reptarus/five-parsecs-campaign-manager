class_name World
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")

@export var terrain_type: GlobalEnums.TerrainType = GlobalEnums.TerrainType.CITY
@export var faction_type: GlobalEnums.FactionType = GlobalEnums.FactionType.NEUTRAL
@export var strife_type: GlobalEnums.StrifeType = GlobalEnums.StrifeType.RESOURCE_CONFLICT

# Variables
var world_step: WorldPhaseUI

func get_terrain_type() -> GlobalEnums.TerrainType:
	return terrain_type

func get_faction_type() -> GlobalEnums.FactionType:
	return faction_type

func get_strife_type() -> GlobalEnums.StrifeType:
	return strife_type
