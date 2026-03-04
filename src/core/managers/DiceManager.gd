extends Node

## Dice Manager for Five Parsecs Campaign Manager
## Integrates the dice system with existing game systems
## Provides centralized dice rolling with visual feedback

signal dice_roll_requested(context: String, dice_pattern: String)
signal dice_result_ready(result: int, context: String)

var dice_system: Resource = null
var dice_feed: Control # Reference to UI dice feed
var auto_mode: bool = true # Whether to auto-roll or request manual input

# Roll history tracking
var _roll_history: Array[Dictionary] = []
const MAX_HISTORY_SIZE: int = 100  # Keep last 100 rolls

## Initialize the dice manager
func _ready() -> void:
	_initialize_dice_system()

func _initialize_dice_system() -> void:
	## Safely initialize dice system with fallback
	# Try to load DiceSystem resource safely
	var dice_system_script = load("res://src/core/systems/DiceSystem.gd")
	if dice_system_script:
		dice_system = dice_system_script.new()
		_setup_dice_system()
	else:
		# Continue without dice_system - methods will use fallback
		pass

func _setup_dice_system() -> void:
	## Configure dice system if loaded successfully
	if not dice_system:
		return
		
	# Configure dice system for Five Parsecs gameplay
	dice_system.auto_roll_enabled = auto_mode
	dice_system.show_animations = true
	dice_system.allow_manual_override = true

	# Connect signals safely
	if dice_system.has_signal("dice_rolled"):
		dice_system.dice_rolled.connect(_on_dice_rolled)
	if dice_system.has_signal("manual_input_requested"):
		dice_system.manual_input_requested.connect(_on_manual_input_requested)

## Set reference to the dice feed UI component
func set_dice_feed(feed: Control) -> void:
	dice_feed = feed
	if dice_feed and dice_feed.has_method("set_dice_system") and dice_system:
		dice_feed.set_dice_system(dice_system)

## Enable/disable automatic rolling
func set_auto_mode(enabled: bool) -> void:
	auto_mode = enabled
	if dice_system:
		dice_system.auto_roll_enabled = enabled

## REPLACEMENT METHODS FOR EXISTING RANDOM CALLS
## These replace direct randi() calls throughout the codebase

## Replace: randi() % 6 + 1
func roll_d6(context: String = "D6 Roll") -> int:
	var result: int = randi_range(1, 6)
	_record_roll(result, context, "D6")
	dice_roll_requested.emit(context, "D6")
	dice_result_ready.emit(result, context)
	return result

## Replace: randi() % 10 + 1
func roll_d10(context: String = "D10 Roll") -> int:
	var result: int = randi_range(1, 10)
	_record_roll(result, context, "D10")
	dice_roll_requested.emit(context, "D10")
	dice_result_ready.emit(result, context)
	return result

## Replace: randi() % 100 + 1
func roll_d100(context: String = "D100 Roll") -> int:
	var result: int = randi_range(1, 100)
	_record_roll(result, context, "D100")
	dice_roll_requested.emit(context, "D100")
	dice_result_ready.emit(result, context)
	return result

## Replace: d66 rolls (tens * 10 + ones)
func roll_d66(context: String = "D66 Roll") -> int:
	var tens: int = randi_range(1, 6)
	var ones: int = randi_range(1, 6)
	var result: int = tens * 10 + ones
	_record_roll(result, context, "D66")
	dice_roll_requested.emit(context, "D66")
	dice_result_ready.emit(result, context)
	return result

## Replace: 2d6 rolls
func roll_2d6(context: String = "2D6 Roll") -> int:
	var result: int = randi_range(1, 6) + randi_range(1, 6)
	_record_roll(result, context, "2D6")
	dice_roll_requested.emit(context, "2D6")
	dice_result_ready.emit(result, context)
	return result

## Replace: attribute generation (2d6 / 3.0 rounded up)
func roll_attribute(context: String = "Attribute Generation") -> int:
	var roll_2d6: int = randi_range(1, 6) + randi_range(1, 6)
	var result: int = int(ceil(roll_2d6 / 3.0))
	_record_roll(result, context, "2D6/3")
	dice_roll_requested.emit(context, "2D6/3")
	dice_result_ready.emit(result, context)
	return result

