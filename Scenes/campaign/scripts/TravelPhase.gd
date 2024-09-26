# TravelPhase.gd
extends Control

signal phase_completed

const RivalResource = preload("res://Resources/Rival.gd")

var game_state: GameState
var starship_travel_events: StarshipTravelEvents

func _init(_game_state: GameState):
	game_state = _game_state
	starship_travel_events = StarshipTravelEvents.new(game_state)

func _ready():
	$MarginContainer/VBoxContainer/StayButton.pressed.connect(_on_stay_pressed)
	$MarginContainer/VBoxContainer/TravelButton.pressed.connect(_on_travel_pressed)
	$MarginContainer/VBoxContainer/BackButton.pressed.connect(_on_back_pressed)

func _on_stay_pressed():
	get_node("/root/Main").load_scene("res://scenes/campaign/GameWorld.tscn")

func _on_travel_pressed():
	if game_state.current_crew.ship.is_damaged():
		var choice = _show_emergency_takeoff_dialog()
		if choice:
			emergency_takeoff()
		else:
			return

	var travel_cost = 5  # Base travel cost
	if not game_state.current_crew.remove_credits(travel_cost):
		_show_insufficient_funds_dialog()
		return

	var destination = game_state.world_generator.generate_new_world()
	if game_state.current_crew.ship.travel_to(destination, game_state):
		var event = starship_travel_events.generate_travel_event()
		_handle_travel_event(event)
		game_state.current_location = destination
		check_for_patrons_and_rivals()
		check_for_licensing_requirement()
		generate_world_traits()
		get_node("/root/Main").load_scene("res://scenes/campaign/GameWorld.tscn")
	else:
		print("Not enough fuel to travel to the destination.")

func _on_back_pressed():
	get_node("/root/Main").load_scene("res://scenes/campaign/CampaignDashboard.tscn")

func emergency_takeoff():
	var damage = randi() % 6 + randi() % 6 + randi() % 6 + 3
	game_state.current_crew.ship.take_damage(damage, game_state)
	_show_emergency_damage_dialog(damage)

func _handle_travel_event(event: Dictionary):
	print("Travel event: " + event.name)
	print(event.description)
	var result = event.action.call()
	print(result)

func _show_emergency_takeoff_dialog() -> bool:
	print("WARNING: Emergency take-off will cause 3D6 Hull Point damage.")
	print("Do you wish to proceed? (y/n)")
	return true  # For demonstration; implement actual user input

func _show_insufficient_funds_dialog():
	print("Insufficient funds for travel. You need 5 credits.")

func _show_emergency_damage_dialog(damage: int):
	print("Emergency take-off caused " + str(damage) + " Hull Point damage.")

func flee_invasion():
	var roll = randi() % 6 + randi() % 6 + 2  # 2D6
	if roll >= 8:
		print("Successfully fled invasion!")
		_on_travel_pressed()
	else:
		print("Failed to escape! Prepare for battle.")
		get_node("/root/Main").load_scene("res://scenes/campaign/Battle.tscn")

func check_for_patrons_and_rivals():
	for patron in game_state.patrons:
		if randi() % 6 + 1 >= 5:
			patron.is_persistent = true
		else:
			game_state.remove_patron(patron)
	
	for rival in game_state.rivals:
		if randi() % 6 + 1 >= 5:
			rival.is_persistent = true
		else:
			game_state.remove_rival(rival)

func check_for_licensing_requirement():
	var roll = randi() % 6 + 1
	if roll >= 5:
		var license_cost = randi() % 6 + 1
		game_state.current_location.set_license_requirement(license_cost)
		print("This world requires a Freelancer License. Cost: " + str(license_cost) + " credits.")
	else:
		print("No license required on this world.")

func attempt_forged_license():
	var roll = randi() % 6 + 1 + game_state.current_crew.get_highest_skill_level("Savvy")
	if roll >= 6:
		print("Successfully obtained a forged license!")
		game_state.current_location.set_license_obtained()
	elif roll == 1:
		print("Attempt to forge license failed. Gained a new Rival.")
		var new_rival = RivalResource.new()
		new_rival.initialize("License Forger", game_state.current_location)
		game_state.add_rival(new_rival)
	else:
		print("Failed to obtain a forged license.")

func generate_world_traits():
	var world_traits = game_state.world_generator.generate_world_traits()
	for world_trait in world_traits:
		print("World trait: " + world_trait.name)
		print(world_trait.effect)
		game_state.current_location.add_trait(world_trait)

func start_phase():
	print("Travel phase started")
	$CompletePhaseButton.pressed.connect(_on_phase_completed)

func _on_phase_completed():
	var world_step = WorldStep.new(game_state)
	world_step.execute_world_step()
	emit_signal("phase_completed")

# Additional methods to handle travel-related actions

func handle_down_time():
	var crew_member = game_state.current_crew.characters[randi() % game_state.current_crew.get_size()]
	crew_member.add_xp(1)
	var repaired_item = game_state.current_crew.ship.inventory.repair_random_item()
	print(crew_member.name + " gained 1 XP. " + (repaired_item.name + " was repaired." if repaired_item else "No items were repaired."))

func handle_distress_call():
	var roll = randi() % 6 + 1
	match roll:
		1:
			var damage = randi() % 6 + 2
			game_state.current_crew.ship.take_damage(damage, game_state)
			print("Ship struck by debris wave, took " + str(damage) + " Hull Point damage.")
		2:
			print("Found only drifting wreckage.")
		3, 4:
			var new_crew = game_state.character_generator.generate_character()
			game_state.current_crew.add_character(new_crew)
			print("Rescued a crew member: " + new_crew.name)
		5, 6:
			if roll + game_state.current_crew.get_highest_skill_level("Savvy") >= 7:
				var loot = game_state.loot_generator.generate_loot()
				game_state.current_crew.ship.add_to_ship_stash(loot)
				print("Successfully saved the ship. Received " + loot.name + " as reward.")
			else:
				var damage = randi() % 6 + 2
				game_state.current_crew.ship.take_damage(damage, game_state)
				print("Failed to save the ship. Took " + str(damage) + " Hull Point damage.")

func handle_drive_trouble():
	var success_count = 0
	for i in range(3):
		var roll = randi() % 6 + 1 + game_state.current_crew.get_highest_skill_level("Savvy")
		if roll >= 6:
			success_count += 1
	if success_count == 3:
		print("Successfully fixed the drive trouble.")
	else:
		game_state.current_crew.ship.ground_for_turns(3 - success_count)
		print("Ship grounded for " + str(3 - success_count) + " turns due to drive trouble.")
