extends Control

# GlobalEnums available as autoload singleton

signal campaign_started(config: Dictionary)

var easy_config = {
	"name": "Quick Start - Story Mode",
	"difficulty": GlobalEnums.DifficultyLevel.STORY,
	"enable_permadeath": false,
	"use_story_track": true,
	"starting_credits": 1500,
	"starting_supplies": 6
}

var hardcore_config = {
	"name": "Quick Start - Nightmare Mode",
	"difficulty": GlobalEnums.DifficultyLevel.NIGHTMARE,
	"enable_permadeath": true,
	"use_story_track": false,
	"starting_credits": 500,
	"starting_supplies": 2
}

var campaign_presets = {
	"story": easy_config,
	"nightmare": hardcore_config
}

func _ready() -> void:
	_setup_preset_buttons()

func _setup_preset_buttons() -> void:
	for preset_id in campaign_presets:
		var preset = campaign_presets[preset_id]
		var button := Button.new()
		button.text = preset.name
		button.tooltip_text = _get_preset_description(preset)
		button.pressed.connect(_on_preset_selected.bind(preset_id))
		$PresetContainer.add_child(button)

func _get_preset_description(preset: Dictionary) -> String:
	var desc: String = "Difficulty: " + GlobalEnums.DifficultyLevel.keys()[preset.difficulty] + "\n"
	desc += "Story Track: " + ("Enabled" if preset.use_story_track else "Disabled") + "\n"
	desc += "Permadeath: " + ("Enabled" if preset.enable_permadeath else "Disabled")
	return desc

func _on_preset_selected(preset_id: String) -> void:
	var config = campaign_presets[preset_id].duplicate()
	campaign_started.emit(config)
	queue_free()