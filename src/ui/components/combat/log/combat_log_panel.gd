@tool
extends PanelContainer

## Signals
signal log_entry_selected(entry: Dictionary)
signal log_cleared

## Node references
@onready var log_list: ItemList = %LogList
@onready var clear_button: Button = %ClearButton
@onready var filter_options: OptionButton = %FilterOptions
@onready var auto_scroll_check: CheckBox = %AutoScrollCheck

## Properties
var max_entries: int = 100
var auto_scroll: bool = true
var current_filter: String = "all"
var log_entries: Array[Dictionary] = []

## Filter options
const FILTER_OPTIONS = {
	"all": "All Events",
	"attack": "Attacks",
	"damage": "Damage",
	"modifier": "Modifiers",
	"override": "Overrides",
	"critical": "Critical Hits"
}

## Entry filter types
var filter_types := {
	"all": true,
	"combat": true,
	"ability": true,
	"reaction": true,
	"area": true,
	"damage": true,
	"modifier": true,
	"critical": true,
	"override": true,
	"result": true
}

## Called when the node enters the scene tree
func _ready() -> void:
	if not Engine.is_editor_hint():
		clear_button.pressed.connect(_on_clear_pressed)
		filter_options.item_selected.connect(_on_filter_changed)
		auto_scroll_check.toggled.connect(_on_auto_scroll_toggled)
		log_list.item_selected.connect(_on_entry_selected)
		
		_setup_filter_options()
		clear_log()

## Sets up the filter dropdown options
func _setup_filter_options() -> void:
	filter_options.clear()
	for key in FILTER_OPTIONS:
		filter_options.add_item(FILTER_OPTIONS[key], filter_options.item_count)
		filter_options.set_item_metadata(filter_options.item_count - 1, key)

## Adds a new entry to the combat log
func add_log_entry(entry_type: String, message: String, details: Dictionary = {}) -> void:
	var timestamp := Time.get_datetime_string_from_system()
	var entry := {
		"type": entry_type,
		"message": message,
		"details": details,
		"timestamp": timestamp
	}
	
	log_entries.append(entry)
	if log_entries.size() > max_entries:
		log_entries.pop_front()
	
	if _should_show_entry(entry):
		_add_entry_to_list(entry)
	
	if auto_scroll:
		log_list.ensure_current_is_visible()

## Adds an entry to the visible list if it matches the current filter
func _add_entry_to_list(entry: Dictionary) -> void:
	var icon := _get_entry_icon(entry.type)
	var text := "[%s] %s" % [entry.timestamp.split(" ")[1], entry.message]
	
	log_list.add_item(text, icon)
	log_list.set_item_metadata(log_list.item_count - 1, entry)

## Returns the appropriate icon for the entry type
func _get_entry_icon(entry_type: String) -> Texture2D:
	# TODO: Return appropriate icons based on entry type
	return null

## Checks if an entry should be shown based on current filter
func _should_show_entry(entry: Dictionary) -> bool:
	if current_filter == "all":
		return true
	return entry.type == current_filter

## Clears the combat log
func clear_log() -> void:
	log_entries.clear()
	log_list.clear()
	log_cleared.emit()

## Called when the clear button is pressed
func _on_clear_pressed() -> void:
	clear_log()

## Called when the filter option changes
func _on_filter_changed(index: int) -> void:
	current_filter = filter_options.get_item_metadata(index)
	_refresh_log_display()

## Called when auto-scroll is toggled
func _on_auto_scroll_toggled(enabled: bool) -> void:
	auto_scroll = enabled

## Called when a log entry is selected
func _on_entry_selected(index: int) -> void:
	var entry = log_list.get_item_metadata(index)
	log_entry_selected.emit(entry)

## Refreshes the log display with current filter
func _refresh_log_display() -> void:
	log_list.clear()
	for entry in log_entries:
		if _should_show_entry(entry):
			_add_entry_to_list(entry)

