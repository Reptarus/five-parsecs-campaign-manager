extends Node2D

const Generator = preload("res://WorldGen/Generator.gd")
const Region = preload("res://WorldGen/Region.gd")

@export var generator: Generator
@export var debug_region: Region

func _unhandled_input(event):
	if event.is_action_pressed('Submit'):
		generator.generate_progression(debug_region, Vector2(0, 0))
