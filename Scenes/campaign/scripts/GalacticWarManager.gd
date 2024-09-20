# GalacticWarManager.gd
extends Node

var game_state: GameState

func _init(_game_state: GameState):
	game_state = _game_state

func check_war_progress():
	for planet in game_state.invaded_planets:
		var roll = randi() % 6 + randi() % 6 + 2  # 2d6
		match roll:
			2, 3, 4:
				planet.status = "Lost to Unity"
				game_state.invaded_planets.erase(planet)
			5, 6, 7:
				planet.status = "Contested"
			8, 9:
				planet.status = "Making Ground"
				planet.unity_progress += 1
			10, 11, 12:
				planet.status = "Unity Victorious"
				game_state.invaded_planets.erase(planet)
				planet.add_troop_presence()

func invade_planet(planet: Location):
	if not game_state.invaded_planets.has(planet):
		game_state.invaded_planets.append(planet)
		planet.status = "Invaded"

func resolve_invasion(planet: Location):
	var roll = randi() % 6 + randi() % 6 + 2  # 2d6
	if roll >= 8:
		game_state.invaded_planets.erase(planet)
		planet.status = "Liberated"
	else:
		planet.status = "Invasion Continues"

func get_invasion_status(planet: Location) -> String:
	return planet.status if planet.status else "Not Invaded"

func get_invaded_planets() -> Array:
	return game_state.invaded_planets

func process_galactic_war_turn():
	check_war_progress()
	
	# Process faction actions and conflicts
	for faction in game_state.factions:
		faction.process_actions()
	
	# Check for new invasions
	for planet in game_state.planets:
		if randf() < 0.1:  # 10% chance of invasion per planet
			invade_planet(planet)
	
	# Resolve ongoing invasions
	for planet in game_state.invaded_planets.duplicate():  # Duplicate to avoid modifying while iterating
		resolve_invasion(planet)

func update_faction_influence(battle_outcome: String):
	var faction_influence_change = 0.1  # Base influence change
	if battle_outcome == "victory":
		game_state.player_faction.influence += faction_influence_change
		game_state.enemy_faction.influence -= faction_influence_change
	else:
		game_state.player_faction.influence -= faction_influence_change
		game_state.enemy_faction.influence += faction_influence_change
	
	# Check for major events
	if game_state.player_faction.influence >= 0.75:
		trigger_galactic_war_event("player_advantage")
	elif game_state.enemy_faction.influence >= 0.75:
		trigger_galactic_war_event("enemy_advantage")

func trigger_galactic_war_event(event_type: String):
	match event_type:
		"player_advantage":
			# Implement player advantage event
			print("Player faction gains a significant advantage in the Galactic War!")
		"enemy_advantage":
			# Implement enemy advantage event
			print("Enemy faction gains a significant advantage in the Galactic War!")
		# Add more event types as needed

# This function can be called from PostBattlePhase
func post_battle_update(battle_outcome: String):
	update_faction_influence(battle_outcome)
	process_galactic_war_turn()
