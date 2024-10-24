# PostBattle.gd
class_name PostBattlePhase
extends Node

var game_state: GameState
var galactic_war_manager: GalacticWarManager
var game_state_manager: GameStateManager

const AdvTrainingManager = preload("res://Resources/WorldPhase/AdvTrainingManager.gd")

func _init(_game_state: GameState) -> void:
	game_state = _game_state
	galactic_war_manager = GalacticWarManager.new(_game_state)

func execute_post_battle_sequence(player_victory: bool) -> void:
	resolve_rival_status(player_victory)
	resolve_patron_status(player_victory)
	determine_quest_progress()
	get_paid(player_victory)
	battlefield_finds()
	check_for_invasion()
	gather_loot()
	determine_injuries_and_recovery()
	experience_and_character_upgrades()
	invest_in_advanced_training()
	purchase_items()
	roll_for_campaign_event()
	roll_for_character_event()
	check_for_galactic_war_progress(player_victory)

func resolve_rival_status(player_victory: bool) -> void:
	for rival in game_state.rivals:
		if rival.location == game_state.current_location:
			if player_victory:
				rival.decrease_strength()
				rival.change_hostility(-10)
			else:
				rival.increase_strength()
				rival.change_hostility(10)
			rival.calculate_economic_impact()

func resolve_patron_status(player_victory: bool) -> void:
	for patron in game_state.patrons:
		if patron.location == game_state.current_location:
			if player_victory:
				patron.change_relationship(5)
				if game_state.patron_job_manager.should_generate_job(patron):
					var new_job = game_state.mission_generator.generate_mission()
					new_job.type = GlobalEnums.Type.PATRON
					new_job.patron = patron
					patron.add_mission(new_job)
					game_state.add_available_mission(new_job)
			else:
				patron.change_relationship(-5)
			
			patron.economic_influence *= 1.05 if player_victory else 0.95
			patron.economic_influence = clamp(patron.economic_influence, 0.5, 2.0)

func determine_quest_progress() -> void:
	for quest in game_state.active_quests:
		if "defeat_enemies" in quest.current_requirements:
			quest.progress["enemies_defeated"] += game_state.enemies_defeated_count
		elif "survive_battles" in quest.current_requirements:
			quest.progress["battles_survived"] += 1

func get_paid(player_victory: bool) -> void:
	var mission_payout = calculate_mission_payout(player_victory)
	game_state.credits += mission_payout
	print("Mission payout: " + str(mission_payout) + " credits")

func battlefield_finds() -> void:
	var finds = generate_battlefield_finds()
	for item in finds:
		game_state.current_ship.inventory.add_item(item)
	print("Battlefield finds: " + str(finds.size()) + " items discovered")

func check_for_invasion() -> void:
	# Implement invasion check logic
	pass

func gather_loot() -> void:
	var loot = generate_loot()
	for item in loot:
		game_state.current_ship.inventory.add_item(item)
	print("Loot gathered: " + str(loot.size()) + " items acquired")

func determine_injuries_and_recovery() -> void:
	for character in game_state.current_crew.members:
		var injury = calculate_injury(character)
		if injury:
			character.apply_injury(injury)
		var recovery_time = calculate_recovery_time(character)
		character.set_recovery_time(recovery_time)
	print("Injuries and recovery times determined for the crew")

func experience_and_character_upgrades() -> void:
	for character in game_state.current_crew.members:
		var xp_gained = calculate_experience_gain(character)
		character.character_advancement.apply_experience(xp_gained)

func invest_in_advanced_training() -> void:
	var adv_training_manager = AdvTrainingManager.new(game_state)
	for character in game_state.current_crew.members:
		var available_courses = adv_training_manager.get_available_courses(character)
		if available_courses.size() > 0:
			var chosen_course = available_courses[randi() % available_courses.size()]
			if adv_training_manager.apply_for_training(character, chosen_course):
				if adv_training_manager.enroll_in_course(character, chosen_course):
					print("%s successfully enrolled in %s" % [character.name, chosen_course])
				else:
					print("%s was accepted but couldn't afford %s" % [character.name, chosen_course])
			else:
				print("%s's application for %s was rejected" % [character.name, chosen_course])

func purchase_items() -> void:
	var economy_manager = game_state.economy_manager
	var world_economy_manager = WorldEconomyManager.new(Location.new(), economy_manager)
	var available_items = world_economy_manager.get_local_market()
	
	for item in available_items:
		var item_price = world_economy_manager.get_item_price(item)
		if game_state.current_crew.credits >= item_price and randf() < 0.3:  # 30% chance to buy an item
			if world_economy_manager.buy_item(game_state.current_crew, item):
				print("%s purchased for %d credits" % [item.name, item_price])
	
	# Selling items
	var inventory = game_state.current_crew.inventory
	for item in inventory.get_items():
		if randf() < 0.2:  # 20% chance to sell an item
			var sell_price = world_economy_manager.get_item_price(item)
			if world_economy_manager.sell_item(game_state.current_crew, item):
				print("%s sold for %d credits" % [item.name, sell_price])
	
	# Update local economy
	world_economy_manager.update_local_economy()

func roll_for_campaign_event() -> void:
	var event = generate_campaign_event()
	apply_campaign_event(event)

func roll_for_character_event() -> void:
	var character = game_state.current_crew.get_random_character()
	var event = generate_character_event()
	apply_character_event(character, event)

