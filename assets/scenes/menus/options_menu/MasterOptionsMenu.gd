extends Control

@onready var tab_container: Button = $"Panel/MarginContainer/VBoxContainer/TabContainer"
@onready var video_options: Button = $"Panel/MarginContainer/VBoxContainer/TabContainer/Video"
@onready var audio_options: Button = $"Panel/MarginContainer/VBoxContainer/TabContainer/Audio"
@onready var audio_input_options: Button = $"Panel/MarginContainer/VBoxContainer/TabContainer/AudioInput"
@onready var input_options = $Panel/MarginContainer/VBoxContainer/TabContainer/Input

func _ready() -> void:
	# Connect signals from child scenes if needed
	pass

func _on_apply_button_pressed() -> void:
	# Call apply methods for each options menu
	video_options.apply_settings()
	audio_options.apply_settings()
	audio_input_options.apply_settings()
	input_options.apply_settings()

func _on_back_button_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://ui/mainmenu/MainMenu.tscn")

# You can add methods to switch tabs programmatically if needed
func switch_to_video_tab() -> void:
	tab_container.current_tab = 0

func switch_to_audio_tab() -> void:
	tab_container.current_tab = 1

func switch_to_audio_input_tab() -> void:
	tab_container.current_tab = 2

func switch_to_input_tab() -> void:
	tab_container.current_tab = 3
