extends Control

signal tutorial_selected(tutorial_type)

func _ready():
	$StoryTrackButton.connect("pressed", Callable(self, "_on_story_track_pressed"))
	$CompendiumButton.connect("pressed", Callable(self, "_on_compendium_pressed"))
	$SkipButton.connect("pressed", Callable(self, "_on_skip_pressed"))

func _on_story_track_pressed():
	emit_signal("tutorial_selected", "story_track")

func _on_compendium_pressed():
	emit_signal("tutorial_selected", "compendium")

func _on_skip_pressed():
	emit_signal("tutorial_selected", "skip")
