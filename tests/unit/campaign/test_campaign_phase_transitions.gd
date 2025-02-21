@tool
extends GameTest

const CampaignSystemScript: GDScript = preload("res://src/core/campaign/CampaignSystem.gd")
const DEFAULT_TIMEOUT: float = 1.0

var campaign_system: Node = null
var _received_signals: Array[String] = []
var _campaign_game_state: Node = null

# Helper function to load test campaign data
func load_test_campaign(state: Node) -> void:
	if not state:
		push_error("Cannot load campaign: game state is null")
		return
		
	var campaign: Resource = create_test_campaign()
	if not campaign:
		push_error("Failed to create test campaign")
		return
		
	_set_state_property(state, "current_campaign", campaign)
	_set_state_property(state, "difficulty_level", GameEnums.DifficultyLevel.NORMAL)
	_set_state_property(state, "enable_permadeath", true)
	_set_state_property(state, "use_story_track", true)
	_set_state_property(state, "auto_save_enabled", true)

func _set_state_property(state: Node, property: String, value: Variant) -> void:
	if not state:
		push_error("Cannot set property on null state")
		return
	if not state.has_method("set"):
		push_error("State object does not have set method")
		return
	TypeSafeMixin._safe_method_call_bool(state, "set", [property, value])

## Safe Property Access Methods
func _get_campaign_system_property(property: String, default_value: Variant = null) -> Variant:
	if not campaign_system:
		push_error("Trying to access property '%s' on null campaign system" % property)
		return default_value
	if not property in campaign_system:
		push_error("Campaign system missing required property: %s" % property)
		return default_value
	return campaign_system.get(property)

func _set_campaign_system_property(property: String, value: Variant) -> void:
	if not campaign_system:
		push_error("Trying to set property '%s' on null campaign system" % property)
		return
	if not property in campaign_system:
		push_error("Campaign system missing required property: %s" % property)
		return
	campaign_system.set(property, value)

func before_each() -> void:
	await super.before_each()
	
	# Initialize game state
	_campaign_game_state = create_test_game_state()
	if not _campaign_game_state:
		push_error("Failed to create game state")
		return
	add_child_autofree(_campaign_game_state)
	track_test_node(_campaign_game_state)
	
	# Load test campaign before validation
	load_test_campaign(_campaign_game_state)
	assert_valid_game_state(_campaign_game_state)
	
	# Set up campaign system
	campaign_system = CampaignSystemScript.new()
	if not campaign_system:
		push_error("Failed to create campaign system instance")
		return
	add_child_autofree(campaign_system)
	track_test_node(campaign_system)
	_connect_signals()
	
	# Initialize with game state
	if campaign_system.has_method("initialize"):
		campaign_system.initialize(_campaign_game_state)

func after_each() -> void:
	_disconnect_signals()
	campaign_system = null
	_campaign_game_state = null
	_received_signals.clear()
	await super.after_each()

func _connect_signals() -> void:
	if not campaign_system:
		return
		
	if campaign_system.has_signal("state_changed"):
		var err := campaign_system.connect("state_changed", _on_signal_received.bind("state_changed"))
		if err != OK:
			push_error("Failed to connect state_changed signal")
	if campaign_system.has_signal("turn_started"):
		var err := campaign_system.connect("turn_started", _on_signal_received.bind("turn_started"))
		if err != OK:
			push_error("Failed to connect turn_started signal")
	if campaign_system.has_signal("turn_ended"):
		var err := campaign_system.connect("turn_ended", _on_signal_received.bind("turn_ended"))
		if err != OK:
			push_error("Failed to connect turn_ended signal")
	if campaign_system.has_signal("phase_changed"):
		var err := campaign_system.connect("phase_changed", _on_signal_received.bind("phase_changed"))
		if err != OK:
			push_error("Failed to connect phase_changed signal")

func _disconnect_signals() -> void:
	if not campaign_system:
		return
		
	if campaign_system.has_signal("state_changed") and campaign_system.is_connected("state_changed", _on_signal_received):
		campaign_system.disconnect("state_changed", _on_signal_received)
	if campaign_system.has_signal("turn_started") and campaign_system.is_connected("turn_started", _on_signal_received):
		campaign_system.disconnect("turn_started", _on_signal_received)
	if campaign_system.has_signal("turn_ended") and campaign_system.is_connected("turn_ended", _on_signal_received):
		campaign_system.disconnect("turn_ended", _on_signal_received)
	if campaign_system.has_signal("phase_changed") and campaign_system.is_connected("phase_changed", _on_signal_received):
		campaign_system.disconnect("phase_changed", _on_signal_received)

func _on_signal_received(signal_name: String) -> void:
	_received_signals.append(signal_name)
	print("Received signal: " + signal_name)

func _get_campaign_resource() -> Resource:
	if not campaign_system:
		push_error("Campaign system is null")
		return null
	return TypeSafeMixin._safe_method_call_resource(campaign_system, "get_campaign")

