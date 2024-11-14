# GalacticWarManager.gd
class_name GalacticWarManager
extends Node

signal faction_action_resolved(faction_name: String, success: bool)
signal faction_defeated(faction_name: String)
signal faction_strength_increased(faction_name: String, new_strength: int)

class Faction:
	var name: String
	var strength: int
	var power: int
	var actions: int
	var influence: float = 0.0

	func _init(p_name: String, p_strength: int, p_power: int):
		name = p_name
		strength = p_strength
		power = p_power
		actions = 2 if p_strength <= 5 else 3

var factions: Array[Faction] = []
var game_state: GameState

func _init(_game_state: GameState) -> void:
	if not _game_state:
		push_error("GameState is required for GalacticWarManager")
		return
	game_state = _game_state
	initialize_factions()

func _ready() -> void:
	randomize()
	game_state.connect("new_turn_started", Callable(self, "_on_new_campaign_turn"))

# Faction Management
func create_faction(faction_name: String, faction_strength: int = 0, faction_power: int = 0) -> Faction:
	var final_strength = faction_strength if faction_strength > 0 else (randi() % 6 + 2)
	var final_power = faction_power if faction_power > 0 else (randi() % 3 + 3)
	
	var faction = Faction.new(faction_name, final_strength, final_power)
	factions.append(faction)
	return faction

func resolve_faction_actions() -> void:
	for faction in factions:
		for i in range(faction.actions):
			var success = randi() % 6 + 1 >= faction.power
			faction_action_resolved.emit(faction.name, success)
			if success:
				game_state.fringe_world_strife_manager.update_world_strife(game_state.current_location)

# Invasion Management
func check_war_progress() -> void:
	for planet in game_state.invaded_planets:
		var roll: int = GameManager.roll_dice(2, 6)
		match roll:
			2, 3, 4:
				planet.status = GlobalEnums.FringeWorldInstability.CRISIS
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
		planet.status = GlobalEnums.FringeWorldInstability.CRISIS

func resolve_invasion(planet: Location) -> void:
	var roll: int = GameManager.roll_dice(2, 6)
	if roll >= 8:
		game_state.invaded_planets.erase(planet)
		planet.status = GlobalEnums.FringeWorldInstability.STABLE
	else:
		planet.status = GlobalEnums.FringeWorldInstability.CONFLICT

# Main Process Functions
func process_galactic_war_turn() -> void:
	check_war_progress()
	resolve_faction_actions()
	if factions.size() >= 2:
		var attacker = factions[0]
		var defender = factions[1]
		var attack_roll = GameManager.roll_dice(2, 6) + attacker.strength
		var defense_roll = GameManager.roll_dice(2, 6) + defender.strength
		
		if attack_roll > defense_roll:
			defender.strength -= 1
			faction_action_resolved.emit(attacker.name, true)
		else:
			attacker.strength -= 1
			faction_action_resolved.emit(defender.name, true)
	
	for faction in factions:
		if randf() < 0.3:
			faction.strength += 1
			faction_action_resolved.emit(faction.name, true)
	
	# Check for new invasions
	for planet in game_state.planets:
		if randf() < 0.1:
			invade_planet(planet)
	
	# Resolve ongoing invasions
	for planet in game_state.invaded_planets.duplicate():
		resolve_invasion(planet)

func update_faction_influence(battle_outcome: GlobalEnums.BattleOutcome) -> void:
	var faction_influence_change: float = 0.1
	if battle_outcome == GlobalEnums.BattleOutcome.VICTORY:
		game_state.player_faction.influence += faction_influence_change
		game_state.enemy_faction.influence -= faction_influence_change
	else:
		game_state.player_faction.influence -= faction_influence_change
		game_state.enemy_faction.influence += faction_influence_change

func _on_new_campaign_turn() -> void:
	process_galactic_war_turn()

func initialize_factions() -> void:
	create_faction("Galactic Empire")
	create_faction("Rebel Alliance")
	create_faction("Trade Federation")
