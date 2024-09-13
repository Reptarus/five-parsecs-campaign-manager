extends Control

var progress = 0.0
var shaders_to_load = []
var current_shader_index = 0

@onready var progress_bar = $ProgressBar
@onready var loading_label = $LoadingLabel

func _ready():
	# List of shaders to preload
	shaders_to_load = [
		"res://shaders/example_shader1.gdshader",
		"res://shaders/example_shader2.gdshader",
		"res://shaders/example_shader3.gdshader",
		# Add more shader paths as needed
	]
	
	load_next_shader()

func _process(_delta):
	if current_shader_index < shaders_to_load.size():
		progress = float(current_shader_index) / shaders_to_load.size()
		progress_bar.value = progress * 100
		loading_label.text = "Loading Shaders: %d%%" % [progress * 100]
	else:
		loading_label.text = "Loading Complete!"
		# Transition to the main game scene
		get_tree().change_scene_to_file("res://scenes/main_game.tscn")

func load_next_shader():
	if current_shader_index < shaders_to_load.size():
		var shader_path = shaders_to_load[current_shader_index]
		var shader = ResourceLoader.load(shader_path, "Shader")
		if shader:
			RenderingServer.get_shader_parameter_list(shader.get_rid())
		
		# Simulate shader compilation time
		await get_tree().create_timer(0.5).timeout
		current_shader_index += 1
		load_next_shader()
