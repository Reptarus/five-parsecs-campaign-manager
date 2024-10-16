# PostBattle.gd
class_name PostBattlePhase
extends Node

var game_state: GameState

@onready var resolve_outcomes_button: Button = $MarginContainer/VBoxContainer/ResolveOutcomesButton
@onready var distribute_rewards_button: Button = $MarginContainer/VBoxContainer/DistributeRewardsButton
@onready var handle_injuries_button: Button = $MarginContainer/VBoxContainer/HandleInjuriesButton
@onready var return_to_dashboard_button: Button = $MarginContainer/VBoxContainer/ReturnToDashboardButton

func _init(_game_state: GameState) -> void:
	game_state = _game_state
<<<<<<< HEAD

func _ready() -> void:
	resolve_outcomes_button.pressed.connect(_on_resolve_outcomes_pressed)
	distribute_rewards_button.pressed.connect(_on_distribute_rewards_pressed)
	handle_injuries_button.pressed.connect(_on_handle_injuries_pressed)
	return_to_dashboard_button.pressed.connect(_on_return_to_dashboard_pressed)
=======
	galactic_war_manager = GalacticWarManager.new(_game_state)
>>>>>>> parent of 1efa334 (worldphase functionality)

func initialize(state: GameState) -> void:
	game_state = state

func _on_resolve_outcomes_pressed() -> void:
	resolve_rival_status()
	resolve_patron_status()
	determine_quest_progress()

func _on_distribute_rewards_pressed() -> void:
	get_paid()
	battlefield_finds()
	gather_loot()

func _on_handle_injuries_pressed() -> void:
	determine_injuries_and_recovery()
	experience_and_character_upgrades()

func _on_return_to_dashboard_pressed() -> void:
	var dashboard_scene: PackedScene = load("res://scenes/CampaignDashboard.tscn")
	var dashboard = dashboard_scene.instantiate()
	dashboard.initialize(game_state)
	get_tree().root.add_child(dashboard)
	queue_free()

func execute_post_battle_sequence() -> void:
	resolve_rival_status()
	resolve_patron_status()
	determine_quest_progress()
	get_paid()
	battlefield_finds()
	check_for_invasion()
	gather_loot()
	determine_injuries_and_recovery()
	experience_and_character_upgrades()
	invest_in_advanced_training()
	purchase_items()
	roll_for_campaign_event()
	roll_for_character_event()
	check_for_galactic_war_progress()

func resolve_rival_status() -> void:
	var battle: Battle = game_state.current_battle
	if battle.held_field and not battle.opponent.is_rival:
		if randi() % 6 + 1 == 1:
			game_state.add_rival(battle.opponent)
	elif battle.held_field and battle.opponent.is_rival:
		var roll: int = randi() % 6 + 1
		roll += 1 if game_state.tracked_rival else 0
		roll += 1 if battle.killed_unique_individual else 0
		if roll >= 4:
			game_state.remove_rival(battle.opponent)

func resolve_patron_status():
	if game_state.current_mission and game_state.current_mission.patron:
		if game_state.current_battle.objective_completed:
			game_state.add_patron_contact(game_state.current_mission.patron)
			print("Mission successful! Patron added to contacts.")
		else:
			print("Mission failed. Patron relationship unchanged.")

func determine_quest_progress():
	if game_state.current_quest:
		var roll = randi() % 6 + 1
		roll += game_state.quest_rumors.size()
		elseroll -= 2 if not game_state.current_battle.objective_completed

		if roll <= 3:
			print("Quest progress: Dead end.")
		elif roll <= 6:
			game_state.add_quest_rumor()
			print("Quest progress: A step closer.")
		else:
			print("Quest progress: Final stage reached!")
			game_state.set_quest_final_stage()

		if roll >= 4:
			if randi() % 6 + 1 >= 5:
				print("Next quest step is on another world.")
				game_state.set_quest_next_world()

func get_paid():
	var payment = randi() % 6 + 1
	if game_state.current_quest and game_state.current_quest.is_final_stage:
		payment = max(randi() % 6 + 1, randi() % 6 + 1) + 1

	if game_state.current_battle.objective_completed:
		payment = max(payment, 3)

	if game_state.current_mission and game_state.current_mission.patron:
		payment += game_state.current_mission.danger_pay

	game_state.add_credits(payment)
	print("Payment received: %d credits" % payment)

func battlefield_finds():
	if game_state.current_battle.held_field:
		var roll = randi() % 100 + 1
		var find = get_battlefield_find(roll)
		print("Battlefield find: %s" % find)
		apply_battlefield_find(find)

func get_battlefield_find(roll: int) -> String:
	if roll <= 15:
		return "Weapon"
	elif roll <= 25:
		return "Usable goods"
	elif roll <= 35:
		return "Curious data stick"
	elif roll <= 45:
		return "Starship part"
	elif roll <= 60:
		return "Personal trinket"
	elif roll <= 75:
		return "Debris"
	elif roll <= 90:
		return "Vital info"
	else:
		return "Nothing of value"

func apply_battlefield_find(find: String):
	match find:
		"Weapon":
			var weapon = game_state.current_battle.get_random_enemy_weapon()
			game_state.add_to_inventory(weapon)
		"Usable goods":
			var consumable = game_state.loot_generator.generate_random_consumable()
			game_state.add_to_inventory(consumable)
		"Curious data stick", "Vital info":
			game_state.add_quest_rumor()
		"Starship part":
			game_state.add_ship_part(2)
		"Personal trinket":
			game_state.add_personal_trinket()
		"Debris":
			game_state.add_credits(randi() % 3 + 1)

