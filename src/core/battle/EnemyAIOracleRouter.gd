class_name FPCM_EnemyAIOracleRouter
extends Resource

## Enemy AI Oracle Router - Three Companion Modes for Enemy Behavior
##
## Tells the player what to make the enemies do on the physical table.
## Tier 3 (FULL_ORACLE) only. Three modes, all companion-oriented.
##
## MODE_REFERENCE: Shows rules text for the enemy's AI type from EnemyAI.json
## MODE_D6_TABLE: Player rolls d6 per enemy group, lookup on AI behavior table
## MODE_CARD_ORACLE: Draw card from CardOracleSystem, interpret by suit/rank
##
## All output is instruction text for the player to execute on the table.

signal enemy_instruction_determined(enemy_group: String, instruction: String)
signal oracle_mode_changed(new_mode: int)

enum OracleMode {
	MODE_REFERENCE = 0,  ## Show AI type rules text (player decides)
	MODE_D6_TABLE = 1,   ## Roll d6, lookup on behavior table
	MODE_CARD_ORACLE = 2 ## Draw card, interpret by suit/rank
}

const MODE_NAMES: Dictionary = {
	OracleMode.MODE_REFERENCE: "Reference",
	OracleMode.MODE_D6_TABLE: "D6 Table",
	OracleMode.MODE_CARD_ORACLE: "Card Oracle",
}

const MODE_DESCRIPTIONS: Dictionary = {
	OracleMode.MODE_REFERENCE: "Show the AI type rules. You read and decide what each enemy does.",
	OracleMode.MODE_D6_TABLE: "Roll d6 per enemy group and look up their action on the behavior table.",
	OracleMode.MODE_CARD_ORACLE: "Draw a card from the oracle deck. Suit = behavior, rank = intensity.",
}

var current_mode: int = OracleMode.MODE_REFERENCE
var card_oracle: FPCM_CardOracleSystem = null
var _ai_data: Dictionary = {}  # Parsed from EnemyAI.json
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.seed = Time.get_unix_time_from_system()
	card_oracle = FPCM_CardOracleSystem.new()
	_load_ai_data()

func _load_ai_data() -> void:
	var file := FileAccess.open("res://data/RulesReference/EnemyAI.json", FileAccess.READ)
	if not file:
		push_warning("EnemyAIOracleRouter: Could not load EnemyAI.json")
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err == OK and json.data is Dictionary:
		_ai_data = json.data

## Set the oracle mode.
func set_mode(mode: int) -> void:
	if mode < OracleMode.MODE_REFERENCE or mode > OracleMode.MODE_CARD_ORACLE:
		return
	current_mode = mode
	oracle_mode_changed.emit(mode)

## Get the current mode name.
func get_mode_name() -> String:
	return MODE_NAMES.get(current_mode, "Unknown")

## Get instruction for an enemy group based on current mode.
## ai_type: "Aggressive", "Cautious", "Tactical", etc.
## group_name: Display name for the enemy group.
## roll_result: Player-provided d6 result (-1 = auto-roll, for MODE_D6_TABLE).
func get_instruction(ai_type: String, group_name: String = "Enemy Group", roll_result: int = -1) -> Dictionary:
	var result: Dictionary = {
		"group": group_name,
		"ai_type": ai_type,
		"mode": current_mode,
		"instruction": "",
		"roll": -1,
		"card": {},
	}

	match current_mode:
		OracleMode.MODE_REFERENCE:
			result.instruction = _get_reference_text(ai_type)
		OracleMode.MODE_D6_TABLE:
			var roll: int = roll_result if roll_result >= 1 else _rng.randi_range(1, 6)
			result.roll = roll
			result.instruction = _get_d6_table_result(ai_type, roll)
		OracleMode.MODE_CARD_ORACLE:
			var card: Dictionary = card_oracle.draw_card()
			result.card = card
			result.instruction = card_oracle.interpret_card(card, ai_type)

	enemy_instruction_determined.emit(group_name, result.instruction)
	return result

