# PostBattle.gd
class_name PostBattlePhase
extends Node

var game_state: GameState
var galactic_war_manager: GalacticWarManager

@onready var resolve_outcomes_button: Button = $MarginContainer/VBoxContainer/ResolveOutcomesButton
@onready var distribute_rewards_button: Button = $MarginContainer/VBoxContainer/DistributeRewardsButton
@onready var handle_injuries_button: Button = $MarginContainer/VBoxContainer/HandleInjuriesButton
@onready var return_to_dashboard_button: Button = $MarginContainer/VBoxContainer/ReturnToDashboardButton

func _init(_game_state: GameState) -> void:
	game_state = _game_state
	galactic_war_manager = GalacticWarManager.new(_game_state)

func _enter_tree() -> void:
	if not game_state:
		game_state = get_node("/root/Main").game_state
	if not galactic_war_manager:
		galactic_war_manager = GalacticWarManager.new(game_state)

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
	process_battle_rewards()
	handle_injuries_and_experience()
	roll_for_events()
	check_for_galactic_war_progress()
	create_logbook_entry()

func get_paid() -> void:
	var mission_payout = calculate_mission_payout()
	game_state.credits += mission_payout
	print("Mission payout: " + str(mission_payout) + " credits")

func battlefield_finds() -> void:
	var finds = generate_battlefield_finds()
	for item in finds:
		game_state.current_ship.inventory.add_item(item)
	print("Battlefield finds: " + str(finds.size()) + " items discovered")

func gather_loot() -> void:
	var loot = generate_loot()
	for item in loot:
		game_state.current_ship.inventory.add_item(item)
	print("Loot gathered: " + str(loot.size()) + " items acquired")

func determine_injuries_and_recovery() -> void:
	for character in game_state.current_crew.members:
		var injury = calculate_injury(character)
		if injury:
			apply_injury(character, injury)
		var recovery_time = calculate_recovery_time(character)
		set_recovery_time(character, recovery_time)
	print("Injuries and recovery times determined for the crew")

func experience_and_character_upgrades() -> void:
	for character in game_state.current_crew.members:
		var xp_gained = calculate_experience_gain(character)
		character.add_experience(xp_gained)
		if character.can_level_up():
			character.level_up()
	print("Experience awarded and character upgrades applied")

func resolve_rival_status() -> void:
	for rival in game_state.rivals:
		if rival.location == game_state.current_location:
			if game_state.last_mission_results == "victory":
				rival.decrease_strength()
				rival.change_hostility(-10)
			else:
				rival.increase_strength()
				rival.change_hostility(10)
			rival.calculate_economic_impact()

func resolve_patron_status() -> void:
	for patron in game_state.patrons:
		if patron.location == game_state.current_location:
			if game_state.last_mission_results == "victory":
				patron.change_relationship(5)
				if game_state.patron_job_manager.should_generate_job(patron):
					var new_job = game_state.mission_generator.generate_missions(game_state)[0]
					new_job.set_type(Mission.Type.PATRON)
					new_job.set_patron(patron)
					patron.add_mission(new_job)
					game_state.available_missions.append(new_job)
			else:
				patron.change_relationship(-5)
			
			patron.economic_influence *= 1.05 if game_state.last_mission_results == "victory" else 0.95
			patron.economic_influence = clamp(patron.economic_influence, 0.5, 2.0)

func determine_quest_progress() -> void:
	for quest in game_state.active_quests:
		if "defeat_enemies" in quest.current_requirements:
			quest.progress["enemies_defeated"] += game_state.enemies_defeated_count
		elif "survive_battles" in quest.current_requirements:
			quest.progress["battles_survived"] += 1

func process_battle_rewards() -> void:
	var rewards = calculate_rewards()
	game_state.credits += rewards.credits
	for item in rewards.items:
		game_state.current_ship.inventory.add_item(item)
	game_state.reputation += rewards.reputation
	
	if game_state.last_mission_results == "victory":
		game_state.story_points += 1

func handle_injuries_and_experience() -> void:
	for character in game_state.current_crew.members:
		apply_injuries(character)
		grant_experience(character)
		
		if character.has_psionic_abilities:
			var psi_roll = randi() % 100 + 1
			if psi_roll <= 10:
				character.advance_psionic_ability()

func roll_for_events() -> void:
	var event = generate_random_event()
	if event:
		apply_event_effects(event)
	
	var rumor_roll = randi() % 100 + 1
	if rumor_roll <= 20:
		var new_rumor = game_state.mission_generator.generate_missions(game_state)[0]
		game_state.available_missions.append(new_rumor)

