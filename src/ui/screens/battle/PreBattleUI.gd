## PreBattleUI manages the pre-battle setup interface
class_name PreBattleUI
extends Control

## Dependencies
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const StoryQuestData = preload("res://src/core/story/StoryQuestData.gd")
const Character = preload("res://src/core/character/Base/Character.gd")
const UnifiedTerrainSystem = preload("res://src/core/terrain/UnifiedTerrainSystem.gd")

## Optional dependencies that may not exist
var _terrain_system_script = preload("res://src/core/terrain/UnifiedTerrainSystem.gd") if FileAccess.file_exists("res://src/core/terrain/UnifiedTerrainSystem.gd") else null

## Signals
signal crew_selected(crew: Array[Character])
signal deployment_confirmed
signal terrain_ready
signal preview_updated

## Node references
@onready var mission_info_panel = $MarginContainer/VBoxContainer/MainContent/LeftPanel/MissionInfo/VBoxContainer/Content
@onready var enemy_info_panel = $MarginContainer/VBoxContainer/MainContent/LeftPanel/EnemyInfo/VBoxContainer/Content
@onready var battlefield_preview = $MarginContainer/VBoxContainer/MainContent/CenterPanel/BattlefieldPreview/VBoxContainer/PreviewContent
@onready var crew_selection_panel = $MarginContainer/VBoxContainer/MainContent/RightPanel/CrewSelection/VBoxContainer/ScrollContainer/Content
@onready var deployment_panel = $MarginContainer/VBoxContainer/MainContent/RightPanel/DeploymentPanel/VBoxContainer/Content
@onready var confirm_button = $MarginContainer/VBoxContainer/FooterPanel/HBoxContainer/ConfirmButton
@onready var back_button = $MarginContainer/VBoxContainer/FooterPanel/HBoxContainer/BackButton

## State
var current_mission: StoryQuestData
var selected_crew: Array[Character]
var terrain_system: Node # Will be cast to UnifiedTerrainSystem if available

func _ready() -> void:
    _initialize_systems()
    _connect_signals()
    confirm_button.disabled = true

## Initialize required systems
func _initialize_systems() -> void:
    if _terrain_system_script:
        terrain_system = _terrain_system_script.new()
        if battlefield_preview:
            battlefield_preview.add_child(terrain_system)
            if terrain_system.has_signal("terrain_generated"):
                terrain_system.terrain_generated.connect(_on_terrain_generated)

## Connect UI signals
func _connect_signals() -> void:
    if confirm_button and not confirm_button.pressed.is_connected(_on_confirm_pressed):
        confirm_button.pressed.connect(_on_confirm_pressed)

## Setup the UI with mission data
func setup_preview(data: Dictionary) -> void:
    if not data:
        push_error("PreBattleUI: Invalid preview data")
        return
        
    _setup_mission_info(data)
    _setup_enemy_info(data)
    _setup_battlefield_preview(data)
    preview_updated.emit()

## Setup mission information
func _setup_mission_info(data: Dictionary) -> void:
    if not mission_info_panel:
        return
        
    var mission_title := Label.new()
    mission_title.text = data.get("title", "Unknown Mission")
    
    var mission_desc := Label.new()
    mission_desc.text = data.get("description", "No description available")
    
    var battle_type := Label.new()
    battle_type.text = "Battle Type: " + GameEnums.BattleType.keys()[data.get("battle_type", 0)]
    
    mission_info_panel.add_child(mission_title)
    mission_info_panel.add_child(mission_desc)
    mission_info_panel.add_child(battle_type)

## Setup enemy information
func _setup_enemy_info(data: Dictionary) -> void:
    if not enemy_info_panel:
        return
        
    var enemy_force = data.get("enemy_force", {})
    var enemy_list := VBoxContainer.new()
    
    for unit in enemy_force.get("units", []):
        var unit_label := Label.new()
        unit_label.text = unit.get("type", "Unknown Unit")
        enemy_list.add_child(unit_label)
    
    enemy_info_panel.add_child(enemy_list)

## Setup battlefield preview
func _setup_battlefield_preview(data: Dictionary) -> void:
    if not battlefield_preview or not terrain_system:
        return
        
    if terrain_system.has_method("generate_battlefield"):
        terrain_system.generate_battlefield(data)

## Setup crew selection
func setup_crew_selection(available_crew: Array[Character]) -> void:
    if not crew_selection_panel:
        return
        
    var crew_list := VBoxContainer.new()
    
    for character in available_crew:
        var char_button := Button.new()
        char_button.text = character.name
        char_button.toggle_mode = true
        char_button.pressed.connect(_on_character_selected.bind(character))
        crew_list.add_child(char_button)
    
    crew_selection_panel.add_child(crew_list)

## Handle character selection
func _on_character_selected(character: Character) -> void:
    if not selected_crew:
        selected_crew = []
        
    if selected_crew.has(character):
        selected_crew.erase(character)
    else:
        selected_crew.append(character)
    
    crew_selected.emit(selected_crew)
    _update_confirm_button()

## Handle terrain generation completion
func _on_terrain_generated(_terrain_data: Dictionary) -> void:
    terrain_ready.emit()
    _update_confirm_button()

## Handle confirm button press
func _on_confirm_pressed() -> void:
    deployment_confirmed.emit()

## Update confirm button state
func _update_confirm_button() -> void:
    if not confirm_button:
        return
        
    confirm_button.disabled = selected_crew.is_empty() or not terrain_system or not terrain_system.has_method("is_terrain_ready") or not terrain_system.is_terrain_ready()

## Get selected crew
func get_selected_crew() -> Array[Character]:
    return selected_crew

## Cleanup
func cleanup() -> void:
    selected_crew.clear()
    current_mission = null
    
    if terrain_system and terrain_system.has_method("cleanup"):
        terrain_system.cleanup()
        
    # Clear UI panels
    for child in mission_info_panel.get_children():
        child.queue_free()
    for child in enemy_info_panel.get_children():
        child.queue_free()
    for child in crew_selection_panel.get_children():
        child.queue_free()
    for child in deployment_panel.get_children():
        child.queue_free()