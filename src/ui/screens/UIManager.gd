# UIManager.gd
extends Node

const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState := preload("res://src/core/state/GameState.gd")
const GameStateManager := preload("res://src/core/managers/GameStateManager.gd")

@warning_ignore("unused_signal")
signal screen_changed(screen: Control)
signal dialog_opened(dialog: Control)
signal dialog_closed(dialog: Control)

@export var main_menu_scene: PackedScene
@export var game_over_scene: PackedScene
@export var hud_scene: PackedScene

# UI state
var screens: Dictionary = {}
var current_screen: Control = null
var game_state: FiveParsecsGameState
var game_manager: GameStateManager
var hud: Control
var active_dialogs: Array[Control] = []

func _init(_game_state: FiveParsecsGameState) -> void:
	game_state = _game_state

func _ready() -> void:
	if hud_scene:
		hud = hud_scene.instantiate()
		add_child(hud)
		hud.hide()

func initialize(manager: GameStateManager) -> void:
	game_manager = manager
	var state = manager.get_game_state()
	if state is FiveParsecsGameState:
		game_state = state
	else:
		push_error("Invalid game state type received from manager")
	
	# Connect to all relevant signals
	if game_manager:
		game_manager.state_changed.connect(_on_game_state_changed)
		game_manager.campaign_phase_changed.connect(_on_campaign_phase_changed)
		game_manager.battle_phase_changed.connect(_on_battle_phase_changed)
		game_manager.game_started.connect(_on_game_started)
		game_manager.game_ended.connect(_on_game_ended)
		game_manager.campaign_victory_achieved.connect(_on_campaign_victory_achieved)
		
		# Show HUD if game is already active
		if game_manager.is_game_active():
			hud.show()

func register_screen(screen_name: String, screen: Control) -> void:
	if screen == null:
		push_error("Attempting to register null screen: " + screen_name)
		return
		
	screens[screen_name] = screen
	if screen.is_inside_tree():
		screen.hide()
	else:
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

func _on_game_started() -> void:
	hud.show()
	if game_manager.is_tutorial:
		change_screen("tutorial")
	else:
		change_screen("setup")

func _on_game_ended() -> void:
	hud.hide()
	hide_all_screens()
	change_screen("main_menu")

func _on_game_state_changed(new_state: int) -> void:
	match new_state:
		GlobalEnums.GameState.SETUP:
			change_screen("setup")
		GlobalEnums.GameState.CAMPAIGN:
			change_screen("campaign")
		GlobalEnums.GameState.BATTLE:
			change_screen("battle")
		GlobalEnums.GameState.GAME_OVER:
			show_game_over_screen(game_state.victory_achieved)

func _on_campaign_phase_changed(new_phase: GlobalEnums.CampaignPhase) -> void:
	update_campaign_phase_display(new_phase)
	if current_screen and current_screen.has_method("on_campaign_phase_changed"):
		current_screen.on_campaign_phase_changed(new_phase)

func _on_battle_phase_changed(new_phase: int) -> void:
	update_battle_phase_display(new_phase)
	if current_screen and current_screen.has_method("on_battle_phase_changed"):
		current_screen.on_battle_phase_changed(new_phase)

func _on_campaign_victory_achieved(victory_type: int) -> void:
	var victory_message := ""
	match victory_type:
		GlobalEnums.CampaignVictoryType.WEALTH_GOAL:
			victory_message = "You've amassed great wealth!"
		GlobalEnums.CampaignVictoryType.REPUTATION_GOAL:
			victory_message = "Your reputation precedes you!"
		GlobalEnums.CampaignVictoryType.FACTION_DOMINANCE:
			victory_message = "You've become a dominant force!"
		GlobalEnums.CampaignVictoryType.STORY_COMPLETE:
			victory_message = "You've completed your epic journey!"
	
	show_game_over_screen(true, victory_message)

func update_campaign_phase_display(phase: GlobalEnums.CampaignPhase) -> void:
	if has_node("HUD/PhaseLabel"):
		$HUD/PhaseLabel.text = "Phase: " + str(GlobalEnums.CampaignPhase.keys()[phase])

func update_battle_phase_display(phase: GlobalEnums.BattlePhase) -> void:
	if has_node("HUD/BattlePhaseLabel"):
		$HUD/BattlePhaseLabel.text = "Battle Phase: " + str(GlobalEnums.BattlePhase.keys()[phase])

func show_game_over_screen(victory: bool, message: String = "") -> void:
	if has_node("GameOverScreen"):
		$GameOverScreen/TitleLabel.text = "Victory!" if victory else "Game Over"
		$GameOverScreen/MessageLabel.text = message if message else \
			"Congratulations! You have achieved victory." if victory else \
			"Your campaign has come to an end."
		$GameOverScreen.show()

func hide_all_screens() -> void:
	for screen in screens.values():
		if is_instance_valid(screen):
			screen.hide()

func hide_game_over_screen() -> void:
	if has_node("GameOverScreen"):
		$GameOverScreen.hide()

func update_tutorial_display(text: String) -> void:
	if has_node("TutorialDisplay"):
		$TutorialDisplay.text = text
		$TutorialDisplay.show()

func hide_tutorial_display() -> void:
	if has_node("TutorialDisplay"):
		$TutorialDisplay.hide()
