extends Resource

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

var game_state: Node
var difficulty_settings: Resource

func _init(_game_state: Node) -> void:
	game_state = _game_state
func initialize(_game_state: Node, _difficulty_settings: Resource) -> void:
	game_state = _game_state
	difficulty_settings = _difficulty_settings
func apply_difficulty(_difficulty_settings: Resource) -> void:
	difficulty_settings = _difficulty_settings
func check_escalation(battle_state: Dictionary) -> Dictionary:
	var escalation: Dictionary = {}
	if _should_escalate(battle_state):
		escalation = _generate_escalation(battle_state.strife_type)
	return escalation

func _should_escalate(battle_state: Dictionary) -> bool:
	var escalation_chance: int = 20 # Base 20% chance

	# Increase chance based on crew composition
	escalation_chance += 5 if GlobalEnums.Origin.FERAL in battle_state.crew_species else 0
	escalation_chance += 5 if GlobalEnums.Origin.SOULLESS in battle_state.crew_species else 0

	# Increase chance if psionics are present
	escalation_chance += 10 if battle_state.has_psionics else 0

	# Decrease chance based on crew's equipment
	escalation_chance -= 5 if battle_state.has_advanced_bot_upgrades else 0

	# Adjust based on difficulty settings
	escalation_chance += difficulty_settings.get_escalation_modifier()

	# Roll for escalation
	return randf() < (escalation_chance / 100.0)

func _generate_escalation(strife_type: GlobalEnums.StrifeType) -> Dictionary:
	var escalation := {}

	match strife_type:
		GlobalEnums.StrifeType.NONE:
			escalation.description = "Minor complications arise"
			escalation.effect = {"damage": 1, "target": "random"}
		GlobalEnums.StrifeType.LOW:
			escalation.description = "Situation intensifies"
			escalation.effect = {
				"add_units": 1,
				"target": "enemy"
			}
		GlobalEnums.StrifeType.MEDIUM:
			escalation.description = "Significant complications"
			escalation.effect = {
				"add_units": 2,
				"environmental_hazard": true,
				"target": "all"
			}
		GlobalEnums.StrifeType.HIGH:
			escalation.description = "Elite enemy reinforcements"
			escalation.effect = {
				"add_elite": true,
				"target": "enemy"
			}
		GlobalEnums.StrifeType.CRITICAL:
			escalation.description = "Multiple threats emerge"
			escalation.effect = {
				"add_units": 2,
				"add_elite": true,
				"environmental_hazard": true,
				"target": "all"
			}
		GlobalEnums.StrifeType.UNREST:
			escalation.description = "Unexpected psionic phenomenon"
			escalation.effect = {
				"psionic_boost": true,
				"psionic_intensity": 2,
				"target": "all"
			}
		GlobalEnums.StrifeType.CIVIL_WAR:
			escalation.description = "Sudden environmental change"
			escalation.effect = {
				"damage": 1,
				"environmental_hazard": true,
				"target": "all"
			}
		GlobalEnums.StrifeType.INVASION:
			escalation.description = "Advanced enemy tactics"
			escalation.effect = {
				"disable_item": true,
				"add_elite": true,
				"target": "player"
			}

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
		for i: int in range(effect.add_units):
			var new_enemy: FPCM_CrewMember = game_state.character_generator.generate_enemy()

			team.append(new_enemy)

	if "add_elite" in effect:
		var elite_enemy: FPCM_CrewMember = game_state.character_generator.generate_elite_enemy()

		team.append(elite_enemy)

	if "disable_item" in effect:
		var random_unit = team[randi() % team.size()]
		random_unit.disable_random_item()

	if "damage" in effect:
		for unit: Variant in team:
			unit.take_damage(effect.damage)

	if "psionic_boost" in effect:
		for unit: Variant in team:
			if unit.has_psionic_powers():
				unit.boost_psionic_power(effect.get("psionic_intensity", 1))

	if "environmental_hazard" in effect:
		for unit: Variant in team:
			if not unit.has_trait("Environmental Protection"):
				unit.apply_status_effect("Hazard", 2)

	if "mutant_bonus" in effect:
		for unit: Variant in team:
			if unit.species == GlobalEnums.Origin.FERAL:
				unit.apply_mutant_bonus()

func generate_suspect(pursuit: bool) -> Dictionary:
	var suspect: Dictionary = {}
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

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null