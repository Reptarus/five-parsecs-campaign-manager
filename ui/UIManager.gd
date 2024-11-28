# UIManager.gd
extends Node

const GlobalEnums = preload("res://Resources/GameData/GlobalEnums.gd")
const GameStateResource = preload("res://Resources/GameData/GameState.gd")
const GameStateManager = preload("res://StateMachines/GameStateManager.gd")

signal screen_changed(screen)

var screens: Dictionary = {}
var current_screen: Control = null
var game_state: GameStateResource
var game_manager: GameStateManager

func initialize(manager: GameStateManager) -> void:
	game_manager = manager
	game_state = manager.game_state

func _ready() -> void:
	# Initialize with empty dictionary
	screens = {}

func register_screen(screen_name: String, screen: Control) -> void:
	if screen == null:
		push_error("Attempting to register null screen: " + screen_name)
		return
		
	screens[screen_name] = screen
	if screen.is_inside_tree():
		screen.hide()
	else:
		# Wait for screen to enter tree before hiding
		await screen.ready
		screen.hide()

func change_screen(screen_name: String) -> void:
	if not screen_name in screens:
		push_error("Screen not found: " + screen_name)
		return
		
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.hide()
		
	current_screen = screens[screen_name]
	if current_screen != null and is_instance_valid(current_screen):
		current_screen.show()
		screen_changed.emit(current_screen)

func update_crew_info() -> void:
	if current_screen != null and current_screen.has_method("update_crew_info"):
		current_screen.update_crew_info()

func update_mission_info() -> void:
	if current_screen != null and current_screen.has_method("update_mission_info"):
		current_screen.update_mission_info()

func update_world_info() -> void:
	if current_screen != null and current_screen.has_method("update_world_info"):
		current_screen.update_world_info()

func show_dialog(title: String, message: String, options: Array = []) -> String:
	var dialog: ConfirmationDialog
	
	if options.is_empty():
		# Use AcceptDialog for simple OK dialogs
		dialog = AcceptDialog.new()
		dialog.ok_button_text = "OK"
	else:
		# Use ConfirmationDialog for dialogs with options
		dialog = ConfirmationDialog.new()
		dialog.ok_button_text = options[0] if options.size() > 0 else "OK"
		dialog.cancel_button_text = options[1] if options.size() > 1 else "Cancel"
		
	dialog.title = title
	dialog.dialog_text = message
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	
	add_child(dialog)
	dialog.popup_centered()
	
	var choice = await dialog.confirmed if options.is_empty() else await dialog.get_ok_button().pressed
	dialog.queue_free()
	
	return options[0] if choice and options.size() > 0 else "OK"

func show_tooltip(text: String, position: Vector2) -> void:
	# Implement tooltip functionality
	pass

func hide_tooltip() -> void:
	# Implement tooltip hiding
	pass

func show_notification(text: String, duration: float = 2.0) -> void:
	# Implement notification system
	pass

func update_credits_display(credits: int) -> void:
	if current_screen != null and current_screen.has_method("update_credits"):
		current_screen.update_credits(credits)

func update_story_points_display():
	$HUD/StoryPointsLabel.text = "Story Points: " + str(game_state.story_points)

func update_turn_display():
	$HUD/TurnLabel.text = "Turn: " + str(game_state.campaign_turn)

func show_loading_screen():
	$LoadingScreen.show()

func hide_loading_screen():
	$LoadingScreen.hide()

func show_game_over_screen(victory: bool):
	if victory:
		$GameOverScreen/TitleLabel.text = "Victory!"
		$GameOverScreen/MessageLabel.text = "Congratulations! You have achieved your victory condition."
	else:
		$GameOverScreen/TitleLabel.text = "Game Over"
		$GameOverScreen/MessageLabel.text = "Your crew's adventure has come to an end."
	
	$GameOverScreen.show()

func hide_game_over_screen():
	$GameOverScreen.hide()

func update_tutorial_display(text: String):
	$TutorialDisplay.text = text
	$TutorialDisplay.show()

func hide_tutorial_display():
	$TutorialDisplay.hide()

func update_campaign_phase_display(phase: GlobalEnums.CampaignPhase):
	$HUD/PhaseLabel.text = "Phase: " + GlobalEnums.CampaignPhase.keys()[phase]
