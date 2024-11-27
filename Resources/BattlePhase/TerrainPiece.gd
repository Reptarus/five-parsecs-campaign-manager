class_name TerrainPiece
extends StaticBody3D

@export var cover_value := 1
@export var height := 1
@export var is_destructible := false
@export var blocks_los := true

var terrain_type: String
var original_position: Vector2

func _ready() -> void:
	add_to_group("terrain")

func get_cover_value() -> int:
	return cover_value

func get_height() -> int:
	return height

func can_be_destroyed() -> bool:
	return is_destructible

func blocks_line_of_sight() -> bool:
	return blocks_los 
