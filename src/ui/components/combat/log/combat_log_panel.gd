@tool
extends PanelContainer

## Signals
signal log_entry_selected(entry: Dictionary)
signal log_cleared

## Node references - SPRINT 5 FIX: Use get_node_or_null to avoid errors in tests
@onready var log_list: ItemList = get_node_or_null("%LogList")
@onready var clear_button: Button = get_node_or_null("%ClearButton")
@onready var filter_options: OptionButton = get_node_or_null("%FilterOptions")
@onready var auto_scroll_check: CheckBox = get_node_or_null("%AutoScrollCheck")

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
		# Only connect signals if nodes exist (for testing without full scene)
		if clear_button:
			clear_button.pressed.connect(_on_clear_pressed)
		if filter_options:
			filter_options.item_selected.connect(_on_filter_changed)
		if auto_scroll_check:
			auto_scroll_check.toggled.connect(_on_auto_scroll_toggled)
		if log_list:
			log_list.item_selected.connect(_on_entry_selected)

		if filter_options:
			_setup_filter_options()
		clear_log()

## Sets up the filter dropdown options

func _setup_filter_options() -> void:
	if not filter_options:
		return
	filter_options.clear()
	for key in FILTER_OPTIONS:
		filter_options.add_item(FILTER_OPTIONS[key], filter_options.item_count)
		filter_options.set_item_metadata(filter_options.item_count - 1, key)

## Adds a new entry to the combat log

func add_log_entry(entry_type: String, message: String, details: Dictionary = {}) -> void:
	var timestamp := Time.get_datetime_string_from_system()
	var entry := {
		"_type": entry_type,
		"message": message,
		"details": details,
		"timestamp": timestamp
	}
	log_entries.append(entry)
	if log_entries.size() > max_entries:
		log_entries.pop_front()

	if _should_show_entry(entry):
		_add_entry_to_list(entry)

	if auto_scroll and log_list:
		log_list.ensure_current_is_visible()

## Adds an entry to the visible list if it matches the current filter
func _add_entry_to_list(entry: Dictionary) -> void:
	if not log_list:
		return  # Skip UI update if log_list not available (testing mode)
	
	var entry_type = entry.get("_type", entry.get("type", ""))
	var icon := _get_entry_icon(entry_type)
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
	if log_list:
		log_list.clear()
	log_cleared.emit()

## Called when the clear button is pressed
func _on_clear_pressed() -> void:
	clear_log()

## Called when the filter option changes

func _on_filter_changed(index: int) -> void:
	if filter_options:
		current_filter = filter_options.get_item_metadata(index)
	_refresh_log_display()

## Called when auto-scroll is toggled

func _on_auto_scroll_toggled(enabled: bool) -> void:
	auto_scroll = enabled

## Called when a log entry is selected

func _on_entry_selected(index: int) -> void:
	if not log_list:
		return
	var entry = log_list.get_item_metadata(index)
	log_entry_selected.emit(entry) # warning: return value discarded (intentional)

## Refreshes the log display with current filter
func _refresh_log_display() -> void:
	if not log_list:
		return
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

