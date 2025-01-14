extends Control

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

signal campaign_started(config: Dictionary)

var campaign_presets = {
    "beginner": {
        "name": "Beginner Campaign",
        "difficulty": GameEnums.DifficultyLevel.EASY,
        "enable_tutorial": true,
        "enable_permadeath": false
    },
    "standard": {
        "name": "Standard Campaign",
        "difficulty": GameEnums.DifficultyLevel.NORMAL,
        "enable_tutorial": false,
        "enable_permadeath": false
    },
    "veteran": {
        "name": "Hardcore Campaign",
        "difficulty": GameEnums.DifficultyLevel.HARDCORE,
        "enable_tutorial": false,
        "enable_permadeath": true
    }
}

func _ready() -> void:
    _setup_preset_buttons()

func _setup_preset_buttons() -> void:
    for preset_id in campaign_presets:
        var preset = campaign_presets[preset_id]
        var button = Button.new()
        button.text = preset.name
        button.tooltip_text = _get_preset_description(preset)
        button.pressed.connect(_on_preset_selected.bind(preset_id))
        $PresetContainer.add_child(button)

func _get_preset_description(preset: Dictionary) -> String:
    var desc = "Difficulty: " + GameEnums.DifficultyLevel.keys()[preset.difficulty] + "\n"
    desc += "Tutorial: " + ("Enabled" if preset.enable_tutorial else "Disabled") + "\n"
    desc += "Permadeath: " + ("Enabled" if preset.enable_permadeath else "Disabled")
    return desc

func _on_preset_selected(preset_id: String) -> void:
    var config = campaign_presets[preset_id].duplicate()
    campaign_started.emit(config)
    queue_free()