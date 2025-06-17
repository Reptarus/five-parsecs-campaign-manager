extends Node2D

const Grid = preload("res://WorldGen/Grid.gd")
const Region = preload("res://WorldGen/Region.gd")
const Tile = preload("res://WorldGen/Tile.gd")

@export var noise: FastNoiseLite

@export var grid: Grid

# Generate main branch of region w/ full progression tree
func generate_progression(source: Region, start: Vector2):
	# Three passes: progression, optional progression, fill-ins
	var used: Array[Tile] = []
	var size: int = randi_range(source.size_range.x, source.size_range.y)
	
	# Place each progression room somewhere on the map in descending y
	var progression_length = source.progression_rooms.size()
	for i in source.progression_rooms.size():
		# Place within appropriate x, y range
		var y_min: int = source.progression_direction * (i * size / progression_length + source.progression_margin)
		var y_max: int = source.progression_direction * ((i + 1) * size / progression_length - source.progression_margin)
		var x = start.x + randi_range(-source.progression_width, source.progression_width)
		var y = start.y + randi_range(y_min, y_max)
		
		# Get the tile from progression rooms (should be a Tile resource)
		var tile = source.progression_rooms[i]
		grid.add_tile(tile, Vector2i(x, y))
	
	# Optional pass: decide whether or not to spawn, and attempt to spawn randomly anywhere in the progression zone
	# TODO: clarify 'weight' situation and how to generate random chance per tile
	for i in source.optional_rooms.size():
		var optional_tile = source.optional_rooms[i]
		# Get weight from tile, fallback to 1 if not available
		var tile_weight = 1
		if optional_tile and optional_tile.has_method("get") and "weight" in optional_tile:
			tile_weight = optional_tile.weight
		elif optional_tile and "weight" in optional_tile:
			tile_weight = optional_tile.weight
			
		if randf() < float(tile_weight) / source.optional_rooms.size():
			var x = start.x + randi_range(-source.progression_width, source.progression_width)
			var y = start.y + source.progression_direction * randi_range(source.progression_margin, size - source.progression_margin)
			grid.add_tile(optional_tile, Vector2i(x, y))
	
	# Environment pass: select environment tiles at (weighted) random and place them in the empty spaces
	# TODO: consult noise map to construct biome
	for x in range(-size, size):
		for y in size:
			var pos_x = x + start.x
			var pos_y = y + start.y
			var env_tile = source.environment_tiles[randi() % source.environment_tiles.size()]
			grid.add_tile(env_tile, Vector2i(pos_x, pos_y))
	
	grid.display()