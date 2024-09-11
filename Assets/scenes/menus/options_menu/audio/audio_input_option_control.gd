
extends Control

@onready var input_option_button: OptionButton = $InputOptionButton
@onready var test_button: Button = $TestButton
@onready var volume_slider: HSlider = $VolumeSlider

var audio_inputs: Array = []

func _ready() -> void:
	_populate_audio_inputs()
	_connect_signals()

func _populate_audio_inputs() -> void:
	audio_inputs = AudioServer.get_input_device_list()
	
	for input in audio_inputs:
		input_option_button.add_item(input)
	
	var current_input = AudioServer.get_input_device()
	input_option_button.select(audio_inputs.find(current_input))

func _connect_signals() -> void:
	input_option_button.item_selected.connect(_on_input_selected)
	test_button.pressed.connect(_on_test_button_pressed)
	volume_slider.value_changed.connect(_on_volume_changed)

func _on_input_selected(index: int) -> void:
	var selected_input = audio_inputs[index]
	AudioServer.set_input_device(selected_input)

func _on_test_button_pressed() -> void:
	# Implement audio input test functionality here
	# For example, you could record a short audio clip and play it back
	print("Testing audio input...")

func _on_volume_changed(value: float) -> void:
	var volume_db = linear_to_db(value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Record"), volume_db)

func _exit_tree() -> void:
	# Save the selected audio input and volume settings
	var config = ConfigFile.new()
	config.set_value("audio", "input_device", AudioServer.get_input_device())
	config.set_value("audio", "input_volume", volume_slider.value)
	config.save("user://audio_settings.cfg")
