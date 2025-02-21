@tool
extends GameTest

## Integration tests for mission flow
##
## Tests the interaction between different mission components:
## - Mission generation and template system
## - Mission state and objective tracking
## - Mission rewards and resource system
## - Mission completion and campaign integration

const MissionScript: GDScript = preload("res://src/core/systems/Mission.gd")
const MissionGeneratorScript: GDScript = preload("res://src/core/systems/MissionGenerator.gd")
const MissionTemplateScript: GDScript = preload("res://src/core/templates/MissionTemplate.gd")

# Type-safe component references
var _mission_generator: Node = null
var _current_mission: Resource = null
var _game_state: Node = null
var _campaign_system: Node = null

# Test lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	# Initialize game state with type safety
	_game_state = create_test_game_state()
	if not _game_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_game_state)
	track_test_node(_game_state)
	
	# Set up campaign system with type safety
	_campaign_system = Node.new()
	if not _campaign_system:
		push_error("Failed to create campaign system")
		return
	_campaign_system.name = "CampaignSystem"
	add_child_autofree(_campaign_system)
	track_test_node(_campaign_system)
	
	# Set up mission generator with type safety
	_mission_generator = Node.new()
	if not _mission_generator:
		push_error("Failed to create mission generator")
		return
	_mission_generator.name = "MissionGenerator"
	_mission_generator.set_script(MissionGeneratorScript)
	add_child_autofree(_mission_generator)
	track_test_node(_mission_generator)
	
	# Wait for everything to initialize
	await stabilize_engine()

func after_each() -> void:
	_mission_generator = null
	_current_mission = null
	_game_state = null
	_campaign_system = null
	await super.after_each()

# Type-safe helper methods
func create_test_campaign() -> Resource:
	var campaign: Resource = Resource.new()
	if not campaign:
		push_error("Failed to create campaign resource")
		return null
	track_test_resource(campaign)
	return campaign

func _get_mission_property(mission: Resource, property: String, default_value: Variant = null) -> Variant:
	if not mission:
		push_error("Cannot get property from null mission")
		return default_value
	return TypeSafeMixin._safe_method_call_variant(mission, "get", [property], default_value)

func _get_state_property(state: Node, property: String, default_value: Variant = null) -> Variant:
	if not state:
		push_error("Cannot get property from null state")
		return default_value
	return TypeSafeMixin._safe_method_call_variant(state, "get", [property], default_value)

func _set_state_property(state: Node, property: String, value: Variant) -> void:
	if not state:
		push_error("Cannot set property on null state")
		return
	TypeSafeMixin._safe_method_call_bool(state, "set", [property, value])

func _call_resource_method(resource: Resource, method: String, args: Array = []) -> Variant:
	if not resource:
		push_error("Cannot call method on null resource")
		return null
	return TypeSafeMixin._safe_method_call_variant(resource, method, args)

func _call_node_method(obj: Object, method: String, args: Array = [], default_value: Variant = null) -> Variant:
	if not obj:
		push_error("Cannot call method on null node")
		return default_value
	return TypeSafeMixin._safe_method_call_variant(obj, method, args, default_value)

# Test cases
func test_mission_generation_to_completion() -> void:
	# Setup campaign with type safety
	var campaign: Resource = create_test_campaign()
	if not campaign:
		push_error("Failed to create test campaign")
		return
	
	_signal_watcher.watch_signals(campaign)
	_signal_watcher.watch_signals(_game_state)
	
	# Set campaign and wait for signals
	_set_state_property(_game_state, "current_campaign", campaign)
	await assert_async_signal(_game_state, "campaign_loaded")
	
	# Start campaign and wait for signals
	_call_resource_method(campaign, "start_campaign")
	await assert_async_signal(campaign, "campaign_started")
	
	# Setup template with type safety
	var template: Resource = MissionTemplateScript.new()
	track_test_resource(template)
	_call_resource_method(template, "set_mission_type", [GameEnums.MissionType.PATROL])
	_call_resource_method(template, "set_difficulty_range", [1, 3])
	_call_resource_method(template, "set_reward_range", [100, 300])
	
	# Generate mission with type safety
	_signal_watcher.watch_signals(_mission_generator)
	_current_mission = _call_node_method(_mission_generator, "generate_mission", [template])
	track_test_resource(_current_mission)
	await assert_async_signal(_mission_generator, "mission_generated")
	
	# Start mission with type safety
	_signal_watcher.watch_signals(_current_mission)
	_call_node_method(_game_state, "start_mission", [_current_mission])
	await assert_async_signal(_game_state, "mission_started")
	
	var current_mission: Resource = _get_state_property(_game_state, "current_mission")
	var current_state: int = TypeSafeMixin._safe_cast_int(_get_state_property(_game_state, "current_state"))
	assert_eq(current_mission, _current_mission, "Current mission should be set")
	assert_eq(current_state, GameEnums.GameState.BATTLE, "Game state should be BATTLE")
	
	# Complete objectives with type safety
	var objectives: Array = TypeSafeMixin._safe_cast_array(_get_mission_property(_current_mission, "objectives"))
	for i in range(objectives.size()):
		_call_resource_method(_current_mission, "complete_objective", [i])
		await assert_async_signal(_current_mission, "objective_completed")
	
	var is_completed: bool = TypeSafeMixin._safe_cast_bool(_get_mission_property(_current_mission, "is_completed"))
	assert_true(is_completed, "Mission should be completed")
	
	# End mission and verify rewards with type safety
	var initial_credits: int = TypeSafeMixin._safe_cast_int(_get_state_property(_game_state, "credits"))
	_call_node_method(_game_state, "end_mission", [_current_mission])
	await assert_async_signal(_game_state, "mission_ended")
	
	var final_credits: int = TypeSafeMixin._safe_cast_int(_get_state_property(_game_state, "credits"))
	var final_state: int = TypeSafeMixin._safe_cast_int(_get_state_property(_game_state, "current_state"))
	assert_gt(final_credits, initial_credits, "Credits should increase after mission")
	assert_eq(final_state, GameEnums.GameState.CAMPAIGN, "Game state should return to CAMPAIGN")

