class_name FPCM_DiceDashboard
extends Control

## Dice Dashboard - Quick Dice Rolling Widget
##
## Provides quick access to common Five Parsecs dice rolls
## with visual feedback and roll history for tabletop-style play.

# Signals
signal dice_rolled(dice_type: String, result: int, context: String)

# UI References
@onready var last_roll_label: Label = %LastRollLabel
@onready var roll_history: RichTextLabel = %RollHistory
@onready var d6_button: Button = %D6Button
@onready var d3_button: Button = %D3Button
@onready var d66_button: Button = %D66Button
@onready var two_d6_button: Button = %TwoD6Button
@onready var context_input: LineEdit = %ContextInput

# Dice rolling history
var roll_history_log: Array[Dictionary] = []
const MAX_HISTORY_ENTRIES: int = 10

# DiceSystem reference (optional - falls back to RNG if not provided)
var dice_system: Object = null

# Context-aware roll descriptions for Five Parsecs combat
const ROLL_CONTEXTS: Dictionary = {
	"REACTION": {"dice": "D6", "label": "Reaction Roll", "description": "Roll <= Reactions stat = Quick Action"},
	"HIT": {"dice": "D6", "label": "Hit Roll", "description": "4+ to hit (before modifiers)"},
	"MORALE": {"dice": "2D6", "label": "Morale Check", "description": "Roll vs enemy Morale value"},
	"BATTLE_EVENT": {"dice": "D100", "label": "Battle Event", "description": "d100 on Battle Events Table (p.116)"},
	"INJURY": {"dice": "D66", "label": "Injury Table", "description": "d66 on Crew Injury Table"},
	"CUSTOM": {"dice": "D6", "label": "Custom Roll", "description": ""},
}

func _ready() -> void:
	## Initialize dice dashboard
	_connect_button_signals()
	_update_display()

func _connect_button_signals() -> void:
	## Connect dice button signals
	if d6_button:
		d6_button.pressed.connect(func(): _roll("D6"))
	if d3_button:
		d3_button.pressed.connect(func(): _roll("D3"))
	if d66_button:
		d66_button.pressed.connect(func(): _roll("D66"))
	if two_d6_button:
		two_d6_button.pressed.connect(func(): _roll("2D6"))

# =====================================================
# DICE ROLLING
# =====================================================

func _roll(dice_type: String) -> void:
	## Roll dice and display result
	var context: String = ""
	if context_input:
		context = context_input.text.strip_edges()

	var result: int = _execute_roll(dice_type)

	# Log roll
	_add_to_history(dice_type, result, context)

	# Update display
	_update_display()

	# Emit signal
	dice_rolled.emit(dice_type, result, context)

func _execute_roll(dice_type: String) -> int:
	## Execute dice roll using DiceSystem or fallback RNG
	var result: int = 0

	# Try DiceSystem first
	if dice_system and dice_system.has_method("roll_dice"):
		var context = context_input.text if context_input else ""
		result = dice_system.roll_dice(context, dice_type)
		return result

	# Fallback: Manual dice rolling
	match dice_type.to_upper():
		"D3":
			result = randi() % 3 + 1
		"D6":
			result = randi() % 6 + 1
		"2D6":
			result = (randi() % 6 + 1) + (randi() % 6 + 1)
		"D66":
			# D66 = tens digit (1-6) + ones digit (1-6) = range 11-66
			var tens: int = randi() % 6 + 1
			var ones: int = randi() % 6 + 1
			result = (tens * 10) + ones
		"D100":
			# D100 using 2D10 method
			var tens_roll: int = randi() % 10
			var ones_roll: int = randi() % 10
			result = (tens_roll * 10) + ones_roll
			if result == 0:
				result = 100 # 00 = 100
		_:
			# Default to D6
			result = randi() % 6 + 1

	return result

# =====================================================
# ROLL HISTORY
# =====================================================

func _add_to_history(dice_type: String, result: int, context: String) -> void:
	## Add roll to history log
	var roll_entry := {
		"dice_type": dice_type,
		"result": result,
		"context": context,
		"timestamp": Time.get_time_string_from_system()
	}

	roll_history_log.push_front(roll_entry)

	# Limit history size
	if roll_history_log.size() > MAX_HISTORY_ENTRIES:
		roll_history_log.resize(MAX_HISTORY_ENTRIES)

func clear_history() -> void:
	## Clear roll history
	roll_history_log.clear()
	_update_display()

# =====================================================
# DISPLAY UPDATES
# =====================================================

