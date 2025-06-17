extends Resource

# Placeholder Tile class since it's not found in scope
class Tile:
	var type: int = 0
	var position: Vector2i = Vector2i.ZERO
	var weight: int = 1

@export var progression_rooms: Array
@export var optional_rooms: Array
@export var optional_room_spawn_chance: float = 0.5 # 1 / (prob ^ weight)
@export var environment_tiles: Array

@export var size_range: Vector2i = Vector2i(20, 30)
@export var progression_width: int = 10
@export var progression_margin: int = 1
@export var progression_direction: int = -1