func test_mission_failure_handling() -> void:
	# Setup campaign with type safety
	var campaign: Resource = create_test_campaign()
	watch_signals(campaign)
	watch_signals(_game_state)
	
	# Set campaign and wait for signals
	_set_state_property(_game_state, "current_campaign", campaign)
	await assert_async_signal(_game_state, "campaign_loaded", SIGNAL_TIMEOUT)
	
	# Start campaign and wait for signals
	_call_resource_method(campaign, "start_campaign")
	await assert_async_signal(campaign, "campaign_started", SIGNAL_TIMEOUT)
	
	# Setup and start mission with type safety
	var template: Resource = MissionTemplateScript.new()
	track_test_resource(template)
	_call_resource_method(template, "set_mission_type", [GameEnums.MissionType.DEFENSE])
	
	watch_signals(_mission_generator)
	_current_mission = _call_node_method(_mission_generator, "generate_mission", [template])
	track_test_resource(_current_mission)
	await assert_async_signal(_mission_generator, "mission_generated", SIGNAL_TIMEOUT)
	
	# Start mission with type safety
	watch_signals(_current_mission)
	_call_node_method(_game_state, "start_mission", [_current_mission])
	await assert_async_signal(_game_state, "mission_started", SIGNAL_TIMEOUT)
	
	# Fail mission with type safety
	_call_resource_method(_current_mission, "fail_mission")
	await assert_async_signal(_current_mission, "mission_failed", SIGNAL_TIMEOUT)
	var is_failed: bool = TypeSafeMixin._safe_cast_bool(_get_mission_property(_current_mission, "is_failed"))
	assert_true(is_failed)
	
	# Verify game state changes with type safety
	var initial_reputation: int = TypeSafeMixin._safe_cast_int(_get_state_property(_game_state, "reputation"))
	_call_node_method(_game_state, "end_mission", [_current_mission])
	await assert_async_signal(_game_state, "mission_ended", SIGNAL_TIMEOUT)
	
	var final_reputation: int = TypeSafeMixin._safe_cast_int(_get_state_property(_game_state, "reputation"))
	assert_lt(final_reputation, initial_reputation)

func test_mission_resource_integration() -> void:
	# Setup campaign with type safety
	var campaign: Resource = create_test_campaign()
	if not campaign:
		push_error("Failed to create test campaign")
		return
	
	_signal_watcher.watch_signals(campaign)
	_signal_watcher.watch_signals(_game_state)
	
	# Set campaign and wait for signals
	_set_state_property(_game_state, "current_campaign", campaign)
	await assert_async_signal(_game_state, "campaign_loaded")
	
	# Start campaign and wait for signals
	_call_resource_method(campaign, "start_campaign")
	await assert_async_signal(campaign, "campaign_started")
	
	# Setup mission with resource requirements
	var template: Resource = MissionTemplateScript.new()
	track_test_resource(template)
	_call_resource_method(template, "set_mission_type", [GameEnums.MissionType.RAID])
	_call_resource_method(template, "set_resource_requirements", [ {
		"fuel": 2,
		"supplies": 1
	}])
	
	_signal_watcher.watch_signals(_mission_generator)
	_current_mission = _call_node_method(_mission_generator, "generate_mission", [template])
	track_test_resource(_current_mission)
	await assert_async_signal(_mission_generator, "mission_generated")
	
	# Verify resource consumption with type safety
	var resources: Dictionary = TypeSafeMixin._safe_cast_dictionary(_get_state_property(_game_state, "resources", {}))
	var initial_fuel: int = TypeSafeMixin._safe_cast_int(resources.get("fuel", 0))
	var initial_supplies: int = TypeSafeMixin._safe_cast_int(resources.get("supplies", 0))
	
	_signal_watcher.watch_signals(_current_mission)
	_call_node_method(_game_state, "start_mission", [_current_mission])
	await assert_async_signal(_game_state, "mission_started")
	
	resources = TypeSafeMixin._safe_cast_dictionary(_get_state_property(_game_state, "resources", {}))
	var final_fuel: int = TypeSafeMixin._safe_cast_int(resources.get("fuel", 0))
	var final_supplies: int = TypeSafeMixin._safe_cast_int(resources.get("supplies", 0))
	
	assert_eq(final_fuel, initial_fuel - 2)
	assert_eq(final_supplies, initial_supplies - 1)

