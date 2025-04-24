@tool
extends Node

# This script serves as a wrapper for FiveParsecsMissionGenerator
# It forwards method calls to the underlying generator instance,
# allowing the RefCounted generator to be used in Node contexts

var _generator = null

func _ready() -> void:
	# Get the generator from metadata
	if has_meta("generator"):
		_generator = get_meta("generator")
	
	# Provide warning if generator is missing
	if not _generator:
		push_error("FiveParsecsMissionGeneratorWrapper: No generator found in metadata")

# Forward method calls to the underlying generator
func generate_mission(difficulty: int = 2, type: int = -1) -> Dictionary:
	if not _get_generator():
		push_error("Cannot generate mission: generator not available")
		return {}
	
	return _get_generator().generate_mission(difficulty, type)

func generate_mission_with_type(type: int) -> Dictionary:
	if not _get_generator():
		push_error("Cannot generate mission: generator not available")
		return {}
	
	return _get_generator().generate_mission_with_type(type)

func serialize_mission(mission_data: Dictionary) -> Dictionary:
	if not _get_generator():
		push_error("Cannot serialize mission: generator not available")
		return {}
	
	return _get_generator().serialize_mission(mission_data)

func deserialize_mission(serialized_data: Dictionary) -> Dictionary:
	if not _get_generator():
		push_error("Cannot deserialize mission: generator not available")
		return {}
	
	return _get_generator().deserialize_mission(serialized_data)

func create_from_save(save_data: Dictionary) -> Dictionary:
	if not _get_generator():
		push_error("Cannot create from save: generator not available")
		return {}
	
	var new_generator = _get_generator().create_from_save(save_data)
	if new_generator:
		return new_generator.serialize_mission({})
	return {}

# Set game state
func set_game_state(game_state) -> bool:
	if not _get_generator() or not _get_generator().has_method("set_game_state"):
		push_error("Cannot set game state: generator not available or method missing")
		return false
	
	return _get_generator().set_game_state(game_state)

# Set world manager
func set_world_manager(world_manager) -> bool:
	if not _get_generator() or not _get_generator().has_method("set_world_manager"):
		push_error("Cannot set world manager: generator not available or method missing")
		return false
	
	return _get_generator().set_world_manager(world_manager)

# Helper method to get the generator, refreshing from metadata if needed
func _get_generator():
	if not _generator and has_meta("generator"):
		_generator = get_meta("generator")
	return _generator

# Signal forwarding setup
func connect_signals_to(target: Object) -> void:
	if not _get_generator():
		push_error("Cannot connect signals: generator not available")
		return
	
	# Identify signals from the generator and forward them
	var generator_signals = []
	if _generator.has_signal("generation_started"):
		generator_signals.append("generation_started")
	if _generator.has_signal("mission_generated"):
		generator_signals.append("mission_generated")
	if _generator.has_signal("generation_completed"):
		generator_signals.append("generation_completed")
	
	# Forward all signals
	for signal_name in generator_signals:
		# First create the signal on the wrapper if it doesn't exist
		if not self.has_signal(signal_name):
			add_user_signal(signal_name)
		
		# Connect generator's signal to wrapper's signal
		if not _generator.is_connected(signal_name, Callable(self, "_on_generator_" + signal_name)):
			_generator.connect(signal_name, Callable(self, "_on_generator_" + signal_name))
		
		# Connect wrapper's signal to target
		if not is_connected(signal_name, Callable(target, "_on_" + signal_name)):
			connect(signal_name, Callable(target, "_on_" + signal_name))

# Signal forwarding methods
func _on_generator_generation_started(data = null) -> void:
	emit_signal("generation_started", data)

func _on_generator_mission_generated(mission) -> void:
	emit_signal("mission_generated", mission)

func _on_generator_generation_completed(data = null) -> void:
	emit_signal("generation_completed", data)
