# GalacticWarManager.gd
extends Node

enum FringeWorldInstability {
	STABLE,
	UNREST,
	CONFLICT,
	REBELLION,
	CIVIL_WAR
}

enum BattleOutcome {
	VICTORY,
	DEFEAT,
	DRAW
}

signal war_status_changed(new_status: int)
signal war_ended(victor: String)

var current_instability: FringeWorldInstability = FringeWorldInstability.STABLE
var game_state: Node # Will be cast to GameState at runtime
var active_conflicts: Array[Dictionary] = []
var faction_strengths: Dictionary = {}

func _ready() -> void:
	game_state = get_node("/root/GameStateManager")
	if not game_state:
		push_error("GameStateManager instance not found")
		queue_free()
		return
	
	initialize_faction_strengths()
	connect_signals()

func initialize_faction_strengths() -> void:
	faction_strengths = {
		"rebels": 50,
		"empire": 50,
		"pirates": 30,
		"merchants": 20
	}

func connect_signals() -> void:
	if game_state:
		game_state.connect("battle_ended", _on_battle_ended)
		game_state.connect("turn_ended", _on_turn_ended)

func update_instability() -> void:
	var previous_instability = current_instability
	
	# Calculate new instability based on faction strengths
	var total_conflict_points = 0
	for strength in faction_strengths.values():
		if strength > 60: # High strength factions generate more conflict
			total_conflict_points += 2
		elif strength < 30: # Weak factions also contribute to instability
			total_conflict_points += 1
	
	# Update instability level based on conflict points
	current_instability = calculate_instability_level(total_conflict_points)
	
	if current_instability != previous_instability:
		war_status_changed.emit(current_instability)
		handle_instability_effects()

func calculate_instability_level(conflict_points: int) -> int:
	if conflict_points <= 1:
		return FringeWorldInstability.STABLE
	elif conflict_points <= 3:
		return FringeWorldInstability.UNREST
	elif conflict_points <= 5:
		return FringeWorldInstability.CONFLICT
	elif conflict_points <= 7:
		return FringeWorldInstability.REBELLION
	else:
		return FringeWorldInstability.CIVIL_WAR

func handle_instability_effects() -> void:
	match current_instability:
		FringeWorldInstability.STABLE:
			_handle_stable_effects()
		FringeWorldInstability.UNREST:
			_handle_unrest_effects()
		FringeWorldInstability.CONFLICT:
			_handle_conflict_effects()
		FringeWorldInstability.REBELLION:
			_handle_rebellion_effects()
		FringeWorldInstability.CIVIL_WAR:
			_handle_civil_war_effects()

func _handle_stable_effects() -> void:
	# Implement stable world effects
	pass

func _handle_unrest_effects() -> void:
	# Implement unrest effects
	pass

func _handle_conflict_effects() -> void:
	# Implement conflict effects
	pass

func _handle_rebellion_effects() -> void:
	# Implement rebellion effects
	pass

func _handle_civil_war_effects() -> void:
	# Implement civil war effects
	pass

func update_faction_strength(faction: String, change: int) -> void:
	if faction in faction_strengths:
		faction_strengths[faction] = clamp(faction_strengths[faction] + change, 0, 100)
		update_instability()

func resolve_conflict(location: String, involved_factions: Array) -> void:
	var battle_result = generate_battle_result(involved_factions)
	apply_battle_results(battle_result, involved_factions)
	check_war_end_conditions()

func generate_battle_result(involved_factions: Array) -> Dictionary:
	var result = {
		"victor": "",
		"outcome": BattleOutcome.DRAW,
		"casualties": {}
	}
	
	# Calculate battle outcome based on faction strengths
	var highest_strength = 0
	for faction in involved_factions:
		var strength = faction_strengths.get(faction, 0)
		if strength > highest_strength:
			highest_strength = strength
			result.victor = faction
			result.outcome = BattleOutcome.VICTORY
	
	return result

func apply_battle_results(result: Dictionary, involved_factions: Array) -> void:
	if result.outcome == BattleOutcome.VICTORY:
		# Strengthen victor, weaken others
		update_faction_strength(result.victor, 5)
		for faction in involved_factions:
			if faction != result.victor:
				update_faction_strength(faction, -3)

func check_war_end_conditions() -> void:
	for faction in faction_strengths:
		if faction_strengths[faction] >= 80:
			war_ended.emit(faction)
			break

func _on_battle_ended(battle_data: Dictionary) -> void:
	if battle_data.has("faction_impacts"):
		for faction in battle_data.faction_impacts:
			update_faction_strength(faction, battle_data.faction_impacts[faction])

func _on_turn_ended() -> void:
	update_instability()
	process_active_conflicts()

func process_active_conflicts() -> void:
	var resolved_conflicts = []
	for conflict in active_conflicts:
		if should_resolve_conflict(conflict):
			resolve_conflict(conflict.location, conflict.factions)
			resolved_conflicts.append(conflict)
	
	# Remove resolved conflicts
	for conflict in resolved_conflicts:
		active_conflicts.erase(conflict)

func should_resolve_conflict(conflict: Dictionary) -> bool:
	# Add logic to determine if a conflict should be resolved this turn
	return randf() > 0.5 # 50% chance to resolve each turn

func get_current_instability() -> int:
	return current_instability

func get_faction_strength(faction: String) -> int:
	return faction_strengths.get(faction, 0)

func add_active_conflict(location: String, factions: Array) -> void:
	active_conflicts.append({
		"location": location,
		"factions": factions,
		"duration": 0
	})
	update_instability()
