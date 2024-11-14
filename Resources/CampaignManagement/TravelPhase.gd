class_name TravelPhase
extends Control

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
var game_state: GameState
var game_state_manager: GameStateManager
var patron_job_manager: PatronJobManager

signal step_completed
signal phase_completed

func _ready() -> void:
	game_state_manager = GameStateManager.get_instance.call()
	if not game_state_manager:
		push_error("GameStateManager not found")
		queue_free()
		return
	
	game_state = game_state_manager.game_state
	patron_job_manager = game_state_manager.patron_job_manager
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
