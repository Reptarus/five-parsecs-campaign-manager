extends Node

## Dice Manager for Five Parsecs Campaign Manager
## Integrates the dice system with existing game systems
## Provides centralized dice rolling with visual feedback

const DiceSystemResource = preload("res://src/core/systems/DiceSystem.gd")

signal dice_roll_requested(context: String, dice_pattern: String)
signal dice_result_ready(result: int, context: String)

var dice_system: DiceSystemResource
var dice_feed: Control # Reference to UI dice feed
var auto_mode: bool = true # Whether to auto-roll or request manual input

## Initialize the dice manager
func _ready() -> void:
	dice_system = DiceSystemResource.new()
	_setup_dice_system()
func _setup_dice_system() -> void:
	# Configure dice system for Five Parsecs gameplay
	dice_system.auto_roll_enabled = auto_mode
	dice_system.show_animations = true
	dice_system.allow_manual_override = true

	# Connect signals
	dice_system.dice_rolled.connect(_on_dice_rolled)
	dice_system.manual_input_requested.connect(_on_manual_input_requested)

## Set reference to the dice feed UI component
func set_dice_feed(feed: Control) -> void:
	dice_feed = feed
	if dice_feed and dice_feed and dice_feed.has_method("set_dice_system"):
		dice_feed.set_dice_system(dice_system)

## Enable/disable automatic rolling
func set_auto_mode(enabled: bool) -> void:
	auto_mode = enabled
	dice_system.auto_roll_enabled = enabled

## REPLACEMENT METHODS FOR EXISTING RANDOM CALLS
## These replace direct randi() calls throughout the codebase

## Replace: randi() % 6 + 1
func roll_d6(context: String = "D6 Roll") -> int:
	var result: int = randi_range(1, 6)
	dice_roll_requested.emit(context, "D6")
	dice_result_ready.emit(result, context)
	return result

## Replace: randi() % 10 + 1  
func roll_d10(context: String = "D10 Roll") -> int:
	var result: int = randi_range(1, 10)
	dice_roll_requested.emit(context, "D10")
	dice_result_ready.emit(result, context)
	return result

## Replace: randi() % 100 + 1
func roll_d100(context: String = "D100 Roll") -> int:
	var result: int = randi_range(1, 100)
	dice_roll_requested.emit(context, "D100")
	dice_result_ready.emit(result, context)
	return result

## Replace: d66 rolls (tens * 10 + ones)
func roll_d66(context: String = "D66 Roll") -> int:
	var tens: int = randi_range(1, 6)
	var ones: int = randi_range(1, 6)
	var result: int = tens * 10 + ones
	dice_roll_requested.emit(context, "D66")
	dice_result_ready.emit(result, context)
	return result

## Replace: 2d6 rolls
func roll_2d6(context: String = "2D6 Roll") -> int:
	var result: int = randi_range(1, 6) + randi_range(1, 6)
	dice_roll_requested.emit(context, "2D6")
	dice_result_ready.emit(result, context)
	return result

## Replace: attribute generation (2d6 / 3.0 rounded up)
func roll_attribute(context: String = "Attribute Generation") -> int:
	var roll_2d6: int = randi_range(1, 6) + randi_range(1, 6)
	var result: int = int(ceil(roll_2d6 / 3.0))
	dice_roll_requested.emit(context, "2D6/3")
	dice_result_ready.emit(result, context)
	return result

## Replace: combat checks with modifiers
func roll_combat_check(modifier: int = 0, context: String = "Combat Check") -> int:
	var base_roll: int = randi_range(1, 10)
	var result: int = base_roll + modifier
	dice_roll_requested.emit(context, "D10+%d" % modifier)
	dice_result_ready.emit(result, context)
	return result

## Replace: injury table rolls
func roll_injury_table(context: String = "Injury Roll") -> int:
	var result: int = randi_range(1, 6)
	dice_roll_requested.emit(context, "D6")
	dice_result_ready.emit(result, context)
	return result

## Replace: reaction tests
func roll_reaction_test(context: String = "Reaction Test") -> int:
	var result: int = randi_range(1, 6) + randi_range(1, 6)
	dice_roll_requested.emit(context, "2D6")
	dice_result_ready.emit(result, context)
	return result

## Replace: morale checks
func roll_morale_check(context: String = "Morale Check") -> int:
	var result: int = randi_range(1, 6)
	dice_roll_requested.emit(context, "D6")
	dice_result_ready.emit(result, context)
	return result

## Replace: custom dice rolls with context
func roll_custom(dice_count: int, dice_sides: int, modifier: int = 0, context: String = "Custom Roll") -> int:
	var result: int = modifier
	for i in range(dice_count):
		result += randi_range(1, dice_sides)
	dice_roll_requested.emit(context, "%dD%d+%d" % [dice_count, dice_sides, modifier])
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
	return {
		"total_rolls": 0,
		"average_result": 0.0,
		"auto_mode": auto_mode
	}

## Get recent roll history
func get_roll_history(count: int = 10) -> String:
	return "Roll history not implemented yet"

## Clear roll history
func clear_roll_history() -> void:
	print("Roll history cleared")

## SIGNAL HANDLERS
func _on_dice_rolled(result: int, context: String) -> void:
	dice_result_ready.emit(result, context)

func _on_manual_input_requested(context: String) -> void:
	# Handle manual input request - could show UI prompt
	print("Manual dice input requested for: " + context)

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
func get_dice_system() -> DiceSystemResource:
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