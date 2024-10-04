# NewCampaignTutorial.gd
extends Control

signal tutorial_choice_made(choice)

@onready var story_track_button = $VBoxContainer/StoryTrackButton
@onready var compendium_button = $VBoxContainer/CompendiumButton
@onready var skip_button = $VBoxContainer/SkipButton

func _ready():
	story_track_button.connect("pressed", _on_story_track_pressed)
	compendium_button.connect("pressed", _on_compendium_pressed)
	skip_button.connect("pressed", _on_skip_pressed)

func _on_story_track_pressed():
	emit_signal("tutorial_choice_made", "story_track")
	queue_free()

func _on_compendium_pressed():
	emit_signal("tutorial_choice_made", "compendium")
	queue_free()

func _on_skip_pressed():
	emit_signal("tutorial_choice_made", "skip")
	queue_free()