func check_for_invasion():
	if game_state.current_battle.opponent.is_invasion_threat:
		var roll = randi() % 6 + 1 + randi() % 6 + 1
		roll += 1 if game_state.has_invasion_evidence else 0
		roll -= 1 if game_state.current_battle.held_field else 0

		if roll >= 9:
			print("Invasion imminent! Prepare to flee!")
			game_state.set_world_invaded()

func gather_loot():
	var loot = game_state.loot_generator.generate_loot()
	game_state.add_to_inventory(loot)
	print("Loot gathered: %s" % loot.name)

	if game_state.current_quest and game_state.current_quest.is_final_stage:
		for i in range(2):
			loot = game_state.loot_generator.generate_loot()
			game_state.add_to_inventory(loot)
			print("Additional quest loot: %s" % loot.name)

func determine_injuries_and_recovery():
	for character in game_state.current_crew.members:
		if character.became_casualty:
			var injury = roll_on_injury_table(character)
			apply_injury(character, injury)

func roll_on_injury_table(character: Character) -> String:
	var roll = randi() % 100 + 1
	if character.is_bot():
		return roll_on_bot_injury_table(roll)
	else:
		return roll_on_human_injury_table(roll)

func roll_on_human_injury_table(roll: int) -> String:
	if roll <= 5:
		return "Gruesome fate"
	elif roll <= 15:
		return "Death or permanent injury"
	elif roll == 16:
		return "Miraculous escape"
	elif roll <= 30:
		return "Equipment loss"
	elif roll <= 45:
		return "Crippling wound"
	elif roll <= 54:
		return "Serious injury"
	elif roll <= 80:
		return "Minor injuries"
	elif roll <= 95:
		return "Knocked out"
	else:
		return "School of hard knocks"

func roll_on_bot_injury_table(roll: int) -> String:
	if roll <= 5:
		return "Obliterated"
	elif roll <= 15:
		return "Destroyed"
	elif roll <= 30:
		return "Equipment loss"
	elif roll <= 45:
		return "Severe damage"
	elif roll <= 65:
		return "Minor damage"
	else:
		return "Just a few dents"

func apply_injury(character: Character, injury: String):
	match injury:
		"Gruesome fate", "Obliterated":
			character.kill()
			character.damage_all_equipment()
		"Death or permanent injury", "Destroyed":
			character.kill()
		"Miraculous escape":
			character.add_luck(1)
			character.lose_all_equipment()
		"Equipment loss":
			character.damage_random_equipment()
		"Crippling wound":
			var surgery_cost = randi() % 6 + 1
			if game_state.credits >= surgery_cost:
				game_state.remove_credits(surgery_cost)
				character.recover_time = randi() % 6 + 1
			else:
				character.permanent_stat_reduction()
		"Serious injury", "Severe damage":
			character.recover_time = randi() % 3 + 2
		"Minor injuries", "Minor damage":
			character.recover_time = 1
		"Knocked out", "Just a few dents":
			pass
		"School of hard knocks":
			character.add_xp(1)

<<<<<<< HEAD
func experience_and_character_upgrades():
	for character in game_state.current_crew.members:
		if character.became_casualty:
			character.add_xp(1)
		elif game_state.current_battle.objective_completed:
			character.add_xp(3)
		else:
			character.add_xp(2)
=======
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
>>>>>>> parent of 1efa334 (worldphase functionality)

		if character == game_state.current_battle.first_to_score_casualty:
			character.add_xp(1)

		if character.killed_unique_individual:
			character.add_xp(1)

		character.apply_experience_upgrades()

func invest_in_advanced_training():
	# This would typically be handled through user input in the UI
	pass

func purchase_items():
	# This would typically be handled through user input in the UI
	pass

<<<<<<< HEAD
func roll_for_campaign_event():
	var event = game_state.campaign_event_generator.generate_event()
	apply_campaign_event(event)

func roll_for_character_event():
	var character = game_state.current_crew.get_random_member()
	var event = game_state.character_event_generator.generate_event(character)
=======
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
	var world_economy_manager = WorldEconomyManager.new(game_state.current_location, economy_manager)
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
>>>>>>> parent of 1efa334 (worldphase functionality)
	apply_character_event(character, event)

func check_for_galactic_war_progress():
	for planet in game_state.invaded_planets:
		var roll = randi() % 6 + 1 + randi() % 6 + 1
		match roll:
			2, 3, 4:
				print("%s lost to Unity" % planet.name)
				game_state.remove_invaded_planet(planet)
			5, 6, 7:
				print("%s remains contested" % planet.name)
			8, 9:
				print("%s: Unity making ground" % planet.name)
				planet.unity_progress += 1
			10, 11, 12:
				print("Unity victorious on %s!" % planet.name)
				game_state.remove_invaded_planet(planet)
				planet.add_troop_presence()

func apply_campaign_event(event: Dictionary):
	# Implement the effects of various campaign events
	print("Applying campaign event: %s" % event.name)
	event.action.call()

<<<<<<< HEAD
func apply_character_event(character: Character, event: Dictionary):
	# Implement the effects of various character events
	print("Applying character event for %s: %s" % [character.name, event.name])
	event.action.call(character)
=======
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
			loot_generator.apply_loot(character, loot, character.ship)
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
>>>>>>> parent of 1efa334 (worldphase functionality)
