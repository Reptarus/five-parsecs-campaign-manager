extends Control

@onready var return_button = $Button
func _ready():
    return_button.connect("pressed", Callable(self, "_on_return_button_pressed"))

func _on_return_button_pressed():
    get_tree().change_scene("res://Scenes/MainMenu.tscn")
