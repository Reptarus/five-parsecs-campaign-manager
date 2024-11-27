# MainGameScene.gd
extends Node

signal scene_changed(scene_name: String)

@onready var scene_container: Node = $SceneContainer
@onready var transition_overlay: ColorRect = $TransitionOverlay
@onready var game_state_manager: GameStateManager = get_node("/root/GameStateManager")

const SCENES: Dictionary = {
	"main_menu": "res://ui/mainmenu/MainMenu.tscn",
	"settings": "res://ui/settings/SettingsScene.tscn",
	"tutorial_main": "res://Resources/UI/Scenes/TutorialMain.tscn",
	"tutorial_overlay": "res://Resources/UI/Scenes/TutorialOverlay.tscn",
	"tutorial_progress": "res://Resources/UI/Scenes/TutorialProgress.tscn",
	"tutorial_content": "res://Resources/UI/Scenes/TutorialContent.tscn",
	"tutorial_selection": "res://Resources/CampaignManagement/Scenes/TutorialSelection.tscn",
	"new_campaign": "res://Resources/Utilities/NewCampaignFlow.tscn",
	"campaign_tutorial": "res://Resources/CampaignManagement/Scenes/NewCampaignTutorial.tscn",
	"initial_crew": "res://Resources/CrewAndCharacters/InitialCrewCreation.tscn",
	"crew_size": "res://Resources/CampaignManagement/Scenes/CrewSizeSelection.tscn",
	"character_creator": "res://Resources/CampaignManagement/Scenes/CharacterCreator.tscn",
	"campaign_setup": "res://Resources/CampaignManagement/Scenes/CampaignSetupScreen.tscn",
	"victory_condition": "res://Resources/CampaignManagement/Scenes/VictoryConditionSelection.tscn",
	"crew_management": "res://Resources/CampaignManagement/Scenes/CrewManagement.tscn",
	"tutorial_phase": "res://Scenes/campaign/TutorialPhase.tscn",
	"world_phase": "res://Resources/WorldPhase/WorldPhaseUI.tscn",
	"travel_phase": "res://Resources/TravelPhase/TravelPhaseUI.tscn",
	"pre_battle": "res://Resources/BattlePhase/PreBattle.tscn",
	"battle": "res://Resources/BattlePhase/Scenes/Battle.tscn",
	"mission_info": "res://Resources/BattlePhase/Scenes/MissionInfoPanel.tscn",
	"enemy_info": "res://Resources/BattlePhase/Scenes/EnemyInfoPanel.tscn",
	"battlefield_preview": "res://Resources/BattlePhase/Scenes/BattlefieldPreview.tscn",
	"character_box": "res://Resources/CrewAndCharacters/Scenes/CharacterBox.tscn"
}

var _current_scene_name: String = ""
var _is_transitioning: bool = false
@export var tutorial_content: TutorialContent
@export var tutorial_state: Resource

func _ready() -> void:
	if not game_state_manager:
		push_error("GameStateManager not found")
		return
		
	transition_overlay.color.a = 0.0
	_validate_scenes()
	change_scene("main_menu")
	
	# Initialize tutorial resources
	tutorial_content = load("res://Resources/GameData/TutorialContent.tres") as TutorialContent
	if not tutorial_content:
		push_warning("Failed to load TutorialContent, creating new instance")
		tutorial_content = TutorialContent.new()
		
	tutorial_state = load("res://Resources/GameData/TutorialState.tres")
	if not tutorial_state:
		tutorial_state = TutorialState.new()
	
	# Connect tutorial signals
	var tutorial_selection = $TutorialSelection
	if tutorial_selection:
		tutorial_selection.tutorial_started.connect(_on_tutorial_started)
		tutorial_selection.tutorial_skipped.connect(_on_tutorial_skipped)

func _on_tutorial_skipped() -> void:
	tutorial_state.is_active = false
	tutorial_state.current_step = ""

func _validate_scenes() -> void:
	for scene_name in SCENES:
		if not ResourceLoader.exists(SCENES[scene_name]):
			push_warning("Scene not found: %s at %s" % [scene_name, SCENES[scene_name]])

func change_scene(scene_name: String) -> void:
	if _is_transitioning:
		push_warning("Scene transition already in progress")
		return
		
	if not SCENES.has(scene_name):
		push_error("Invalid scene name: %s" % scene_name)
		return
		
	_is_transitioning = true
	
	var transition = create_tween()
	transition.tween_property(transition_overlay, "color:a", 1.0, 0.3)
	await transition.finished
	
	_change_scene_content(scene_name)
	
	transition = create_tween()
	transition.tween_property(transition_overlay, "color:a", 0.0, 0.3)
	await transition.finished
	
	_is_transitioning = false
	_current_scene_name = scene_name
	scene_changed.emit(scene_name)

func _change_scene_content(scene_name: String) -> void:
	for child in scene_container.get_children():
		child.queue_free()
	
	var scene_path = SCENES[scene_name]
	if ResourceLoader.exists(scene_path):
		var new_scene = load(scene_path)
		if new_scene:
			scene_container.add_child(new_scene.instantiate())
		else:
			push_error("Failed to load scene: %s" % scene_path)
	else:
		push_error("Scene file not found: %s" % scene_path)

func preload_scene(scene_name: String) -> void:
	if SCENES.has(scene_name) and ResourceLoader.exists(SCENES[scene_name]):
		ResourceLoader.load_threaded_request(SCENES[scene_name])

func _on_tutorial_started(type: String) -> void:
	tutorial_state.tutorial_type = type
	tutorial_state.is_active = true
	tutorial_state.current_step = "introduction"
	
	# Initialize appropriate tutorial track
	match type:
		"story":
			_start_story_tutorial()
		"quick_start":
			_start_quick_tutorial()

func _start_story_tutorial() -> void:
	var layout = StoryTrackTutorialLayout.get_story_layout("introduction")
	var game_state = get_node("/root/GameState")
	game_state.start_tutorial_mission(layout)

func _start_quick_tutorial() -> void:
	var tutorial_manager = get_node("TutorialManager")
	if tutorial_manager:
		tutorial_manager.start_tutorial(GameTutorialManager.TutorialTrack.QUICK_START)
		tutorial_manager.start_tutorial(GameTutorialManager.TutorialTrack.QUICK_START)
