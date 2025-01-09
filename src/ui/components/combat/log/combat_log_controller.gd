@tool
extends Node

## Signals
signal entry_selected(entry: Dictionary)
signal context_action_requested(action: String, entry: Dictionary)
signal verification_requested(entry: Dictionary)

## Node references
@onready var combat_log: PanelContainer = %CombatLogPanel

## Properties
var combat_resolver: Node = null
var combat_manager: Node = null
var override_controller: Node = null
var house_rules_panel: Node = null
var active_filters: Array[String] = []
var max_history: int = 1000

## Called when the node enters scene tree
func _ready() -> void:
	if not Engine.is_editor_hint():
		combat_log.log_entry_selected.connect(_on_log_entry_selected)
		combat_log.log_cleared.connect(_on_log_cleared)

## Sets up combat system references
func setup_combat_system(resolver: Node, manager: Node, override_ctrl: Node, rules_panel: Node) -> void:
	combat_resolver = resolver
	combat_manager = manager
	override_controller = override_ctrl
	house_rules_panel = rules_panel
	
	# Connect combat system signals
	if combat_resolver:
		combat_resolver.dice_roll_requested.connect(_on_dice_roll_requested)
		combat_resolver.dice_roll_completed.connect(_on_dice_roll_completed)
		combat_resolver.override_requested.connect(_on_override_requested)
		combat_resolver.modifier_applied.connect(_on_modifier_applied)
	
	if combat_manager:
		combat_manager.combat_state_changed.connect(_on_combat_state_changed)
		combat_manager.combat_action_completed.connect(_on_combat_action_completed)
		combat_manager.critical_hit.connect(_on_critical_hit)
	
	if override_controller:
		override_controller.override_applied.connect(_on_override_applied)
		override_controller.override_cancelled.connect(_on_override_cancelled)
	
	if house_rules_panel:
		house_rules_panel.rule_added.connect(_on_house_rule_added)
		house_rules_panel.rule_modified.connect(_on_house_rule_modified)
		house_rules_panel.rule_removed.connect(_on_house_rule_removed)

## Adds a combat event to the log
func log_combat_event(event_type: String, message: String, details: Dictionary = {}) -> void:
	if should_log_event(event_type):
		combat_log.add_log_entry(event_type, message, details)

## Checks if event should be logged based on filters
func should_log_event(event_type: String) -> bool:
	if active_filters.is_empty():
		return true
	return event_type in active_filters

## Updates active filters
func update_filters(filters: Array[String]) -> void:
	active_filters = filters
	# TODO: Refresh log display based on new filters

## Clears the combat log
func clear_log() -> void:
	combat_log.clear_log()

## Exports log to dictionary
func export_log() -> Dictionary:
	return {
		"timestamp": Time.get_datetime_string_from_system(),
		"entries": combat_log.log_entries
	}

## Signal handlers for combat system
func _on_dice_roll_requested(context: String, modifiers: Dictionary) -> void:
	var msg = "Rolling for %s" % context
	if not modifiers.is_empty():
		msg += " with modifiers"
	log_combat_event("roll", msg, {"context": context, "modifiers": modifiers})

func _on_dice_roll_completed(context: String, result: int) -> void:
	log_combat_event("roll", "Roll result for %s: %d" % [context, result],
		{"context": context, "result": result})

func _on_override_requested(context: String, current_value: int) -> void:
	log_combat_event("override", "Manual override requested for %s (Current: %d)" % [context, current_value],
		{"context": context, "current_value": current_value})

func _on_override_applied(context: String, value: int) -> void:
	log_combat_event("override", "Manual override applied to %s: %d" % [context, value],
		{"context": context, "value": value})

func _on_override_cancelled(context: String) -> void:
	log_combat_event("override", "Manual override cancelled for %s" % context,
		{"context": context})

func _on_modifier_applied(source: String, value: int, description: String) -> void:
	combat_log.log_modifier(source, value, description)

func _on_combat_state_changed(new_state: Dictionary) -> void:
	log_combat_event("state", "Combat state updated", {"state": new_state})

func _on_combat_action_completed(action: Dictionary) -> void:
	var msg = "Completed action: %s" % action.get("type", "Unknown")
	log_combat_event("action", msg, action)

func _on_critical_hit(attacker: String, target: String, multiplier: float) -> void:
	combat_log.log_critical_hit(attacker, target, multiplier)

## Signal handlers for house rules
func _on_house_rule_added(rule: Dictionary) -> void:
	log_combat_event("rule", "House rule added: %s" % rule.name, rule)

func _on_house_rule_modified(rule: Dictionary) -> void:
	log_combat_event("rule", "House rule modified: %s" % rule.name, rule)

func _on_house_rule_removed(rule_id: String) -> void:
	log_combat_event("rule", "House rule removed: %s" % rule_id, {"id": rule_id})

## Signal handlers for log interaction
func _on_log_entry_selected(entry: Dictionary) -> void:
	entry_selected.emit(entry)

func _on_log_cleared() -> void:
	# Handle any cleanup needed when log is cleared
	pass

## Context action handlers
func handle_context_action(action: String, entry: Dictionary) -> void:
	match action:
		"verify":
			verification_requested.emit(entry)
		"override":
			if entry.type == "roll" and override_controller:
				override_controller.request_override(
					entry.details.context,
					entry.details.get("result", 0)
				)
		_:
			context_action_requested.emit(action, entry)