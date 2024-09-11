extends Control

func _on_video_button_pressed():
    get_node("/root/Main").goto_scene("res://assets/scenes/menus/options_menu/video/video_options_menu.tscn")

func _on_audio_button_pressed():
    get_node("/root/Main").goto_scene("res://assets/scenes/menus/options_menu/audio/audio_options_menu.tscn")

func _on_gameplay_button_pressed():
    get_node("/root/Main").goto_scene("res://assets/scenes/menus/options_menu/gameplay/gameplay_options_menu.tscn")

func _on_back_button_pressed():
    get_node("/root/Main").goto_scene("res://ui/mainmenu/MainMenu.tscn")
