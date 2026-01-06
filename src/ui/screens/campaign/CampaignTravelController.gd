class_name FPCM_CampaignTravelController
extends Control

const GameState = preload("res://src/core/state/GameState.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")

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

signal step_completed
signal phase_completed

func _ready() -> void:
	game_state_manager = get_node("/root/GameStateManager")
	if not game_state_manager:
		push_error("GameStateManager not found")
		queue_free()
		return

	var state_node: Node = game_state_manager.get_game_state()
	if state_node is GameState:
		game_state = state_node
	else:
		push_error("Invalid game state type")
		queue_free()
		return

	# SystemsAutoload handles patron system access
	var systems_autoload: Node = get_node_or_null("/root/SystemsAutoload")
	if not systems_autoload or not systems_autoload.are_systems_ready():
		push_error("SystemsAutoload not available or not ready")
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
	var systems_autoload: Node = get_node_or_null("/root/SystemsAutoload")
	if not systems_autoload:
		push_error("SystemsAutoload not available")
		return

	var available_patrons = systems_autoload.get_active_patrons()
	for patron in available_patrons:
		var description = patron.get("description", "Patron available")
		_display_result(patrons_list, description)
	step_completed.emit()

func _display_result(container: Control, description: String) -> void:
	var label := Label.new()
	label.text = description
	container.add_child(label)

