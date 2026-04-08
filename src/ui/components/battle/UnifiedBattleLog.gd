class_name FPCM_UnifiedBattleLog
extends PanelContainer

## Unified Battle Log — merges realtime feed + structured journal
##
## Two views:
## - "Live" — scrolling BBCode feed (replaces FallbackLog)
## - "Journal" — structured entries with filtering (replaces BattleJournal)
##
## Exposes the same API as BattleJournal so all signal connections work.

signal entry_added(entry: Dictionary)
signal journal_cleared()

# Design tokens
const SPACING_SM: int = UIColors.SPACING_SM
const SPACING_MD: int = UIColors.SPACING_MD
const FONT_SIZE_SM: int = UIColors.FONT_SIZE_SM
const FONT_SIZE_MD: int = UIColors.FONT_SIZE_MD
const FONT_SIZE_LG: int = UIColors.FONT_SIZE_LG
const COLOR_BASE: Color = UIColors.COLOR_BASE
const COLOR_ELEVATED: Color = UIColors.COLOR_ELEVATED
const COLOR_BORDER: Color = UIColors.COLOR_BORDER
const COLOR_ACCENT: Color = UIColors.COLOR_ACCENT
const COLOR_TEXT_PRIMARY: Color = UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY: Color = UIColors.COLOR_TEXT_SECONDARY
const TOUCH_TARGET_MIN: int = UIColors.TOUCH_TARGET_MIN

# Entry type colors (matching BattleJournal)
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
	"defeat": Color.DARK_RED,
	"dice": UIColors.COLOR_AMBER,
	# Equipment effects (Session 47)
	"armor_save": Color.STEEL_BLUE,
	"deflector_field": UIColors.COLOR_CYAN,
	"stim_pack": UIColors.COLOR_EMERALD,
	"trait_effect": Color.SANDY_BROWN,
	"item_consumed": UIColors.COLOR_RED,
}

# Keyword system (from BattleJournal)
const BattleKeywordDBClass = preload(
	"res://src/core/battle/BattleKeywordDB.gd"
)
var _keyword_db: BattleKeywordDBClass = null

# State
var entries: Array[Dictionary] = []
var current_round: int = 1
var battle_started: bool = false
var _active_filter: String = "all"
var _show_live: bool = true  # true = Live feed, false = Journal view

# UI nodes
var _outer_vbox: VBoxContainer
var _header_bar: HBoxContainer
var _title_label: Label
var _filter_button: OptionButton
var _view_toggle: Button
var _live_feed: RichTextLabel
var _journal_scroll: ScrollContainer
var _journal_entries: VBoxContainer
var _export_button: Button


func _ready() -> void:
	_keyword_db = BattleKeywordDBClass.new()
	_build_ui()


