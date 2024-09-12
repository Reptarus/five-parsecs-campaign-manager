# Travel.gd
extends Control

const RivalResource = preload("res://Resources/Rival.gd")

var game_state: GameState
var starship_travel_events: StarshipTravelEvents

func _init(_game_state: GameState):
	game_state = _game_state
	starship_travel_events = StarshipTravelEvents.new(game_state)

func _ready():
	$MarginContainer/VBoxContainer/StayButton.connect("pressed", Callable(self, "_on_stay_pressed"))
	$MarginContainer/VBoxContainer/TravelButton.connect("pressed", Callable(self, "_on_travel_pressed"))
	$MarginContainer/VBoxContainer/BackButton.connect("pressed", Callable(self, "_on_back_pressed"))

func _on_stay_pressed():
	get_node("/root/Main").load_scene("res://scenes/campaign/World.tscn")

func _on_travel_pressed():
	if game_state.current_crew.ship.hull_damage > 0:
		var choice = _show_emergency_takeoff_dialog()
		if choice:
			emergency_takeoff()
		else:
			return

	if not game_state.remove_credits(5):  # Travel cost
		_show_insufficient_funds_dialog()
		return

	var event = starship_travel_events.generate_travel_event()
	_handle_travel_event(event)
	game_state.generate_new_world()
	get_node("/root/Main").load_scene("res://scenes/campaign/World.tscn")

func _on_back_pressed():
	get_node("/root/Main").load_scene("res://scenes/campaign/CampaignDashboard.tscn")

func emergency_takeoff():
	var damage = randi() % 6 + randi() % 6 + randi() % 6 + 3
	game_state.current_crew.ship.take_damage(damage)
	_show_emergency_damage_dialog(damage)

func _handle_travel_event(event: Dictionary):
	print("Travel event: " + event.name)
	print(event.description)
	var result = event.action.call()
	print(result)

func _show_emergency_takeoff_dialog() -> bool:
	print("WARNING: Emergency take-off will cause 3D6 Hull Point damage.")
	print("Do you wish to proceed? (y/n)")
	return true

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
		game_state.current_world.set_license_requirement(license_cost)
		print("This world requires a Freelancer License. Cost: " + str(license_cost) + " credits.")
	else:
		print("No license required on this world.")

func attempt_forged_license():
	var roll = randi() % 6 + 1 + game_state.current_crew.get_best_savvy()
	if roll >= 6:
		print("Successfully obtained a forged license!")
		game_state.current_world.set_license_obtained()
	elif roll == 1:
		print("Attempt to forge license failed. Gained a new Rival.")
		var new_rival = Rival.new("License Forger", game_state.current_location)  # Create a new Rival instance
		game_state.add_rival(new_rival)  # Pass the new Rival instance to add_rival()
	else:
		print("Failed to obtain a forged license.")

func generate_world_traits():
	var world_traits = game_state.world_generator.generate_world_traits()
	for world_trait in world_traits:
		print("World trait: " + world_trait.name)
		print(world_trait.effect)
		game_state.current_world.add_trait(world_trait)