func _update_display() -> void:
	## Update visual display
	if not is_node_ready():
		return

	# Update last roll display
	if last_roll_label:
		if roll_history_log.size() > 0:
			var last_roll: Dictionary = roll_history_log[0]
			var context_text: String = ""
			if last_roll.context != "":
				context_text = " - %s" % last_roll.context

			last_roll_label.text = "Last Roll: %s = %d%s" % [
				last_roll.dice_type,
				last_roll.result,
				context_text
			]

			# Color code based on dice type for visual interest
			match last_roll.dice_type.to_upper():
				"D3":
					last_roll_label.modulate = Color("#87CEEB")  # Light Blue
				"D6":
					last_roll_label.modulate = Color("#FFFFFF")  # White
				"2D6":
					last_roll_label.modulate = Color("#90EE90")  # Light Green
				"D66":
					last_roll_label.modulate = Color("#FFFF00")  # Yellow
				"D100":
					last_roll_label.modulate = Color("#FFA500")  # Orange
				_:
					last_roll_label.modulate = Color("#FFFFFF")  # White
		else:
			last_roll_label.text = "No rolls yet"
			last_roll_label.modulate = Color("#808080")  # Gray

	# Update roll history display
	if roll_history:
		roll_history.clear()

		if roll_history_log.size() > 0:
			for entry in roll_history_log:
				var context_text: String = ""
				if entry.context != "":
					context_text = " - %s" % entry.context

				var history_line: String = "[%s] %s = %d%s\n" % [
					entry.timestamp,
					entry.dice_type,
					entry.result,
					context_text
				]

				roll_history.append_text(history_line)
		else:
			roll_history.append_text("[color=gray]No roll history[/color]")

# =====================================================
# CONFIGURATION
# =====================================================

func set_dice_system(system: Object) -> void:
	## Set DiceSystem reference for integrated rolling
	dice_system = system

func get_last_roll() -> Dictionary:
	## Get last roll result
	if roll_history_log.size() > 0:
		return roll_history_log[0]
	return {}

func get_roll_history() -> Array[Dictionary]:
	## Get full roll history
	return roll_history_log.duplicate()

# =====================================================
# QUICK ROLL INTERFACE
# =====================================================

func quick_roll_d6(context: String = "") -> int:
	## Quick D6 roll from code
	if context_input and context != "":
		context_input.text = context

	_roll("D6")

	if roll_history_log.size() > 0:
		return roll_history_log[0].result
	return 0

func quick_roll_d3(context: String = "") -> int:
	## Quick D3 roll from code
	if context_input and context != "":
		context_input.text = context

	_roll("D3")

	if roll_history_log.size() > 0:
		return roll_history_log[0].result
	return 0

func quick_roll_2d6(context: String = "") -> int:
	## Quick 2D6 roll from code
	if context_input and context != "":
		context_input.text = context

	_roll("2D6")

	if roll_history_log.size() > 0:
		return roll_history_log[0].result
	return 0

# =====================================================
# CONTEXT-AWARE ROLLS
# =====================================================

## Roll with a predefined context (see ROLL_CONTEXTS).
func context_roll(context_key: String) -> int:
	var ctx: Dictionary = ROLL_CONTEXTS.get(context_key, ROLL_CONTEXTS.CUSTOM)
	var dice_type: String = ctx.dice
	var label: String = ctx.label

	if context_input:
		context_input.text = label

	_roll(dice_type)

	if roll_history_log.size() > 0:
		return roll_history_log[0].result
	return 0

## Get the interpretation text for a context-aware roll result.
func get_roll_interpretation(context_key: String, result: int) -> String:
	match context_key:
		"REACTION":
			return "Rolled %d - compare to crew Reactions stat" % result
		"HIT":
			if result >= 4:
				return "Rolled %d - HIT (before modifiers)" % result
			else:
				return "Rolled %d - MISS (before modifiers)" % result
		"MORALE":
			return "Rolled %d - compare to enemy Morale value" % result
		"BATTLE_EVENT":
			return "Rolled %d - look up on Battle Events Table (p.116)" % result
		"INJURY":
			return "Rolled %d - look up on Injury Table" % result
		_:
			return "Rolled %d" % result

## Get available context roll types for UI display.
func get_context_types() -> Array[Dictionary]:
	var types: Array[Dictionary] = []
	for key: String in ROLL_CONTEXTS:
		var ctx: Dictionary = ROLL_CONTEXTS[key]
		types.append({
			"key": key,
			"dice": ctx.dice,
			"label": ctx.label,
			"description": ctx.description,
		})
	return types
