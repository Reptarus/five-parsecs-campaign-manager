# UIManager.gd
class_name UIManager
extends Node

var current_screen: Control
var screens: Dictionary = {}
var game_state: GameState

func initialize(state: GameState):
	game_state = state

func _ready():
	# Register all screens
	register_screen("main_menu", $MainMenu)
	register_screen("campaign_setup", $CampaignSetup)
	register_screen("world_view", $WorldView)
	register_screen("crew_management", $CrewManagement)
	register_screen("mission_select", $MissionSelect)
	register_screen("battle", $Battle)
	register_screen("post_battle", $PostBattle)
	
	# Set initial screen
	change_screen("main_menu")

func register_screen(screen_name: String, screen: Control):
	screens[screen_name] = screen
	screen.hide()

func change_screen(screen_name: String):
	if current_screen:
		current_screen.hide()
	
	if screen_name in screens:
		current_screen = screens[screen_name]
		current_screen.show()
		emit_signal("screen_changed", current_screen)
	else:
		push_error("Screen not found: " + screen_name)

func update_crew_info():
	if current_screen.has_method("update_crew_info"):
		current_screen.update_crew_info()

func update_mission_info():
	if current_screen.has_method("update_mission_info"):
		current_screen.update_mission_info()

func update_world_info():
	if current_screen.has_method("update_world_info"):
		current_screen.update_world_info()

func show_dialog(title: String, message: String, options: Array):
	var dialog = $DialogBox
	dialog.set_title(title)
	dialog.set_message(message)
	dialog.set_options(options)
	dialog.show()

func show_tooltip(control: Control, text: String):
	var tooltip = $Tooltip
	tooltip.set_text(text)
	tooltip.set_position(control.get_global_position() + Vector2(0, control.get_size().y))
	tooltip.show()

func hide_tooltip():
	$Tooltip.hide()

func show_notification(message: String, duration: float = 2.0):
	var notif = $Notification
	notif.text = message
	notif.show()
	
	await get_tree().create_timer(duration).timeout
	notif.hide()

func update_credits_display():
	$HUD/CreditsLabel.text = "Credits: " + str(game_state.credits)

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
