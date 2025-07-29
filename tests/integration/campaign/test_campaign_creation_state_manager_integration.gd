@tool
extends GdUnitGameTest

## Integration tests for CampaignCreationStateManager
## These tests validate the complete campaign creation workflow with real systems

# Real system imports
const CampaignCreationStateManager = preload("res://src/core/campaign/creation/CampaignCreationStateManager.gd")
const GameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Character.gd")

# Test instances
var _state_manager: CampaignCreationStateManager
var _game_state: GameState
var _tracked_objects: Array[Node] = []

func before_test() -> void:
	super.before_test()
	await _initialize_test_environment()

func after_test() -> void:
	# Clean up tracked objects
	for obj in _tracked_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	_tracked_objects.clear()
	
	# Clean up main instances
	if is_instance_valid(_state_manager):
		_state_manager.queue_free()
		_state_manager = null
	if is_instance_valid(_game_state):
		_game_state.queue_free()
		_game_state = null
	
	super.after_test()

func _initialize_test_environment() -> void:
	# Initialize real game state
	_game_state = GameState.new()
	_game_state.name = "TestGameState"
	add_child(_game_state)
	_tracked_objects.append(_game_state)
	
	# Initialize real state manager
	_state_manager = CampaignCreationStateManager.new()
	_state_manager.name = "TestStateManager"
	add_child(_state_manager)
	_tracked_objects.append(_state_manager)
	
	# Allow systems to initialize
	await get_tree().process_frame

