class_name PreBattleSceneScript
extends Control

signal battle_started
signal setup_completed

const MISSION_PANEL_SCENE = preload("res://Resources/BattlePhase/Scenes/MissionInfoPanel.tscn")
const ENEMY_PANEL_SCENE = preload("res://Resources/BattlePhase/Scenes/EnemyInfoPanel.tscn")
const BATTLEFIELD_PREVIEW_SCENE = preload("res://Resources/BattlePhase/Scenes/BattlefieldPreview.tscn")
const CHARACTER_BOX_SCENE = preload("res://Resources/CrewAndCharacters/Scenes/CharacterBox.tscn")

@onready var game_state: GameState = get_node("/root/GameStateManager").game_state
var terrain_generator: TerrainGenerator
var current_mission: Mission

# UI Elements
@onready var mission_container = $HBoxContainer/MissionPanel
@onready var enemy_container = $HBoxContainer/EnemyPanel
@onready var battlefield_container = $HBoxContainer/BattlefieldPanel
@onready var crew_container = $BottomPanel/CrewContainer
@onready var map_legend = $HBoxContainer/BattlefieldPanel/MapLegend
@onready var generate_terrain_button = $ButtonContainer/GenerateTerrainButton
@onready var place_characters_button = $ButtonContainer/PlaceCharactersButton
@onready var start_battle_button = $ButtonContainer/StartBattleButton
@onready var back_button = $ButtonContainer/BackButton

var mission_icons := {
	"assassination_target": preload("res://Assets/Icons/assassination_target.png"),
	"escort_target": preload("res://Assets/Icons/escort_target.png"),
	"intel": preload("res://Assets/Icons/intel.png"),
	"objective": preload("res://Assets/Icons/objective.png")
}

func _ready() -> void:
	current_mission = game_state.current_mission
	if not current_mission:
		push_error("No mission loaded")
		return
		
	initialize()
	setup_ui()
	connect_signals()

func initialize() -> void:
	terrain_generator = TerrainGenerator.new()
	terrain_generator.initialize(game_state)

func setup_ui() -> void:
	setup_mission_info()
	setup_enemy_info()
	setup_battlefield_preview()
	setup_crew_selection()
	setup_map_legend()
	update_button_states()

func connect_signals() -> void:
	generate_terrain_button.pressed.connect(_on_generate_terrain_pressed)
	place_characters_button.pressed.connect(_on_place_characters_pressed)
	start_battle_button.pressed.connect(_on_start_battle_pressed)
	back_button.pressed.connect(_on_back_pressed)

func setup_mission_info() -> void:
	var mission_panel = MISSION_PANEL_SCENE.instantiate()
	mission_panel.setup(current_mission)
	mission_container.add_child(mission_panel)

func setup_enemy_info() -> void:
	var enemy_panel = ENEMY_PANEL_SCENE.instantiate()
	enemy_panel.setup(current_mission.enemies)
	enemy_container.add_child(enemy_panel)

func setup_battlefield_preview() -> void:
	var preview = BATTLEFIELD_PREVIEW_SCENE.instantiate()
	preview.setup(current_mission.battlefield_size)
	battlefield_container.add_child(preview)

func setup_crew_selection() -> void:
	for character in game_state.current_crew.members:
		var char_box = CHARACTER_BOX_SCENE.instantiate()
		char_box.setup(character)
		crew_container.add_child(char_box)

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

func update_button_states() -> void:
	place_characters_button.disabled = true
	start_battle_button.disabled = true
	generate_terrain_button.disabled = false

func _on_generate_terrain_pressed() -> void:
	var battlefield_size := GlobalEnums.TerrainSize.MEDIUM
	var terrain_type := current_mission.terrain_type
	
	terrain_generator.generate_terrain(battlefield_size, terrain_type)
	terrain_generator.generate_features(current_mission.required_features, current_mission)
	terrain_generator.generate_cover()
	terrain_generator.generate_loot()
	terrain_generator.generate_enemies()
	terrain_generator.generate_npcs()
	
	_visualize_battlefield()
	place_characters_button.disabled = false
	generate_terrain_button.disabled = true

func _on_place_characters_pressed() -> void:
	_place_characters()
	start_battle_button.disabled = false
	place_characters_button.disabled = true

func _on_start_battle_pressed() -> void:
	battle_started.emit()
	queue_free()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Management/CampaignDashboard.tscn")

func _visualize_battlefield() -> void:
	var battlefield_view = BattlefieldView.new()
	battlefield_view.setup(terrain_generator.get_battlefield_data())
	battlefield_container.add_child(battlefield_view)

func _place_characters() -> void:
	var deployment_zone = _get_deployment_zone()
	var characters = game_state.current_crew.get_active_members()
	var placed_characters = []

	for character in characters:
		var valid_positions = _get_valid_positions(deployment_zone, placed_characters)
		if valid_positions.is_empty():
			push_warning("No valid positions left for character deployment")
			break

		var char_position = _select_position(valid_positions)
		_place_character(character, char_position)
		placed_characters.append({"character": character, "position": char_position})

	game_state.combat_manager.set_initial_positions(placed_characters)
	setup_completed.emit()

func _get_deployment_zone() -> Rect2:
	var battlefield_size = current_mission.battlefield_size
	return Rect2(Vector2.ZERO, Vector2(6, battlefield_size.y))