## Adds an attack roll entry
func log_attack_roll(attacker: String, target: String, roll: int, modifiers: Dictionary) -> void:
	var msg := "%s attacks %s (Roll: %d)" % [attacker, target, roll]
	var details := {
		"roll": roll,
		"modifiers": modifiers,
		"attacker": attacker,
		"target": target
	}
	add_log_entry("attack", msg, details)

## Adds a damage entry
func log_damage(target: String, damage: int, source: String) -> void:
	var msg := "%s takes %d damage from %s" % [target, damage, source]
	var details := {
		"target": target,
		"damage": damage,
		"source": source
	}
	add_log_entry("damage", msg, details)

## Adds a modifier entry
func log_modifier(source: String, value: int, description: String) -> void:
	var msg := "%s: %+d (%s)" % [source, value, description]
	var details := {
		"source": source,
		"value": value,
		"description": description
	}
	add_log_entry("modifier", msg, details)

## Adds an override entry
func log_override(context: String, original: int, new: int) -> void:
	var msg := "Manual override: %s (%d → %d)" % [context, original, new]
	var details := {
		"context": context,
		"original": original,
		"new": new
	}
	add_log_entry("override", msg, details)

## Adds a critical hit entry
func log_critical_hit(attacker: String, target: String, multiplier: float) -> void:
	var msg := "CRITICAL HIT! %s hits %s (x%.1f)" % [attacker, target, multiplier]
	var details := {
		"attacker": attacker,
		"target": target,
		"multiplier": multiplier
	}
	add_log_entry("critical", msg, details)

## Adds a special ability entry
func log_special_ability(character: String, ability: String, targets: Array, cooldown: int) -> void:
	var msg := "%s uses %s" % [character, ability]
	if not targets.is_empty():
		msg += " on " + ", ".join(targets)
	msg += " (Cooldown: %d)" % cooldown
	var details := {
		"character": character,
		"ability": ability,
		"targets": targets,
		"cooldown": cooldown
	}
	add_log_entry("ability", msg, details)

## Adds a reaction entry
func log_reaction(character: String, reaction: String, trigger: String) -> void:
	var msg := "%s reacts with %s to %s" % [character, reaction, trigger]
	var details := {
		"character": character,
		"reaction": reaction,
		"trigger": trigger
	}
	add_log_entry("reaction", msg, details)

## Adds an area effect entry
func log_area_effect(effect: String, center: Vector2, radius: float, affected: Array) -> void:
	var msg := "%s affects %d targets in %.1f radius" % [effect, affected.size(), radius]
	var details := {
		"effect": effect,
		"center": center,
		"radius": radius,
		"affected": affected
	}
	add_log_entry("area", msg, details)

## Adds an enhanced combat result entry
func log_combat_result(attacker: String, target: String, result: Dictionary) -> void:
	var msg := "Combat Result: %s vs %s" % [attacker, target]
	if result.has("hit"):
		msg += " - " + ("Hit!" if result.hit else "Miss!")
	if result.has("damage"):
		msg += " (%d damage)" % result.damage
	if result.has("effects"):
		msg += " Effects: " + ", ".join(result.effects)
	
	add_log_entry("result", msg, result)

## Updates the display with performance optimizations
func _update_display() -> void:
	if log_entries.size() > 1000:
		# Trim old entries to maintain performance
		log_entries = log_entries.slice(-1000)
	
	# Batch update the display
	var entries_to_display := []
	for entry in log_entries:
		if _should_display_entry(entry):
			entries_to_display.append(entry)
	
	# Update in chunks to avoid freezing
	var chunk_size := 50
	for i in range(0, entries_to_display.size(), chunk_size):
		var chunk := entries_to_display.slice(i, i + chunk_size)
		for entry in chunk:
			_add_entry_to_list(entry)
		await get_tree().process_frame

## Checks if an entry should be displayed based on current filters
func _should_display_entry(entry: Dictionary) -> bool:
	if filter_types.get("all", true):
		return true
	return filter_types.get(entry.get("type", ""), true)