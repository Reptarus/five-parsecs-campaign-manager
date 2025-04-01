extends Node

var _combat_state = {"phase": "SETUP", "active_team": 0, "round": 1}
var _registered_characters = []

signal combat_state_changed(new_state)
signal character_registered(character)
signal combat_started
signal combat_ended
signal phase_changed(old_phase, new_phase)

func initialize():
	_combat_state = {"phase": "SETUP", "active_team": 0, "round": 1}
	_registered_characters = []
	return true
	
func setup_default_state():
	_combat_state = {"phase": "SETUP", "active_team": 0, "round": 1}
	return true
	
func get_combat_state():
	return _combat_state
	
func set_combat_state(state):
	var old_phase = _combat_state.get("phase", "SETUP")
	_combat_state = state
	var new_phase = _combat_state.get("phase", "SETUP")
	
	if old_phase != new_phase:
		emit_signal("phase_changed", old_phase, new_phase)
	
	emit_signal("combat_state_changed", _combat_state)
	return true
	
func register_character(character):
	if character and not character in _registered_characters:
		_registered_characters.append(character)
		emit_signal("character_registered", character)
		return true
	return false
	
func add_character(character):
	return register_character(character)
	
func get_registered_characters():
	return _registered_characters
	
func start_combat():
	var old_phase = _combat_state.get("phase", "SETUP")
	_combat_state["phase"] = "DEPLOYMENT"
	emit_signal("combat_started")
	emit_signal("phase_changed", old_phase, "DEPLOYMENT")
	return true
	
func end_combat():
	var old_phase = _combat_state.get("phase", "COMBAT")
	_combat_state["phase"] = "RESOLUTION"
	emit_signal("combat_ended")
	emit_signal("phase_changed", old_phase, "RESOLUTION")
	return true
	
func advance_phase():
	var phases = ["SETUP", "DEPLOYMENT", "COMBAT", "RESOLUTION"]
	var current_phase = _combat_state.get("phase", "SETUP")
	var current_index = phases.find(current_phase)
	
	if current_index >= 0 and current_index < phases.size() - 1:
		var old_phase = current_phase
		var new_phase = phases[current_index + 1]
		_combat_state["phase"] = new_phase
		emit_signal("phase_changed", old_phase, new_phase)
		return true
	
	return false
