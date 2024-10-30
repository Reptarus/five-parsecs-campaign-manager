extends Control

const MISSION_PANEL_SCENE = preload("res://Resources/BattlePhase/Scenes/MissionInfoPanel.tscn")
const ENEMY_PANEL_SCENE = preload("res://Resources/BattlePhase/Scenes/EnemyInfoPanel.tscn")
const BATTLEFIELD_PREVIEW_SCENE = preload("res://Resources/BattlePhase/Scenes/BattlefieldPreview.tscn")
const CHARACTER_BOX_SCENE = preload("res://Resources/CrewAndCharacters/Scenes/CharacterBox.tscn")

@onready var mission_container = $HBoxContainer/MissionPanel
@onready var enemy_container = $HBoxContainer/EnemyPanel
@onready var battlefield_container = $HBoxContainer/BattlefieldPanel
@onready var crew_container = $BottomPanel/CrewContainer
@onready var map_legend = $HBoxContainer/BattlefieldPanel/MapLegend

var mission_icons = {
    "assassination_target": preload("res://Assets/Icons/assassination_target.png"),
    "escort_target": preload("res://Assets/Icons/escort_target.png"),
    "intel": preload("res://Assets/Icons/intel.png"),
    "objective": preload("res://Assets/Icons/objective.png"),
    # Add other mission-specific icons
}

func _ready() -> void:
    setup_mission_info()
    setup_enemy_info()
    setup_battlefield_preview()
    setup_crew_selection()
    setup_map_legend()

func setup_map_legend() -> void:
    for icon_name in mission_icons:
        var icon_container = HBoxContainer.new()
        var icon = TextureRect.new()
        icon.texture = mission_icons[icon_name]
        var label = Label.new()
        label.text = icon_name.capitalize()
        icon_container.add_child(icon)
        icon_container.add_child(label)
        map_legend.add_child(icon_container) 