# GalacticWarManager.gd
class_name GalacticWarManager
extends Node

var game_state: GameState

func _init(_game_state: GameState) -> void:
	game_state = _game_state

func check_war_progress() -> void:
	for planet in game_state.invaded_planets:
		var roll: int = GameManager.roll_dice(2, 6)
		match roll:
			2, 3, 4:
				planet.status = GlobalEnums.FringeWorldInstability.CHAOS
				game_state.invaded_planets.erase(planet)
			5, 6, 7:
				planet.status = GlobalEnums.FringeWorldInstability.CONFLICT
			8, 9:
				planet.status = GlobalEnums.FringeWorldInstability.UNREST
				planet.unity_progress += 1
			10, 11, 12:
				planet.status = GlobalEnums.FringeWorldInstability.STABLE
				game_state.invaded_planets.erase(planet)
				planet.add_troop_presence()

func invade_planet(planet: Location) -> void:
	if not game_state.invaded_planets.has(planet):
		game_state.invaded_planets.append(planet)
		planet.status = GlobalEnums.FringeWorldInstability.CHAOS

func resolve_invasion(planet: Location) -> void:
	var roll: int = GameManager.roll_dice(2, 6)
	if roll >= 8:
		game_state.invaded_planets.erase(planet)
		planet.status = GlobalEnums.FringeWorldInstability.STABLE
	else:
		planet.status = GlobalEnums.FringeWorldInstability.CONFLICT

func get_invasion_status(planet: Location) -> GlobalEnums.FringeWorldInstability:
	return planet.status if planet.status else GlobalEnums.FringeWorldInstability.STABLE

func get_invaded_planets() -> Array[Location]:
	return game_state.invaded_planets

func process_galactic_war_turn() -> void:
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

func update_faction_influence(battle_outcome: GlobalEnums.BattleOutcome) -> void:
	var faction_influence_change: float = 0.1  # Base influence change
	if battle_outcome == GlobalEnums.BattleOutcome.VICTORY:
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

func trigger_galactic_war_event(event_type: String) -> void:
	match event_type:
		"player_advantage":
			# Implement player advantage event
			print("Player faction gains a significant advantage in the Galactic War!")
		"enemy_advantage":
			# Implement enemy advantage event
			print("Enemy faction gains a significant advantage in the Galactic War!")
		# Add more event types as needed

# This function can be called from PostBattlePhase
func post_battle_update(battle_outcome: GlobalEnums.BattleOutcome) -> void:
	update_faction_influence(battle_outcome)
	process_galactic_war_turn()
