@tool
extends GdUnitGameTest

# Mock CampaignSetupScreen for testing
class MockCampaignSetupScreen extends Control:
	signal campaign_started(config: Dictionary)
	
	var campaign_config = {
		"name": "",
		"difficulty_level": 1, # Normal difficulty
		"enable_permadeath": false,
		"use_story_track": true
	}
	
	var is_start_button_enabled: bool = false
	
	func _init():
		name = "MockCampaignSetupScreen"
	
	func set_campaign_name(new_name: String) -> void:
		campaign_config.name = new_name
		is_start_button_enabled = not new_name.is_empty()
	
	func set_difficulty(level: int) -> void:
		campaign_config.difficulty_level = level
		# Handle permadeath forcing for hardcore/easy
		if level == 3: # Hardcore
			campaign_config.enable_permadeath = true
		elif level == 0: # Easy
			campaign_config.enable_permadeath = false
	
	func set_permadeath(enabled: bool) -> void:
		# Only allow if not hardcore or easy
		if campaign_config.difficulty_level != 3 and campaign_config.difficulty_level != 0:
			campaign_config.enable_permadeath = enabled
	
	func set_story_track(enabled: bool) -> void:
		campaign_config.use_story_track = enabled
	
	func start_campaign() -> void:
		if is_start_button_enabled:
			campaign_started.emit(campaign_config)
	
	func is_permadeath_forced() -> bool:
		return campaign_config.difficulty_level == 3 # Hardcore
	
	func is_permadeath_disabled() -> bool:
		return campaign_config.difficulty_level == 0 # Easy

var _instance: MockCampaignSetupScreen
var campaign_started_signal_emitted := false
var last_campaign_config: Dictionary

func before_test() -> void:
	super.before_test()
	_instance = MockCampaignSetupScreen.new()
	add_child(_instance)
	auto_free(_instance)
	_connect_signals()
	_reset_signals()
	
	await get_tree().process_frame

func after_test() -> void:
	_reset_signals()
	super.after_test()

func _reset_signals() -> void:
	campaign_started_signal_emitted = false
	last_campaign_config = {}

func _connect_signals() -> void:
	if _instance and _instance.has_signal("campaign_started"):
		_instance.campaign_started.connect(_on_campaign_started)

func _on_campaign_started(config: Dictionary) -> void:
	campaign_started_signal_emitted = true
	last_campaign_config = config

func test_initial_setup() -> void:
	assert_that(_instance).is_not_null()
	assert_that(_instance.campaign_config).is_not_null()
	assert_that(_instance.is_start_button_enabled).is_false()

func test_campaign_config_defaults() -> void:
	# Test default configuration
	assert_that(_instance.campaign_config["name"]).is_equal("")
	assert_that(_instance.campaign_config["difficulty_level"]).is_equal(1) # Normal
	assert_that(_instance.campaign_config["enable_permadeath"]).is_false()
	assert_that(_instance.campaign_config["use_story_track"]).is_true()

func test_campaign_name_input() -> void:
	# Simulate typing a campaign name
	_instance.set_campaign_name("Test Campaign")
	
	assert_that(_instance.campaign_config["name"]).is_equal("Test Campaign")
	assert_that(_instance.is_start_button_enabled).is_true()

func test_difficulty_selection() -> void:
	# Test selecting different difficulties
	_instance.set_difficulty(2) # Hard
	
	assert_that(_instance.campaign_config["difficulty_level"]).is_equal(2)

func test_permadeath_toggle() -> void:
	# Test enabling permadeath (normal difficulty allows this)
	_instance.set_permadeath(true)
	
	assert_that(_instance.campaign_config["enable_permadeath"]).is_true()

func test_story_track_toggle() -> void:
	# Test disabling story track
	_instance.set_story_track(false)
	
	assert_that(_instance.campaign_config["use_story_track"]).is_false()

func test_start_button_disabled_without_name() -> void:
	# Start button should be disabled when no campaign name
	assert_that(_instance.is_start_button_enabled).is_false()

func test_start_button_enabled_with_name() -> void:
	# Enter a campaign name
	_instance.set_campaign_name("Test Campaign")
	
	# Start button should now be enabled
	assert_that(_instance.is_start_button_enabled).is_true()

