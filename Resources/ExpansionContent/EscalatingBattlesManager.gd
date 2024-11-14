class_name EscalatingBattlesManager
extends Resource

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
	escalation_chance += 5 if GlobalEnums.Origin.MUTANT in battle_state.crew_species else 0
	escalation_chance += 5 if GlobalEnums.Origin.HYBRID in battle_state.crew_species else 0
	
	# Increase chance if psionics are present
	escalation_chance += 10 if battle_state.has_psionics else 0
	
	# Decrease chance based on crew's equipment
	escalation_chance -= 5 if battle_state.has_advanced_bot_upgrades else 0
	
	# Adjust based on difficulty settings
	escalation_chance += difficulty_settings.get_escalation_modifier()
	
	# Roll for escalation
	return randf() < (escalation_chance / 100.0)

func _generate_escalation(battle_state: Dictionary) -> Dictionary:
	var escalation_type = GlobalEnums.StrifeType.values()[randi() % GlobalEnums.StrifeType.size()]
	var escalation = {
		"type": escalation_type,
		"description": "",
		"effect": {}
	}
	
	match escalation_type:
		GlobalEnums.StrifeType.RESOURCE_CONFLICT:
			escalation.description = "Enemy reinforcements arrive"
			escalation.effect = {"add_units": randi_range(1, 3), "target": "enemy"}
		GlobalEnums.StrifeType.POLITICAL_UNREST:
			escalation.description = "Unexpected psionic phenomenon occurs"
			escalation.effect = {"psionic_boost": true, "target": "all"}
			escalation.effect["psionic_intensity"] = 2
		GlobalEnums.StrifeType.CRIMINAL_WARFARE:
			escalation.description = "Sudden environmental change"
			escalation.effect = {"damage": 1, "target": "all"}
		GlobalEnums.StrifeType.CORPORATE_RIVALRY:
			escalation.description = "Random crew equipment malfunctions"
			escalation.effect = {"disable_item": true, "target": "player"}
	
	# Modify effect based on battle state
	if GlobalEnums.Origin.MUTANT in battle_state.crew_species:
		escalation.description += " (Mutants provide advantage)"
		escalation.effect["mutant_bonus"] = true
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
			var new_enemy = game_state.character_generator.generate_enemy()
			team.append(new_enemy)
	if "disable_item" in effect:
		var random_unit = team[randi() % team.size()]
		random_unit.disable_random_item()
	if "damage" in effect:
		for unit in team:
			unit.take_damage(effect.damage)
	if "psionic_boost" in effect:
		for unit in team:
			if unit.has_psionic_powers():
				unit.boost_psionic_power()
	if "mutant_bonus" in effect:
		for unit in team:
			if unit.species == GlobalEnums.Origin.MUTANT:
				unit.apply_mutant_bonus()

func generate_suspect(pursuit: bool) -> Dictionary:
	var suspect = {}
	var roll = GameManager.roll_dice(1, 6)
	
	match roll:
		1:
			suspect = {"type": "Nothing interesting", "action": "Remove the marker"}
		2:
			if pursuit:
				suspect = {"type": "Enemy", "action": "Replace with enemy figure"}
			else:
				suspect = {"type": "Nothing interesting", "action": "Remove the marker"}
		3, 4, 5:
			suspect = {"type": "Enemy", "action": "Replace with enemy figure"}
		6:
			suspect = {"type": "Ambush", "action": "Replace with enemy figure and place second enemy"}
	
	return suspect

func handle_evasion(crew_member: Character, enemies_in_sight: Array) -> int:
	if enemies_in_sight.is_empty():
		var roll = GameManager.roll_dice(1, 6) + crew_member.savvy
		return max(0, roll - 4)
	return 0

