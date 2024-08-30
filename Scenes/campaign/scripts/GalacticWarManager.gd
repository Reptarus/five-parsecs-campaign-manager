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
