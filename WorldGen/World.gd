extends Node2D

@export var generator: Generator
@export var debug_region: Region

func _unhandled_input(event):
	if event.is_action_pressed('Submit'):
		generator.generate_progression(debug_region, Vector2(0, 0))
