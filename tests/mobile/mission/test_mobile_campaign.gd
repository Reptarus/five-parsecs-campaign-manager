@tool
extends "res://tests/fixtures/game_test.gd"

const FiveParsecsCampaignSystem := preload("res://src/core/campaign/CampaignSystem.gd")

var campaign_system: Node
var campaign: Resource
var game_state: Node

func before_each() -> void:
	await super.before_each()
	gut.p("Setting up mobile campaign test environment...")
	
	# Set up mobile environment
	simulate_mobile_environment("phone_portrait")
	
	# Initialize game state
	game_state = create_test_game_state()
	add_child(game_state)
	track_test_node(game_state)
	assert_valid_game_state(game_state)
	
	# Set up campaign system
	campaign_system = FiveParsecsCampaignSystem.new(game_state)
	add_child(campaign_system)
	track_test_node(campaign_system)
	watch_signals(campaign_system)
	
	await get_tree().process_frame
	gut.p("Mobile test environment setup complete")

func after_each() -> void:
	if campaign:
		_signal_watcher.clear()
	await super.after_each()
	campaign = null
	campaign_system = null
	game_state = null

func test_mobile_campaign_performance() -> void:
	gut.p("Starting mobile campaign performance test")
	
	# Create and start campaign
	var campaign_config = {
		"name": "Mobile Test Campaign",
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"victory_type": GameEnums.FiveParcsecsCampaignVictoryType.STANDARD,
		"crew_size": GameEnums.CrewSize.FOUR,
		"use_story_track": true
	}
	
	campaign = campaign_system.create_campaign(campaign_config)
	watch_signals(campaign)
	campaign.start_campaign()
	
	# Test campaign phase transitions under different mobile conditions
	var resolutions = ["phone_portrait", "phone_landscape", "tablet_portrait"]
	
	for resolution in resolutions:
		gut.p("Testing campaign performance in %s mode..." % resolution)
		simulate_mobile_environment(resolution)
		await get_tree().process_frame
		
		# Measure phase transition performance
		var results = await measure_mobile_performance(func():
			campaign.change_phase(GameEnums.FiveParcsecsCampaignPhase.UPKEEP)
			await get_tree().process_frame
			campaign.change_phase(GameEnums.FiveParcsecsCampaignPhase.CAMPAIGN)
			await get_tree().process_frame
		)
		
		# Performance assertions
		assert_true(results.average_fps >= 30.0,
			"Average FPS should be at least 30 in %s mode" % resolution)
		assert_true(results.minimum_fps >= 20.0,
			"Minimum FPS should be at least 20 in %s mode" % resolution)
		assert_true(results.memory_delta_kb < 2048,
			"Memory usage increase should be less than 2MB in %s mode" % resolution)
		
		gut.p("Performance results for %s:" % resolution)
		gut.p("- Average FPS: %.2f" % results.average_fps)
		gut.p("- 95th percentile FPS: %.2f" % results["95th_percentile_fps"])
		gut.p("- Minimum FPS: %.2f" % results.minimum_fps)
		gut.p("- Memory Delta: %.2f KB" % results.memory_delta_kb)
		gut.p("- Draw Calls Delta: %d" % results.draw_calls_delta)
		gut.p("- Objects Delta: %d" % results.objects_delta)

func test_mobile_save_load() -> void:
	gut.p("Testing mobile save/load functionality")
	
	# Create initial campaign
	var campaign_config = {
		"name": "Mobile Save Test",
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"victory_type": GameEnums.FiveParcsecsCampaignVictoryType.STANDARD,
		"crew_size": GameEnums.CrewSize.FOUR,
		"use_story_track": true
	}
	
	campaign = campaign_system.create_campaign(campaign_config)
	watch_signals(campaign)
	campaign.start_campaign()
	
	# Test save/load under different mobile conditions
	var resolutions = ["phone_portrait", "phone_landscape"]
	
	for resolution in resolutions:
		gut.p("Testing save/load in %s mode..." % resolution)
		simulate_mobile_environment(resolution)
		await get_tree().process_frame
		
		# Save campaign
		var save_results = await measure_mobile_performance(func():
			campaign_system.save_campaign(campaign)
			await get_tree().process_frame
		)
		
		# Load campaign
		var load_results = await measure_mobile_performance(func():
			campaign_system.load_campaign("Mobile Save Test")
			await get_tree().process_frame
		)
		
		# Performance assertions
		assert_true(save_results.average_fps >= 30.0,
			"Save operation should maintain at least 30 FPS in %s mode" % resolution)
		assert_true(load_results.average_fps >= 30.0,
			"Load operation should maintain at least 30 FPS in %s mode" % resolution)
		
		gut.p("Save/Load performance in %s:" % resolution)
		gut.p("Save operation:")
		gut.p("- Average FPS: %.2f" % save_results.average_fps)
		gut.p("- Memory Delta: %.2f KB" % save_results.memory_delta_kb)
		gut.p("Load operation:")
		gut.p("- Average FPS: %.2f" % load_results.average_fps)
		gut.p("- Memory Delta: %.2f KB" % load_results.memory_delta_kb)

func test_mobile_input_handling() -> void:
	gut.p("Testing mobile input handling")
	
	# Create and start campaign
	var campaign_config = {
		"name": "Mobile Input Test",
		"difficulty": GameEnums.DifficultyLevel.NORMAL,
		"victory_type": GameEnums.FiveParcsecsCampaignVictoryType.STANDARD,
		"crew_size": GameEnums.CrewSize.FOUR,
		"use_story_track": true
	}
	
	campaign = campaign_system.create_campaign(campaign_config)
	watch_signals(campaign)
	campaign.start_campaign()
	
	# Test touch input for common campaign actions
	var touch_actions = [
		{"position": Vector2(100, 100), "action": "select_character"},
		{"position": Vector2(200, 200), "action": "open_inventory"},
		{"position": Vector2(300, 300), "action": "start_mission"}
	]
	
	for action in touch_actions:
		# Simulate touch
		simulate_touch_event(action.position, true)
		await get_tree().process_frame
		simulate_touch_event(action.position, false)
		await get_tree().process_frame
		
		# Verify action response
		assert_signal_emitted(campaign, action.action + "_triggered",
			"Campaign should respond to touch input for " + action.action)
		
		# Test touch responsiveness
		var response_results = await measure_mobile_performance(func():
			simulate_touch_event(action.position, true)
			await get_tree().process_frame
			simulate_touch_event(action.position, false)
			await get_tree().process_frame
		)
		
		assert_true(response_results.average_fps >= 45.0,
			"Touch response should maintain at least 45 FPS")
		
		gut.p("Touch response performance for %s:" % action.action)
		gut.p("- Average FPS: %.2f" % response_results.average_fps)
		gut.p("- Response Time: %.2f ms" % (1000.0 / response_results.average_fps))