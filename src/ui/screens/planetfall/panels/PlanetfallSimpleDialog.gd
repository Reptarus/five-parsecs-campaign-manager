class_name PlanetfallSimpleDialog
extends Control

## Reusable simple-interaction panel for Planetfall turn steps requiring
## light player input: roll buttons, spinners, simple choices.
## Used for Steps 2 (Repairs), 12 (Track Enemy Info), 13 (Replacements),
## and 17 (Character Event).
##
## Configured via configure() with a step ID that determines behavior.
## Implements the standard panel interface contract.

signal phase_completed(result_data: Dictionary)

const PlanetfallEventResolverScript := preload(
	"res://src/core/systems/PlanetfallEventResolver.gd")

const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_ELEVATED := Color("#252542")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")
const COLOR_CYAN := Color("#4FC3F7")
const FONT_SIZE_LG := 18
const FONT_SIZE_MD := 16
const FONT_SIZE_SM := 14
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24

var _campaign: Resource
var _phase_manager: Node
var _step_id: String = ""
var _phase_index: int = -1
var _resolver: PlanetfallEventResolverScript
var _resolved: bool = false
var _result_data: Dictionary = {}

var _title_label: Label
var _content_vbox: VBoxContainer
var _result_container: VBoxContainer
var _action_btn: Button
var _continue_btn: Button

## Step-specific controls
var _rm_spinner: SpinBox
var _selected_character_id: String = ""


func _ready() -> void:
	_resolver = PlanetfallEventResolverScript.new()
	_build_ui()


## ============================================================================
## PANEL INTERFACE CONTRACT
## ============================================================================

func set_campaign(campaign_resource: Resource) -> void:
	_campaign = campaign_resource


func set_phase_manager(pm: Node) -> void:
	_phase_manager = pm


func configure(step_id: String, phase_index: int) -> void:
	_step_id = step_id
	_phase_index = phase_index
	if _title_label:
		_title_label.text = _get_step_title().to_upper()


func refresh() -> void:
	_resolved = false
	_result_data = {}
	_selected_character_id = ""
	if _title_label:
		_title_label.text = _get_step_title().to_upper()
	# Clear previous content and results
	_clear_container(_content_vbox)
	_clear_container(_result_container)
	# Build step-specific content
	_build_step_content()
	if _action_btn:
		_action_btn.visible = true
		_action_btn.disabled = false
		_action_btn.text = _get_action_button_text()
	if _continue_btn:
		_continue_btn.visible = false


func complete() -> void:
	if not _resolved:
		_on_action_pressed()
	else:
		_on_continue_pressed()


## ============================================================================
## UI BUILD
## ============================================================================