func check_for_galactic_war_progress() -> void:
	galactic_war_manager.post_battle_update(game_state.last_mission_results)

func create_logbook_entry() -> void:
	var entry = generate_logbook_entry()
	game_state.add_logbook_entry(entry)
	
	game_state.campaign_turn += 1
	
	check_campaign_milestones()

# Helper functions

func calculate_rewards() -> Dictionary:
	var rewards = {
		"credits": 0,
		"items": [],
		"reputation": 0
	}
	
	rewards.credits = randi_range(100, 1000) * game_state.difficulty_settings.battle_difficulty
	
	var possible_items = ["Medkit", "Shield Generator", "Weapon Upgrade"]
	for i in range(randi_range(1, 3)):
		rewards.items.append(possible_items[randi() % possible_items.size()])
	
	rewards.reputation = randi_range(1, 5) * game_state.difficulty_settings.battle_difficulty
	
	return rewards

func apply_injuries(character: Character) -> void:
	var injury_chance = 0.1 + (1.0 - character.health / character.max_health) * 0.2
	if randf() < injury_chance:
		var possible_injuries = ["Minor Wound", "Broken Bone", "Concussion"]
		var injury = possible_injuries[randi() % possible_injuries.size()]
		character.apply_injury(injury)

func grant_experience(character: Character) -> void:
	var base_xp = 50
	var performance_multiplier = 1.0 + (character.kills * 0.1)
	var xp_gained = int(base_xp * performance_multiplier * game_state.difficulty_settings.battle_difficulty)
	character.add_experience(xp_gained)

func generate_random_event() -> Dictionary:
	var possible_events = [
		{
			"name": "Unexpected Ally",
			"description": "A former enemy decides to join your crew.",
			"effect": func(): game_state.current_crew.add_member(Character.new())
		},
		{
			"name": "Equipment Malfunction",
			"description": "One of your ship's systems malfunctions.",
			"effect": func(): game_state.current_ship.damage_random_system()
		},
		{
			"name": "Valuable Intel",
			"description": "You discover valuable information about your next mission.",
			"effect": func(): game_state.mission_generator.reveal_mission_info(game_state.available_missions[0])
		}
	]
	return possible_events[randi() % possible_events.size()]

func apply_event_effects(event: Dictionary) -> void:
	print(event.description)
	event.effect.call()

func generate_logbook_entry() -> String:
	var entry = "Battle Report - {date}\n\n".format({"date": Time.get_date_string_from_system()})
	entry += "Location: {location}\n".format({"location": game_state.current_location.name})
	entry += "Outcome: {outcome}\n".format({"outcome": game_state.last_mission_results})
	entry += "Casualties: {casualties}\n".format({"casualties": game_state.enemies_defeated_count})
	entry += "Notable events:\n"
	for event in game_state.current_mission.events:
		entry += "- " + event + "\n"
	return entry

func calculate_mission_payout() -> int:
	var base_payout = 500
	var difficulty_multiplier = game_state.difficulty_settings.battle_difficulty * 0.5
	var performance_bonus = 200 if game_state.last_mission_results == "victory" else 0
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
	var injury_chance = 0.1 + (1.0 - character.health / character.max_health) * 0.2
	if randf() < injury_chance:
		var possible_injuries = ["Minor Wound", "Broken Bone", "Concussion", "Severe Burn", "Internal Injury"]
		return possible_injuries[randi() % possible_injuries.size()]
	return ""

func apply_injury(character: Character, injury: String) -> void:
	character.add_injury(injury)
	match injury:
		"Minor Wound":
			character.health -= 10
		"Broken Bone":
			character.health -= 20
			character.movement_speed *= 0.8
		"Concussion":
			character.health -= 15
			character.accuracy *= 0.9
		"Severe Burn":
			character.health -= 25
			character.defense *= 0.9
		"Internal Injury":
			character.health -= 30
			character.stamina *= 0.8

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

func set_recovery_time(character: Character, recovery_time: int) -> void:
	character.set_recovery_time(recovery_time)

func calculate_experience_gain(character: Character) -> int:
	var base_xp = 50
	var performance_multiplier = 1.0 + (character.kills * 0.1)
	var difficulty_bonus = game_state.difficulty_settings.battle_difficulty * 20
	var survival_bonus = 25 if character.health > 0 else 0
	return int(base_xp * performance_multiplier + difficulty_bonus + survival_bonus)

func check_campaign_milestones():
	# Implement milestone checking logic here
	pass
