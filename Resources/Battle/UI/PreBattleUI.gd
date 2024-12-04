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
    "assassination_target": preload("res://assets/Basic assets/Icons/17.png"),
    "escort_target": preload("res://assets/Basic assets/Icons/18.png"),
    "intel": preload("res://assets/Basic assets/Icons/05.png"),
    "objective": preload("res://assets/Basic assets/Icons/07.png"),
    # Add other mission-specific icons
}

func _ready() -> void:
    setup_ui()

func setup_ui() -> void:
    setup_mission_info()
    setup_enemy_info()
    setup_battlefield_preview()
    setup_crew_selection()
    setup_map_legend()

func setup_mission_info() -> void:
    var mission_panel = MISSION_PANEL_SCENE.instantiate()
    mission_container.add_child(mission_panel)

func setup_enemy_info() -> void:
    var enemy_panel = ENEMY_PANEL_SCENE.instantiate()
    enemy_container.add_child(enemy_panel)

func setup_battlefield_preview() -> void:
    var battlefield_preview = BATTLEFIELD_PREVIEW_SCENE.instantiate()
    battlefield_container.add_child(battlefield_preview)
func setup_crew_selection() -> void:
    var game_state = get_node("/root/GameState")
    for character in game_state.current_crew.members:
        var character_box = CHARACTER_BOX_SCENE.instantiate()
        crew_container.add_child(character_box)

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