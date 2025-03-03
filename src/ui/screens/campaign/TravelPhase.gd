class_name TravelPhase
extends Control

const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
const PatronJobManager = preload("res://src/core/campaign/PatronJobManager.gd")

enum TravelStep {
	UPKEEP,
	PATRON_CHECK,
	MISSION_START
}

@export var tab_container: TabContainer
@export var back_button: Button
@export var log_book: TextEdit
@export var patrons_list: Control
@export var mission_details: Control

var current_step: TravelStep = TravelStep.UPKEEP
var game_state: FiveParsecsGameState
var game_state_manager: GameStateManager
var patron_job_manager: PatronJobManager

signal step_completed
signal phase_completed

func _ready() -> void:
	game_state_manager = get_node("/root/GameStateManager")
	if not game_state_manager:
		push_error("GameStateManager not found")
		queue_free()
		return
	
	var state_node = game_state_manager.get_game_state()
	if state_node is FiveParsecsGameState:
		game_state = state_node
	else:
		push_error("Invalid game state type")
		queue_free()
		return
	
	var manager_node = game_state_manager.get_patron_job_manager()
	if manager_node is PatronJobManager:
		patron_job_manager = manager_node
	else:
		push_error("Invalid patron job manager type")
		queue_free()
		return
	
	_setup_current_step()

func _setup_current_step() -> void:
	match current_step:
		TravelStep.UPKEEP:
			# Implement the logic for the UPKEEP step
			pass
		TravelStep.PATRON_CHECK:
			process_patron_check()
		TravelStep.MISSION_START:
			# Implement the logic for the MISSION_START step
			pass

func process_patron_check() -> void:
	var available_patrons = patron_job_manager.get_available_patrons()
	for patron in available_patrons:
		_display_result(patrons_list, patron.get_description())
	step_completed.emit()

func _display_result(container: Control, description: String) -> void:
	var label = Label.new()
	label.text = description
	container.add_child(label)
