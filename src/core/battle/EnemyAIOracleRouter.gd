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

## Compendium pp.42-43 AI Variations. The core AI (this file's own data) is
## DICELESS; the dice tables belong to that DLC option and live in
## data/compendium/difficulty_toggles.json, behind ContentFlag.AI_VARIATIONS.
const CompendiumTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")

var current_mode: int = OracleMode.MODE_REFERENCE
var card_oracle: FPCM_CardOracleSystem = null
var _ai_data: Dictionary = {}  # Parsed from EnemyAI.json — CORE RULES pp.42-43 only
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
##
## ⚠ THE CORE RULES AI IS DICELESS (p.42: "The default AI is diceless to keep the
## game moving as quickly as possible"). Until Sep 2026 this function printed a
## base condition and a 1D6 table for every enemy at every tier — the COMPENDIUM
## pp.42-43 AI Variations option, which `data/RulesReference/EnemyAI.json` held by
## mistake. The core bullets (pp.42-43) appeared nowhere in the app, and a player
## without the DLC was being told to roll dice the game does not use.
func _get_reference_text(ai_type: String) -> String:
	var type_data: Dictionary = _find_ai_type(ai_type)
	if type_data.is_empty():
		return "Unknown AI type: %s. Use common sense for enemy behavior." % ai_type

	var type_name: String = str(type_data.get("name", ai_type))
	var text: String = "%s AI (Core Rules p.%s)\n" % [
		type_name, str(type_data.get("page", 42))]
	text += "%s\n" % str(type_data.get("description", ""))
	for bullet in type_data.get("core_rules", []):
		text += "\n  - %s" % str(bullet)

	var variation: String = _variation_text(type_name)
	if not variation.is_empty():
		text += "\n\n%s" % variation
	return text


## The Compendium pp.42-43 AI Variations block for this type, or "" when the
## option is off (or the type is one of the three the book leaves unchanged).
func _variation_text(ai_type: String) -> String:
	var variation: Dictionary = CompendiumTogglesRef.ai_variation_for(ai_type)
	if variation.is_empty():
		return ""
	var rules: Dictionary = CompendiumTogglesRef.AI_VARIATION_RULES
	var text: String = "AI VARIATIONS (Compendium pp.42-43)\n"
	text += "Base condition (check FIRST): %s\n" % str(
		variation.get("base_condition", ""))
	text += "\nOtherwise roll 1D6:"
	for entry in variation.get("actions", []):
		if entry is Dictionary:
			text += "\n  %d: %s" % [
				int(entry.get("roll", 0)), str(entry.get("action", ""))]
	for line in rules.get("group_actions", []):
		text += "\n\nGroup actions: %s" % str(line)
	var impossible: String = str(rules.get("impossible_actions", ""))
	if not impossible.is_empty():
		text += "\n\n%s" % impossible
	return text


## MODE_D6_TABLE: Look up an action on the Compendium pp.42-43 variation table.
##
## This mode IS the AI Variations option, so it reads the Compendium data and
## says so when the option is off, rather than inventing a roll.
func _get_d6_table_result(ai_type: String, roll: int) -> String:
	var type_data: Dictionary = _find_ai_type(ai_type)
	if type_data.is_empty():
		return "Unknown AI type: %s. Roll: %d." % [ai_type, roll]

	var type_name: String = str(type_data.get("name", ai_type))
	var row: Dictionary = CompendiumTogglesRef.get_ai_behavior(type_name, roll)
	if row.is_empty():
		if not CompendiumTogglesRef.ai_variations_enabled():
			return ("%s: the core AI is DICELESS (Core Rules p.42). Enable AI"
				+ " Variations (Compendium p.42) to roll for enemy actions.\n\n%s") % [
					type_name, _get_reference_text(ai_type)]
		# p.42: "enemies with the Beast, Rampage, and Guardian AIs function as
		# they would currently. No changes are made."
		return ("%s has no variation table — the Compendium leaves it unchanged"
			+ " (p.42).\n\n%s") % [type_name, _get_reference_text(ai_type)]

	var header: String = "%s AI - Rolled %d (Compendium pp.42-43)\n" % [
		type_name, int(row.get("roll", roll))]
	header += "Base condition (check FIRST): %s\n\n" % str(
		CompendiumTogglesRef.ai_variation_for(type_name).get("base_condition", ""))
	return header + "Action: %s" % str(row.get("action", ""))

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

## True when the Compendium AI Variations option is on, so a UI can hide the D6
## mode instead of offering a roll the core rules do not have.
func variations_enabled() -> bool:
	return CompendiumTogglesRef.ai_variations_enabled()

## The Compendium p.42 "How to Use the New AI" steps, or [] when the option is
## off — the CORE rules have no activation procedure beyond the type's bullets.
##
## Was reading an "AI Decision Making" section of EnemyAI.json that was itself
## Compendium p.42 text mislabelled as core; the file is core-only now.
func get_decision_steps() -> Array:
	if not CompendiumTogglesRef.ai_variations_enabled():
		return []
	var rules: Dictionary = CompendiumTogglesRef.AI_VARIATION_RULES
	var steps: Variant = rules.get("how_to_use", [])
	return steps if steps is Array else []

## `get_targeting_priority()` was DELETED (Sep 2026). Its three "priorities"
## ("Closest visible opponent", "Opponent in the open", "Random selection if
## multiple equal targets") appear in NEITHER rulebook — targeting is part of
## each AI type's own bullets (pp.42-43), which differ per type. It had zero
## callers, so nothing showed the invented list; do not re-add it.

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