func _build_ui() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SPACING_LG)
	scroll.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = _get_step_title().to_upper()
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Step-specific content area
	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(_content_vbox)

	# Results area
	_result_container = VBoxContainer.new()
	_result_container.add_theme_constant_override("separation", SPACING_SM)
	vbox.add_child(_result_container)

	# Buttons
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", SPACING_MD)
	vbox.add_child(btn_box)

	_action_btn = Button.new()
	_action_btn.text = _get_action_button_text()
	_action_btn.custom_minimum_size = Vector2(200, 48)
	_action_btn.pressed.connect(_on_action_pressed)
	btn_box.add_child(_action_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.custom_minimum_size = Vector2(200, 48)
	_continue_btn.pressed.connect(_on_continue_pressed)
	_continue_btn.visible = false
	btn_box.add_child(_continue_btn)


## ============================================================================
## STEP-SPECIFIC CONTENT
## ============================================================================

func _build_step_content() -> void:
	match _step_id:
		"repairs":
			_build_repairs_content()
		"track_enemy_info":
			_build_track_info_content()
		"replacements":
			_build_replacements_content()
		"character_event":
			_build_character_event_content()


func _build_repairs_content() -> void:
	## Step 2: Colony damage repair + RM conversion. Planetfall p.59.
	if not _campaign:
		return
	var integrity: int = _campaign.colony_integrity if "colony_integrity" in _campaign else 0
	var repair_rate: int = _campaign.repair_capacity if "repair_capacity" in _campaign else 1
	var rm: int = _campaign.raw_materials if "raw_materials" in _campaign else 0
	var bot_broken: bool = not (_campaign.bot_operational if "bot_operational" in _campaign else true)

	_add_info_text("Colony Integrity: %d" % integrity)
	_add_info_text("Base Repair Rate: %d point(s) per turn" % repair_rate)
	_add_info_text("Raw Materials Available: %d" % rm)

	if integrity >= 0:
		_add_info_text("\n[color=#10B981]No colony damage to repair.[/color]")

	if bot_broken:
		_add_info_text(
			"\n[color=#D97706]Colony Bot is Broken — it will be repaired but cannot deploy this turn.[/color]")

	# RM-to-repair spinner (max 3 per turn, capped by available RM)
	if integrity < 0 and rm > 0:
		var max_rm: int = mini(3, rm)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", SPACING_SM)
		_content_vbox.add_child(row)

		var lbl := Label.new()
		lbl.text = "Spend Raw Materials for extra repairs (max 3):"
		lbl.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		row.add_child(lbl)

		_rm_spinner = SpinBox.new()
		_rm_spinner.min_value = 0
		_rm_spinner.max_value = max_rm
		_rm_spinner.value = 0
		_rm_spinner.step = 1
		_rm_spinner.custom_minimum_size.x = 80
		row.add_child(_rm_spinner)


func _build_track_info_content() -> void:
	## Step 12: Track Enemy Information & Mission Data. Planetfall p.68.
	_add_info_text(
		"If you fought a Tactical Enemy and won, add 1 Enemy Information for that enemy type.")
	_add_info_text(
		"Note any Mission Data obtained on your roster.")
	_add_info_text(
		"\nThe TurnController will track these automatically based on battle results.")


func _build_replacements_content() -> void:
	## Step 13: Replacement phase. Planetfall p.69.
	if not _campaign:
		return
	var roster_size: int = _campaign.roster.size() if "roster" in _campaign else 0
	var max_roster: int = 8
	var milestones: int = _campaign.milestones_completed if "milestones_completed" in _campaign else 0
	var attempts: int = 1 + milestones

	_add_info_text("Current Roster: %d / %d" % [roster_size, max_roster])
	_add_info_text("Replacement Attempts Available: %d (1 + %d milestones)" % [attempts, milestones])

	if roster_size >= max_roster:
		_add_info_text(
			"\n[color=#D97706]Roster is full — no replacements needed.[/color]")


func _build_character_event_content() -> void:
	## Step 17: Character Event. Planetfall pp.70-71.
	if not _campaign or not "roster" in _campaign:
		return
	var roster: Array = _campaign.roster
	_add_info_text("A random character will be selected for a Character Event.")
	_add_info_text("Roster size: %d characters" % roster.size())


## ============================================================================
## ACTION HANDLERS
## ============================================================================

func _on_action_pressed() -> void:
	_action_btn.disabled = true
	_resolved = true

	match _step_id:
		"repairs":
			_resolve_repairs()
		"track_enemy_info":
			_resolve_track_info()
		"replacements":
			_resolve_replacements()
		"character_event":
			_resolve_character_event()

	_continue_btn.visible = true
	_continue_btn.disabled = false


func _on_continue_pressed() -> void:
	_continue_btn.disabled = true
	phase_completed.emit(_result_data)


func _resolve_repairs() -> void:
	## Step 2 resolution. Planetfall p.59.
	if not _campaign:
		return
	var integrity: int = _campaign.colony_integrity if "colony_integrity" in _campaign else 0
	var repair_rate: int = _campaign.repair_capacity if "repair_capacity" in _campaign else 1

	# Base repair
	var total_repair: int = repair_rate

	# RM conversion
	var rm_spent: int = 0
	if _rm_spinner:
		rm_spent = int(_rm_spinner.value)
		total_repair += rm_spent

	# Only repair if there's damage (integrity < 0)
	if integrity < 0:
		var actual_repair: int = mini(total_repair, -integrity)
		if _campaign.has_method("repair_colony"):
			_campaign.repair_colony(actual_repair)
		if rm_spent > 0 and _campaign.has_method("spend_raw_materials"):
			_campaign.spend_raw_materials(rm_spent)
		_add_result_bbcode(
			"[color=#10B981]Repaired %d point(s) of colony damage.[/color]" % actual_repair)
		if rm_spent > 0:
			_add_result_bbcode("Spent %d Raw Material(s) for extra repairs." % rm_spent)
		_result_data["rm_spent"] = rm_spent
	else:
		_add_result_bbcode("No colony damage to repair.")

	# Bot repair
	if _campaign and "bot_operational" in _campaign and not _campaign.bot_operational:
		_campaign.bot_operational = true
		_add_result_bbcode(
			"[color=#10B981]Colony Bot repaired![/color] (Cannot deploy this turn.)")


func _resolve_track_info() -> void:
	## Step 12 resolution. Planetfall p.68.
	_add_result_bbcode("Enemy Information and Mission Data tracked.")
	_add_result_bbcode(
		"[color=#808080]Full tracking will be automated when battle results are wired.[/color]")


func _resolve_replacements() -> void:
	## Step 13 resolution. Planetfall p.69.
	if not _campaign:
		return
	var roster_size: int = _campaign.roster.size() if "roster" in _campaign else 0
	var max_roster: int = 8

	if roster_size >= max_roster:
		_add_result_bbcode("Roster is full — no replacements needed.")
		return

	var milestones: int = _campaign.milestones_completed if "milestones_completed" in _campaign else 0
	var attempts: int = 1 + milestones
	var new_characters: Array = []

	for attempt_num in range(attempts):
		if roster_size + new_characters.size() >= max_roster:
			_add_result_bbcode("Roster full — remaining attempts skipped.")
			break

		var roll: int = _resolver.roll_2d6()
		var result: Dictionary = _resolver.resolve_replacement(roll)
		var result_type: String = result.get("result", "none")

		_add_result_bbcode(
			"[b]Attempt %d:[/b] Rolled 2D6 = %d" % [attempt_num + 1, roll])

		match result_type:
			"none":
				_add_result_bbcode("  No replacement available.")
			"random_class":
				var class_roll: int = _resolver.roll_d6()
				var char_class: String = _resolver.resolve_replacement_class(class_roll)
				_add_result_bbcode(
					"  [color=#10B981]Replacement available![/color] D6 = %d → %s" % [
						class_roll, char_class.capitalize()])
				new_characters.append({"class": char_class, "loyalty": "committed"})
			"player_choice":
				_add_result_bbcode(
					"  [color=#10B981]Replacement of your choice available![/color]")
				# Default to trooper for auto-resolve; real panel would offer choice
				new_characters.append({"class": "trooper", "loyalty": "committed"})

	if not new_characters.is_empty():
		_add_result_bbcode(
			"\n[color=#10B981]%d new character(s) added to roster.[/color]" % new_characters.size())
	_result_data["new_characters"] = new_characters


func _resolve_character_event() -> void:
	## Step 17 resolution. Planetfall pp.70-71.
	if not _campaign or not "roster" in _campaign:
		_add_result_bbcode("No roster available.")
		return

	var roster: Array = _campaign.roster
	if roster.is_empty():
		_add_result_bbcode("No characters in roster.")
		return

	# Random character selection
	var char_idx: int = randi_range(0, roster.size() - 1)
	var char_dict: Dictionary = roster[char_idx]
	var char_name: String = char_dict.get("name", "Unknown")
	_selected_character_id = char_dict.get("id", "")

	# Roll D100
	var roll: int = _resolver.roll_d100()
	var event: Dictionary = _resolver.resolve_character_event(roll)
	var event_name: String = event.get("name", "Unknown Event")
	var event_desc: String = event.get("description", "")

	_add_result_bbcode("[b]Selected Character:[/b] %s" % char_name)
	_add_result_bbcode("[b]D100 Roll:[/b] %d" % roll)
	_add_result_bbcode("\n[b]%s[/b]" % event_name)
	_add_result_bbcode(event_desc)

	# Apply simple effects
	var effect: Dictionary = event.get("effect", {})
	if effect.has("xp"):
		var xp: int = effect.get("xp", 0)
		char_dict["xp"] = char_dict.get("xp", 0) + xp
		_add_result_bbcode(
			"\n[color=#10B981]+%d XP for %s[/color]" % [xp, char_name])
	if effect.has("loyalty_up"):
		_add_result_bbcode(
			"\n[color=#10B981]%s gains a level of Loyalty[/color]" % char_name)
	if effect.has("loyalty_down"):
		_add_result_bbcode(
			"\n[color=#DC2626]%s loses a level of Loyalty[/color]" % char_name)
	if effect.has("sick_bay_turns"):
		var turns: int = effect.get("sick_bay_turns", 0)
		if _campaign.has_method("add_to_sick_bay"):
			_campaign.add_to_sick_bay(_selected_character_id, turns)
		_add_result_bbcode(
			"\n[color=#D97706]%s sent to Sick Bay for %d turn(s)[/color]" % [char_name, turns])
	if effect.has("colony_morale"):
		var morale: int = effect.get("colony_morale", 0)
		if _campaign.has_method("adjust_morale"):
			_campaign.adjust_morale(morale)
		var color: String = "#10B981" if morale > 0 else "#DC2626"
		_add_result_bbcode(
			"\n[color=%s]Colony Morale %+d[/color]" % [color, morale])
	if effect.has("story_points"):
		var sp: int = effect.get("story_points", 0)
		if _campaign.has_method("add_story_points"):
			_campaign.add_story_points(sp)
		_add_result_bbcode(
			"\n[color=#10B981]+%d Story Point(s)[/color]" % sp)
	if effect.has("enemy_information"):
		_add_result_bbcode(
			"\n[color=#4FC3F7]+1 Enemy Information[/color]")

	_result_data["character_id"] = _selected_character_id
	_result_data["event"] = event


## ============================================================================
## HELPERS
## ============================================================================

func _get_step_title() -> String:
	match _step_id:
		"repairs": return "Step 2: Repairs"
		"track_enemy_info": return "Step 12: Track Enemy Info & Mission Data"
		"replacements": return "Step 13: Replacements"
		"character_event": return "Step 17: Character Event"
	return "Simple Dialog"


func _get_action_button_text() -> String:
	match _step_id:
		"repairs": return "Apply Repairs"
		"track_enemy_info": return "Confirm"
		"replacements": return "Roll for Replacements"
		"character_event": return "Roll Character Event"
	return "Resolve"


func _add_info_text(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = text
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	_content_vbox.add_child(lbl)


func _add_result_bbcode(text: String) -> void:
	var lbl := RichTextLabel.new()
	lbl.bbcode_enabled = true
	lbl.fit_content = true
	lbl.scroll_active = false
	lbl.text = text
	lbl.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	lbl.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)
	_result_container.add_child(lbl)


func _clear_container(container: VBoxContainer) -> void:
	if not container:
		return
	for child in container.get_children():
		child.queue_free()
