@tool
class_name FPCM_OptionalAutomationManager
extends Resource

## Optional Automation Manager - Accessibility Features
##
## This system provides optional automation for users who need it while
## maintaining the tabletop assistant philosophy. Think of it as "accessibility
## modes" rather than video game automation.
##
## Features:
## - Digital dice rolling with physical override
## - Optional combat resolution assistance
## - Movement calculation aids
## - Rule lookup automation
## - BUT: Always with player confirmation and manual override options

# Dependencies
const DiceSystem = preload("res://src/core/systems/DiceSystem.gd")
const BattlefieldManager = preload("res://src/core/battle/BattlefieldManager.gd")
const EnemyTracker = preload("res://src/core/battle/EnemyTracker.gd")

# Signals
signal automation_suggestion(suggestion: Dictionary)
signal dice_roll_suggested(roll_data: Dictionary)
signal combat_resolution_available(options: Array)
signal user_confirmation_required(action: String, details: Dictionary)
signal automation_completed(action: String, result: Dictionary)

# Automation levels - user configurable
enum AutomationLevel {
	MANUAL_ONLY, # Pure tabletop - no automation
	DICE_ASSISTANCE, # Digital dice only
	BASIC_HELP, # Dice + calculation assistance
	GUIDED_PLAY, # Suggestions for actions
	FULL_ASSISTANCE # Maximum automation (still with confirmation)
}

# User preferences
var current_automation_level: AutomationLevel = AutomationLevel.DICE_ASSISTANCE
var always_confirm_actions: bool = true
var show_calculation_steps: bool = true
var enable_rule_suggestions: bool = true
var accessibility_mode: bool = false

# System components
var dice_system: DiceSystem
var battlefield_manager: BattlefieldManager
var enemy_tracker: EnemyTracker

# Automation state
var pending_actions: Array = []
var automation_history: Array = []

func _init():
	dice_system = DiceSystem.new()
	_setup_accessibility_defaults()

## Setup default accessibility-friendly settings
func _setup_accessibility_defaults() -> void:
	# Configure dice system for accessibility
	dice_system.auto_roll_enabled = false # Default to manual override
	dice_system.allow_manual_override = true
	dice_system.show_animations = true
	dice_system.always_show_breakdown = true

## Set automation level with appropriate warnings
func set_automation_level(level: AutomationLevel) -> void:
	var old_level = current_automation_level
	current_automation_level = level
	
	match level:
		AutomationLevel.MANUAL_ONLY:
			_disable_all_automation()
		AutomationLevel.DICE_ASSISTANCE:
			_enable_dice_assistance_only()
		AutomationLevel.BASIC_HELP:
			_enable_basic_automation()
		AutomationLevel.GUIDED_PLAY:
			_enable_guided_automation()
		AutomationLevel.FULL_ASSISTANCE:
			_enable_full_automation()
	
	print("Automation level changed from %s to %s" % [
		AutomationLevel.keys()[old_level],
		AutomationLevel.keys()[level]
	])

## Enable accessibility mode with enhanced features
func enable_accessibility_mode(enable: bool = true) -> void:
	accessibility_mode = enable
	
	if enable:
		# Enhanced settings for accessibility
		dice_system.always_show_breakdown = true
		dice_system.animation_speed = 0.5 # Slower for easier reading
		show_calculation_steps = true
		always_confirm_actions = true
		
		print("Accessibility mode enabled - enhanced visual feedback and confirmations")
	else:
		print("Accessibility mode disabled")

## Digital dice rolling with full manual override
func roll_dice_with_options(pattern: DiceSystem.DicePattern, context: String = "") -> Dictionary:
	var roll_options = {
		"pattern": pattern,
		"context": context,
		"auto_available": current_automation_level >= AutomationLevel.DICE_ASSISTANCE,
		"manual_required": current_automation_level == AutomationLevel.MANUAL_ONLY,
		"show_both": accessibility_mode
	}
	
	dice_roll_suggested.emit(roll_options)
	
	if roll_options.manual_required:
		return {"type": "manual_input_required", "pattern": pattern, "context": context}
	else:
		var result = dice_system.roll_dice(pattern, context, always_confirm_actions)
		_log_automation_action("dice_roll", {"pattern": pattern, "result": result.total, "context": context})
		return {"type": "roll_result", "result": result}

## Combat resolution assistance (with full player control)
func suggest_combat_resolution(attacker: Dictionary, target: Dictionary, context: String = "") -> Dictionary:
	if current_automation_level < AutomationLevel.BASIC_HELP:
		return {"type": "manual_only", "message": "Combat resolution assistance disabled"}
	
	var combat_options = {
		"attacker": attacker,
		"target": target,
		"context": context,
		"calculation_steps": [],
		"suggested_rolls": [],
		"rule_references": []
	}
	
	# Calculate combat modifiers with full transparency
	combat_options.calculation_steps = _calculate_combat_steps(attacker, target)
	
	# Suggest dice rolls needed
	combat_options.suggested_rolls = [
		{"type": "attack_roll", "dice": "1d6", "modifiers": combat_options.calculation_steps},
		{"type": "damage_roll", "dice": "1d6", "weapon": attacker.get("weapon", {})}
	]
	
	# Provide rule references
	combat_options.rule_references = [
		"Core Rules p.71 - Combat Resolution",
		"Weapon traits affect attack rolls",
		"Cover provides -2 to hit"
	]
	
	# Always require confirmation
	if always_confirm_actions:
		user_confirmation_required.emit("combat_resolution", combat_options)
		return {"type": "confirmation_required", "options": combat_options}
	
	combat_resolution_available.emit([combat_options])
	return {"type": "suggestions_available", "options": combat_options}

