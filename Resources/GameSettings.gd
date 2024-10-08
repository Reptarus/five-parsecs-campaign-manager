extends Resource
class_name GameSettings

@export var difficulty: int = 1  # Default to Normal
@export var disable_tutorial_popup: bool = false
@export var auto_save: bool = true
@export var language: int = 0  # Default to English

func _init():
    # Initialize default values if needed
    pass