func verify_campaign_state(campaign: Resource, expected_state: Dictionary) -> void:
	if not campaign:
		push_error("Cannot verify state of null campaign")
		return
	if expected_state.has("phase"):
		assert_eq(_get_campaign_system_property("current_phase", -1), expected_state.phase,
			"Campaign phase should match expected state")
	if expected_state.has("turn"):
		assert_eq(_get_campaign_system_property("current_turn", -1), expected_state.turn,
			"Campaign turn should match expected state")

func verify_signal_sequence(expected_signals: Array[String]) -> void:
	for i in range(expected_signals.size()):
		var expected: String = expected_signals[i]
		assert_true(i < _received_signals.size(), "Should have enough signals")
		assert_eq(_received_signals[i], expected,
			"Signal %d should be %s" % [i, expected])

func verify_missing_signals(emitter: Object, expected_signals: Array[String]) -> void:
	for signal_name in expected_signals:
		assert_false(signal_name in _received_signals,
			"Signal %s should not have been emitted" % signal_name)

# Test campaign phase transitions
func test_campaign_phase_transitions() -> void:
	print("Testing campaign phase transitions...")
	
	# Verify initial state
	verify_campaign_state(_get_campaign_resource(), {
		"phase": GameEnums.FiveParcsecsCampaignPhase.SETUP,
		"turn": 0
	})
	
	# Start campaign
	campaign_system.start_campaign()
	await get_tree().create_timer(DEFAULT_TIMEOUT).timeout
	
	# Verify campaign started correctly
	verify_campaign_state(_get_campaign_resource(), {
		"phase": GameEnums.FiveParcsecsCampaignPhase.STORY,
		"turn": 1
	})
	
	# Verify signals
	verify_signal_sequence([
		"state_changed",
		"turn_started",
		"phase_changed"
	])
	
	# Progress through phases
	if campaign_system.has_method("next_phase"):
		campaign_system.next_phase()
	await get_tree().create_timer(DEFAULT_TIMEOUT).timeout
	
	verify_campaign_state(_get_campaign_resource(), {
		"phase": GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP,
		"turn": 1
	})
	
	# Complete battle phase
	if campaign_system.has_method("complete_phase"):
		campaign_system.complete_phase()
	await get_tree().create_timer(DEFAULT_TIMEOUT).timeout
	
	verify_campaign_state(_get_campaign_resource(), {
		"phase": GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION,
		"turn": 1
	})
	
	# Verify final signal sequence
	verify_signal_sequence([
		"state_changed",
		"turn_started",
		"phase_changed",
		"phase_changed",
		"phase_changed"
	])

# Test invalid phase transitions
func test_invalid_phase_transitions() -> void:
	print("Testing invalid phase transitions...")
	
	# Try to complete phase before starting campaign
	if campaign_system.has_method("complete_phase"):
		campaign_system.complete_phase()
	await get_tree().create_timer(DEFAULT_TIMEOUT).timeout
	
	# Verify we're still in setup
	verify_campaign_state(_get_campaign_resource(), {
		"phase": GameEnums.FiveParcsecsCampaignPhase.SETUP,
		"turn": 0
	})
	
	# Try to skip to post-battle
	if campaign_system.has_method("set_phase"):
		campaign_system.set_phase(GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION)
	await get_tree().create_timer(DEFAULT_TIMEOUT).timeout
	
	# Verify we're still in setup
	verify_campaign_state(_get_campaign_resource(), {
		"phase": GameEnums.FiveParcsecsCampaignPhase.SETUP,
		"turn": 0
	})
	
	# Verify no phase change signals were emitted
	verify_missing_signals(campaign_system, ["phase_changed"])

# Test campaign turn progression
func test_campaign_turn_progression() -> void:
	print("Testing campaign turn progression...")
	
	# Start campaign
	if campaign_system.has_method("start_campaign"):
		campaign_system.start_campaign()
	await get_tree().create_timer(DEFAULT_TIMEOUT).timeout
	
	# Complete a full turn cycle
	var phases: Array[int] = [
		GameEnums.FiveParcsecsCampaignPhase.STORY,
		GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP,
		GameEnums.FiveParcsecsCampaignPhase.BATTLE_RESOLUTION
	]
	
	for phase in phases:
		if campaign_system.has_method("next_phase"):
			campaign_system.next_phase()
		await get_tree().create_timer(DEFAULT_TIMEOUT).timeout
	
	# Verify turn incremented
	verify_campaign_state(_get_campaign_resource(), {
		"phase": GameEnums.FiveParcsecsCampaignPhase.STORY,
		"turn": 2
	})
	
	# Verify signals for turn progression
	verify_signal_sequence([
		"state_changed",
		"turn_started",
		"phase_changed",
		"phase_changed",
		"phase_changed",
		"phase_changed",
		"turn_ended",
		"turn_started"
	])