## MODE_REFERENCE: Get the full rules text for an AI type.
func _get_reference_text(ai_type: String) -> String:
	var type_data: Dictionary = _find_ai_type(ai_type)
	if type_data.is_empty():
		return "Unknown AI type: %s. Use common sense for enemy behavior." % ai_type

	var text: String = "%s AI\n" % type_data.get("name", ai_type)
	text += "%s\n\n" % type_data.get("description", "")
	text += "Base Condition: %s" % type_data.get("base_condition", "None")

	if type_data.has("note"):
		text += "\n\nNote: %s" % type_data.note

	if type_data.has("behavior_table"):
		text += "\n\nBehavior Table (roll d6):"
		for entry: Dictionary in type_data.behavior_table:
			text += "\n  %s: %s" % [entry.get("roll", "?"), entry.get("action", "")]

	return text

## MODE_D6_TABLE: Look up action from behavior table.
func _get_d6_table_result(ai_type: String, roll: int) -> String:
	var type_data: Dictionary = _find_ai_type(ai_type)
	if type_data.is_empty():
		return "Unknown AI type: %s. Roll: %d." % [ai_type, roll]

	# Types without behavior tables always follow base condition
	if not type_data.has("behavior_table"):
		return "%s (no behavior table): %s" % [
			type_data.get("name", ai_type),
			type_data.get("base_condition", "Act according to type.")]

	# Check base condition first (as per AI Decision Making rules)
	var base: String = type_data.get("base_condition", "")
	var header: String = "%s AI - Rolled %d\n" % [type_data.get("name", ai_type), roll]
	header += "Base Condition: %s\n\n" % base

	# Lookup behavior table
	var table: Array = type_data.behavior_table
	var clamped_roll: int = clampi(roll, 1, 6)
	var action: String = "Act according to type."

	for entry: Dictionary in table:
		var entry_roll: String = entry.get("roll", "")
		if entry_roll == str(clamped_roll):
			action = entry.get("action", action)
			break

	return header + "Action: %s" % action

## Find AI type data from loaded JSON.
func _find_ai_type(ai_type: String) -> Dictionary:
	var enemy_ai: Dictionary = _ai_data.get("EnemyAI", {})
	var content: Array = enemy_ai.get("content", [])

	for section: Dictionary in content:
		if section.get("title", "") == "AI Types":
			var types: Array = section.get("types", [])
			for type_entry: Dictionary in types:
				if type_entry.get("name", "").to_lower() == ai_type.to_lower():
					return type_entry

	return {}

## Get all available AI type names.
func get_ai_types() -> Array[String]:
	var types: Array[String] = []
	var enemy_ai: Dictionary = _ai_data.get("EnemyAI", {})
	var content: Array = enemy_ai.get("content", [])

	for section: Dictionary in content:
		if section.get("title", "") == "AI Types":
			for type_entry: Dictionary in section.get("types", []):
				types.append(type_entry.get("name", "Unknown"))

	return types

## Get AI decision making steps (for reference display).
func get_decision_steps() -> Array:
	var enemy_ai: Dictionary = _ai_data.get("EnemyAI", {})
	var content: Array = enemy_ai.get("content", [])

	for section: Dictionary in content:
		if section.get("title", "") == "AI Decision Making":
			return section.get("steps", [])

	return []

## Get targeting priority rules.
func get_targeting_priority() -> Array:
	var enemy_ai: Dictionary = _ai_data.get("EnemyAI", {})
	var content: Array = enemy_ai.get("content", [])

	for section: Dictionary in content:
		if section.get("title", "") == "AI Targeting Priority":
			return section.get("priorities", [])

	return []

## Serialize for save/load.
func serialize() -> Dictionary:
	return {
		"current_mode": current_mode,
		"card_oracle": card_oracle.serialize() if card_oracle else {},
	}

## Deserialize from save data.
func deserialize(data: Dictionary) -> void:
	current_mode = data.get("current_mode", OracleMode.MODE_REFERENCE)
	if card_oracle and data.has("card_oracle"):
		card_oracle.deserialize(data.card_oracle)