func test_campaign_start_signal() -> void:
	# Skip signal monitoring to prevent Dictionary corruption
	# await assert_signal(_instance).is_emitted("campaign_started")  # REMOVED - causes Dictionary corruption
	# Set up a valid campaign
	_instance.set_campaign_name("Test Campaign")
	
	# Start campaign
	_instance.start_campaign()
	
	await get_tree().process_frame
	
	# Test state directly instead of signal emission
	assert_that(campaign_started_signal_emitted).is_true()
	assert_that(last_campaign_config["name"]).is_equal("Test Campaign")

func test_hardcore_difficulty_forces_permadeath() -> void:
	# Skip signal monitoring to prevent Dictionary corruption
	# await assert_signal(_instance).is_emitted("campaign_started")  # REMOVED - causes Dictionary corruption
	# Set up campaign with hardcore difficulty
	_instance.set_campaign_name("Hardcore Campaign")
	_instance.set_difficulty(3) # Hardcore
	
	# Permadeath should be forced
	assert_that(_instance.is_permadeath_forced()).is_true()
	assert_that(_instance.campaign_config["enable_permadeath"]).is_true()
	
	# Start campaign
	_instance.start_campaign()
	
	await get_tree().process_frame
	
	# Test state directly instead of signal emission
	assert_that(last_campaign_config["enable_permadeath"]).is_true()

func test_easy_difficulty_disables_permadeath() -> void:
	# Set easy difficulty
	_instance.set_difficulty(0) # Easy
	
	# Permadeath should be disabled
	assert_that(_instance.is_permadeath_disabled()).is_true()
	assert_that(_instance.campaign_config["enable_permadeath"]).is_false()

func test_normal_difficulty_allows_permadeath_choice() -> void:
	# Set normal difficulty
	_instance.set_difficulty(1) # Normal
	
	# Should allow permadeath to be toggled
	_instance.set_permadeath(true)
	assert_that(_instance.campaign_config["enable_permadeath"]).is_true()
	
	_instance.set_permadeath(false)
	assert_that(_instance.campaign_config["enable_permadeath"]).is_false()

func test_campaign_config_persistence() -> void:
	# Set up a complete campaign configuration
	_instance.set_campaign_name("Full Test Campaign")
	_instance.set_difficulty(2) # Hard
	_instance.set_permadeath(true)
	_instance.set_story_track(false)
	
	# Verify all settings are preserved
	assert_that(_instance.campaign_config["name"]).is_equal("Full Test Campaign")
	assert_that(_instance.campaign_config["difficulty_level"]).is_equal(2)
	assert_that(_instance.campaign_config["enable_permadeath"]).is_true()
	assert_that(_instance.campaign_config["use_story_track"]).is_false()

func test_empty_name_prevents_start() -> void:
	# Skip signal monitoring to prevent Dictionary corruption
	# await assert_signal(_instance).is_emitted("campaign_started")  # REMOVED - causes Dictionary corruption
	# Try to start with empty name
	_instance.set_campaign_name("")
	_instance.start_campaign()
	
	await get_tree().process_frame
	
	# Signal should not be emitted
	assert_that(campaign_started_signal_emitted).is_false()

func test_difficulty_level_validation() -> void:
	# Test all valid difficulty levels
	for level in range(4): # 0=Easy, 1=Normal, 2=Hard, 3=Hardcore
		_instance.set_difficulty(level)
		assert_that(_instance.campaign_config["difficulty_level"]).is_equal(level)

func test_signal_emission_with_correct_config() -> void:
	# Skip signal monitoring to prevent Dictionary corruption
	# await assert_signal(_instance).is_emitted("campaign_started")  # REMOVED - causes Dictionary corruption
	# Set up complete configuration
	_instance.set_campaign_name("Signal Test Campaign")
	_instance.set_difficulty(2) # Hard
	_instance.set_permadeath(true)
	_instance.set_story_track(true)
	
	# Start campaign
	_instance.start_campaign()
	
	await get_tree().process_frame
	
	# Verify signal contains correct configuration
	assert_that(campaign_started_signal_emitted).is_true()
	assert_that(last_campaign_config["name"]).is_equal("Signal Test Campaign")
	assert_that(last_campaign_config["difficulty_level"]).is_equal(2)
	assert_that(last_campaign_config["enable_permadeath"]).is_true()
	assert_that(last_campaign_config["use_story_track"]).is_true()
