extends Control

signal tutorial_started(type: String)
signal tutorial_skipped

func _ready() -> void:
	$VBoxContainer/StoryTrackButton.pressed.connect(_on_story_track_pressed)
	$VBoxContainer/CompendiumButton.pressed.connect(_on_compendium_pressed)
	$VBoxContainer/SkipButton.pressed.connect(_on_skip_pressed)

func _on_story_track_pressed() -> void:
	tutorial_started.emit("story")

func _on_compendium_pressed() -> void:
	tutorial_started.emit("compendium")

func _on_skip_pressed() -> void:
	tutorial_skipped.emit()
