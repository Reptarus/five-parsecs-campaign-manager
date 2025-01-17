extends PanelContainer
class_name BasePhasePanel

signal phase_action_completed
signal phase_action_failed(error_message: String)

var game_state: GameState
var phase_manager: CampaignPhaseManager

func _init() -> void:
	custom_minimum_size = Vector2(400, 300)

func setup(state: GameState, manager: CampaignPhaseManager) -> void:
	game_state = state
	phase_manager = manager
	_setup_phase_ui()
	_connect_signals()

func _setup_phase_ui() -> void:
	# Override in child classes to setup phase-specific UI
	pass

func _connect_signals() -> void:
	# Override in child classes to connect phase-specific signals
	pass

func _on_phase_started() -> void:
	# Override in child classes to handle phase start
	pass

func _on_phase_completed() -> void:
	# Override in child classes to handle phase completion
	pass

func _on_phase_failed(error: String) -> void:
	# Override in child classes to handle phase failure
	push_error("Phase failed: %s" % error)
	phase_action_failed.emit(error)

func _validate_phase_requirements() -> Dictionary:
	# Override in child classes to validate phase-specific requirements
	return {
		"valid": true,
		"error": ""
	}

func _execute_phase_action() -> void:
	# Override in child classes to execute phase-specific actions
	push_warning("No phase action implemented")
	phase_action_completed.emit()

func start_phase() -> void:
	var validation = _validate_phase_requirements()
	if not validation.valid:
		_on_phase_failed(validation.error)
		return
	
	_on_phase_started()
	_execute_phase_action()

func complete_phase() -> void:
	_on_phase_completed()
	phase_action_completed.emit()

func cleanup() -> void:
	# Override in child classes to perform cleanup when panel is removed
	pass