func check_for_galactic_war_progress(player_victory: bool) -> void:
	var battle_outcome = GlobalEnums.BattleOutcome.VICTORY if player_victory else GlobalEnums.BattleOutcome.DEFEAT
	galactic_war_manager.post_battle_update(battle_outcome)

# Helper functions
func calculate_mission_payout(player_victory: bool) -> int:
	var base_payout = 500
	var difficulty_multiplier = game_state.difficulty_settings.battle_difficulty * 0.5
	var performance_bonus = 200 if player_victory else 0
	var casualties_penalty = game_state.enemies_defeated_count * -50
	return int(base_payout + (base_payout * difficulty_multiplier) + performance_bonus + casualties_penalty)

func generate_battlefield_finds() -> Array:
	var finds = []
	var possible_finds = ["Ammo Cache", "Medical Supplies", "Scrap Metal", "Alien Artifact", "Abandoned Equipment"]
	var num_finds = randi() % 3 + 1
	for _i in range(num_finds):
		finds.append(possible_finds[randi() % possible_finds.size()])
	return finds

func generate_loot() -> Array:
	var loot = []
	var possible_loot = ["Credits", "Weapon", "Armor", "Cybernetic", "Ship Part"]
	var num_loot = randi() % 4 + 2
	for _i in range(num_loot):
		loot.append(possible_loot[randi() % possible_loot.size()])
	return loot

func calculate_injury(character: Character) -> String:
	var injury_chance = 0.1 + (1.0 - character.toughness / character.get_max_toughness()) * 0.2
	if randf() < injury_chance:
		var possible_injuries = ["Minor Wound", "Broken Bone", "Concussion", "Severe Burn", "Internal Injury"]
		return possible_injuries[randi() % possible_injuries.size()]
	return ""

func calculate_recovery_time(character: Character) -> int:
	var base_recovery_time = 3
	for injury in character.injuries:
		match injury:
			"Minor Wound":
				base_recovery_time += 1
			"Broken Bone":
				base_recovery_time += 5
			"Concussion":
				base_recovery_time += 3
			"Severe Burn":
				base_recovery_time += 4
			"Internal Injury":
				base_recovery_time += 7
	return base_recovery_time

func calculate_experience_gain(character: Character) -> int:
	var base_xp = 50
	var performance_multiplier = 1.0 + (character.kills * 0.1)
	var difficulty_bonus = game_state.difficulty_settings.battle_difficulty * 20
	var survival_bonus = 25 if not character.is_defeated else 0
	return int(base_xp * performance_multiplier + difficulty_bonus + survival_bonus)

func generate_campaign_event() -> Dictionary:
	var event_generator = CampaignEventGenerator.new(game_state_manager)
	var event: StoryEvent = event_generator.generate_event()
	return event.to_dictionary()  # Assuming StoryEvent has a to_dictionary() method

func apply_campaign_event(event: StoryEvent) -> void:
	# Assuming event is already a StoryEvent instance
	event.apply_event_effects(game_state_manager)
	
	if "battle_setup" in event:
		var battle = Battle.new()  # Assuming you have a Battle class
		event.setup_battle(battle)
	
	if "rewards" in event:
		event.apply_rewards(game_state_manager)

func generate_character_event() -> Dictionary:
	var event_tables = load_json_file("res://data/event_tables.json")
	var mission_events = event_tables["mission_events"]
	return mission_events[randi() % mission_events.size()]

func apply_character_event(character: Character, event: Dictionary) -> void:
	var battle_event_manager = BattleEventManager.new(game_state)
	var event_data = {"character": character}
	var battle_event = battle_event_manager._create_event(BattleEventManager.EventType.values()[randi() % BattleEventManager.EventType.size()], event_data)

	# Apply the event effect to the character
	match event["effect"]:
		"Gain a temporary ally":
			# Logic to add a temporary ally
			var ally = Character.create_temporary()
			game_state.add_temporary_ally(ally)
		"Equipment malfunction":
			character.disable_random_item()
		"Hostile environment":
			# Apply penalty to character's rolls
			character.add_temporary_modifier("hostile_environment", -1)
		"Lucky break":
			# Grant advantage on next roll
			character.add_temporary_modifier("lucky_break", 1)
		"Hidden cache":
			# Add random loot to character's inventory
			var loot_generator = LootGenerator.new()
			var loot = loot_generator.generate_loot()
			loot_generator.apply_loot(game_state.current_crew, loot, character.ship)
		"Vital info":
			# Turn in information to get a Corporate Patron
			var patron = Patron.new()
			game_state.add_corporate_patron(patron)
		"Invasion Evidence":
			# Earn credits and increase invasion chance
			game_state.add_credits(1)
			game_state.increase_invasion_chance(1)
		_:
			# Default case for other effects
			print("Applying effect: ", event["effect"])
	
	# Apply the battle event effect
	battle_event_manager.apply_event(battle_event, [character], [])  # Assuming the character is on the player's team

	# Roll for potential Quest or disappearance (for mysterious characters)
	if character.is_mysterious():
		var roll = randi() % 36 + 1  # 2D6
		if roll == 2:
			game_state.remove_character(character)
			game_state.add_story_points(2)
		elif roll >= 11:
			game_state.add_quest()
	
	# Apply the battle event effect
	battle_event_manager.apply_event(battle_event, [character], [])  # Assuming the character is on the player's team

func load_json_file(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result == OK:
			return json.get_data()
		else:
			push_error("JSON Parse Error: " + json.get_error_message() + " at line " + str(json.get_error_line()))
			return {}
	else:
		push_error("Failed to open file: " + file_path)
		return {}
