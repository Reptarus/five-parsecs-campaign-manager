class_name FPCM_DiceSystem
extends Resource

## Digital Dice System for Five Parsecs Campaign Manager
## Provides visual dice rolling with manual override options
## Integrates with existing random number generation throughout the codebase

signal dice_rolled(result: DiceRoll)
signal dice_animation_started(dice_count: int, dice_type: String)
signal dice_animation_completed(result: DiceRoll)
signal manual_input_requested(dice_roll: DiceRoll)

## Dice roll result data
class DiceRoll extends Resource:
	@export var dice_count: int = 1
	@export var dice_type: String = "d6" # d6, d10, d20, d100, d66
	@export var modifier: int = 0
	@export var individual_rolls: Array[int] = []
	@export var total: int = 0
	@export var description: String = ""
	@export var context: String = "" # What this roll is for
	@export var timestamp: float = 0.0
	@export var is_manual: bool = false
	@export var roll_id: String = ""
	
	func _init(p_dice_count: int = 1, p_dice_type: String = "d6", p_modifier: int = 0, p_context: String = "") -> void:
		dice_count = p_dice_count
		dice_type = p_dice_type
		modifier = p_modifier
		context = p_context
		timestamp = Time.get_ticks_msec() / 1000.0
		roll_id = "roll_" + str(randi()) + "_" + str(timestamp)
	
	func get_display_text() -> String:
		var rolls_text = str(individual_rolls).replace("[", "").replace("]", "")
		if modifier != 0:
			var mod_text: String = "+" + str(modifier) if modifier > 0 else str(modifier)
			return "%dd%s %s = %s %s = %d" % [dice_count, dice_type.substr(1), mod_text, rolls_text, mod_text, total]
		else:
			return "%dd%s = %s = %d" % [dice_count, dice_type.substr(1), rolls_text, total]
	
	func get_simple_text() -> String:
		if modifier != 0:
			var mod_text: String = "+" + str(modifier) if modifier > 0 else str(modifier)
			return "%dd%s%s = %d" % [dice_count, dice_type.substr(1), mod_text, total]
		else:
			return "%dd%s = %d" % [dice_count, dice_type.substr(1), total]

## Settings for dice system behavior
var auto_roll_enabled: bool = true
var show_animations: bool = true
var animation_speed: float = 1.0
var _always_show_breakdown: bool = false
var allow_manual_override: bool = true
var _dice_sound_enabled: bool = true

## Roll history for reference
var roll_history: Array[DiceRoll] = []
var max_history_size: int = 100

## Common Five Parsecs dice patterns
enum DicePattern {
	D6, # Standard d6 (1-6)
	D10, # Standard d10 (1-10)
	D66, # Two d6 read as tens/ones (11-66)
	D100, # Percentile dice (1-100)
	ATTRIBUTE, # 2d6/3 rounded up for character generation
	COMBAT, # Combat resolution dice
	INJURY, # Injury table roll (d100)
	REACTION, # Reaction test (d6)
	MORALE # Morale check (d6)
}

## Roll dice with visual feedback and manual override option
func roll_dice(pattern: DicePattern, context: String = "", allow_manual: bool = true) -> DiceRoll:
	var dice_roll = _create_dice_roll_for_pattern(pattern, context)
	
	if allow_manual and allow_manual_override and not auto_roll_enabled:
		# Request _manual input
		manual_input_requested.emit(dice_roll) # warning: return value discarded (intentional)
		return dice_roll
	else:
		# Perform automatic roll
		return _execute_dice_roll(dice_roll)

## Roll custom dice configuration
func roll_custom(dice_count: int, dice_sides: int, modifier: int = 0, context: String = "", allow_manual: bool = true) -> DiceRoll:
	var dice_roll = DiceRoll.new(dice_count, "d" + str(dice_sides), modifier, context)
	
	if allow_manual and allow_manual_override and not auto_roll_enabled:
		manual_input_requested.emit(dice_roll) # warning: return value discarded (intentional)
		return dice_roll
	else:
		return _execute_dice_roll(dice_roll)

## Execute the actual dice roll with animation
func _execute_dice_roll(dice_roll: DiceRoll) -> DiceRoll:
	if show_animations:
		dice_animation_started.emit(dice_roll.dice_count, dice_roll.dice_type) # warning: return value discarded (intentional)
	
	# Perform the actual rolling
	dice_roll.individual_rolls.clear()
	
	match dice_roll.dice_type:
		"d6":
			for i in range(dice_roll.dice_count):
				dice_roll.individual_rolls.append(randi() % 6 + 1)
		"d10":
			for i in range(dice_roll.dice_count):
				dice_roll.individual_rolls.append(randi() % 10 + 1)
		"d20":
			for i in range(dice_roll.dice_count):
				dice_roll.individual_rolls.append(randi() % 20 + 1)
		"d100":
			for i in range(dice_roll.dice_count):
				dice_roll.individual_rolls.append(randi() % 100 + 1)
		"d66":
			for i in range(dice_roll.dice_count):
				var tens = randi() % 6 + 1
				var ones = randi() % 6 + 1
				dice_roll.individual_rolls.append(tens * 10 + ones)
	
	# Calculate total
	dice_roll.total = dice_roll.individual_rolls.reduce(func(a, b): return a + b, 0) + dice_roll.modifier
	
	# Add to history
	_add_to_history(dice_roll)
	
	# Emit signals
	dice_rolled.emit(dice_roll) # warning: return value discarded (intentional)
	if show_animations:
		dice_animation_completed.emit(dice_roll) # warning: return value discarded (intentional)
	
	return dice_roll