func test_complete_campaign_creation_workflow() -> void:
	"""Test the complete end-to-end campaign creation workflow."""
	# Phase 1: Configuration
	var config_data = {
		"campaign_name": "Integration Test Campaign",
		"difficulty_level": 2,
		"victory_condition": "escape",
		"story_track_enabled": true,
		"house_rules": {"advanced_reactions": true}
	}
	
	_state_manager.set_phase_data(CampaignCreationStateManager.Phase.CONFIG, config_data)
	var stored_config = _state_manager.get_phase_data(CampaignCreationStateManager.Phase.CONFIG)
	
	assert_that(stored_config.campaign_name).is_equal("Integration Test Campaign")
	assert_that(stored_config.difficulty_level).is_equal(2)
	assert_that(stored_config.victory_condition).is_equal("escape")
	
	# Phase 2: Crew Setup
	var crew_data = {
		"members": [
			{
				"character_name": "Captain Test",
				"is_captain": true,
				"combat": 4,
				"reaction": 3,
				"toughness": 4,
				"savvy": 2,
				"tech": 1,
				"move": 4,
				"background": "Military",
				"motivation": "Escape"
			},
			{
				"character_name": "Tech Specialist",
				"is_captain": false,
				"combat": 2,
				"reaction": 4,
				"toughness": 2,
				"savvy": 4,
				"tech": 5,
				"move": 3,
				"background": "Academic",
				"motivation": "Knowledge"
			},
			{
				"character_name": "Gunner",
				"is_captain": false,
				"combat": 5,
				"reaction": 3,
				"toughness": 5,
				"savvy": 1,
				"tech": 2,
				"move": 3,
				"background": "Soldier",
				"motivation": "Money"
			}
		],
		"size": 3,
		"has_captain": true,
		"completion_level": 0.95,
		"backend_generated": true
	}
	
	_state_manager.set_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP, crew_data)
	var stored_crew = _state_manager.get_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP)
	
	assert_that(stored_crew.size).is_equal(3)
	assert_that(stored_crew.has_captain).is_true()
	assert_that(stored_crew.members.size()).is_equal(3)
	
	# Validate crew member data structure
	var captain = stored_crew.members[0]
	assert_that(captain.character_name).is_equal("Captain Test")
	assert_that(captain.is_captain).is_true()
	assert_that(captain.combat).is_equal(4)
	
	# Phase 3: Captain Creation
	var captain_data = {
		"character_data": captain,
		"leadership_bonuses": {"crew_morale": 1, "mission_success": 0.1},
		"special_abilities": ["Inspiring Presence", "Tactical Awareness"]
	}
	
	_state_manager.set_phase_data(CampaignCreationStateManager.Phase.CAPTAIN_CREATION, captain_data)
	var stored_captain = _state_manager.get_phase_data(CampaignCreationStateManager.Phase.CAPTAIN_CREATION)
	
	assert_that(stored_captain.character_data.character_name).is_equal("Captain Test")
	assert_that(stored_captain.leadership_bonuses.crew_morale).is_equal(1)
	assert_that(stored_captain.special_abilities).contains(["Inspiring Presence"])
	
	# Phase 4: Ship Assignment
	var ship_data = {
		"name": "Test Freighter",
		"type": "light_freighter",
		"hull_points": 15,
		"fuel_capacity": 8,
		"cargo_capacity": 12,
		"weapon_mounts": 2,
		"upgrades": ["Improved Engines", "Better Armor"],
		"is_configured": true
	}
	
	_state_manager.set_phase_data(CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT, ship_data)
	var stored_ship = _state_manager.get_phase_data(CampaignCreationStateManager.Phase.SHIP_ASSIGNMENT)
	
	assert_that(stored_ship.name).is_equal("Test Freighter")
	assert_that(stored_ship.hull_points).is_equal(15)
	assert_that(stored_ship.upgrades).contains(["Improved Engines"])
	
	# Phase 5: Equipment Generation
	var equipment_data = {
		"equipment": [
			{"name": "Military Rifle", "type": "weapon", "damage": "2d6", "range": 24},
			{"name": "Combat Armor", "type": "armor", "protection": 2, "encumbrance": 1},
			{"name": "Med-kit", "type": "consumable", "uses": 3, "effect": "heal_wound"},
			{"name": "Scanner", "type": "gear", "function": "detect_enemies", "range": 12}
		],
		"total_value": 850,
		"is_complete": true,
		"backend_generated": true,
		"generation_method": "balanced_loadout"
	}
	
	_state_manager.set_phase_data(CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION, equipment_data)
	var stored_equipment = _state_manager.get_phase_data(CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION)
	
	assert_that(stored_equipment.equipment.size()).is_equal(4)
	assert_that(stored_equipment.total_value).is_equal(850)
	assert_that(stored_equipment.is_complete).is_true()
	
	# Phase 6: Validation and Completion
	var validation_summary = _state_manager.get_validation_summary()
	
	assert_that(validation_summary.completion_percentage).is_greater_than(90.0)
	assert_that(validation_summary.can_complete).is_true()
	assert_that(validation_summary.validation_errors.size()).is_equal(0)
	
	# Final Campaign Creation
	var final_campaign_data = _state_manager.complete_campaign_creation()
	
	assert_that(final_campaign_data).is_not_empty()
	assert_that(final_campaign_data).contains_keys(["config", "crew", "captain", "ship", "equipment", "metadata"])
	
	# Validate final data integrity
	assert_that(final_campaign_data.config.campaign_name).is_equal("Integration Test Campaign")
	assert_that(final_campaign_data.crew.size).is_equal(3)
	assert_that(final_campaign_data.captain.character_data.character_name).is_equal("Captain Test")
	assert_that(final_campaign_data.ship.name).is_equal("Test Freighter")
	assert_that(final_campaign_data.equipment.equipment.size()).is_equal(4)

func test_state_manager_validation_integration() -> void:
	"""Test that validation works correctly with partial data sets."""
	# Test with minimal config
	var minimal_config = {
		"campaign_name": "Minimal Test",
		"difficulty_level": 1
	}
	
	_state_manager.set_phase_data(CampaignCreationStateManager.Phase.CONFIG, minimal_config)
	var early_validation = _state_manager.get_validation_summary()
	
	assert_that(early_validation.completion_percentage).is_less_than(50.0)
	assert_that(early_validation.can_complete).is_false()
	
	# Add crew data
	var minimal_crew = {
		"members": [{"character_name": "Solo", "is_captain": true}],
		"size": 1,
		"has_captain": true
	}
	
	_state_manager.set_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP, minimal_crew)
	var mid_validation = _state_manager.get_validation_summary()
	
	assert_that(mid_validation.completion_percentage).is_greater_than(early_validation.completion_percentage)
	
	# Test error detection with invalid data
	var invalid_crew = {
		"members": [],
		"size": 0,
		"has_captain": false
	}
	
	_state_manager.set_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP, invalid_crew)
	var error_validation = _state_manager.get_validation_summary()
	
	assert_that(error_validation.validation_errors.size()).is_greater_than(0)
	assert_that(error_validation.can_complete).is_false()

