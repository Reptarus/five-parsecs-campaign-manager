# NewCampaignTutorial.gd
extends Control

@warning_ignore("unused_signal")
signal tutorial_choice_made(choice: String)

func _ready():
    # Set up buttons and connect signals
    $StoryTrackButton.connect("pressed", _on_story_track_pressed)
    $CompendiumButton.connect("pressed", _on_compendium_pressed)
    $SkipButton.connect("pressed", _on_skip_pressed)

func _on_story_track_pressed():
    emit_signal("tutorial_choice_made", "story_track")

func _on_compendium_pressed():
    emit_signal("tutorial_choice_made", "compendium")

func _on_skip_pressed():
    emit_signal("tutorial_choice_made", "skip")
