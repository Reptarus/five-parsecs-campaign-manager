class_name EscalatingBattlesManager
extends Resource

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")

var game_state: Node
var difficulty_settings: Resource

func _init(_game_state: Node) -> void:
	game_state = _game_state

func initialize(_game_state: Node, _difficulty_settings: Resource) -> void:
	game_state = _game_state
	difficulty_settings = _difficulty_settings

func apply_difficulty(_difficulty_settings: Resource):
	difficulty_settings = _difficulty_settings

func check_escalation(battle_state: Dictionary) -> Dictionary:
	var escalation = {}
	if _should_escalate(battle_state):
		escalation = _generate_escalation(battle_state.strife_type)
	return escalation

func _should_escalate(battle_state: Dictionary) -> bool:
	var escalation_chance = 20  # Base 20% chance
	
	# Increase chance based on crew composition
	escalation_chance += 5 if GameEnums.Origin.FERAL in battle_state.crew_species else 0
	escalation_chance += 5 if GameEnums.Origin.SOULLESS in battle_state.crew_species else 0
	
	# Increase chance if psionics are present
	escalation_chance += 10 if battle_state.has_psionics else 0
	
	# Decrease chance based on crew's equipment
	escalation_chance -= 5 if battle_state.has_advanced_bot_upgrades else 0
	
	# Adjust based on difficulty settings
	escalation_chance += difficulty_settings.get_escalation_modifier()
	
	# Roll for escalation
	return randf() < (escalation_chance / 100.0)

func _generate_escalation(strife_type: int) -> Dictionary:
	var escalation := {}
	
	match strife_type:
		GameEnums.StrifeType.RESOURCE_CONFLICT:
			escalation.description = "Enemy reinforcements arrive"
			escalation.effect = {"add_units": randi_range(1, 3), "target": "enemy"}
		GameEnums.StrifeType.POLITICAL_UNREST:
			escalation.description = "Unexpected psionic phenomenon occurs"
			escalation.effect = {"psionic_boost": true, "target": "all"}
			escalation.effect["psionic_intensity"] = 2
		GameEnums.StrifeType.CRIMINAL_UPRISING:
			escalation.description = "Sudden environmental change"
			escalation.effect = {"damage": 1, "target": "all"}
		GameEnums.StrifeType.CORPORATE_WAR:
			escalation.description = "Random crew equipment malfunctions"
			escalation.effect = {"disable_item": true, "target": "player"}
	
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
			if unit.species == GameEnums.Origin.FERAL:
				unit.apply_mutant_bonus()

func generate_suspect(pursuit: bool) -> Dictionary:
	var suspect = {}
	var roll = randi() % 6 + 1
	
	match roll:
		1:
			suspect.type = "civilian"
			suspect.armed = false
		2, 3:
			suspect.type = "criminal"
			suspect.armed = true
		4, 5:
			suspect.type = "gang_member"
			suspect.armed = true
		6:
			if pursuit:
				suspect.type = "elite"
				suspect.armed = true
			else:
				suspect.type = "gang_member"
				suspect.armed = true
	
	return suspect

func handle_evasion(crew_member: Node, enemies_in_sight: Array) -> int:
	if enemies_in_sight.is_empty():
		var roll = randi() % 6 + 1
		return maxi(0, roll + crew_member.savvy - 4)
	return 0

