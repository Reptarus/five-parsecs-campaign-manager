@tool
extends GutTest

const PhaseManager := preload("res://src/core/campaign/CampaignPhaseManager.gd")
const CampaignManagerResource := preload("res://src/core/managers/CampaignManager.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")
const SignalWatcher = preload("res://addons/gut/signal_watcher.gd")

# Test variables
var manager: Node = null
var game_state: Node = null
var campaign_manager: Resource = null

# Signal tracking
var _signal_watcher: Node = null

# Test tracking
var _tracked_nodes: Array[Node] = []
var _tracked_resources: Array[Resource] = []

# Safe casting helper functions
func _safe_cast_object(value: Variant, error_message: String = "") -> Object:
	if not value is Object:
		push_error("Cannot cast to Object: %s" % error_message)
		return null
	return value

func _safe_cast_node(value: Variant, error_message: String = "") -> Node:
	if not value is Node:
		push_error("Cannot cast to Node: %s" % error_message)
		return null
	return value

func _safe_cast_resource(value: Variant, error_message: String = "") -> Resource:
	if not value is Resource:
		push_error("Cannot cast to Resource: %s" % error_message)
		return null
	return value

func _safe_cast_bool(value: Variant, error_message: String = "") -> bool:
	if not value is bool:
		push_error("Cannot cast to bool: %s" % error_message)
		return false
	return value

func _safe_cast_int(value: Variant, error_message: String = "") -> int:
	if not value is int:
		push_error("Cannot cast to int: %s" % error_message)
		return 0
	return value

func _safe_cast_signal_watcher(value: Variant, error_message: String = "") -> SignalWatcher:
	if not value is SignalWatcher:
		push_error("Cannot cast to SignalWatcher: %s" % error_message)
		return null
	return value

# Helper function to safely call methods
func _call_method_safe(obj: Variant, method: String, args: Array = [], expected_type: int = TYPE_NIL, default_value: Variant = null) -> Variant:
	var object: Object = _safe_cast_object(obj, "Cannot call method on non-Object")
	if not object:
		return default_value
	
	if not object.has_method(method):
		push_error("Method %s not found in object" % method)
		return default_value
	
	var raw_result: Variant = object.callv(method, args)
	var result: Variant = raw_result
	
	if expected_type != TYPE_NIL and typeof(result) != expected_type:
		push_error("Expected return type %s but got %s" % [expected_type, typeof(result)])
		return default_value
	
	return result

# Helper function for safe node method calls
func _call_node_method_bool(node: Variant, method: String, args: Array = [], default_value: bool = false) -> bool:
	var n: Node = _safe_cast_node(node, "Cannot call method on non-Node")
	if not n:
		return default_value
	
	if not n.has_method(method):
		push_error("Method %s not found in node" % method)
		return default_value
	
	var raw_result: Variant = n.callv(method, args)
	if not raw_result is bool:
		push_error("Method %s did not return a bool" % method)
		return default_value
	return raw_result

func _call_node_method_int(node: Variant, method: String, args: Array = [], default_value: int = 0) -> int:
	var n: Node = _safe_cast_node(node, "Cannot call method on non-Node")
	if not n:
		return default_value
	
	if not n.has_method(method):
		push_error("Method %s not found in node" % method)
		return default_value
	
	var raw_result: Variant = n.callv(method, args)
	if not raw_result is int:
		push_error("Method %s did not return an int" % method)
		return default_value
	return raw_result

## Test tracking methods
func track_test_node(node: Node) -> void:
	if not node in _tracked_nodes:
		_tracked_nodes.append(node)

func track_test_resource(resource: Resource) -> void:
	if not resource in _tracked_resources:
		_tracked_resources.append(resource)

func cleanup_tracked_nodes() -> void:
	for node in _tracked_nodes:
		if is_instance_valid(node) and node.is_inside_tree():
			node.queue_free()
	_tracked_nodes.clear()

func cleanup_tracked_resources() -> void:
	_tracked_resources.clear()