## Handle manual dice input from UI
func input_manual_result(dice_roll: DiceRoll, manual_rolls: Array[int]) -> DiceRoll:
	dice_roll.individual_rolls = manual_rolls.duplicate()
	dice_roll.total = dice_roll.individual_rolls.reduce(func(a, b): return a + b, 0) + dice_roll.modifier
	dice_roll.is_manual = true
	
	_add_to_history(dice_roll)
	dice_rolled.emit(dice_roll) # warning: return value discarded (intentional)
	
	return dice_roll

## Create dice roll configuration for common patterns
func _create_dice_roll_for_pattern(pattern: DicePattern, context: String) -> DiceRoll:
	match pattern:
		DicePattern.D6:
			return DiceRoll.new(1, "d6", 0, context)
		DicePattern.D10:
			return DiceRoll.new(1, "d10", 0, context)
		DicePattern.D66:
			return DiceRoll.new(1, "d66", 0, context)
		DicePattern.D100:
			return DiceRoll.new(1, "d100", 0, context)
		DicePattern.ATTRIBUTE:
			var roll = DiceRoll.new(2, "d6", 0, context + " (Attribute Generation)")
			roll.description = "Roll 2d6, divide by 3, round up"
			return roll
		DicePattern.COMBAT:
			return DiceRoll.new(1, "d6", 0, context + " (Combat)")
		DicePattern.INJURY:
			return DiceRoll.new(1, "d100", 0, context + " (Injury Table)")
		DicePattern.REACTION:
			return DiceRoll.new(1, "d6", 0, context + " (Reaction Test)")
		DicePattern.MORALE:
			return DiceRoll.new(1, "d6", 0, context + " (Morale Check)")
		_:
			return DiceRoll.new(1, "d6", 0, context)

## Convenience methods for common Five Parsecs rolls
func roll_d6(context: String = "") -> int:
	var result = roll_dice(DicePattern.D6, context)
	return result.total

func roll_d10(context: String = "") -> int:
	var result = roll_dice(DicePattern.D10, context)
	return result.total

func roll_d66(context: String = "") -> int:
	var result = roll_dice(DicePattern.D66, context)
	return result.total

func roll_d100(context: String = "") -> int:
	var result = roll_dice(DicePattern.D100, context)
	return result.total

func roll_2d6(context: String = "") -> int:
	var result = roll_custom(2, 6, 0, context)
	return result.total

func roll_attribute(context: String = "") -> int:
	var result = roll_dice(DicePattern.ATTRIBUTE, context)
	# For attribute generation: 2d6, divide by 3, round up
	return int(ceil(float(result.total) / 3.0))

## Add roll to history
func _add_to_history(dice_roll: DiceRoll) -> void:
	roll_history.append(dice_roll) # warning: return value discarded (intentional)
	if roll_history.size() > max_history_size:
		roll_history.pop_front()

## Get recent rolls
func get_recent_rolls(count: int = 10) -> Array[DiceRoll]:
	var recent_count = min(count, roll_history.size())
	return roll_history.slice(roll_history.size() - recent_count)

## Clear roll history
func clear_history() -> void:
	roll_history.clear()

## Get roll by ID
func get_roll_by_id(roll_id: String) -> DiceRoll:
	for roll in roll_history:
		if roll.roll_id == roll_id:
			return roll
	return null

## Legacy compatibility methods - bridge to existing randi() calls
func legacy_d6() -> int:
	return roll_d6("legacy call")

func legacy_d10() -> int:
	return roll_d10("legacy call")

func legacy_d100() -> int:
	return roll_d100("legacy call")

func legacy_d66() -> int:
	return roll_d66("legacy call")

## Configuration methods
func set_auto_roll(enabled: bool) -> void:
	auto_roll_enabled = enabled

func set_animations(enabled: bool) -> void:
	show_animations = enabled

func set_manual_override(enabled: bool) -> void:
	allow_manual_override = enabled

func set_animation_speed(speed: float) -> void:
	animation_speed = clamp(speed, 0.1, 3.0)

## Statistics methods
func get_roll_statistics() -> Dictionary:
	var stats = {
		"total_rolls": roll_history.size(),
		"d6_rolls": 0,
		"d10_rolls": 0,
		"d100_rolls": 0,
		"d66_rolls": 0,
		"manual_rolls": 0,
		"average_d6": 0.0,
		"average_d10": 0.0
	}
	
	var d6_sum: int = 0
	var d6_count: int = 0
	var d10_sum: int = 0
	var d10_count: int = 0
	
	for roll in roll_history:
		if roll.is_manual:
			stats.manual_rolls += 1
		
		match roll.dice_type:
			"d6":
				stats.d6_rolls += 1
				d6_sum += roll.total
				d6_count += 1
			"d10":
				stats.d10_rolls += 1
				d10_sum += roll.total
				d10_count += 1
			"d100":
				stats.d100_rolls += 1
			"d66":
				stats.d66_rolls += 1
	
	if d6_count > 0:
		stats.average_d6 = float(d6_sum) / float(d6_count)
	if d10_count > 0:
		stats.average_d10 = float(d10_sum) / float(d10_count)
	
	return stats
