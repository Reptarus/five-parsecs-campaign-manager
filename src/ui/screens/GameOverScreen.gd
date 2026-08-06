extends Control

const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
## The canonical victory evaluator (Core Rules p.64, 18 condition types). The
## same one CampaignPhaseManager uses on turn rollover.
const VictoryCheckerRef = preload("res://src/core/victory/VictoryChecker.gd")

## %-unique, not $-paths: the three nodes now live inside
## MarginContainer/CenterContainer/Column so they can be laid out instead of
## absolutely positioned, and a $-path would have to be rewritten every time the
## wrapper changes. They previously sat at the scene root at fixed offsets — the
## outcome label was a 40x23 px box (too small to render the word "Victory!") and
## the button was 96 px wide for the text "Return to Main Menu".
@onready var return_button: Button = %Button
@onready var victory_label: Label = %VictoryLabel
@onready var defeat_label: Label = %DefeatLabel

var game_state_manager: GameStateManager

func _ready() -> void:
	var potential_game_state_manager = get_node_or_null("/root/GameStateManager")
	if potential_game_state_manager is GameStateManager:
		game_state_manager = potential_game_state_manager
	else:
		push_error("Node at /root/GameStateManager is not of type GameStateManager")
		return

	if not game_state_manager:
		push_error("GameStateManager not found. Make sure GameStateManager is properly set up as an AutoLoad.")
		return

	# The .tscn ALREADY wires Button.pressed -> _on_return_button_pressed via a
	# [connection]. Connecting again here made Godot error ("Signal 'pressed' is
	# already connected"), and had it succeeded the handler would have fired
	# twice per press. The scene connection is the one true wiring; this guard
	# keeps the code path working for anyone who builds the screen without it.
	if not return_button.pressed.is_connected(_on_return_button_pressed):
		return_button.pressed.connect(_on_return_button_pressed)

	DialogStyles.style_primary_button(return_button)
	ScreenChrome.apply_page_chrome(
		self, get_node_or_null("MarginContainer") as MarginContainer
	)

	_update_game_over_display()

func _update_game_over_display() -> void:
	## THE BUG THIS FIXES: this called game_state_manager.check_victory_conditions(),
	## which DOES NOT EXIST — GameStateManager only has get/set_victory_conditions()
	## accessors. A nonexistent method call aborts the enclosing function, so
	## _update_game_over_display() unwound at this line every single time and
	## NEITHER label was ever shown or hidden. The Game Over screen displayed
	## whatever the scene happened to ship with, regardless of the outcome.
	##
	## Routed through VictoryChecker, the evaluator CampaignPhaseManager already
	## uses, so the screen agrees with the turn-rollover check that sent us here.
	# The campaign lives on GameState, not on the manager — GameStateManager has
	# no get_current_campaign(). Checked rather than assumed, because assuming a
	# method exists is precisely what broke this function in the first place.
	var campaign: Variant = null
	var gs = game_state_manager.game_state
	if gs != null and gs.has_method("get_current_campaign"):
		campaign = gs.get_current_campaign()

	var achieved: bool = false
	if campaign != null:
		var turn: int = 0
		if "progress_data" in campaign and campaign.progress_data is Dictionary:
			turn = int(campaign.progress_data.get("turns_played", 0))
		achieved = bool(VictoryCheckerRef.check_victory(campaign, turn) \
			.get("achieved", false))

	victory_label.visible = achieved
	defeat_label.visible = not achieved

func _on_return_button_pressed() -> void:
	## Route through SceneRouter like every other screen. The previous direct
	## change_scene_to_file() targeted a bare "ui/mainmenu/MainMenu.tscn" — a path
	## that does not exist in this repo (the real one is under src/ui/screens/), so
	## ending a campaign dead-ended on the Game Over screen with no way back.
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("main_menu")
		return
	get_tree().change_scene_to_file("res://src/ui/screens/mainmenu/MainMenu.tscn")
