class_name FPCM_BattleJournal
extends PanelContainer

## Battle Journal
##
## Records events during battle for narrative review.
## Tracks key moments, casualties, objectives, and notable actions.

# Signals
signal entry_added(entry: Dictionary)
signal journal_cleared()
signal entry_undone(entry: Dictionary)

# Keyword system
const BattleKeywordDBClass = preload("res://src/core/battle/BattleKeywordDB.gd")
var _keyword_db: BattleKeywordDBClass = null

# UI References
@onready var title_label: Label = $VBox/TitleLabel
@onready var round_label: Label = $VBox/RoundLabel
@onready var entries_container: VBoxContainer = $VBox/ScrollContainer/EntriesContainer
@onready var entry_count_label: Label = $VBox/EntryCountLabel

# Journal state
var entries: Array[Dictionary] = []
var current_round: int = 1
var battle_started: bool = false
var _active_filter: String = "all"  # "all", "combat", "event", "morale"
var _undo_stack: Array[Dictionary] = []
const MAX_UNDO_DEPTH: int = 10

# Entry types with colors
const ENTRY_COLORS := {
	"round": Color.WHITE,
	"objective": Color.MEDIUM_PURPLE,
	"casualty_crew": UIColors.COLOR_RED,
	"casualty_enemy": UIColors.COLOR_AMBER,
	"event": Color.GOLD,
	"morale": Color.INDIAN_RED,
	"initiative": UIColors.COLOR_CYAN,
	"action": Color.LIGHT_GRAY,
	"victory": UIColors.COLOR_EMERALD,
	"defeat": Color.DARK_RED
}

func _ready() -> void:
	_keyword_db = BattleKeywordDBClass.new()
	_setup_panel_style()
	_update_display()

func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 3
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color.SLATE_GRAY
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

## Start a new battle
func start_battle(objective_name: String = "") -> void:
	clear()
	battle_started = true
	current_round = 1

	add_entry("round", "Battle Begins")

	if not objective_name.is_empty():
		add_entry("objective", "Objective: %s" % objective_name)

## Add a journal entry
func add_entry(entry_type: String, text: String, details: String = "") -> void:
	var entry := {
		"type": entry_type,
		"text": text,
		"details": details,
		"round": current_round,
		"timestamp": Time.get_ticks_msec()
	}

	entries.append(entry)
	_add_entry_to_display(entry)
	entry_added.emit(entry)

## Add a round marker
func new_round() -> void:
	current_round += 1
	add_entry("round", "Round %d" % current_round)
	if round_label:
		round_label.text = "Round %d" % current_round

## Log crew casualty
func log_crew_casualty(character_name: String, cause: String = "") -> void:
	var text := "%s goes down" % character_name
	add_entry("casualty_crew", text, cause)

## Log enemy casualty
func log_enemy_casualty(enemy_name: String, killer: String = "") -> void:
	var text := "%s eliminated" % enemy_name
	var details := "by %s" % killer if not killer.is_empty() else ""
	add_entry("casualty_enemy", text, details)

## Log battle event
func log_event(event_name: String, description: String = "") -> void:
	add_entry("event", event_name, description)

## Log morale check
func log_morale(result: String, fled: int = 0) -> void:
	var text := "Morale: %s" % result
	var details := "%d enemies fled" % fled if fled > 0 else ""
	add_entry("morale", text, details)

## Log initiative result
func log_initiative(success: bool, total: int) -> void:
	var text := "Initiative: %s (rolled %d)" % ["Seized!" if success else "Failed", total]
	add_entry("initiative", text)

## Log action
func log_action(character_name: String, action: String) -> void:
	var text := "%s: %s" % [character_name, action]
	add_entry("action", text)

## Log victory
func log_victory(reason: String = "") -> void:
	var text := "VICTORY!"
	add_entry("victory", text, reason)

## Log defeat
func log_defeat(reason: String = "") -> void:
	var text := "DEFEAT"
	add_entry("defeat", text, reason)

## Clear the journal
func clear() -> void:
	entries.clear()
	current_round = 1
	battle_started = false

	if entries_container:
		for child in entries_container.get_children():
			child.queue_free()

	_update_display()
	journal_cleared.emit()

## Get all entries
func get_entries() -> Array[Dictionary]:
	return entries