## Safe Property Access Methods
func _get_property_safe(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	var object: Object = _safe_cast_object(obj, "Cannot get property from non-Object")
	if not object:
		return default_value
	
	if not property in object:
		return default_value
	
	return object.get(property)

func _get_manager_property(target_manager: Variant, property: String, default_value: Variant = null) -> Variant:
	var node: Node = _safe_cast_node(target_manager, "Cannot get property from non-Node manager")
	if not node:
		return default_value
	return _get_property_safe(node, property, default_value)

func _get_state_property(state: Variant, property: String, default_value: Variant = null) -> Variant:
	var node: Node = _safe_cast_node(state, "Cannot get property from non-Node state")
	if not node:
		return default_value
	return _get_property_safe(node, property, default_value)

func _get_property_int(obj: Variant, property: String, default_value: int = 0) -> int:
	var raw_value: Variant = _get_property_safe(obj, property, default_value)
	var value: int = _safe_cast_int(raw_value, "Property %s is not an int" % property)
	return value

func _get_property_bool(obj: Variant, property: String, default_value: bool = false) -> bool:
	var raw_value: Variant = _get_property_safe(obj, property, default_value)
	var value: bool = _safe_cast_bool(raw_value, "Property %s is not a bool" % property)
	return value

# Signal watching helper
func watch_signals(emitter: Object) -> void:
	var watcher := _safe_cast_signal_watcher(_signal_watcher, "Signal watcher not initialized")
	if not watcher:
		return
	if not emitter:
		return
	if not watcher.has_method("watch_signal"):
		push_error("Signal watcher missing required method")
		return
	watcher.watch_signal(emitter, "phase_changed")

func assert_signal_emitted(object: Object, signal_name: String, text: String = "") -> void:
	var watcher := _safe_cast_signal_watcher(_signal_watcher, "Signal watcher not initialized")
	if not watcher:
		return
	if not object:
		return
	if not watcher.has_method("did_emit"):
		push_error("Signal watcher missing required method")
		return
	var result: Variant = _call_method_safe(watcher, "did_emit", [object, signal_name], TYPE_BOOL, false)
	var did_emit: bool = _safe_cast_bool(result, "Signal emission check failed")
	assert_true(did_emit, text)

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	cleanup_tracked_nodes()
	cleanup_tracked_resources()
	
	# Initialize game state
	var state_script: GDScript = load("res://src/core/state/GameState.gd")
	if not state_script:
		push_error("Failed to load GameState script")
		return
		
	# Create a properly typed GameState instance
	var state_instance: Node = Node.new()
	if not state_instance:
		push_error("Failed to create base node")
		return
		
	state_instance.set_script(state_script)
	if not state_instance.get_script() == state_script:
		push_error("Failed to set GameState script")
		return
		
	game_state = state_instance
	
	var state_node := _safe_cast_node(game_state, "Failed to create game state node")
	if not state_node:
		return
		
	add_child(state_node)
	track_test_node(state_node)
	
	# Initialize campaign manager
	var game_state_instance := state_node as GameState
	if not game_state_instance:
		push_error("Failed to cast state_node to GameState")
		return
	campaign_manager = CampaignManagerResource.new(game_state_instance)
	var campaign_resource := _safe_cast_resource(campaign_manager, "Failed to create campaign manager")
	if not campaign_resource:
		return
	track_test_resource(campaign_resource)
	
	# Initialize phase manager
	manager = PhaseManager.new()
	var phase_node := _safe_cast_node(manager, "Failed to create phase manager")
	if not phase_node:
		return
		
	if not phase_node.has_method("setup"):
		push_error("Phase manager missing required setup method")
		return
		
	var setup_result: Variant = _call_method_safe(phase_node, "setup", [state_node])
	if setup_result == null:
		push_error("Failed to setup phase manager")
		return
		
	add_child(phase_node)
	track_test_node(phase_node)
	
	# Initialize signal watcher
	var watcher_script: GDScript = load("res://addons/gut/signal_watcher.gd")
	if not watcher_script:
		push_error("Failed to load SignalWatcher script")
		return
		
	var watcher_node: Node = Node.new()
	if not watcher_node:
		push_error("Failed to create watcher node")
		return
		
	watcher_node.set_script(watcher_script)
	if not watcher_node.get_script() == watcher_script:
		push_error("Failed to set SignalWatcher script")
		return
		
	_signal_watcher = watcher_node
	
	var watcher := _safe_cast_signal_watcher(_signal_watcher, "Failed to create signal watcher")
	if not watcher:
		return
		
	add_child(_signal_watcher)
	track_test_node(_signal_watcher)
	
	await get_tree().process_frame

func after_each() -> void:
	cleanup_tracked_nodes()
	cleanup_tracked_resources()
	manager = null
	campaign_manager = null
	game_state = null
	_signal_watcher = null
	await super.after_each()

# Test Methods
func test_initial_state() -> void:
	var campaign_res: Resource = campaign_manager
	assert_not_null(campaign_res, "Campaign manager should be initialized")
	var state_node: Node = game_state
	assert_not_null(state_node, "Game state should be initialized")
	
	var difficulty: int = _get_property_int(game_state, "difficulty_level", GlobalEnums.DifficultyLevel.NORMAL)
	assert_eq(difficulty, GlobalEnums.DifficultyLevel.NORMAL, "Should have normal difficulty")
	
	assert_valid_game_state(game_state)

func test_initial_phase() -> void:
	watch_signals(manager)
	
	var initial_phase := _get_property_int(manager, "current_phase", GlobalEnums.CampaignPhase.NONE)
	assert_eq(initial_phase, GlobalEnums.CampaignPhase.NONE, "Initial phase should be NONE")
	
	var phase_node := _safe_cast_node(manager, "Manager is not a Node")
	if not phase_node:
		return
		
	assert_true(_call_node_method_bool(phase_node, "start_phase", [GlobalEnums.CampaignPhase.SETUP]), "Should start SETUP phase")
	
	var current_phase := _get_property_int(manager, "current_phase", GlobalEnums.CampaignPhase.NONE)
	assert_eq(current_phase, GlobalEnums.CampaignPhase.SETUP, "Phase should be SETUP after start")
	
	assert_signal_emitted(manager, "phase_changed", "Phase changed signal should be emitted")

func test_phase_transition_requirements() -> void:
	watch_signals(manager)
	
	var phase_node := _safe_cast_node(manager, "Manager is not a Node")
	if not phase_node:
		return
	
	# Start with SETUP phase
	assert_true(_call_node_method_bool(phase_node, "start_phase", [GlobalEnums.CampaignPhase.SETUP]), "Should start SETUP phase")
	var setup_phase := _get_property_int(manager, "current_phase", GlobalEnums.CampaignPhase.NONE)
	assert_eq(setup_phase, GlobalEnums.CampaignPhase.SETUP, "Should start in SETUP phase")
	assert_signal_emitted(manager, "phase_changed", "Phase changed signal should be emitted")
	
	# Test transition to UPKEEP
	assert_true(_call_node_method_bool(phase_node, "start_phase", [GlobalEnums.CampaignPhase.UPKEEP]), "Should transition to UPKEEP from SETUP")
	var upkeep_phase := _get_property_int(manager, "current_phase", GlobalEnums.CampaignPhase.NONE)
	assert_eq(upkeep_phase, GlobalEnums.CampaignPhase.UPKEEP, "Phase should be UPKEEP")
	assert_signal_emitted(manager, "phase_changed", "Phase changed signal should be emitted")
	
	# Test invalid transition
	assert_false(_call_node_method_bool(phase_node, "start_phase", [GlobalEnums.CampaignPhase.BATTLE_RESOLUTION]), "Should not transition to invalid phase")

func assert_valid_game_state(state: Node) -> void:
	var state_node := _safe_cast_node(state, "Invalid game state node")
	if not state_node:
		return
		
	var campaign_state: Variant = _get_state_property(state_node, "current_campaign")
	if campaign_state == null:
		push_error("Campaign state is null")
		return
	
	# Validate campaign state
	var campaign_variant: Variant = campaign_state
	assert_true(campaign_variant != null, "Campaign state should be initialized")
	
	var difficulty := _get_property_int(state_node, "difficulty_level", -1)
	assert_eq(difficulty, GlobalEnums.DifficultyLevel.NORMAL, "Difficulty should be set to normal")
	
	var permadeath := _get_property_bool(state_node, "enable_permadeath", false)
	assert_true(permadeath, "Permadeath should be enabled")
	
	var story_track := _get_property_bool(state_node, "use_story_track", false)
	assert_true(story_track, "Story track should be enabled")
	
	var auto_save := _get_property_bool(state_node, "auto_save_enabled", false)
	assert_true(auto_save, "Auto save should be enabled")