## Replace: combat checks with modifiers
func roll_combat_check(modifier: int = 0, context: String = "Combat Check") -> int:
	var base_roll: int = randi_range(1, 10)
	var result: int = base_roll + modifier
	var dice_type: String = "D10+%d" % modifier if modifier != 0 else "D10"
	_record_roll(result, context, dice_type)
	dice_roll_requested.emit(context, dice_type)
	dice_result_ready.emit(result, context)
	return result

## Replace: injury table rolls
func roll_injury_table(context: String = "Injury Roll") -> int:
	var result: int = randi_range(1, 6)
	_record_roll(result, context, "D6")
	dice_roll_requested.emit(context, "D6")
	dice_result_ready.emit(result, context)
	return result

## Replace: reaction tests
func roll_reaction_test(context: String = "Reaction Test") -> int:
	var result: int = randi_range(1, 6) + randi_range(1, 6)
	_record_roll(result, context, "2D6")
	dice_roll_requested.emit(context, "2D6")
	dice_result_ready.emit(result, context)
	return result

## Replace: morale checks
func roll_morale_check(context: String = "Morale Check") -> int:
	var result: int = randi_range(1, 6)
	_record_roll(result, context, "D6")
	dice_roll_requested.emit(context, "D6")
	dice_result_ready.emit(result, context)
	return result

## Replace: custom dice rolls with context
func roll_custom(dice_count: int, dice_sides: int, modifier: int = 0, context: String = "Custom Roll") -> int:
	var result: int = modifier
	for i in range(dice_count):
		result += randi_range(1, dice_sides)
	var dice_type: String = "%dD%d" % [dice_count, dice_sides]
	if modifier != 0:
		dice_type += "+%d" % modifier
	_record_roll(result, context, dice_type)
	dice_roll_requested.emit(context, dice_type)
	dice_result_ready.emit(result, context)
	return result

## SPECIALIZED FIVE PARSECS ROLLS

## Equipment generation rolls
func roll_equipment_type(context: String = "Equipment Type") -> int:
	return roll_d100("Equipment: " + context)

func roll_equipment_quality(context: String = "Equipment Quality") -> int:
	return roll_d100("Quality: " + context)

## Mission generation rolls
func roll_mission_type(context: String = "Mission Type") -> int:
	return roll_d6("Mission: " + context)

func roll_mission_difficulty(context: String = "Mission Difficulty") -> int:
	return roll_d6("Difficulty: " + context)

func roll_mission_reward(base_amount: int, context: String = "Mission Reward") -> int:
	var multiplier = roll_d6("Reward Multiplier: " + context)
	return base_amount * multiplier

## Character generation rolls
func roll_character_background(context: String = "Character Background") -> int:
	return roll_d66("Background: " + context)

func roll_character_motivation(context: String = "Character Motivation") -> int:
	return roll_d66("Motivation: " + context)

func roll_character_name(context: String = "Character Name") -> int:
	return roll_d66("Name: " + context)

## Battle rolls
func roll_initiative(context: String = "Initiative") -> int:
	return roll_d6("Initiative: " + context)

func roll_hit_chance(modifier: int = 0, context: String = "Hit Chance") -> int:
	return roll_combat_check(modifier, "Hit: " + context)

func roll_damage(dice_count: int = 1, context: String = "Damage") -> int:
	return roll_custom(dice_count, 6, 0, "Damage: " + context)

## World generation rolls
func roll_world_type(context: String = "World Type") -> int:
	return roll_d100("World Type: " + context)

func roll_world_features(context: String = "World Features") -> int:
	return roll_d100("Features: " + context)

## Patron and rival rolls
func roll_patron_type(context: String = "Patron Type") -> int:
	return roll_d66("Patron: " + context)

func roll_patron_job(context: String = "Patron Job") -> int:
	return roll_d6("Job: " + context)

func roll_rival_activity(context: String = "Rival Activity") -> int:
	return roll_d6("Rival: " + context)

## Campaign event rolls
func roll_campaign_event(context: String = "Campaign Event") -> int:
	return roll_d100("Event: " + context)

func roll_upkeep_event(context: String = "Upkeep Event") -> int:
	return roll_d6("Upkeep: " + context)