## Movement calculation assistance
func calculate_movement_assistance(character: Dictionary, destination: Vector2, terrain_map: Array = []) -> Dictionary:
	if current_automation_level < AutomationLevel.BASIC_HELP:
		return {"type": "manual_calculation"}
	
	var movement_data = {
		"character": character,
		"start_position": character.get("position", Vector2.ZERO),
		"end_position": destination,
		"distance_inches": 0.0,
		"movement_cost": 0,
		"terrain_penalties": [],
		"can_reach": false,
		"calculation_steps": []
	}
	
	# Calculate distance
	var distance_pixels = movement_data.start_position.distance_to(destination)
	movement_data.distance_inches = distance_pixels / 32.0 # Assuming 32 pixels per inch
	
	# Calculate movement cost with terrain
	movement_data.calculation_steps.append("Base distance: %.1f inches" % movement_data.distance_inches)
	
	var movement_points = character.get("speed", 6)
	movement_data.movement_cost = int(movement_data.distance_inches)
	
	# Check terrain penalties
	if not terrain_map.is_empty():
		var terrain_penalty = _calculate_terrain_penalty(movement_data.start_position, destination, terrain_map)
		movement_data.terrain_penalties = terrain_penalty.penalties
		movement_data.movement_cost += terrain_penalty.additional_cost
		movement_data.calculation_steps.append_array(terrain_penalty.steps)
	
	movement_data.can_reach = movement_data.movement_cost <= movement_points
	movement_data.calculation_steps.append("Total cost: %d / %d movement points" % [movement_data.movement_cost, movement_points])
	
	return {"type": "movement_calculated", "data": movement_data}

## Line of sight calculation assistance
func calculate_line_of_sight(from: Vector2, to: Vector2, terrain_map: Array = []) -> Dictionary:
	if current_automation_level < AutomationLevel.BASIC_HELP:
		return {"type": "manual_check"}
	
	var los_data = {
		"from": from,
		"to": to,
		"has_line_of_sight": true,
		"blocking_terrain": [],
		"calculation_steps": []
	}
	
	los_data.calculation_steps.append("Checking line of sight from %s to %s" % [from, to])
	
	# Simple line of sight calculation
	# TODO: Implement proper terrain-based LOS checking
	var blocked_by = _check_terrain_blocking(from, to, terrain_map)
	los_data.blocking_terrain = blocked_by
	los_data.has_line_of_sight = blocked_by.is_empty()
	
	if los_data.has_line_of_sight:
		los_data.calculation_steps.append("Clear line of sight - no obstructions")
	else:
		los_data.calculation_steps.append("Line of sight blocked by: %s" % ", ".join(blocked_by))
	
	return {"type": "los_calculated", "data": los_data}

## Rule lookup automation
func suggest_relevant_rules(context: String, keywords: Array = []) -> Dictionary:
	if not enable_rule_suggestions or current_automation_level < AutomationLevel.BASIC_HELP:
		return {"type": "manual_lookup"}
	
	var rule_suggestions = {
		"context": context,
		"suggested_rules": [],
		"page_references": [],
		"quick_reference": {}
	}
	
	# Match context to relevant rules
	match context.to_lower():
		"combat", "attack", "shooting":
			rule_suggestions.suggested_rules = [
				"Combat Resolution (Core Rules p.71)",
				"Weapon Traits (Core Rules p.45)",
				"Cover and Concealment (Core Rules p.74)"
			]
			rule_suggestions.quick_reference = {
				"base_to_hit": "4+ on 1d6",
				"cover_penalty": "-2 to hit",
				"range_modifiers": "Point Blank +1, Short 0, Medium -1, Long -2"
			}
		
		"movement", "move":
			rule_suggestions.suggested_rules = [
				"Movement Rules (Core Rules p.68)",
				"Terrain Effects (Core Rules p.76)",
				"Climbing and Jumping (Core Rules p.69)"
			]
			rule_suggestions.quick_reference = {
				"base_movement": "6 inches per turn",
				"difficult_terrain": "Costs double movement",
				"running": "Double movement, cannot shoot"
			}
		
		"injury", "casualty":
			rule_suggestions.suggested_rules = [
				"Injury Tables (Core Rules p.85)",
				"Medical Treatment (Core Rules p.88)",
				"Character Recovery (Core Rules p.142)"
			]
			rule_suggestions.quick_reference = {
				"injury_roll": "Roll 1d100 on injury table",
				"medical_aid": "+1 to recovery rolls",
				"natural_healing": "1 week per injury level"
			}
	
	return {"type": "rules_found", "suggestions": rule_suggestions}

