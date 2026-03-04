# This file should be referenced via preload
# Use explicit preloads instead of global class names
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
	# Use GameState autoload directly (GameStateManager.get_game_state() is always null)
	var gs = get_node_or_null("/root/GameState")
	if gs:
		game_state = gs
	else:
		push_error("TravelPhase: GameState autoload not found")
		return

	game_state_manager = get_node_or_null("/root/GameStateManager")

	# PatronJobManager is not an autoload and GameStateManager has no getter for it.
	# Leave patron_job_manager null — patron features are not yet wired.

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
	if not patron_job_manager:
		step_completed.emit()
		return
	var available_patrons = patron_job_manager.get_available_patrons()
	for patron in available_patrons:
		_display_result(patrons_list, patron.get_description())
	step_completed.emit()

func _display_result(container: Control, description: String) -> void:
	if not container:
		return
	var label = Label.new()
	label.text = description
	container.add_child(label)
