extends Resource

# GlobalEnums available as autoload singleton

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
		GlobalEnums.StrifeType.TENSIONS:
			escalation.description = "Situation intensifies"
			escalation.effect = {
				"add_units": 1,
				"target": "enemy"
			}
		GlobalEnums.StrifeType.UNREST:
			escalation.description = "Significant complications"
			escalation.effect = {
				"add_units": 2,
				"damage": 2,
				"target": "enemy"
			}
		GlobalEnums.StrifeType.CONFLICT:
			escalation.description = "Major escalation"
			escalation.effect = {
				"add_units": 3,
				"damage": 3,
				"environmental_hazard": true,
				"target": "all"
			}
		GlobalEnums.StrifeType.WAR:
			escalation.description = "Critical situation"
			escalation.effect = {
				"add_units": 4,
				"damage": 4,
				"environmental_hazard": true,
				"target": "all"
			}

	return escalation

func apply_escalation_effects(escalation: Dictionary, crew_members: Array[Character]) -> void:
	# Apply escalation effects to crew members
	for crew_member in crew_members:
		if escalation.effect.has("damage"):
			crew_member.take_damage(escalation.effect.damage)
		if escalation.effect.has("psionic_boost"):
			crew_member.add_psionic_boost(escalation.effect.psionic_intensity)

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