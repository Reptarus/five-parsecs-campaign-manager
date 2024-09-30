class_name EscalatingBattlesManager
extends Resource

enum EscalationType {
	REINFORCEMENTS,
	PSIONIC_EVENT,
	EQUIPMENT_MALFUNCTION,
	ENVIRONMENTAL_HAZARD,
	ALIEN_INTERVENTION,
	CRITICAL_HIT,
	WEAPON_MALFUNCTION,
	MORALE_BOOST,
	MORALE_DROP,
	TACTICAL_ADVANTAGE,
	ENEMY_MISTAKE,
	UNEXPECTED_ALLY,
	HEROIC_MOMENT,
	LUCKY_DODGE,
	AMMO_SHORTAGE,
	COVER_DESTROYED,
	ENEMY_SURRENDER,
	FRIENDLY_FIRE,
	SNIPER_SHOT,
	MELEE_CLASH,
	GRENADE_THROW,
	MEDICAL_EMERGENCY
}

var game_state: GameState
var difficulty_settings: DifficultySettings

func _init(_game_state: GameState):
	game_state = _game_state

func initialize(_game_state: GameState, _difficulty_settings: DifficultySettings):
	game_state = _game_state
	difficulty_settings = _difficulty_settings

func apply_difficulty(_difficulty_settings: DifficultySettings):
	difficulty_settings = _difficulty_settings

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
	
	# Adjust based on difficulty settings
	escalation_chance += difficulty_settings.get_escalation_modifier()
	
	# Roll for escalation
	return randf() < (escalation_chance / 100.0)

func _generate_escalation(battle_state: Dictionary) -> Dictionary:
	var escalation_type = EscalationType.values()[randi() % EscalationType.size()]
	var escalation = {
		"type": escalation_type,
		"description": "",
		"effect": {}
	}
	
	match escalation_type:
		EscalationType.REINFORCEMENTS:
			escalation.description = "Enemy reinforcements arrive"
			escalation.effect = {"add_units": randi() % 3 + 1, "target": "enemy"}
		EscalationType.PSIONIC_EVENT:
			escalation.description = "Unexpected psionic phenomenon occurs"
			escalation.effect = {"psionic_boost": true, "target": "all"}
		EscalationType.EQUIPMENT_MALFUNCTION:
			escalation.description = "Random crew equipment malfunctions"
			escalation.effect = {"disable_item": true, "target": "player"}
		EscalationType.ENVIRONMENTAL_HAZARD:
			escalation.description = "Sudden environmental change"
			escalation.effect = {"damage": 1, "target": "all"}
		EscalationType.ALIEN_INTERVENTION:
			escalation.description = "Unexpected alien species intervenes"
			escalation.effect = {"add_units": 1, "target": "random"}
		# Add cases for other escalation types...
	
	# Modify effect based on battle state
	if "Skulkers" in battle_state.crew_species:
		escalation.description += " (Skulkers provide advantage)"
		escalation.effect["skulker_bonus"] = true
	if battle_state.has_psionics:
		escalation.description += " (Psionic effects intensified)"
		escalation.effect["psionic_intensity"] = 2
	
	return escalation

func apply_escalation(escalation: Dictionary, player_team: Array, enemy_team: Array) -> void:
	match escalation.effect.target:
		"player":
			_apply_to_team(escalation.effect, player_team)
		"enemy":
			_apply_to_team(escalation.effect, enemy_team)
		"all":
			_apply_to_team(escalation.effect, player_team)
			_apply_to_team(escalation.effect, enemy_team)
		"random":
			if randf() > 0.5:
				_apply_to_team(escalation.effect, player_team)
			else:
				_apply_to_team(escalation.effect, enemy_team)

func _apply_to_team(effect: Dictionary, team: Array) -> void:
	if "add_units" in effect:
		for i in range(effect.add_units):
			team.append(game_state.character_generator.generate_character())
	if "disable_item" in effect:
		var random_unit = team[randi() % team.size()]
		random_unit.disable_random_item()
	if "damage" in effect:
		for unit in team:
			unit.take_damage(effect.damage)
	# Add more effect applications as needed...