func test_state_manager_persistence_integration() -> void:
	"""Test that state manager data persists correctly through save/load cycles."""
	# Set up complete campaign data
	var test_config = {
		"campaign_name": "Persistence Test",
		"difficulty_level": 3,
		"victory_condition": "wealth"
	}
	
	var test_crew = {
		"members": [{"character_name": "Persistent Captain", "is_captain": true}],
		"size": 1,
		"has_captain": true
	}
	
	_state_manager.set_phase_data(CampaignCreationStateManager.Phase.CONFIG, test_config)
	_state_manager.set_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP, test_crew)
	
	# Get serialized state
	var serialized_state = _state_manager.serialize_state()
	assert_that(serialized_state).is_not_empty()
	assert_that(serialized_state).contains_keys(["phases", "current_phase", "creation_timestamp"])
	
	# Create new state manager and load data
	var new_state_manager = CampaignCreationStateManager.new()
	add_child(new_state_manager)
	_tracked_objects.append(new_state_manager)
	
	var deserialize_success = new_state_manager.deserialize_state(serialized_state)
	assert_that(deserialize_success).is_true()
	
	# Verify data integrity after deserialization
	var loaded_config = new_state_manager.get_phase_data(CampaignCreationStateManager.Phase.CONFIG)
	var loaded_crew = new_state_manager.get_phase_data(CampaignCreationStateManager.Phase.CREW_SETUP)
	
	assert_that(loaded_config.campaign_name).is_equal("Persistence Test")
	assert_that(loaded_config.difficulty_level).is_equal(3)
	assert_that(loaded_crew.members[0].character_name).is_equal("Persistent Captain")

func test_state_manager_error_handling_integration() -> void:
	"""Test that state manager handles error conditions gracefully."""
	# Test invalid phase data
	var result = _state_manager.set_phase_data(999, {})  # Invalid phase
	assert_that(result).is_false()
	
	# Test getting data from uninitialized phase
	var empty_data = _state_manager.get_phase_data(CampaignCreationStateManager.Phase.EQUIPMENT_GENERATION)
	assert_that(empty_data).is_empty()
	
	# Test validation with completely empty state
	var empty_validation = _state_manager.get_validation_summary()
	assert_that(empty_validation.completion_percentage).is_equal(0.0)
	assert_that(empty_validation.can_complete).is_false()
	
	# Test completion attempt with insufficient data
	var incomplete_campaign = _state_manager.complete_campaign_creation()
	assert_that(incomplete_campaign).is_empty()

func test_state_manager_phase_transitions() -> void:
	"""Test that phase transitions work correctly."""
	# Start with CONFIG phase
	assert_that(_state_manager.get_current_phase()).is_equal(CampaignCreationStateManager.Phase.CONFIG)
	
	# Set config data and advance
	var config = {"campaign_name": "Phase Test", "difficulty_level": 1}
	_state_manager.set_phase_data(CampaignCreationStateManager.Phase.CONFIG, config)
	
	var advance_result = _state_manager.advance_to_next_phase()
	assert_that(advance_result).is_true()
	assert_that(_state_manager.get_current_phase()).is_equal(CampaignCreationStateManager.Phase.CREW_SETUP)
	
	# Test phase completion tracking
	var phase_completion = _state_manager.get_phase_completion(CampaignCreationStateManager.Phase.CONFIG)
	assert_that(phase_completion).is_greater_than(0.0)
	
	# Test getting phase requirements
	var crew_requirements = _state_manager.get_phase_requirements(CampaignCreationStateManager.Phase.CREW_SETUP)
	assert_that(crew_requirements).is_not_empty()
	assert_that(crew_requirements).contains_key("minimum_crew_size")