func test_mission_state_persistence() -> void:
	# Setup campaign with type safety
	var campaign: Resource = create_test_campaign()
	if not campaign:
		push_error("Failed to create test campaign")
		return
	
	_signal_watcher.watch_signals(campaign)
	_signal_watcher.watch_signals(_game_state)
	
	# Set campaign and wait for signals
	_set_state_property(_game_state, "current_campaign", campaign)
	await assert_async_signal(_game_state, "campaign_loaded")
	
	# Start campaign and wait for signals
	_call_resource_method(campaign, "start_campaign")
	await assert_async_signal(campaign, "campaign_started")
	
	# Generate and start mission with type safety
	var template: Resource = MissionTemplateScript.new()
	track_test_resource(template)
	_call_resource_method(template, "set_mission_type", [GameEnums.MissionType.PATROL])
	
	_signal_watcher.watch_signals(_mission_generator)
	_current_mission = _call_node_method(_mission_generator, "generate_mission", [template])
	track_test_resource(_current_mission)
	await assert_async_signal(_mission_generator, "mission_generated")
	
	_signal_watcher.watch_signals(_current_mission)
	_call_node_method(_game_state, "start_mission", [_current_mission])
	await assert_async_signal(_game_state, "mission_started")
	
	# Complete some objectives with type safety
	_call_resource_method(_current_mission, "complete_objective", [0])
	await assert_async_signal(_current_mission, "objective_completed")
	
	# Save and load state with type safety
	var save_data: Dictionary = _call_node_method(_game_state, "save_state")
	var new_game_state: Node = create_test_game_state()
	if not new_game_state:
		push_error("Failed to create new game state")
		return
	add_child_autofree(new_game_state)
	track_test_node(new_game_state)
	
	_call_node_method(new_game_state, "load_state", [save_data])
	var loaded_mission: Resource = _get_state_property(new_game_state, "current_mission")
	
	var original_completion: float = _call_resource_method(_current_mission, "get_completion_percentage")
	var loaded_completion: float = _call_resource_method(loaded_mission, "get_completion_percentage")
	assert_eq(loaded_completion, original_completion)

func test_rapid_mission_transitions() -> void:
	# Setup campaign with type safety
	var campaign: Resource = create_test_campaign()
	if not campaign:
		push_error("Failed to create test campaign")
		return
	
	_signal_watcher.watch_signals(campaign)
	_signal_watcher.watch_signals(_game_state)
	
	# Set campaign and wait for signals
	_set_state_property(_game_state, "current_campaign", campaign)
	await assert_async_signal(_game_state, "campaign_loaded")
	
	# Start campaign and wait for signals
	_call_resource_method(campaign, "start_campaign")
	await assert_async_signal(campaign, "campaign_started")
	
	var template: Resource = MissionTemplateScript.new()
	track_test_resource(template)
	_call_resource_method(template, "set_mission_type", [GameEnums.MissionType.PATROL])
	
	_signal_watcher.watch_signals(_mission_generator)
	var start_time: int = Time.get_ticks_msec()
	
	for i in range(10):
		var mission: Resource = _call_node_method(_mission_generator, "generate_mission", [template])
		track_test_resource(mission)
		await assert_async_signal(_mission_generator, "mission_generated")
		
		_signal_watcher.watch_signals(mission)
		_call_node_method(_game_state, "start_mission", [mission])
		await assert_async_signal(_game_state, "mission_started")
		
		_call_resource_method(mission, "complete_objective", [0])
		await assert_async_signal(mission, "objective_completed")
		
		_call_node_method(_game_state, "end_mission", [mission])
		await assert_async_signal(_game_state, "mission_ended")
	
	var duration: int = Time.get_ticks_msec() - start_time
	assert_lt(duration, 1000, "Should handle rapid mission transitions efficiently")
