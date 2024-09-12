class_name CampaignManager
extends Resource

signal phase_changed(new_phase: TurnPhase)
signal turn_completed

enum TurnPhase {
	UPKEEP,
	STORY_POINT,
	MOVE_TO_NEW_LOCATION,
	RUMORS_AND_HAPPENINGS,
	QUEST_PROGRESS,
	RECRUIT,
	TRAINING_AND_STUDY,
	TRADE,
	PATRON_JOB,
	MISSION,
	POST_MISSION,
	END_TURN
}

var game_state: GameState
var current_phase: TurnPhase = TurnPhase.UPKEEP
var use_expanded_missions: bool = false

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func start_new_turn(main_scene: Node) -> void:
	game_state.current_turn += 1
	game_state.reset_turn_specific_data()
	
	var turn_summary = create_campaign_turn_summary()
	game_state.logbook.add_entry(turn_summary)
	
	var save_manager = SaveManager.new()
	save_manager.save_game(game_state, "user://autosave.json")
	
	start_world_phase(main_scene)

func start_world_phase(main_scene: Node):
	var world_phase_scene = load("res://Scenes/campaign/WorldPhase.tscn").instantiate()
	world_phase_scene.initialize(game_state)
	main_scene.add_child(world_phase_scene)

func advance_phase() -> void:
	current_phase = TurnPhase.values()[(current_phase + 1) % TurnPhase.size()]
	phase_changed.emit(current_phase)

func perform_upkeep() -> bool:
	var upkeep_cost: int = game_state.current_crew.calculate_upkeep_cost()
	if game_state.remove_credits(upkeep_cost):
		for crew_member in game_state.current_crew.members:
			crew_member.recover_time = max(0, crew_member.recover_time - 1)
		return true
	else:
		game_state.current_crew.decrease_morale()
		return false

func handle_story_point() -> bool:
	if game_state.story_points > 0:
		game_state.remove_story_points(1)
		return true
	return false

func move_to_new_location(location_index: int) -> bool:
	var locations: Array = game_state.get_all_locations()
	if location_index >= 0 and location_index < locations.size():
		game_state.current_location = locations[location_index]
		return true
	return false

func generate_events() -> Dictionary:
	return game_state.event_system.generate_random_event()

func update_quests() -> Array:
	return game_state.quest_system.update_quests()

func recruit_crew(recruit_index: int) -> bool:
	var potential_recruits: Array = game_state.character_generator.generate_recruits()
	if recruit_index >= 0 and recruit_index < potential_recruits.size():
		return game_state.current_crew.add_member(potential_recruits[recruit_index])
	return false

func train_and_study(crew_index: int, skill: String, skill_type: Skill.SkillType) -> bool:
	if crew_index >= 0 and crew_index < game_state.current_crew.members.size():
		var crew_member = game_state.current_crew.members[crew_index]
		
		# Check if the character already has the skill
		if crew_member.has_skill(skill):
			# If they have the skill, increase its level
			crew_member.increase_skill_level(skill)
		else:
			# If they don't have the skill, add it
			crew_member.add_skill(skill, skill_type)
		
		return true  # Training/studying was successful
	
	return false  # Invalid crew index or other failure

func trade_items(buy: bool, item_index: int) -> bool:
	if buy:
		var available_items = game_state.equipment_manager.get_available_items()
		if item_index >= 0 and item_index < available_items.size():
			return game_state.equipment_manager.buy_item(available_items[item_index])
	else:
		var crew_items = game_state.current_crew.get_all_items()
		if item_index >= 0 and item_index < crew_items.size():
			return game_state.equipment_manager.sell_item(crew_items[item_index])
	return false

func check_patron_jobs() -> Array:
	return game_state.patron_job_manager.get_available_jobs()

func start_mission(mission_index: int) -> bool:
	var available_missions: Array = game_state.mission_generator.generate_available_missions()
	if mission_index >= 0 and mission_index < available_missions.size():
		game_state.current_mission = available_missions[mission_index]
		return true
	return false

func handle_post_mission() -> Dictionary:
	if game_state.current_mission:
		var results = {
			"loot": game_state.current_mission.generate_loot(),
			"injuries": [],
			"xp_gained": game_state.current_mission.xp_reward
		}
		game_state.add_credits(results.loot.credits)
		for item in results.loot.items:
			game_state.equipment_manager.add_item(item)

		for crew_member in game_state.current_crew.members:
			if crew_member.became_casualty:
				var injury = crew_member.roll_injury()
				results.injuries.append({"crew_member": crew_member.name, "injury": injury})

		game_state.current_crew.update_experience(results.xp_gained)
		game_state.current_mission = null
		return results
	return {}

func end_turn() -> void:
	game_state.advance_turn()
	turn_completed.emit()
	start_new_turn(game_state.current_turn)

func create_campaign_turn_summary() -> String:
	return "Turn %d: %s" % [game_state.current_turn, game_state.current_location.name]