## BATCH ROLLING FOR MULTIPLE OPERATIONS

## Roll multiple dice of the same type
func roll_multiple_d6(count: int, context: String = "Multiple D6") -> Array[int]:
	var results: Array[int] = []
	for i: int in range(count):
		results.append(roll_d6("%s (%d/%d)" % [context, i + 1, count]))
	return results

func roll_multiple_d100(count: int, context: String = "Multiple D100") -> Array[int]:
	var results: Array[int] = []
	for i: int in range(count):
		results.append(roll_d100("%s (%d/%d)" % [context, i + 1, count]))
	return results

## LEGACY COMPATIBILITY
## These methods provide compatibility with existing code patterns

## Direct replacement for randi() % sides + 1
func legacy_randi_range(sides: int, context: String = "Legacy Roll") -> int:
	match sides:
		6: return roll_d6(context)
		10: return roll_d10(context)
		100: return roll_d100(context)
		_: return roll_custom(1, sides, 0, context)

## Direct replacement for randi() % max + min
func legacy_randi_range_min_max(min_val: int, max_val: int, context: String = "Legacy Range") -> int:
	var range_size: int = max_val - min_val + 1
	var roll: int = roll_custom(1, range_size, min_val - 1, context)
	return roll

## STATISTICS AND ANALYSIS

## Get rolling statistics for debugging/balancing
func get_roll_statistics() -> Dictionary:
	var total_rolls: int = _roll_history.size()
	var average_result: float = 0.0
	if total_rolls > 0:
		var sum: int = 0
		for entry in _roll_history:
			sum += entry.get("result", 0)
		average_result = float(sum) / float(total_rolls)
	return {
		"total_rolls": total_rolls,
		"average_result": average_result,
		"auto_mode": auto_mode
	}

## Record a roll in history
func _record_roll(result: int, context: String, dice_type: String) -> void:
	var entry: Dictionary = {
		"result": result,
		"context": context,
		"dice_type": dice_type,
		"timestamp": Time.get_unix_time_from_system()
	}
	_roll_history.push_front(entry)

	# Trim history if too large
	while _roll_history.size() > MAX_HISTORY_SIZE:
		_roll_history.pop_back()

## Get recent roll history as formatted string
func get_roll_history(count: int = 10) -> String:
	if _roll_history.is_empty():
		return "No rolls recorded yet"

	var lines: PackedStringArray = []
	var entries_to_show: int = mini(count, _roll_history.size())

	lines.append("=== Recent Dice Rolls (%d) ===" % entries_to_show)

	for i in range(entries_to_show):
		var entry: Dictionary = _roll_history[i]
		var result: int = entry.get("result", 0)
		var context: String = entry.get("context", "Unknown")
		var dice_type: String = entry.get("dice_type", "?")
		lines.append("  [%s] %d - %s" % [dice_type, result, context])

	return "\n".join(lines)

## Get roll history as array of dictionaries
func get_roll_history_data(count: int = 10) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var entries_to_show: int = mini(count, _roll_history.size())

	for i in range(entries_to_show):
		result.append(_roll_history[i])

	return result

## Clear roll history
func clear_roll_history() -> void:
	_roll_history.clear()

## SIGNAL HANDLERS
func _on_dice_rolled(result: int, context: String) -> void:
	dice_result_ready.emit(result, context)

func _on_manual_input_requested(context: String) -> void:
	# Handle manual input request - could show UI prompt
	pass

## SETTINGS MANAGEMENT
func save_dice_settings() -> Dictionary:
	return {
		"auto_mode": auto_mode,
		"dice_feed_enabled": dice_feed != null
	}

func load_dice_settings(settings: Dictionary) -> void:
	auto_mode = settings.get("auto_mode", true)

## INTEGRATION HELPERS

## Get the underlying dice system for advanced operations
func get_dice_system() -> Resource:
	return dice_system

## Check if dice system is ready for rolling
func is_ready() -> bool:
	return dice_system != null

## Force a manual roll request for testing
func request_manual_roll(dice_count: int, dice_sides: int, context: String = "Manual Test") -> void:
	var old_auto_mode: bool = auto_mode
	auto_mode = false
	var _result: int = roll_custom(dice_count, dice_sides, 0, context)
	auto_mode = old_auto_mode