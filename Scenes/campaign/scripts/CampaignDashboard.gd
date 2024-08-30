class_name CampaignDashboard
extends Control

@export var game_state: GameState
@export var campaign_manager: CampaignManager

@onready var phase_label: Label = $PhaseLabel
@onready var instruction_label: Label = $InstructionLabel
@onready var action_button: Button = $ActionButton
@onready var options_container: VBoxContainer = $OptionsContainer
@onready var crew_info_label: Label = $CrewInfoLabel
@onready var credits_label: Label = $CreditsLabel
@onready var story_points_label: Label = $StoryPointsLabel

func _ready() -> void:
	action_button.pressed.connect(_on_action_button_pressed)
	campaign_manager.phase_changed.connect(_on_phase_changed)
	update_display()

func _on_phase_changed(new_phase: CampaignManager.TurnPhase) -> void:
	update_display()

func update_display() -> void:
	phase_label.text = CampaignManager.TurnPhase.keys()[campaign_manager.current_phase].capitalize().replace("_", " ")
	crew_info_label.text = "Crew: " + game_state.current_crew.name + " (" + str(game_state.current_crew.get_member_count()) + " members)"
	credits_label.text = "Credits: " + str(game_state.credits)
	story_points_label.text = "Story Points: " + str(game_state.story_points)

	match campaign_manager.current_phase:
		CampaignManager.TurnPhase.UPKEEP:
			instruction_label.text = "Pay upkeep costs and remove Injury markers"
			action_button.text = "Complete Upkeep"
		CampaignManager.TurnPhase.STORY_POINT:
			instruction_label.text = "Choose to spend a Story Point or not"
			action_button.text = "Use Story Point" if game_state.story_points > 0 else "Skip Story Point"
		CampaignManager.TurnPhase.MOVE_TO_NEW_LOCATION:
			instruction_label.text = "Choose to move to a new location or stay"
			action_button.text = "Choose Location"
			_display_location_options()
		CampaignManager.TurnPhase.RUMORS_AND_HAPPENINGS:
			instruction_label.text = "Roll for Rumors and Happenings"
			action_button.text = "Generate Events"
		CampaignManager.TurnPhase.QUEST_PROGRESS:
			instruction_label.text = "Check for Quest progress"
			action_button.text = "Update Quests"
		CampaignManager.TurnPhase.RECRUIT:
			instruction_label.text = "Attempt to recruit new crew members"
			action_button.text = "Recruit"
			_display_recruit_options()
		CampaignManager.TurnPhase.TRAINING_AND_STUDY:
			instruction_label.text = "Train crew or study new skills"
			action_button.text = "Train/Study"
			_display_training_options()
		CampaignManager.TurnPhase.TRADE:
			instruction_label.text = "Buy or sell items"
			action_button.text = "Trade"
			_display_trade_options()
		CampaignManager.TurnPhase.PATRON_JOB:
			instruction_label.text = "Check for Patron Jobs"
			action_button.text = "Check Jobs"
		CampaignManager.TurnPhase.MISSION:
			instruction_label.text = "Choose and complete a mission"
			action_button.text = "Start Mission"
			_display_mission_options()
		CampaignManager.TurnPhase.POST_MISSION:
			instruction_label.text = "Resolve post-mission tasks"
			action_button.text = "Resolve Mission"
		CampaignManager.TurnPhase.END_TURN:
			instruction_label.text = "End the current turn"
			action_button.text = "End Turn"

func _on_action_button_pressed() -> void:
	match campaign_manager.current_phase:
		CampaignManager.TurnPhase.UPKEEP:
			var success = campaign_manager.perform_upkeep()
			if success:
				print("Upkeep paid and Injury markers removed.")
			else:
				print("Insufficient funds for upkeep! Crew morale decreases.")
		CampaignManager.TurnPhase.STORY_POINT:
			var used = campaign_manager.handle_story_point()
			if used:
				print("Story Point used! Choose an effect:")
				_display_story_point_options()
			else:
				print("No Story Point used this turn.")
		CampaignManager.TurnPhase.MOVE_TO_NEW_LOCATION:
			var location_index = _get_selected_option()
			if campaign_manager.move_to_new_location(location_index):
				print("Moved to new location: " + game_state.current_location.name)
			else:
				print("Failed to move to new location.")
		CampaignManager.TurnPhase.RUMORS_AND_HAPPENINGS:
			var event = campaign_manager.generate_events()
			if event:
				print("New event: " + event.title)
				_display_event_details(event)
			else:
				print("No new events this turn.")
		CampaignManager.TurnPhase.QUEST_PROGRESS:
			var updated_quests = campaign_manager.update_quests()
			for quest in updated_quests:
				print("Quest updated: " + quest.title)
			_display_quest_updates(updated_quests)
		CampaignManager.TurnPhase.RECRUIT:
			var recruit_index = _get_selected_option()
			if campaign_manager.recruit_crew(recruit_index):
				print("New crew member recruited!")
			else:
				print("Failed to recruit new crew member.")
		CampaignManager.TurnPhase.TRAINING_AND_STUDY:
			var crew_index = _get_selected_option()
			var skill = _get_selected_skill()
			if campaign_manager.train_and_study(crew_index, skill):
				print("Training successful!")
			else:
				print("Training failed.")
		CampaignManager.TurnPhase.TRADE:
			var buy = _get_trade_action()
			var item_index = _get_selected_option()
			if campaign_manager.trade_items(buy, item_index):
				print("Trade successful!")
			else:
				print("Trade failed.")
		CampaignManager.TurnPhase.PATRON_JOB:
			var available_jobs = campaign_manager.check_patron_jobs()
			_display_patron_jobs(available_jobs)
		CampaignManager.TurnPhase.MISSION:
			var mission_index = _get_selected_option()
			if campaign_manager.start_mission(mission_index):
				print("Mission started: " + game_state.current_mission.title)
				_start_mission_scene()
			else:
				print("Failed to start mission.")
		CampaignManager.TurnPhase.POST_MISSION:
			var results = campaign_manager.handle_post_mission()
			_display_mission_results(results)
		CampaignManager.TurnPhase.END_TURN:
			campaign_manager.end_turn()

	campaign_manager.advance_phase()
	update_display()