func _build_ui() -> void:
	# Panel style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.set_corner_radius_all(8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_BORDER
	style.set_content_margin_all(SPACING_SM)
	add_theme_stylebox_override("panel", style)

	_outer_vbox = VBoxContainer.new()
	_outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_outer_vbox.add_theme_constant_override("separation", SPACING_SM)
	add_child(_outer_vbox)

	# Header bar
	_header_bar = HBoxContainer.new()
	_header_bar.add_theme_constant_override("separation", SPACING_SM)
	_outer_vbox.add_child(_header_bar)

	_title_label = Label.new()
	_title_label.text = "Battle Log"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_header_bar.add_child(_title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_bar.add_child(spacer)

	# Filter dropdown
	_filter_button = OptionButton.new()
	_filter_button.add_item("All", 0)
	_filter_button.add_item("Combat", 1)
	_filter_button.add_item("Events", 2)
	_filter_button.add_item("Morale", 3)
	_filter_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	_filter_button.item_selected.connect(_on_filter_changed)
	_filter_button.visible = not _show_live  # Only in journal view
	_header_bar.add_child(_filter_button)

	# View toggle
	_view_toggle = Button.new()
	_view_toggle.text = "Journal"
	_view_toggle.custom_minimum_size = Vector2(80, TOUCH_TARGET_MIN)
	var toggle_style := StyleBoxFlat.new()
	toggle_style.bg_color = COLOR_ELEVATED
	toggle_style.set_corner_radius_all(4)
	toggle_style.set_content_margin_all(SPACING_SM)
	_view_toggle.add_theme_stylebox_override("normal", toggle_style)
	var toggle_hover := toggle_style.duplicate()
	toggle_hover.bg_color = COLOR_ACCENT
	_view_toggle.add_theme_stylebox_override("hover", toggle_hover)
	_view_toggle.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_view_toggle.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_view_toggle.pressed.connect(_toggle_view)
	_header_bar.add_child(_view_toggle)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", COLOR_BORDER)
	_outer_vbox.add_child(sep)

	# Live feed view (RichTextLabel — the realtime colored log)
	_live_feed = RichTextLabel.new()
	_live_feed.bbcode_enabled = true
	_live_feed.scroll_following = true
	_live_feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_live_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_live_feed.custom_minimum_size = Vector2(0, 100)
	_live_feed.add_theme_font_size_override(
		"normal_font_size", FONT_SIZE_SM
	)
	_live_feed.add_theme_color_override(
		"default_color", COLOR_TEXT_PRIMARY
	)
	_outer_vbox.add_child(_live_feed)

	# Journal view (structured entries, hidden by default)
	_journal_scroll = ScrollContainer.new()
	_journal_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_journal_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	_journal_scroll.visible = false
	_outer_vbox.add_child(_journal_scroll)

	_journal_entries = VBoxContainer.new()
	_journal_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journal_entries.add_theme_constant_override("separation", 4)
	_journal_scroll.add_child(_journal_entries)

	# Export button (journal view only)
	_export_button = Button.new()
	_export_button.text = "Export Journal"
	_export_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	_export_button.visible = false
	_export_button.pressed.connect(_on_export_pressed)
	var export_style := toggle_style.duplicate()
	_export_button.add_theme_stylebox_override("normal", export_style)
	_export_button.add_theme_color_override(
		"font_color", COLOR_TEXT_PRIMARY
	)
	_export_button.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_outer_vbox.add_child(_export_button)


# ============================================================================
# PUBLIC API — matches BattleJournal interface
# ============================================================================

## Add a live feed message (replaces FallbackLog _log_message)
func add_live_message(
	message: String,
	color: Color = Color.WHITE,
	round_num: int = -1
) -> void:
	var prefix := ""
	if round_num >= 0:
		prefix = "[R%d] " % round_num
	_live_feed.append_text(
		"[color=%s]%s%s[/color]\n" % [
			color.to_html(), prefix, message
		]
	)
	_live_feed.scroll_to_line(_live_feed.get_line_count())


## Start a new battle
func start_battle(objective_name: String = "") -> void:
	clear()
	battle_started = true
	current_round = 1
	add_entry("round", "Battle Begins")
	if not objective_name.is_empty():
		add_entry("objective", "Objective: %s" % objective_name)


## Add a structured journal entry
func add_entry(
	entry_type: String,
	text: String,
	details: String = ""
) -> void:
	var entry := {
		"type": entry_type,
		"text": text,
		"details": details,
		"round": current_round,
		"timestamp": Time.get_ticks_msec()
	}
	entries.append(entry)
	_add_entry_to_journal(entry)

	# Also echo to live feed with appropriate color
	var color: Color = ENTRY_COLORS.get(entry_type, Color.WHITE)
	var display := text
	if not details.is_empty():
		display += " (%s)" % details
	add_live_message(display, color, current_round)

	entry_added.emit(entry)


## Advance to next round
func new_round() -> void:
	current_round += 1
	add_entry("round", "Round %d" % current_round)


func set_round(round_num: int) -> void:
	current_round = round_num


## Log crew casualty
func log_crew_casualty(
	character_name: String, cause: String = ""
) -> void:
	add_entry(
		"casualty_crew",
		"%s goes down" % character_name,
		cause
	)


## Log enemy casualty
func log_enemy_casualty(
	enemy_name: String, killer: String = ""
) -> void:
	var details := "by %s" % killer if not killer.is_empty() else ""
	add_entry("casualty_enemy", "%s eliminated" % enemy_name, details)


## Log battle event
func log_event(
	event_name: String, description: String = ""
) -> void:
	add_entry("event", event_name, description)


## Log morale check
func log_morale(result: String, fled: int = 0) -> void:
	var details := "%d enemies fled" % fled if fled > 0 else ""
	add_entry("morale", "Morale: %s" % result, details)


## Log initiative result
func log_initiative(success: bool, total: int) -> void:
	var text := "Initiative: %s (rolled %d)" % [
		"Seized!" if success else "Failed", total
	]
	add_entry("initiative", text)


## Log action
func log_action(character_name: String, action: String) -> void:
	add_entry("action", "%s: %s" % [character_name, action])


## Log victory
func log_victory(reason: String = "") -> void:
	add_entry("victory", "VICTORY!", reason)


## Log defeat
func log_defeat(reason: String = "") -> void:
	add_entry("defeat", "DEFEAT", reason)


## Log armor/screen save result
func log_armor_save(
	target_name: String, save_type: String, threshold: int, roll: int, saved: bool
) -> void:
	var result_text: String = "SAVED" if saved else "FAILED"
	add_entry(
		"armor_save",
		"[%s] %s save (%d+): rolled %d — %s" % [
			target_name, save_type, threshold, roll, result_text],
	)


## Log deflector field auto-deflect
func log_deflector_use(target_name: String) -> void:
	add_entry(
		"deflector_field",
		"[Deflector Field] %s — hit automatically deflected" % target_name,
	)


## Log stim-pack preventing elimination
func log_stim_pack(target_name: String) -> void:
	add_entry(
		"stim_pack",
		"[Stim-pack] %s survives with Stun instead of elimination" % target_name,
	)


## Log weapon trait effect during combat
func log_trait_effect(
	character_name: String, trait_name: String, effect_text: String
) -> void:
	add_entry(
		"trait_effect",
		"[%s] %s — %s" % [trait_name, character_name, effect_text],
	)


## Log single-use item consumed
func log_item_consumed(
	character_name: String, item_name: String
) -> void:
	add_entry(
		"item_consumed",
		"%s consumed by %s" % [item_name, character_name],
	)


## Clear all log content
func clear() -> void:
	entries.clear()
	current_round = 1
	battle_started = false
	_live_feed.clear()
	for child in _journal_entries.get_children():
		child.queue_free()
	journal_cleared.emit()


## Get all entries
func get_entries() -> Array[Dictionary]:
	return entries


## Get summary text (for export)
func get_summary() -> String:
	var summary := "Battle Journal\n==============\n\n"
	var crew_cas := 0
	var enemy_cas := 0
	for entry in entries:
		if entry.type == "casualty_crew":
			crew_cas += 1
		elif entry.type == "casualty_enemy":
			enemy_cas += 1
		summary += "• %s\n" % entry.text
		if not entry.details.is_empty():
			summary += "  (%s)\n" % entry.details
	summary += "\n--- Summary ---\n"
	summary += "Rounds: %d\n" % current_round
	summary += "Crew casualties: %d\n" % crew_cas
	summary += "Enemy casualties: %d\n" % enemy_cas
	return summary


# ============================================================================
# INTERNAL
# ============================================================================

func _toggle_view() -> void:
	_show_live = not _show_live
	_live_feed.visible = _show_live
	_journal_scroll.visible = not _show_live
	_filter_button.visible = not _show_live
	_export_button.visible = not _show_live
	_view_toggle.text = "Journal" if _show_live else "Live"
	_title_label.text = "Battle Log" if _show_live else "Battle Journal"


func _on_filter_changed(index: int) -> void:
	match index:
		0: _active_filter = "all"
		1: _active_filter = "combat"
		2: _active_filter = "events"
		3: _active_filter = "morale"
	_rebuild_journal_display()


func _rebuild_journal_display() -> void:
	for child in _journal_entries.get_children():
		child.queue_free()
	for entry in entries:
		if _passes_filter(entry):
			_add_entry_to_journal(entry)


func _passes_filter(entry: Dictionary) -> bool:
	if _active_filter == "all":
		return true
	match _active_filter:
		"combat":
			return entry.type in [
				"casualty_crew", "casualty_enemy",
				"action", "dice"
			]
		"events":
			return entry.type in [
				"event", "objective", "round",
				"victory", "defeat"
			]
		"morale":
			return entry.type in ["morale", "initiative"]
	return true


func _add_entry_to_journal(entry: Dictionary) -> void:
	if not _passes_filter(entry):
		return

	var text_label := RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.scroll_active = false
	var display_text: String = entry.text
	if _keyword_db:
		display_text = _keyword_db.parse_text_for_keywords(
			display_text
		)
	if not entry.get("details", "").is_empty():
		display_text += " [color=#808080](%s)[/color]" % entry.details

	text_label.text = display_text
	text_label.add_theme_font_size_override("normal_font_size", 12)
	var color: Color = ENTRY_COLORS.get(entry.type, Color.WHITE)
	text_label.add_theme_color_override("default_color", color)

	_journal_entries.add_child(text_label)


func _on_export_pressed() -> void:
	var summary := get_summary()
	DisplayServer.clipboard_set(summary)
	# Brief visual feedback
	_export_button.text = "Copied!"
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(_export_button):
			_export_button.text = "Export Journal"
	)
