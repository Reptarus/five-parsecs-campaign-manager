# MainGameScene.gd
extends Node

# Only preload what we know exists
const GameStateManager = preload("res://src/data/resources/Core/GameState/GameStateManager.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const UIManager = preload("res://src/ui/screens/UIManager.gd")

signal scene_changed(scene_name: String)

@onready var scene_container: Control = $SceneContainer
@onready var transition_overlay: ColorRect = $TransitionOverlay
@onready var ui_manager: UIManager = $UIManager

var game_state_manager: GameStateManager

# Scenes dictionary - we'll add more as we create them
const SCENES: Dictionary = {
	"main_menu": "res://src/ui/screens/mainmenu/MainMenu.tscn",
	"campaign_setup": "res://src/ui/screens/management/CampaignSetup.tscn",
	"campaign_manager": "res://src/ui/screens/management/CampaignManager.tscn",
	"battle": "res://src/core/battle/Battle.tscn",
	"post_battle": "res://src/ui/screens/battle/PostBattle.tscn",
	"crew_management": "res://src/ui/screens/management/CrewManagement.tscn",
	"tutorial_setup": "res://src/ui/screens/tutorial/InitialCrewCreation.tscn",
	"options": "res://src/ui/screens/options/video_options_menu.tscn",
	"library": "res://src/ui/screens/reference/RulesReference.tscn"
}

var _current_scene_name: String = ""
var _is_transitioning: bool = false

func _ready() -> void:
	# Initialize managers
	game_state_manager = GameStateManager.new()
	add_child(game_state_manager)
	
	# Setup initial display
	transition_overlay.color.a = 0.0
	_validate_scenes()
	
	# Start with main menu
	change_scene("main_menu")

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
	# Clear existing scene
	for child in scene_container.get_children():
		child.queue_free()
	
	var scene_path = SCENES[scene_name]
	if ResourceLoader.exists(scene_path):
		var new_scene = load(scene_path)
		if new_scene:
			var instance = new_scene.instantiate()
			scene_container.add_child(instance)
			
			# Register with UI Manager
			ui_manager.register_screen(scene_name, instance)
			ui_manager.change_screen(scene_name)
			
			# Initialize if it's the main menu
			if scene_name == "main_menu" and instance.has_method("setup"):
				instance.setup(game_state_manager)
		else:
			push_error("Failed to load scene: %s" % scene_path)
	else:
		push_error("Scene file not found: %s" % scene_path)

func preload_scene(scene_name: String) -> void:
	if SCENES.has(scene_name) and ResourceLoader.exists(SCENES[scene_name]):
		ResourceLoader.load_threaded_request(SCENES[scene_name])