func log_modifier(source: String, _value: int, description: String) -> void:
	var msg := "%s: %+d (%s)" % [source, _value, description]
	var details := {
		"source": source,
		"_value": _value,
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

## Adds an enhanced combat result entry with full BBCode formatting

func log_combat_result(attacker: String, target: String, result: Dictionary) -> void:
	var msg := _format_combat_result(attacker, target, result)
	add_log_entry("result", msg, result)

## Formats combat result with complete breakdown
func _format_combat_result(attacker: String, target: String, result: Dictionary) -> String:
	var lines: PackedStringArray = []

	# Header
	lines.append("%s attacks %s" % [attacker, target])

	# Hit/Miss determination with roll breakdown
	if result.has("hit"):
		var hit_line := _format_hit_miss(result)
		lines.append(hit_line)

	# Modifier breakdown (if any modifiers present)
	var modifier_line := _format_modifiers(result)
	if not modifier_line.is_empty():
		lines.append(modifier_line)

	# Damage breakdown (only if hit)
	if result.get("hit", false):
		var damage_line := _format_damage(result)
		if not damage_line.is_empty():
			lines.append(damage_line)

		# Armor/Screen/Shield saves
		var save_line := _format_saves(result)
		if not save_line.is_empty():
			lines.append(save_line)

		# Wounds and elimination
		var wound_line := _format_wounds(result)
		if not wound_line.is_empty():
			lines.append(wound_line)

	# Special effects
	var effects_line := _format_effects(result)
	if not effects_line.is_empty():
		lines.append(effects_line)

	return " | ".join(lines)

## Formats hit/miss with roll vs threshold
func _format_hit_miss(result: Dictionary) -> String:
	var hit: bool = result.get("hit", false)
	var hit_roll: int = result.get("hit_roll", 0)
	var modified_roll: int = result.get("modified_hit_roll", hit_roll)
	var threshold: int = result.get("hit_threshold", 5)

	if hit:
		if modified_roll == hit_roll:
			return "[color=#10B981]HIT![/color] Rolled %d vs %d+" % [hit_roll, threshold]
		else:
			return "[color=#10B981]HIT![/color] Rolled %d = %d vs %d+" % [hit_roll, modified_roll, threshold]
	else:
		return "[color=#DC2626]MISS![/color] Rolled %d, needed %d+" % [hit_roll, threshold]

## Formats modifier breakdown
func _format_modifiers(result: Dictionary) -> String:
	var mods: PackedStringArray = []

	# Range bonus
	if result.has("mod_range_bonus"):
		var range_band: String = result.get("range_band", "")
		var bonus: int = result.get("mod_range_bonus", 0)
		if bonus != 0:
			mods.append("+%d range (%s)" % [bonus, range_band])

	# Targeting bonus (armor_hit_bonus)
	if result.has("armor_hit_bonus"):
		var bonus: int = result.get("armor_hit_bonus", 0)
		if bonus != 0:
			mods.append("+%d targeting" % bonus)

	# Camouflage penalty
	if result.has("camouflage_penalty"):
		var penalty: int = result.get("camouflage_penalty", 0)
		if penalty != 0:
			mods.append("-%d camouflage" % penalty)

	# Battle visor reroll
	if result.get("battle_visor_used", false):
		var reroll: int = result.get("battle_visor_reroll", 0)
		mods.append("Battle Visor reroll: 1 → %d" % reroll)

	if mods.is_empty():
		return ""
	return "Modifiers: " + ", ".join(mods)

## Formats damage breakdown
func _format_damage(result: Dictionary) -> String:
	var damage_roll: int = result.get("damage_roll", 0)
	if damage_roll == 0:
		return ""

	var parts: PackedStringArray = []
	parts.append("Damage: Rolled %d" % damage_roll)

	# Weapon modification damage bonus
	if result.has("weapon_mod_damage_bonus"):
		var bonus: int = result.get("weapon_mod_damage_bonus", 0)
		if bonus != 0:
			var total: int = damage_roll + bonus
			parts.append("+ %d weapon = %d" % [bonus, total])

	return " ".join(parts)

## Formats save results (armor/screen/shield)
func _format_saves(result: Dictionary) -> String:
	# Shield block check
	if result.get("shield_blocked", false):
		return "[color=#4FC3F7]Shield blocked![/color]"

	# Check for piercing bypassing armor
	var effects: Array = result.get("effects", [])
	if "armor_pierced" in effects:
		return "[color=#D97706]Piercing weapon bypassed armor[/color]"

	# Screen save
	if result.get("screen_saved", false):
		return "[color=#4FC3F7]Screen Save![/color]"

	# Armor save
	if result.get("armor_saved", false):
		var armor_roll: int = result.get("armor_roll", 0)
		return "[color=#4FC3F7]Armor Save![/color] Rolled %d" % armor_roll

	return ""

## Formats wound/elimination results
func _format_wounds(result: Dictionary) -> String:
	var effects: Array = result.get("effects", [])

	# Auto-medicator negation
	if "auto_medicator_negated_wound" in effects:
		return "[color=#10B981]Auto-Medicator negated wound![/color]"

	# Target eliminated
	if result.get("target_eliminated", false):
		return "[color=#DC2626]TARGET ELIMINATED![/color]"

	# Wounds inflicted
	var wounds: int = result.get("wounds_inflicted", 0)
	if wounds > 0:
		return "[color=#D97706]%d wound inflicted[/color]" % wounds

	return ""

## Formats special effects
func _format_effects(result: Dictionary) -> String:
	var effects: Array = result.get("effects", [])
	if effects.is_empty():
		return ""

	var formatted: PackedStringArray = []

	for effect in effects:
		match effect:
			"stunned":
				formatted.append("Stunned")
			"push_back":
				formatted.append("Pushed 1\"")
			"suppressed":
				formatted.append("Suppressed")
			"critical_extra_hit":
				var wounds: int = result.get("wounds_inflicted", 2)
				return "Critical: %d Hits" % wounds
			"eliminated", "armor_pierced", "shield_blocked", "screen_deflected", "auto_medicator_negated_wound":
				# These are handled elsewhere, skip
				pass
			_:
				# Unknown effect, format it nicely
				formatted.append(effect.replace("_", " ").capitalize())

	if formatted.is_empty():
		return ""

	return "Effects: " + ", ".join(formatted)

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
	for i: int in range(0, entries_to_display.size(), chunk_size):
		var chunk := entries_to_display.slice(i, i + chunk_size)
		for entry in chunk:
			_add_entry_to_list(entry)
		await get_tree().process_frame

## Checks if an entry should be displayed based on current filters
func _should_display_entry(entry: Dictionary) -> bool:
	if filter_types.get("all", true):
		return true
	return filter_types.get(entry.get("type", ""), true)

