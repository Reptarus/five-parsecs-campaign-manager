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

func _ready() -> void:
	resolve_outcomes_button.pressed.connect(_on_resolve_outcomes_pressed)
	distribute_rewards_button.pressed.connect(_on_distribute_rewards_pressed)
	handle_injuries_button.pressed.connect(_on_handle_injuries_pressed)
	return_to_dashboard_button.pressed.connect(_on_return_to_dashboard_pressed)

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
			var new_rival = Rival.new(battle.opponent.name, battle.opponent.location)
			# Copy relevant data from battle.opponent to new_rival
			game_state.add_rival(new_rival)
	elif battle.held_field and battle.opponent.is_rival:
		var roll: int = randi() % 6 + 1
		roll += 1 if game_state.tracked_rival else 0
		roll += 1 if battle.killed_unique_individual else 0
		if roll >= 4:
			# Find the corresponding Rival object in the game state
			var rival_to_remove = game_state.find_rival_by_name(battle.opponent.name)
			if rival_to_remove:
				game_state.remove_rival(rival_to_remove)


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
		roll -= 2 if not game_state.current_battle.objective_completed else 0

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

func roll_on_injury_table(character) -> String:
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

func apply_injury(character, injury: String):
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

func experience_and_character_upgrades():
	for character in game_state.current_crew.members:
		if character.became_casualty:
			character.add_xp(1)
		elif game_state.current_battle.objective_completed:
			character.add_xp(3)
		else:
			character.add_xp(2)

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

func roll_for_campaign_event():
	var event = game_state.campaign_event_generator.generate_event()
	apply_campaign_event(event)

func roll_for_character_event():
	var character = game_state.current_crew.get_random_member()
	var event = game_state.character_event_generator.generate_event(character)
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

func apply_character_event(character, event: Dictionary):
	# Implement the effects of various character events
	print("Applying character event for %s: %s" % [character.name, event.name])
	event.action.call(character)