func _display_location_options() -> void:
	options_container.clear()
	var locations = game_state.get_all_locations()
	for i in range(locations.size()):
		var option = CheckBox.new()
		option.text = locations[i].name
		options_container.add_child(option)

func _display_recruit_options() -> void:
	options_container.clear()
	var recruits = game_state.mission_generator.generate_recruits()
	for i in range(recruits.size()):
		var option = CheckBox.new()
		option.text = recruits[i].name + " - " + CharacterCreationData.Background.keys()[recruits[i].background]
		options_container.add_child(option)

func _display_training_options() -> void:
	options_container.clear()
	for i in range(game_state.current_crew.members.size()):
		var crew_member = game_state.current_crew.members[i]
		var option = OptionButton.new()
		option.text = crew_member.name
		for skill in crew_member.skills.keys():
			option.add_item(skill)
		options_container.add_child(option)

func _display_trade_options() -> void:
	options_container.clear()
	var buy_button = Button.new()
	buy_button.text = "Buy"
	buy_button.pressed.connect(func(): _show_buy_options())
	options_container.add_child(buy_button)

	var sell_button = Button.new()
	sell_button.text = "Sell"
	sell_button.pressed.connect(func(): _show_sell_options())
	options_container.add_child(sell_button)

func _show_buy_options() -> void:
	options_container.clear()
	var available_items = game_state.equipment_manager.get_available_items()
	for item in available_items:
		var option = CheckBox.new()
		option.text = item.name + " - " + str(item.cost) + " credits"
		options_container.add_child(option)

func _show_sell_options() -> void:
	options_container.clear()
	var crew_items = game_state.current_crew.get_all_items()
	for item in crew_items:
		var option = CheckBox.new()
		option.text = item.name + " - " + str(item.sell_value) + " credits"
		options_container.add_child(option)

func _display_mission_options() -> void:
	options_container.clear()
	var available_missions = game_state.mission_generator.generate_available_missions()
	for mission in available_missions:
		var option = CheckBox.new()
		option.text = mission.title + " - Reward: " + str(mission.reward) + " credits"
		options_container.add_child(option)

func _display_story_point_options() -> void:
	options_container.clear()
	var effects = ["Reroll", "Add Bonus", "Avoid Danger", "Gain Information"]
	for effect in effects:
		var option = CheckBox.new()
		option.text = effect
		options_container.add_child(option)

func _display_event_details(event: Dictionary) -> void:
	options_container.clear()
	var details = Label.new()
	details.text = event.description
	options_container.add_child(details)

func _display_quest_updates(quests: Array) -> void:
	options_container.clear()
	for quest in quests:
		var quest_label = Label.new()
		quest_label.text = quest.title + " - Progress: " + str(quest.progress) + "%"
		options_container.add_child(quest_label)

func _display_patron_jobs(jobs: Array) -> void:
	options_container.clear()
	for job in jobs:
		var job_button = Button.new()
		job_button.text = job.title + " - Reward: " + str(job.reward) + " credits"
		job_button.pressed.connect(func(): _accept_patron_job(job))
		options_container.add_child(job_button)

func _accept_patron_job(job: Mission) -> void:
	game_state.patron_job_manager.accept_job(job)
	print("Accepted patron job: " + job.title)

func _start_mission_scene() -> void:
	# This would typically transition to a new scene for mission gameplay
	print("Starting mission: " + game_state.current_mission.title)
	# For now, we'll just simulate mission completion
	_simulate_mission_completion()

func _simulate_mission_completion() -> void:
	# This is a placeholder for actual mission gameplay
	print("Mission completed successfully!")
	campaign_manager.advance_phase()  # Move to post-mission phase

func _display_mission_results(results: Dictionary) -> void:
	options_container.clear()
	var result_text = "Mission Results:\n"
	result_text += "Credits earned: " + str(results.loot.credits) + "\n"
	result_text += "Items found: " + ", ".join(results.loot.items.map(func(item): return item.name)) + "\n"
	result_text += "XP gained: " + str(results.xp_gained) + "\n"

	if results.injuries.size() > 0:
		result_text += "Injuries sustained:\n"
		for injury in results.injuries:
			result_text += injury.crew_member + " - " + injury.injury + "\n"

	var result_label = Label.new()
	result_label.text = result_text
	options_container.add_child(result_label)

func _get_selected_option() -> int:
	for i in range(options_container.get_child_count()):
		var option = options_container.get_child(i)
		if option is CheckBox and option.pressed:
			return i
	return -1

func _get_selected_skill() -> String:
	var selected_option = options_container.get_child(_get_selected_option())
	if selected_option is OptionButton:
		return selected_option.get_item_text(selected_option.selected)
	return ""

func _get_trade_action() -> bool:
	return options_container.get_child(0).pressed  # True if Buy, False if Sell

func clear_options() -> void:
	for child in options_container.get_children():
		child.queue_free()
