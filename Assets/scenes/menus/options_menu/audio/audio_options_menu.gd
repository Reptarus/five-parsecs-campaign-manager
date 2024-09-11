extends Control

@onready var master_volume_slider = $MasterVolumeSlider
@onready var music_volume_slider = $MusicVolumeSlider
@onready var sfx_volume_slider = $SFXVolumeSlider

func _ready():
    load_current_settings()

func load_current_settings():
    var config = ConfigFile.new()
    config.load("user://audio_settings.cfg")
    
    master_volume_slider.value = config.get_value("audio", "master_volume", 0.5)
    music_volume_slider.value = config.get_value("audio", "music_volume", 0.5)
    sfx_volume_slider.value = config.get_value("audio", "sfx_volume", 0.5)

func _on_master_volume_changed(value):
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))

func _on_music_volume_changed(value):
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))

func _on_sfx_volume_changed(value):
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))

func _on_apply_button_pressed():
    var config = ConfigFile.new()
    config.set_value("audio", "master_volume", master_volume_slider.value)
    config.set_value("audio", "music_volume", music_volume_slider.value)
    config.set_value("audio", "sfx_volume", sfx_volume_slider.value)
    config.save("user://audio_settings.cfg")

func _on_back_button_pressed():
    get_node("/root/Main").goto_scene("res://assets/scenes/menus/options_menu/options_menu.tscn")
