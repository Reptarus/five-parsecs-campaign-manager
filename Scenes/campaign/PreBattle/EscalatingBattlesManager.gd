class_name EscalatingBattlesManager
extends Node

var game_state: GameState

func _init(_game_state: GameState):
	game_state = _game_state

func check_escalation(battle_state: Dictionary) -> Dictionary:
	var escalation = {}
	if _should_escalate(battle_state):
		escalation = _generate_escalation(battle_state)
	return escalation

func _should_escalate(battle_state: Dictionary) -> bool:
	var escalation_chance = 20  # Base 20% chance
	
	# Increase chance based on crew composition
	escalation_chance += 5 if "Skulkers" in battle_state.crew_species else 0
	escalation_chance += 5 if "Krag" in battle_state.crew_species else 0
	
	# Increase chance if psionics are present
	escalation_chance += 10 if battle_state.has_psionics else 0
	
	# Decrease chance based on crew's equipment
	escalation_chance -= 5 if battle_state.has_advanced_bot_upgrades else 0
	
	# Roll for escalation
	return randi() % 100 < escalation_chance

func _generate_escalation(battle_state: Dictionary) -> Dictionary:
	var roll = randi() % 100 + 1
	var escalation = {}
	
	if roll <= 30:
		escalation = {"type": "reinforcements", "effect": "Enemy reinforcements arrive"}
	elif roll <= 50:
		escalation = {"type": "psionic_event", "effect": "Unexpected psionic phenomenon occurs"}
	elif roll <= 70:
		escalation = {"type": "equipment_malfunction", "effect": "Random crew equipment malfunctions"}
	elif roll <= 85:
		escalation = {"type": "environmental_hazard", "effect": "Sudden environmental change"}
	else:
		escalation = {"type": "alien_intervention", "effect": "Unexpected alien species intervenes"}
	
	# Modify effect based on battle state
	if "Skulkers" in battle_state.crew_species:
		escalation.effect += " (Skulkers provide advantage)"
	if battle_state.has_psionics:
		escalation.effect += " (Psionic effects intensified)"
	
	return escalation
