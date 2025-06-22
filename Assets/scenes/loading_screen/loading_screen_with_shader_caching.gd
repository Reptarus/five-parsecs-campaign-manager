extends Control

var progress: float = 0.0
var shaders_to_load: Array[String] = []
var current_shader_index: int = 0

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var loading_label: Label = $LoadingLabel

func _ready() -> void:
	# List of shaders to preload
	shaders_to_load = [
		"res://shaders/example_shader1.gdshader",
		"res://shaders/example_shader2.gdshader",
		"res://shaders/example_shader3.gdshader"



		# Add more shader paths as needed
	]
	
	load_next_shader()

func _process(_delta: float) -> void:
	if current_shader_index < shaders_to_load.size():
		progress = float(current_shader_index) / shaders_to_load.size()
		progress_bar.value = progress * 100.0
		loading_label.text = "Loading Shaders: %d%%" % [progress * 100.0]
	else:
		loading_label.text = "Loading Complete!"
		# Transition to the main game scene using deferred call
		get_tree().call_deferred("change_scene_to_file", "res://scenes/main_game.tscn")

func load_next_shader() -> void:
	if current_shader_index < shaders_to_load.size():
		var shader_path: String = shaders_to_load[current_shader_index]
		var shader: Shader = ResourceLoader.load(shader_path, "Shader")
		if shader:
			RenderingServer.get_shader_parameter_list(shader.get_rid())
		
		# Simulate shader compilation time
		await get_tree().create_timer(0.5).timeout
		current_shader_index += 1
		load_next_shader()