## Batch automation for multiple actions (with confirmation)
func execute_batch_automation(actions: Array) -> Dictionary:
	if current_automation_level < AutomationLevel.GUIDED_PLAY:
		return {"type": "batch_not_available"}
	
	var batch_result = {
		"actions": [],
		"confirmations_needed": [],
		"completed": [],
		"failed": []
	}
	
	for action in actions:
		var result = _process_single_automation(action)
		
		if result.get("requires_confirmation", false):
			batch_result.confirmations_needed.append(result)
		elif result.get("success", false):
			batch_result.completed.append(result)
		else:
			batch_result.failed.append(result)
	
	return batch_result

## User confirmation handler
func confirm_automation_action(action_id: String, confirmed: bool, parameters: Dictionary = {}) -> Dictionary:
	if not confirmed:
		_log_automation_action("action_declined", {"action_id": action_id})
		return {"type": "action_declined", "action_id": action_id}
	
	# Execute the confirmed action
	var result = _execute_confirmed_action(action_id, parameters)
	_log_automation_action("action_confirmed", {"action_id": action_id, "result": result})
	
	automation_completed.emit(action_id, result)
	return result

## Private helper methods

func _disable_all_automation() -> void:
	dice_system.auto_roll_enabled = false
	dice_system.allow_manual_override = true

func _enable_dice_assistance_only() -> void:
	dice_system.auto_roll_enabled = true
	dice_system.allow_manual_override = true

func _enable_basic_automation() -> void:
	_enable_dice_assistance_only()
	enable_rule_suggestions = true

func _enable_guided_automation() -> void:
	_enable_basic_automation()
	always_confirm_actions = true

func _enable_full_automation() -> void:
	_enable_guided_automation()
	# Note: Still requires confirmation for major actions

func _calculate_combat_steps(attacker: Dictionary, target: Dictionary) -> Array:
	var steps = []
	
	# Base calculations
	var base_skill = attacker.get("combat_skill", 0)
	steps.append("Base Combat Skill: %d" % base_skill)
	
	# Weapon modifiers
	var weapon = attacker.get("weapon", {})
	if weapon.has("accuracy_bonus"):
		steps.append("Weapon Accuracy: +%d" % weapon.accuracy_bonus)
	
	# Range modifiers
	var distance = attacker.get("distance_to_target", 0)
	if distance > 0:
		var range_mod = _get_range_modifier(distance)
		steps.append("Range (%d\"): %d" % [distance, range_mod])
	
	# Cover
	if target.get("in_cover", false):
		steps.append("Target in Cover: -2")
	
	return steps

func _calculate_terrain_penalty(start: Vector2, end: Vector2, terrain_map: Array) -> Dictionary:
	# TODO: Implement proper terrain penalty calculation
	return {
		"penalties": [],
		"additional_cost": 0,
		"steps": ["No terrain penalties calculated"]
	}

func _check_terrain_blocking(from: Vector2, to: Vector2, terrain_map: Array) -> Array:
	# TODO: Implement proper LOS blocking calculation
	return []

func _get_range_modifier(distance: float) -> int:
	if distance <= 6:
		return 1 # Point blank
	elif distance <= 12:
		return 0 # Short
	elif distance <= 24:
		return -1 # Medium
	else:
		return -2 # Long

func _process_single_automation(action: Dictionary) -> Dictionary:
	# TODO: Implement individual action processing
	return {"success": false, "requires_confirmation": true}

func _execute_confirmed_action(action_id: String, parameters: Dictionary) -> Dictionary:
	# TODO: Implement confirmed action execution
	return {"type": "action_executed", "action_id": action_id}

func _log_automation_action(action_type: String, details: Dictionary) -> void:
	var log_entry = {
		"timestamp": Time.get_ticks_msec(),
		"action_type": action_type,
		"details": details,
		"automation_level": AutomationLevel.keys()[current_automation_level]
	}
	
	automation_history.append(log_entry)
	
	# Keep history manageable
	if automation_history.size() > 100:
		automation_history = automation_history.slice(-100)

## Export settings for saving
func export_settings() -> Dictionary:
	return {
		"automation_level": current_automation_level,
		"always_confirm_actions": always_confirm_actions,
		"show_calculation_steps": show_calculation_steps,
		"enable_rule_suggestions": enable_rule_suggestions,
		"accessibility_mode": accessibility_mode,
		"dice_settings": dice_system.save_settings()
	}

## Import settings from save
func import_settings(settings: Dictionary) -> void:
	current_automation_level = settings.get("automation_level", AutomationLevel.DICE_ASSISTANCE)
	always_confirm_actions = settings.get("always_confirm_actions", true)
	show_calculation_steps = settings.get("show_calculation_steps", true)
	enable_rule_suggestions = settings.get("enable_rule_suggestions", true)
	accessibility_mode = settings.get("accessibility_mode", false)
	
	if settings.has("dice_settings"):
		# TODO: Implement dice system settings import
		pass