## Get summary text
func get_summary() -> String:
	var summary := "Battle Journal\n"
	summary += "==============\n\n"

	var crew_casualties := 0
	var enemy_casualties := 0
	var events_count := 0

	for entry in entries:
		match entry.type:
			"casualty_crew":
				crew_casualties += 1
			"casualty_enemy":
				enemy_casualties += 1
			"event":
				events_count += 1

		summary += "• %s\n" % entry.text
		if not entry.details.is_empty():
			summary += "  (%s)\n" % entry.details

	summary += "\n--- Summary ---\n"
	summary += "Rounds: %d\n" % current_round
	summary += "Crew casualties: %d\n" % crew_casualties
	summary += "Enemy casualties: %d\n" % enemy_casualties
	summary += "Events: %d\n" % events_count

	return summary

func _add_entry_to_display(entry: Dictionary) -> void:
	if not entries_container:
		return

	var container := VBoxContainer.new()

	# Entry text - use RichTextLabel for keyword hints
	var text_label := RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.scroll_active = false
	var display_text: String = entry.text
	if _keyword_db:
		display_text = _keyword_db.parse_text_for_keywords(display_text)
	text_label.text = display_text
	text_label.add_theme_font_size_override("normal_font_size", 12)

	var color = ENTRY_COLORS.get(entry.type, Color.WHITE)
	text_label.add_theme_color_override("default_color", color)

	container.add_child(text_label)

	# Details if present
	if not entry.details.is_empty():
		var details_label := Label.new()
		details_label.text = "  %s" % entry.details
		details_label.add_theme_font_size_override("font_size", 10)
		details_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
		container.add_child(details_label)

	entries_container.add_child(container)

	# Auto-scroll to bottom
	await get_tree().process_frame
	var scroll = entries_container.get_parent()
	if scroll is ScrollContainer:
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

	_update_display()

func _update_display() -> void:
	if round_label:
		round_label.text = "Round %d" % current_round

	if entry_count_label:
		entry_count_label.text = "%d entries" % entries.size()

# =====================================================
# UNDO SUPPORT
# =====================================================

## Undo the last journal entry.
func undo_last_entry() -> Dictionary:
	if entries.is_empty():
		return {}

	var undone: Dictionary = entries.pop_back()
	undone["undone"] = true
	_undo_stack.append(undone)
	if _undo_stack.size() > MAX_UNDO_DEPTH:
		_undo_stack.pop_front()

	# Rebuild display
	_rebuild_display()
	entry_undone.emit(undone)
	return undone

## Get undo stack for review.
func get_undo_stack() -> Array[Dictionary]:
	return _undo_stack.duplicate()

# =====================================================
# EXPORT
# =====================================================

## Export journal as readable text narrative.
func export_narrative() -> String:
	var narrative := "=== Battle Journal ===\n\n"
	var last_round := 0

	for entry: Dictionary in entries:
		var entry_round: int = entry.get("round", 0)
		if entry_round != last_round and entry.type != "round":
			narrative += "\n"
			last_round = entry_round

		if entry.type == "round":
			narrative += "\n--- %s ---\n" % entry.text
		else:
			narrative += "  %s" % entry.text
			if not entry.details.is_empty():
				narrative += " (%s)" % entry.details
			narrative += "\n"

	narrative += "\n" + get_summary()
	return narrative

## Copy journal export to clipboard.
func copy_to_clipboard() -> void:
	DisplayServer.clipboard_set(export_narrative())

# =====================================================
# CATEGORY FILTER
# =====================================================

## Set active filter category.
## Valid: "all", "combat", "event", "morale"
func set_filter(category: String) -> void:
	_active_filter = category
	_rebuild_display()

## Get current filter.
func get_filter() -> String:
	return _active_filter

## Check if entry matches current filter.
func _matches_filter(entry: Dictionary) -> bool:
	if _active_filter == "all":
		return true
	match _active_filter:
		"combat":
			return entry.type in ["casualty_crew", "casualty_enemy", "action", "initiative"]
		"event":
			return entry.type in ["event", "round", "victory", "defeat"]
		"morale":
			return entry.type in ["morale"]
	return true

## Rebuild the display from entries (used after undo or filter change).
func _rebuild_display() -> void:
	if not entries_container:
		return

	for child in entries_container.get_children():
		child.queue_free()

	for entry: Dictionary in entries:
		if _matches_filter(entry):
			_add_entry_to_display(entry)

	_update_display()
