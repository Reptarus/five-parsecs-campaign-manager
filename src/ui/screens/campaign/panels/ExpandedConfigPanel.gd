extends FiveParsecsCampaignPanel

## GDScript 2.0: Five Parsecs Expanded Campaign Configuration Panel
## Production-ready implementation with comprehensive campaign setup options
## NOW INCLUDES VICTORY CONDITIONS (removes need for separate VictoryConditionsPanel)

const STEP_NUMBER := 1  # Step 1 of 7 in campaign wizard (Configuration)

# GlobalEnums available as autoload singleton
const FPCM_VictoryDescriptions = preload("res://src/game/victory/VictoryDescriptions.gd")
const CustomVictoryDialog = preload("res://src/ui/components/victory/CustomVictoryDialog.gd")
const CompendiumMissionsExpandedRef = preload("res://src/data/compendium_missions_expanded.gd")
const CompendiumDifficultyTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")
const ExpansionFeatureSectionScript = preload("res://src/ui/components/dlc/ExpansionFeatureSection.gd")
const ProgressiveDifficultyTrackerRef = preload("res://src/core/systems/ProgressiveDifficultyTracker.gd")

# Compendium Setup Sequence flags (pp.11-12) — promoted to dedicated card
# Labels/descriptions sourced from DLCContentCatalog.gd + Compendium page refs
const COMPENDIUM_SETUP_FLAGS: Array[Dictionary] = [
	{"flag": "EXPANDED_LOANS", "label": "Loans: Who Do You Owe?",
		"description": "Borrow credits with consequences — loan origin, interest, and enforcement (Compendium pp.152-158)"},
	{"flag": "EXPANDED_FACTIONS", "label": "Expanded Factions",
		"description": "More factions with unique traits and relationships (Compendium pp.148-153)"},
	{"flag": "FRINGE_WORLD_STRIFE", "label": "Fringe World Strife",
		"description": "Planetary instability tracking and strife events (Compendium pp.148-153)"},
	{"flag": "DRAMATIC_COMBAT", "label": "Dramatic Combat",
		"description": "Cinematic combat with narrative beats and dramatic moments (Compendium pp.89-95)"},
	{"flag": "CASUALTY_TABLES", "label": "Casualty Tables",
		"description": "Detailed casualty outcomes after battle (Compendium pp.96-100)"},
	{"flag": "DETAILED_INJURIES", "label": "Detailed Post-battle Injuries",
		"description": "Expanded injury and recovery system (Compendium pp.101-104)"},
]

# GDScript 2.0: Typed signals
signal campaign_config_updated(config: Dictionary)
signal campaign_setup_complete(config: Dictionary)

# Autonomous signals for coordinator pattern
signal campaign_config_data_complete(data: Dictionary)
signal campaign_config_validation_failed(errors: Array[String])

# Granular signals for real-time integration
signal campaign_config_data_changed(data: Dictionary)
signal victory_conditions_set(conditions: Dictionary)
signal victory_conditions_changed(conditions: Dictionary)  # NEW for real-time updates
signal narrative_options_changed(data: Dictionary)

var local_campaign_config: Dictionary = {
	"campaign_name": "",
	"campaign_type": "standard",
	"difficulty_level": GlobalEnums.DifficultyLevel.NORMAL,  # Default: STANDARD
	"campaign_crew_size": 6,  # Core Rules p.63: 4, 5, or 6
	"victory_conditions": {},
	"story_track_enabled": false,
	"introductory_campaign": false,
	"progressive_difficulty_options": [],
	"is_complete": false
}

# UI Components with safe access
var campaign_name_input: LineEdit
var campaign_type_option: OptionButton
var difficulty_option: OptionButton  # Difficulty selector
var victory_conditions_list: VBoxContainer
var story_track_checkbox: CheckBox
var intro_campaign_checkbox: CheckBox
var narrative_combo_label: Label
var summary_label: Label

# Crew size selector (Core Rules p.63)
var crew_size_option: OptionButton
var crew_size_description: Label

# Description labels for displaying option details
var campaign_type_description: Label
var difficulty_description: Label  # Difficulty level description
var victory_condition_description: RichTextLabel  # Rich text for full narrative + strategy
var story_track_description: Label
var intro_campaign_description: Label

# Campaign configuration options — loaded from campaign_config.json
var campaign_types: Dictionary = {}
var victory_conditions: Dictionary = {}
var story_tracks: Dictionary = {}
var tutorial_modes: Dictionary = {}
## Config data loaded from JSON
var _config_db: Dictionary = {}

# Difficulty levels keyed by GlobalEnums.DifficultyLevel enum values
# CRITICAL: Keys must match GlobalEnums values exactly (EASY=1, NORMAL=2, CHALLENGING=4, HARDCORE=6, INSANITY=8)
# Core Rules p.65 — difficulty levels (EASY is a custom addition, not in book)
var difficulty_levels: Dictionary = {
	GlobalEnums.DifficultyLevel.EASY: {
		"name": "Easy",
		"description": "+1 XP per battle. +1 credit post-battle reward. Remove 1 Basic enemy if facing 5+. Only 'Play 20 turns' and 'Win 20 battles' victories allowed."
	},
	GlobalEnums.DifficultyLevel.NORMAL: {
		"name": "Normal",
		"description": "No changes to game mechanics. All rules apply as written."
	},
	GlobalEnums.DifficultyLevel.CHALLENGING: {
		"name": "Challenging",
		"description": "When rolling 2D6 for enemy numbers, reroll any die showing 1-2 before selecting the highest."
	},
	GlobalEnums.DifficultyLevel.HARDCORE: {
		"name": "Hardcore",
		"description": "+1 Basic enemy per battle. +2 Invasion rolls. -2 Seize the Initiative. +1 Unique Individual rolls. -1 starting story point."
	},
	GlobalEnums.DifficultyLevel.INSANITY: {
		"name": "Insanity",
		"description": "+1 Specialist enemy per battle. Always a Unique Individual (2D6: 11-12 = two). +3 Invasion. -3 Initiative. No story points ever. No Stars of the Story."
	}
}

var selected_victory_conditions: Dictionary = {}
var _story_track_enabled: bool = false
var _intro_campaign_enabled: bool = false
var selected_difficulty_toggles: Array[String] = []
var difficulty_toggle_checkboxes: Dictionary = {}  # id -> CheckBox
var _compendium_setup_checkboxes: Dictionary = {}  # flag_name -> CheckBox

# Progressive Difficulty (Compendium pp.30-31)
var progressive_basic_checkbox: CheckBox
var progressive_advanced_checkbox: CheckBox
var progressive_warning_label: Label

# Custom victory dialog
var custom_victory_button: Button
var custom_victory_dialog: Window

func _on_campaign_state_updated(state_data: Dictionary) -> void:
	## Override from interface - handle campaign state updates
	# Update panel state based on campaign state if needed
	if state_data.has("campaign_config") and state_data.campaign_config is Dictionary:
		var config_state_data = state_data.campaign_config
		if config_state_data.has("campaign_name"):
			# Merge external changes into local config to preserve required keys
			local_campaign_config.merge(config_state_data, true)
			_update_display()

func _ready() -> void:
	# Load config data from JSON
	_load_campaign_config()

	# GDScript 2.0: Set panel info before base initialization
	set_panel_info("Campaign Setup", "Configure campaign name, victory conditions, and options.")

	# GDScript 2.0: Use super() keyword
	super()

	# Initialize campaign config-specific functionality
	call_deferred("_initialize_components")

func _load_campaign_config() -> void:
	var path := "res://data/campaign_config.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("ExpandedConfigPanel: Failed to open campaign_config.json at %s, using fallback" % path)
		_apply_fallback_config()
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("ExpandedConfigPanel: Failed to parse campaign_config.json")
		_apply_fallback_config()
		return
	if json.data is Dictionary:
		_config_db = json.data
		campaign_types = _config_db.get("campaign_types", {})
		victory_conditions = _config_db.get("victory_conditions", {})
		story_tracks = _config_db.get("story_tracks", {})
		tutorial_modes = _config_db.get("tutorial_modes", {})
	if campaign_types.is_empty():
		_apply_fallback_config()

func _apply_fallback_config() -> void:
	campaign_types = {
		"standard": {"name": "Standard Campaign", "description": "A full campaign with all systems enabled"},
		"story_focused": {"name": "Story-Focused Campaign", "description": "Emphasis on narrative and story track progression"},
		"combat_focused": {"name": "Combat-Focused Campaign", "description": "Emphasis on tactical combat and missions"},
		"exploration_focused": {"name": "Exploration-Focused Campaign", "description": "Emphasis on exploration and discovery"}
	}
	# Core Rules p.64 — exact victory conditions from the book
	victory_conditions = {
		"turns_20": {"name": "Play 20 Campaign Turns", "description": "Complete 20 full campaign turns", "target": 20, "type": "turns", "category": "duration"},
		"turns_50": {"name": "Play 50 Campaign Turns", "description": "Complete 50 full campaign turns", "target": 50, "type": "turns", "category": "duration"},
		"turns_100": {"name": "Play 100 Campaign Turns", "description": "Complete 100 full campaign turns", "target": 100, "type": "turns", "category": "duration"},
		"quests_3": {"name": "Complete 3 Quests", "description": "Complete 3 story quests", "target": 3, "type": "quests", "category": "quest"},
		"quests_5": {"name": "Complete 5 Quests", "description": "Complete 5 story quests", "target": 5, "type": "quests", "category": "quest"},
		"quests_10": {"name": "Complete 10 Quests", "description": "Complete 10 story quests", "target": 10, "type": "quests", "category": "quest"},
		"battles_20": {"name": "Win 20 Tabletop Battles", "description": "Win 20 tabletop battles", "target": 20, "type": "battles_won", "category": "combat"},
		"battles_50": {"name": "Win 50 Tabletop Battles", "description": "Win 50 tabletop battles", "target": 50, "type": "battles_won", "category": "combat"},
		"battles_100": {"name": "Win 100 Tabletop Battles", "description": "Win 100 tabletop battles", "target": 100, "type": "battles_won", "category": "combat"},
		"unique_kills_10": {"name": "Kill 10 Unique Individuals", "description": "Defeat 10 Unique Individuals in battle", "target": 10, "type": "unique_kills", "category": "combat"},
		"unique_kills_25": {"name": "Kill 25 Unique Individuals", "description": "Defeat 25 Unique Individuals in battle", "target": 25, "type": "unique_kills", "category": "combat"},
		"upgrade_1x10": {"name": "Upgrade 1 Character 10 Times", "description": "Upgrade a single character 10 times", "target": 10, "type": "character_upgrades", "category": "growth", "characters_required": 1},
		"upgrade_3x10": {"name": "Upgrade 3 Characters 10 Times", "description": "Upgrade 3 characters 10 times each", "target": 10, "type": "character_upgrades", "category": "growth", "characters_required": 3},
		"upgrade_5x10": {"name": "Upgrade 5 Characters 10 Times", "description": "Upgrade 5 characters 10 times each", "target": 10, "type": "character_upgrades", "category": "growth", "characters_required": 5},
		"challenging_50": {"name": "50 Turns in Challenging Mode", "description": "Play 50 campaign turns in Challenging difficulty", "target": 50, "type": "turns", "category": "challenge", "required_difficulty": "challenging"},
		"hardcore_50": {"name": "50 Turns in Hardcore Mode", "description": "Play 50 campaign turns in Hardcore difficulty", "target": 50, "type": "turns", "category": "challenge", "required_difficulty": "hardcore"},
		"insanity_50": {"name": "50 Turns in Insanity Mode", "description": "Play 50 campaign turns in Insanity difficulty", "target": 50, "type": "turns", "category": "challenge", "required_difficulty": "insanity"},
	}
	story_tracks = {
		"none": {"name": "No Story Track", "description": "Standard campaign without story progression"},
		"mystery_signal": {"name": "Mystery Signal", "description": "Your crew discovers a mysterious signal that leads to a greater conspiracy"},
		"faction_conflict": {"name": "Faction Conflict", "description": "Navigate the complex politics between warring factions"},
		"ancient_ruins": {"name": "Ancient Ruins", "description": "Explore ancient alien ruins and uncover their secrets"},
		"smuggler_network": {"name": "Smuggler Network", "description": "Build a criminal empire in the shadows"}
	}
	tutorial_modes = {
		"none": {"name": "No Tutorial", "description": "Standard campaign without tutorial guidance"},
		"quick_start": {"name": "Quick Start Tutorial", "description": "Learn basic mechanics with guided steps"},
		"advanced": {"name": "Advanced Tutorial", "description": "Master all systems with comprehensive guidance"}
	}

func _setup_panel_content() -> void:
	## Override from BaseCampaignPanel - setup campaign config-specific content
	# This will be called after BaseCampaignPanel structure is ready
	pass

func _initialize_components() -> void:
	## Initialize campaign config panel with card-based design system
	# Get or create main container
	var main_container = safe_get_node("ContentMargin/MainContent/FormContent/FormContainer", 
		func(): return create_basic_container("VBox"))
	
	# Clear existing content to rebuild with design system
	for child in main_container.get_children():
		child.queue_free()
	
	# Apply proper spacing between section cards
	main_container.add_theme_constant_override("separation", SPACING_LG)

	# NOTE: Progress indicator removed - CampaignCreationUI handles progress display centrally

	# Responsive multi-column layout: HFlowContainer auto-wraps cards
	# Desktop (1200px): 2 columns, Mobile (<480px): 1 column
	var flow := HFlowContainer.new()
	flow.name = "FlowContent"
	flow.add_theme_constant_override("h_separation", SPACING_LG)
	flow.add_theme_constant_override("v_separation", SPACING_LG)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(flow)

	# Build card-based UI sections into flow container
	_build_campaign_identity_section(flow)
	_build_campaign_type_section(flow)
	_build_crew_size_section(flow)
	_build_difficulty_section(flow)
	_build_victory_conditions_section(flow)
	_build_narrative_options_section(flow)
	_build_compendium_setup_section(flow)
	_build_expansion_features_section(flow)
	_build_progressive_difficulty_section(flow)

	# Set min widths for flow layout: narrow cards pair up, wide cards get own row
	for child in flow.get_children():
		child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		child.custom_minimum_size.x = 500

	# SPRINT 27 FIX: Setup options BEFORE connecting signals to prevent double-loading
	# (selecting default values triggers signal handlers, causing duplicate _update_display calls)
	_setup_campaign_options()
	_connect_signals()
	_update_display()
	_update_all_descriptions()
	call_deferred("emit_panel_ready")

func _build_campaign_identity_section(parent: Control) -> void:
	## Build campaign name input section with card design
	campaign_name_input = LineEdit.new()
	campaign_name_input.placeholder_text = "Enter a memorable campaign name..."
	_style_line_edit(campaign_name_input)
	
	var input_wrapper = _create_labeled_input("Campaign Name", campaign_name_input)
	
	var card = _create_section_card(
		"CAMPAIGN IDENTITY",
		input_wrapper,
		"Choose a memorable name for your crew's journey across the Fringe"
	)
	parent.add_child(card)

func _build_crew_size_section(parent: Control) -> void:
	## Build crew size selector card (Core Rules p.63, Step 1 of Campaign Preparation)
	crew_size_option = OptionButton.new()
	_style_option_button(crew_size_option)

	crew_size_description = Label.new()
	crew_size_description.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	crew_size_description.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	crew_size_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	content.add_child(_create_labeled_input("Campaign Crew Size", crew_size_option))
	content.add_child(crew_size_description)

	var card = _create_section_card(
		"CREW SIZE",
		content,
		"Sets starting crew, deployment limit, and enemy number formula"
	)
	parent.add_child(card)

func _build_campaign_type_section(parent: Control) -> void:
	## Build campaign type selector with card design
	campaign_type_option = OptionButton.new()
	_style_option_button(campaign_type_option)

	# Create description label
	campaign_type_description = Label.new()
	campaign_type_description.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	campaign_type_description.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	campaign_type_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	content.add_child(_create_labeled_input("Campaign Type", campaign_type_option))
	content.add_child(campaign_type_description)

	var card = _create_section_card(
		"CAMPAIGN STYLE",
		content,
		""
	)
	parent.add_child(card)

func _build_difficulty_section(parent: Control) -> void:
	## Build difficulty selector with card design and description
	difficulty_option = OptionButton.new()
	_style_option_button(difficulty_option)

	# Create description label for difficulty details
	difficulty_description = Label.new()
	difficulty_description.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	difficulty_description.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	difficulty_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)
	content.add_child(_create_labeled_input("Difficulty Level", difficulty_option))
	content.add_child(difficulty_description)

	var card = _create_section_card(
		"DIFFICULTY LEVEL",
		content,
		"Affects enemy strength, resource availability, and overall survival odds"
	)
	parent.add_child(card)


func _build_difficulty_toggles_section(parent: Control) -> void:
	## Build Compendium difficulty toggles (DLC-gated)
	var toggles: Array[Dictionary] = []
	toggles.assign(CompendiumDifficultyTogglesRef.get_difficulty_toggles())
	difficulty_toggle_checkboxes.clear()

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)

	if toggles.is_empty():
		# DLC not enabled — show locked indicator
		var locked_label := Label.new()
		locked_label.text = "Requires Compendium DLC to unlock combat toggles"
		locked_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		locked_label.add_theme_color_override("font_color", COLOR_TEXT_DISABLED)
		locked_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(locked_label)
	else:
		# Group toggles by category
		var categories: Array[String] = []
		categories.assign(CompendiumDifficultyTogglesRef.get_categories())
		for category in categories:
			var cat_toggles: Array[Dictionary] = []
			cat_toggles.assign(CompendiumDifficultyTogglesRef.get_toggles_by_category(category))
			if cat_toggles.is_empty():
				continue

			# Category header
			var cat_label := Label.new()
			cat_label.text = CompendiumDifficultyTogglesRef.get_category_name(category)
			cat_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
			cat_label.add_theme_color_override("font_color", COLOR_ACCENT)
			content.add_child(cat_label)

			# Checkboxes for each toggle in this category
			for toggle in cat_toggles:
				var toggle_id: String = toggle.get("id", "")
				var cb := CheckBox.new()
				cb.text = toggle.get("name", toggle_id)
				cb.tooltip_text = toggle.get("description", "")
				cb.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
				cb.add_theme_font_size_override("font_size", FONT_SIZE_MD)
				cb.toggled.connect(_on_difficulty_toggle_changed.bind(toggle_id))
				content.add_child(cb)
				difficulty_toggle_checkboxes[toggle_id] = cb

	var card = _create_section_card(
		"COMPENDIUM COMBAT OPTIONS",
		content,
		"Optional rules from the Five Parsecs Compendium"
	)
	parent.add_child(card)

func _on_difficulty_toggle_changed(enabled: bool, toggle_id: String) -> void:
	if enabled and toggle_id not in selected_difficulty_toggles:
		selected_difficulty_toggles.append(toggle_id)
	elif not enabled and toggle_id in selected_difficulty_toggles:
		selected_difficulty_toggles.erase(toggle_id)
	local_campaign_config["difficulty_toggles"] = selected_difficulty_toggles.duplicate()
	campaign_config_data_changed.emit(local_campaign_config)

func _build_victory_conditions_section(parent: Control) -> void:
	## Build victory conditions section with card selectors
	victory_conditions_list = VBoxContainer.new()
	victory_conditions_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	victory_conditions_list.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Wrap in ScrollContainer to prevent overflow on desktop multi-column
	var victory_scroll := ScrollContainer.new()
	victory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	victory_scroll.custom_minimum_size = Vector2(0, 300)
	victory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	victory_scroll.add_child(victory_conditions_list)

	# Create description label for selection summary
	victory_condition_description = RichTextLabel.new()
	victory_condition_description.bbcode_enabled = true
	victory_condition_description.fit_content = true
	victory_condition_description.custom_minimum_size = Vector2(0, 60)
	victory_condition_description.add_theme_color_override(
		"default_color", COLOR_TEXT_SECONDARY)
	victory_condition_description.add_theme_font_size_override(
		"normal_font_size", FONT_SIZE_SM)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_MD)
	content.add_child(victory_scroll)
	content.add_child(victory_condition_description)
	
	var card = _create_section_card(
		"VICTORY CONDITIONS",
		content,
		"Select one or more conditions - achieve ANY to win your campaign"
	)
	# Force full-width row in HFlowContainer (don't pair with other cards)
	card.custom_minimum_size.x = 1000
	parent.add_child(card)

func _build_narrative_options_section(parent: Control) -> void:
	## Unified narrative options: Story Track + Introductory Campaign
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_MD)

	# --- Story Track toggle (Core Rules Appendix V) ---
	story_track_checkbox = CheckBox.new()
	story_track_checkbox.text = "Enable Story Track"
	story_track_checkbox.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	story_track_checkbox.add_theme_font_size_override(
		"font_size", FONT_SIZE_MD)
	story_track_checkbox.toggled.connect(_on_story_track_toggled)
	content.add_child(story_track_checkbox)

	story_track_description = Label.new()
	story_track_description.text = (
		"7-event narrative arc overlaying your campaign "
		+ "(Core Rules Appendix V). Recommended for experienced players.")
	story_track_description.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	story_track_description.add_theme_color_override(
		"font_color", COLOR_TEXT_SECONDARY)
	story_track_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(story_track_description)

	# --- Introductory Campaign toggle (Compendium pp.104-109) ---
	# DLC-gated: show checkbox if Fixer's Guidebook DLC is OWNED.
	# Uses is_feature_available() (not is_feature_enabled()) because the
	# per-campaign feature toggle hasn't been set yet during creation.
	var has_intro: bool = false
	var _dlc: Node = get_node_or_null("/root/DLCManager")
	if _dlc and _dlc.has_method("is_feature_available"):
		has_intro = _dlc.is_feature_available(
			_dlc.ContentFlag.INTRODUCTORY_CAMPAIGN)
	if has_intro:
		var sep := HSeparator.new()
		sep.modulate = COLOR_BORDER
		content.add_child(sep)

		intro_campaign_checkbox = CheckBox.new()
		intro_campaign_checkbox.text = "Start Introductory Campaign"
		intro_campaign_checkbox.custom_minimum_size = Vector2(
			0, TOUCH_TARGET_MIN)
		intro_campaign_checkbox.add_theme_font_size_override(
			"font_size", FONT_SIZE_MD)
		intro_campaign_checkbox.toggled.connect(
			_on_intro_campaign_toggled)
		content.add_child(intro_campaign_checkbox)

		intro_campaign_description = Label.new()
		intro_campaign_description.text = (
			"6 guided encounters teaching core mechanics step by step "
			+ "(Compendium pp.104-109). Recommended for first-time players.")
		intro_campaign_description.add_theme_font_size_override(
			"font_size", FONT_SIZE_SM)
		intro_campaign_description.add_theme_color_override(
			"font_color", COLOR_TEXT_SECONDARY)
		intro_campaign_description.autowrap_mode = \
			TextServer.AUTOWRAP_WORD_SMART
		content.add_child(intro_campaign_description)

	# --- Combo explanation (visible when BOTH enabled) ---
	narrative_combo_label = Label.new()
	narrative_combo_label.text = (
		"Extended Experience: The Introductory Campaign teaches "
		+ "you the rules over 5 turns, then the Story Track activates "
		+ "automatically — providing a guided narrative journey from "
		+ "beginner to story veteran.")
	narrative_combo_label.add_theme_font_size_override(
		"font_size", FONT_SIZE_SM)
	narrative_combo_label.add_theme_color_override(
		"font_color", COLOR_ACCENT_HOVER)
	narrative_combo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	narrative_combo_label.visible = false
	content.add_child(narrative_combo_label)

	var card := _create_section_card(
		"NARRATIVE OPTIONS",
		content,
		""
	)
	parent.add_child(card)

func _on_story_track_toggled(enabled: bool) -> void:
	_story_track_enabled = enabled
	local_campaign_config["story_track_enabled"] = enabled
	_update_narrative_combo_label()
	campaign_config_data_changed.emit(local_campaign_config)

func _on_intro_campaign_toggled(enabled: bool) -> void:
	_intro_campaign_enabled = enabled
	local_campaign_config["introductory_campaign"] = enabled
	_update_narrative_combo_label()
	campaign_config_data_changed.emit(local_campaign_config)

func _update_narrative_combo_label() -> void:
	if narrative_combo_label:
		narrative_combo_label.visible = (
			_story_track_enabled and _intro_campaign_enabled)


func _build_compendium_setup_section(parent: Control) -> void:
	## Compendium Setup Sequence options (pp.11-12) — per-campaign toggles
	## for features that the Compendium says should be chosen at setup time.
	var dlc: Node = Engine.get_main_loop().root.get_node_or_null(
		"/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc or not dlc.has_method("is_feature_available"):
		return

	# Filter to only flags whose DLC pack is owned
	var available_flags: Array[Dictionary] = []
	for opt: Dictionary in COMPENDIUM_SETUP_FLAGS:
		var flag_val: int = dlc.ContentFlag.get(opt["flag"], -1)
		if flag_val >= 0 and dlc.is_feature_available(flag_val):
			available_flags.append(opt)

	if available_flags.is_empty():
		return

	_compendium_setup_checkboxes.clear()
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)

	var prev_pack := ""
	for opt: Dictionary in available_flags:
		var flag_name: String = opt["flag"]
		var flag_val: int = dlc.ContentFlag.get(flag_name, -1)

		# Determine which pack this flag belongs to for group separators
		var current_pack := ""
		if flag_name in ["EXPANDED_LOANS", "EXPANDED_FACTIONS", "FRINGE_WORLD_STRIFE"]:
			current_pack = "fixers_guidebook"
		else:
			current_pack = "freelancers_handbook"

		# Add separator between DLC pack groups
		if not prev_pack.is_empty() and current_pack != prev_pack:
			var sep := HSeparator.new()
			sep.modulate = COLOR_BORDER
			content.add_child(sep)
		prev_pack = current_pack

		# CheckBox with touch-friendly sizing
		var cb := CheckBox.new()
		cb.text = opt["label"]
		cb.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		cb.add_theme_font_size_override("font_size", FONT_SIZE_MD)
		if flag_val >= 0:
			cb.button_pressed = dlc.is_feature_enabled(flag_val)
		cb.toggled.connect(_on_compendium_setup_toggled.bind(flag_name))
		content.add_child(cb)
		_compendium_setup_checkboxes[flag_name] = cb

		# Description label
		var desc := Label.new()
		desc.text = opt["description"]
		desc.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(desc)

	var card := _create_section_card(
		"COMPENDIUM SETUP OPTIONS",
		content,
		"Per-campaign optional rules from the Compendium (pp.11-12)"
	)
	# Force full-width row in HFlowContainer
	card.custom_minimum_size.x = 1000
	parent.add_child(card)

func _on_compendium_setup_toggled(enabled: bool, flag_name: String) -> void:
	var dlc: Node = Engine.get_main_loop().root.get_node_or_null(
		"/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc:
		return
	var flag_val: int = dlc.ContentFlag.get(flag_name, -1)
	if flag_val < 0:
		return
	dlc.set_feature_enabled(flag_val, enabled)
	if dlc.has_method("serialize_campaign_flags"):
		local_campaign_config["enabled_flags"] = dlc.serialize_campaign_flags()
	campaign_config_data_changed.emit(local_campaign_config)


func _build_expansion_features_section(parent: Control) -> void:
	## Unified expansion features section — replaces separate
	## difficulty toggles + compendium options sections.
	var section: VBoxContainer = ExpansionFeatureSectionScript.new()
	# Exclude flags already shown in the Compendium Setup Options card above
	var excluded: Array[String] = []
	for opt: Dictionary in COMPENDIUM_SETUP_FLAGS:
		excluded.append(opt["flag"])
	section.setup("campaign_creation", excluded)
	section.flags_changed.connect(_on_expansion_flags_changed)
	section.upsell_requested.connect(_on_expansion_upsell)

	var card = _create_section_card(
		"EXPANSION FEATURES",
		section,
		"Toggle Compendium expansion content for this campaign"
	)
	parent.add_child(card)

func _build_progressive_difficulty_section(parent: Control) -> void:
	## Progressive Difficulty (Compendium pp.30-31) — DLC-gated
	var dlc = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc or not dlc.has_method("is_feature_enabled"):
		return
	if not dlc.is_feature_enabled(dlc.ContentFlag.PROGRESSIVE_DIFFICULTY):
		return

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", SPACING_SM)

	var desc := Label.new()
	desc.text = "Ramp up challenge as you play. Options can be combined."
	desc.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(desc)

	progressive_basic_checkbox = CheckBox.new()
	progressive_basic_checkbox.text = "Option 1: Classic (Respawn + Strength)"
	progressive_basic_checkbox.tooltip_text = "Enemies respawn and increase by campaign turn. Compendium p.30."
	progressive_basic_checkbox.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	progressive_basic_checkbox.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	progressive_basic_checkbox.toggled.connect(_on_progressive_difficulty_changed)
	content.add_child(progressive_basic_checkbox)

	progressive_advanced_checkbox = CheckBox.new()
	progressive_advanced_checkbox.text = "Option 2: Compendium (Toggle Escalation)"
	progressive_advanced_checkbox.tooltip_text = "Progressively enables difficulty toggles and elite enemies. Compendium p.31."
	progressive_advanced_checkbox.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	progressive_advanced_checkbox.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	progressive_advanced_checkbox.toggled.connect(_on_progressive_difficulty_changed)
	content.add_child(progressive_advanced_checkbox)

	progressive_warning_label = Label.new()
	progressive_warning_label.text = ""
	progressive_warning_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	progressive_warning_label.add_theme_color_override("font_color", COLOR_WARNING)
	progressive_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progressive_warning_label.visible = false
	content.add_child(progressive_warning_label)

	var card = _create_section_card(
		"PROGRESSIVE DIFFICULTY",
		content,
		"Turn-based challenge escalation (Compendium pp.30-31)"
	)
	parent.add_child(card)

func _on_progressive_difficulty_changed(_toggled: bool) -> void:
	var options: Array = []
	if progressive_basic_checkbox and progressive_basic_checkbox.button_pressed:
		options.append(ProgressiveDifficultyTrackerRef.ProgressionType.BASIC)
	if progressive_advanced_checkbox and progressive_advanced_checkbox.button_pressed:
		options.append(ProgressiveDifficultyTrackerRef.ProgressionType.ADVANCED)

	local_campaign_config["progressive_difficulty_options"] = options

	# Show warning when both options are active
	if progressive_warning_label:
		if options.size() >= 2:
			progressive_warning_label.text = "Combining both options is likely to be deadly around Turn 20!"
			progressive_warning_label.visible = true
		else:
			progressive_warning_label.visible = false

	campaign_config_data_changed.emit(local_campaign_config)

func _on_expansion_flags_changed(flags: Dictionary) -> void:
	local_campaign_config["enabled_flags"] = flags
	campaign_config_data_changed.emit(local_campaign_config)

func _on_expansion_upsell(_dlc_id: String) -> void:
	var router := get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to("store")


func _update_all_descriptions() -> void:
	## Update all description labels with current selection info
	_update_campaign_type_description()
	_update_difficulty_description()
	_update_victory_condition_description()
	_update_story_track_description()
	_update_tutorial_mode_description()

func _update_campaign_type_description() -> void:
	## Update campaign type description based on current selection
	if not campaign_type_description or not campaign_type_option:
		return

	var index = campaign_type_option.selected
	if index < 0:
		return

	var selected_text = campaign_type_option.get_item_text(index)
	for key in campaign_types.keys():
		if campaign_types[key].name == selected_text:
			campaign_type_description.text = "→ " + campaign_types[key].description
			return

	campaign_type_description.text = ""

func _update_difficulty_description() -> void:
	## Update difficulty description based on current selection
	if not difficulty_description or not difficulty_option:
		return

	var index = difficulty_option.selected
	if index < 0:
		return

	var difficulty_id = difficulty_option.get_item_id(index)
	if difficulty_levels.has(difficulty_id):
		difficulty_description.text = "→ " + difficulty_levels[difficulty_id].description
	else:
		difficulty_description.text = ""

func _update_victory_condition_description() -> void:
	## Update victory condition description summary (descriptions now shown inline in cards)
	if not victory_condition_description:
		return

	if selected_victory_conditions.is_empty():
		victory_condition_description.text = "[i]Click cards above to select victory conditions. Descriptions are shown on each card.[/i]"
		return

	# Build summary for selected conditions (full descriptions are on the cards)
	var condition_count = selected_victory_conditions.size()
	var summary_text = ""
	
	if condition_count == 1:
		summary_text = "[b]1 Victory Condition Selected[/b]\n"
		summary_text += "[color=#88aa88]Achieve this condition to win your campaign![/color]"
	else:
		summary_text = "[b]%d Victory Conditions Selected[/b]\n" % condition_count
		summary_text += "[color=#ffcc88]You can achieve ANY of these conditions to win![/color]"
	
	victory_condition_description.text = summary_text

func _update_story_track_description() -> void:
	## No-op: description is static in the new checkbox-based UI
	pass

func _update_tutorial_mode_description() -> void:
	## No-op: description is static in the new checkbox-based UI
	pass

func _connect_signals() -> void:
	## Establish signal connections with error handling
	if campaign_name_input:
		campaign_name_input.text_changed.connect(_on_campaign_name_changed)
	if campaign_type_option:
		campaign_type_option.item_selected.connect(_on_campaign_type_changed)
	if crew_size_option:
		crew_size_option.item_selected.connect(_on_crew_size_changed)
	if difficulty_option:
		difficulty_option.item_selected.connect(_on_difficulty_changed)
	# Story track + intro campaign checkboxes connect in _build_narrative_options_section

func _setup_campaign_options() -> void:
	## Setup campaign configuration options
	_setup_campaign_type_options()
	_setup_crew_size_options()
	_setup_difficulty_options()
	_setup_victory_conditions()
	# Story track + intro campaign are checkboxes, no setup needed

func _setup_campaign_type_options() -> void:
	## Setup campaign type options
	if not campaign_type_option:
		return

	campaign_type_option.clear()
	for key in campaign_types.keys():
		var campaign_type = campaign_types[key]
		campaign_type_option.add_item(campaign_type.name)

	# Set default selection
	campaign_type_option.select(0)

func _setup_crew_size_options() -> void:
	## Setup crew size options (Core Rules p.63): 4, 5, or 6
	if not crew_size_option:
		return

	crew_size_option.clear()
	crew_size_option.add_item("4 — Small Crew", 4)
	crew_size_option.add_item("5 — Medium Crew", 5)
	crew_size_option.add_item("6 — Standard Crew (Default)", 6)

	# Default to 6 (index 2)
	crew_size_option.select(2)
	local_campaign_config.campaign_crew_size = 6
	_update_crew_size_description()

func _on_crew_size_changed(index: int) -> void:
	## Handle crew size selection change
	if not crew_size_option:
		return

	var size_id: int = crew_size_option.get_item_id(index)
	local_campaign_config["campaign_crew_size"] = size_id
	_update_crew_size_description()
	_update_display()
	_validate_and_complete()

func _update_crew_size_description() -> void:
	## Update crew size description based on current selection
	if not crew_size_description:
		return

	var size: int = local_campaign_config.get("campaign_crew_size", 6)
	match size:
		4:
			crew_size_description.text = (
				"→ Roll 2D6 pick LOWER for enemy numbers. "
				+ "Deploy up to 4 crew in battle. Fewer enemies on average.")
		5:
			crew_size_description.text = (
				"→ Roll 1D6 for enemy numbers. "
				+ "Deploy up to 5 crew in battle. Moderate challenge.")
		6:
			crew_size_description.text = (
				"→ Roll 2D6 pick HIGHER for enemy numbers. "
				+ "Deploy up to 6 crew in battle. Full experience.")
		_:
			crew_size_description.text = ""

func _setup_difficulty_options() -> void:
	## Setup difficulty options using actual GlobalEnums.DifficultyLevel enum values as IDs
	if not difficulty_option:
		return

	difficulty_option.clear()

	# CRITICAL: IDs must be actual GlobalEnums.DifficultyLevel values so DifficultyModifiers works
	difficulty_option.add_item("Story", GlobalEnums.DifficultyLevel.EASY)             # 1
	difficulty_option.add_item("Standard", GlobalEnums.DifficultyLevel.NORMAL)        # 2
	difficulty_option.add_item("Challenging", GlobalEnums.DifficultyLevel.CHALLENGING) # 4
	difficulty_option.add_item("Hardcore", GlobalEnums.DifficultyLevel.HARDCORE)       # 6
	difficulty_option.add_item("Insanity", GlobalEnums.DifficultyLevel.INSANITY)      # 8

	# Default to Standard (index 1, which is ID GlobalEnums.DifficultyLevel.NORMAL)
	difficulty_option.select(1)
	local_campaign_config.difficulty_level = GlobalEnums.DifficultyLevel.NORMAL

func _setup_victory_conditions() -> void:
	## Setup victory conditions as interactive card selectors
	if not victory_conditions_list:
		return

	# Clear existing conditions
	for child in victory_conditions_list.get_children():
		child.queue_free()

	# Apply spacing between cards
	victory_conditions_list.add_theme_constant_override("separation", SPACING_SM)

	# Create card selectors for each victory condition
	for key in victory_conditions.keys():
		var condition = victory_conditions[key]
		var card = _create_victory_condition_card(key, condition)
		victory_conditions_list.add_child(card)


	# Add Custom button for creating custom victory conditions
	custom_victory_button = _create_add_button("+ Custom Victory Condition")
	custom_victory_button.tooltip_text = "Create a custom victory condition with adjusted targets"
	custom_victory_button.pressed.connect(_on_custom_victory_pressed)
	victory_conditions_list.add_child(custom_victory_button)

func _setup_story_track_options() -> void:
	## No-op: story track is now a checkbox, set up in _build_narrative_options_section
	pass

func _setup_tutorial_mode_options() -> void:
	## No-op: tutorial mode is now a checkbox, set up in _build_narrative_options_section
	pass

# Signal handlers
func _on_campaign_name_changed(new_text: String) -> void:
	## Handle campaign name change
	local_campaign_config.campaign_name = new_text
	_update_display()
	_validate_and_complete()

func _on_campaign_type_changed(index: int) -> void:
	## Handle campaign type change
	if not campaign_type_option:
		return

	var selected_text = campaign_type_option.get_item_text(index)
	for key in campaign_types.keys():
		if campaign_types[key].name == selected_text:
			local_campaign_config.campaign_type = key
			break

	_update_campaign_type_description()
	_update_display()
	_validate_and_complete()

func _on_difficulty_changed(index: int) -> void:
	## Handle difficulty level change
	if not difficulty_option:
		return

	# Get the difficulty level ID from the selected item (actual GlobalEnums.DifficultyLevel value)
	var difficulty_id = difficulty_option.get_item_id(index)
	local_campaign_config.difficulty_level = difficulty_id

	# Easy mode restricts available victory conditions (Core Rules p.64)
	_update_victory_conditions_availability(difficulty_id)

	_update_difficulty_description()
	_update_display()
	_validate_and_complete()

func _update_victory_conditions_availability(difficulty: int) -> void:
	## Enable/disable victory condition cards based on difficulty (Core Rules p.64)
	## Easy mode: only "Play 20 turns" and "Win 20 battles" are available
	if not victory_conditions_list:
		return

	var is_restricted: bool = DifficultyModifiers.are_only_basic_victory_conditions_available(difficulty)

	for child in victory_conditions_list.get_children():
		if child == custom_victory_button:
			# Hide custom button in Easy mode
			child.visible = not is_restricted
			continue

		# Victory condition cards store their key in metadata
		if not child.has_meta("victory_key"):
			continue

		var vc_key: String = child.get_meta("victory_key")
		if is_restricted:
			# Easy mode: only basic victory conditions (Core Rules p.64: "Play 20 turns" / "Win 20 battles")
			# Map panel keys to basic conditions: "combat" (win battles) and "story" (complete missions)
			var is_basic: bool = vc_key in ["combat", "story"]
			child.modulate.a = 1.0 if is_basic else 0.4
			# Deselect any restricted condition
			if not is_basic and selected_victory_conditions.has(vc_key):
				selected_victory_conditions.erase(vc_key)
		else:
			child.modulate.a = 1.0


func _create_victory_condition_card(key: String, condition: Dictionary) -> PanelContainer:
	## Create an interactive card selector for a victory condition
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN * 2)  # 96dp tall
	card.name = "VictoryCard_%s" % key
	card.set_meta("victory_key", key)
	
	# Apply card styling (unselected state)
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_ELEVATED
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(SPACING_MD)
	card.add_theme_stylebox_override("panel", style)
	
	# Content layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_XS)
	
	# Title row (name + checkmark indicator)
	var title_row = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var title = Label.new()
	title.text = condition.name
	title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	
	var checkmark = Label.new()
	checkmark.text = "✓"
	checkmark.name = "Checkmark"
	checkmark.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	checkmark.add_theme_color_override("font_color", COLOR_SUCCESS)
	checkmark.visible = false  # Hidden until selected
	title_row.add_child(checkmark)
	
	vbox.add_child(title_row)
	
	# Description (always visible inline)
	var desc = Label.new()
	desc.text = condition.description
	desc.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	desc.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)
	
	# Target badge
	var target = Label.new()
	target.text = "Target: %d %s" % [int(condition.target), condition.type]
	target.add_theme_font_size_override("font_size", FONT_SIZE_XS)
	target.add_theme_color_override("font_color", COLOR_ACCENT)
	vbox.add_child(target)
	
	card.add_child(vbox)

	# BUG-029 FIX: Children must not consume mouse events — pass them through
	# to the PanelContainer so gui_input fires on click
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Make clickable
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_victory_card_clicked.bind(key, card))
	card.mouse_entered.connect(_on_victory_card_hover.bind(card))
	card.mouse_exited.connect(_on_victory_card_unhover.bind(card))

	return card

func _on_victory_card_clicked(event: InputEvent, key: String, card: PanelContainer) -> void:
	## Handle click on victory condition card
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Toggle selection
		var is_selected = selected_victory_conditions.has(key)
		if is_selected:
			selected_victory_conditions.erase(key)
			_set_card_selected_state(card, false)
		else:
			selected_victory_conditions[key] = victory_conditions[key].duplicate()
			_set_card_selected_state(card, true)
		
		# Emit real-time update signals
		victory_conditions_changed.emit(selected_victory_conditions)
		_update_victory_condition_description()
		_update_display()
		_validate_and_complete()

func _on_victory_card_hover(card: PanelContainer) -> void:
	## Handle mouse hover on victory card
	var is_selected = selected_victory_conditions.has(card.get_meta("victory_key"))
	if not is_selected:
		var style = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_color = COLOR_ACCENT
		style.set_border_width_all(3)
		card.add_theme_stylebox_override("panel", style)

func _on_victory_card_unhover(card: PanelContainer) -> void:
	## Handle mouse exit from victory card
	var is_selected = selected_victory_conditions.has(card.get_meta("victory_key"))
	if not is_selected:
		var style = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		style.border_color = COLOR_BORDER
		style.set_border_width_all(2)
		card.add_theme_stylebox_override("panel", style)

func _set_card_selected_state(card: PanelContainer, selected: bool) -> void:
	## Update visual state of victory condition card
	var style = card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	var checkmark = card.find_child("Checkmark", true, false)

	# BUG-034 FIX: Update description/target text color alongside background
	# so contrast remains readable on the darkened accent background
	var desc_label: Label = null
	var target_label: Label = null
	var vbox = card.get_child(0) if card.get_child_count() > 0 else null
	if vbox:
		for child in vbox.get_children():
			if child is Label and child.name != "Checkmark":
				if child.text.begins_with("Target:"):
					target_label = child
				elif child.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART:
					desc_label = child

	if selected:
		# Selected state: focus border, subtle accent tint, visible checkmark
		style.border_color = COLOR_FOCUS
		style.set_border_width_all(3)
		style.bg_color = COLOR_ACCENT.darkened(0.2)
		if checkmark:
			checkmark.visible = true
		if desc_label:
			desc_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		if target_label:
			target_label.add_theme_color_override("font_color", COLOR_FOCUS)
	else:
		# Unselected state: normal border, default background
		style.border_color = COLOR_BORDER
		style.set_border_width_all(2)
		style.bg_color = COLOR_ELEVATED
		if checkmark:
			checkmark.visible = false
		if desc_label:
			desc_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		if target_label:
			target_label.add_theme_color_override("font_color", COLOR_ACCENT)

	card.add_theme_stylebox_override("panel", style)


## Story track and intro campaign handlers moved to
## _on_story_track_toggled() and _on_intro_campaign_toggled()
## in _build_narrative_options_section region above.

func _on_custom_victory_pressed() -> void:
	## Open custom victory condition dialog
	if not custom_victory_dialog:
		custom_victory_dialog = CustomVictoryDialog.new()
		custom_victory_dialog.custom_condition_created.connect(_on_custom_condition_created)
		add_child(custom_victory_dialog)

	custom_victory_dialog.show_dialog()

func _on_custom_condition_created(condition_type: int, target_value: int) -> void:
	## Handle custom victory condition creation
	var data = FPCM_VictoryDescriptions.get_victory_data(condition_type)
	var name = data.get("name", "Custom")

	# Create unique key for this custom condition
	var custom_key = "custom_%d_%d" % [condition_type, target_value]

	# Add to selected conditions
	selected_victory_conditions[custom_key] = {
		"name": "%s (Custom: %d)" % [name, target_value],
		"description": data.get("short_desc", "Custom victory condition"),
		"target": target_value,
		"type": condition_type,
		"is_custom": true
	}

	# Emit signals for real-time updates
	victory_conditions_changed.emit(selected_victory_conditions)
	_update_victory_condition_description()
	_update_display()
	_validate_and_complete()


func _reset_to_defaults() -> void:
	## Reset campaign configuration to defaults

	# Reset to default values
	local_campaign_config = {
		"campaign_name": "",
		"campaign_type": "standard",
		"difficulty_level": GlobalEnums.DifficultyLevel.NORMAL,  # Default: STANDARD
		"victory_conditions": {},
		"story_track": "",
		"tutorial_mode": "",
		"is_complete": false
	}
	selected_victory_conditions = {}
	_story_track_enabled = false
	_intro_campaign_enabled = false
	selected_difficulty_toggles.clear()

	# Reset toggle checkboxes
	for toggle_id in difficulty_toggle_checkboxes:
		var cb: CheckBox = difficulty_toggle_checkboxes[toggle_id]
		if cb:
			cb.set_pressed_no_signal(false)

	# Reset UI components
	_reset_ui_components()

	# Update display
	_update_display()


func _reset_ui_components() -> void:
	## Reset UI components to default values
	if campaign_name_input:
		campaign_name_input.text = ""

	if campaign_type_option:
		campaign_type_option.select(0)

	if difficulty_option:
		difficulty_option.select(1)  # Default to Standard (index 1)

	if story_track_checkbox:
		story_track_checkbox.set_pressed_no_signal(false)
	if intro_campaign_checkbox:
		intro_campaign_checkbox.set_pressed_no_signal(false)

	# Reset victory condition checkboxes
	if victory_conditions_list:
		for child in victory_conditions_list.get_children():
			if child is CheckBox:
				child.button_pressed = false

func _update_display() -> void:
	## Update the campaign configuration display
	_update_summary()

func _update_summary() -> void:
	## Update summary display with current configuration
	if not summary_label:
		return
	
	var summary_text = "Campaign Configuration:\n"
	summary_text += "• Name: %s\n" % (local_campaign_config.campaign_name if local_campaign_config.campaign_name else "Unnamed")
	summary_text += "• Type: %s\n" % campaign_types.get(local_campaign_config.campaign_type, {}).get("name", "Standard")
	summary_text += "• Victory Conditions: %d selected\n" % selected_victory_conditions.size()
	summary_text += "• Story Track: %s\n" % ("Enabled" if _story_track_enabled else "Disabled")
	summary_text += "• Introductory Campaign: %s" % ("Enabled" if _intro_campaign_enabled else "Disabled")
	
	summary_label.text = summary_text

func _validate_and_complete() -> void:
	## Validate campaign configuration and update completion status
	var errors = _validate_campaign_config()
	
	if not errors.is_empty():
		local_campaign_config.is_complete = false
		campaign_config_validation_failed.emit(errors)
		return
	
	local_campaign_config.is_complete = true
	local_campaign_config.victory_conditions = selected_victory_conditions.duplicate()
	local_campaign_config.story_track_enabled = _story_track_enabled
	local_campaign_config.introductory_campaign = _intro_campaign_enabled
	
	# Emit completion signal (connected in CampaignCreationUI) and notify coordinator
	campaign_config_data_complete.emit(local_campaign_config)
	_notify_coordinator_of_campaign_config_update()

func _validate_campaign_config() -> Array[String]:
	## Validate campaign configuration and return error messages
	var errors: Array[String] = []
	
	# Validate campaign name
	if local_campaign_config.campaign_name.strip_edges().is_empty():
		errors.append("Campaign name cannot be empty")
	elif local_campaign_config.campaign_name.length() > 50:
		errors.append("Campaign name cannot exceed 50 characters")
	
	# Validate campaign type
	if not campaign_types.has(local_campaign_config.campaign_type):
		errors.append("Invalid campaign type selection")
	
	# Victory conditions validated at finalization (Step 7), not here —
	# blocking here prevents campaign name from propagating to coordinator
	# when the user types a name before selecting victory conditions.
	
	# Validate story track (optional)
	if false: # Story track is now a bool, no validation needed
		errors.append("Invalid story track selection")
	
	# Validate tutorial mode (optional)
	if false: # Intro campaign is now a bool, no validation needed
		errors.append("Invalid tutorial mode selection")
	
	return errors

# PHASE 6 INTEGRATION: Coordinator communication
func _notify_coordinator_of_campaign_config_update() -> void:
	## Notify the campaign coordinator of campaign config state changes
	# Use inherited coordinator reference from BaseCampaignPanel
	var coordinator = get_coordinator_reference()
	if coordinator and coordinator.has_method("update_campaign_config_state"):
		coordinator.update_campaign_config_state(local_campaign_config)
	else:
		pass

func _on_coordinator_set() -> void:
	## Called when coordinator is assigned - sync initial state from coordinator

	var coordinator = get_coordinator_reference()
	if coordinator and coordinator.has_method("get_unified_campaign_state"):
		var state = coordinator.get_unified_campaign_state()
		if state.has("campaign_config") and state.campaign_config is Dictionary:
			var config_data = state.campaign_config
			if not config_data.is_empty():
				restore_panel_data(config_data)
			else:
				pass
		else:
			pass
	else:
		pass

# Public API methods
func get_campaign_config() -> Dictionary:
	## Get current campaign configuration
	return local_campaign_config.duplicate()

func set_campaign_config(config: Dictionary) -> void:
	## Set campaign configuration from external source — merge to preserve required keys
	local_campaign_config.merge(config, true)
	selected_victory_conditions = config.get("victory_conditions", {}).duplicate()
	_story_track_enabled = config.get("story_track_enabled", false)
	_intro_campaign_enabled = config.get("introductory_campaign", false)

	# Restore crew size selector if present
	if config.has("campaign_crew_size") and crew_size_option:
		var size_val: int = config.get("campaign_crew_size", 6)
		for i in range(crew_size_option.get_item_count()):
			if crew_size_option.get_item_id(i) == size_val:
				crew_size_option.select(i)
				break
		_update_crew_size_description()

	_update_display()
	_validate_and_complete()

func get_victory_conditions() -> Dictionary:
	## Get selected victory conditions
	return selected_victory_conditions.duplicate()

func get_story_track_enabled() -> bool:
	## Get story track toggle state
	return _story_track_enabled

func get_intro_campaign_enabled() -> bool:
	## Get introductory campaign toggle state
	return _intro_campaign_enabled

# Required interface methods
func validate_panel() -> bool:
	## Validate panel data and return simple boolean result
	var errors = _validate_campaign_config()
	return errors.is_empty()

func get_panel_data() -> Dictionary:
	## Get panel data - interface implementation
	return get_campaign_config_data()

func set_panel_data(data: Dictionary) -> void:
	## Set panel data - interface implementation for state restoration (BaseCampaignPanel contract)
	restore_panel_data(data)

func reset_panel() -> void:
	## Reset panel to default state
	_reset_to_defaults()

func get_campaign_config_data() -> Dictionary:
	## Get campaign config data in standardized format
	return {
		"campaign_name": local_campaign_config.get("campaign_name", ""),
		"campaign_type": local_campaign_config.get("campaign_type", "standard"),
		"difficulty_level": local_campaign_config.get("difficulty_level", 2),
		"difficulty_toggles": selected_difficulty_toggles.duplicate(),
		"victory_conditions": selected_victory_conditions.duplicate(),
		"story_track_enabled": _story_track_enabled,
		"introductory_campaign": _intro_campaign_enabled,
		"progressive_difficulty_options": local_campaign_config.get(
			"progressive_difficulty_options", []),
		"is_complete": local_campaign_config.get("is_complete", false),
		"metadata": {
			"last_modified": Time.get_unix_time_from_system(),
			"version": "1.0",
			"panel_type": "expanded_campaign_config"
		}
	}

# Panel data persistence implementation
func restore_panel_data(data: Dictionary) -> void:
	## Restore panel data from persistence system
	if data.is_empty():
		return
	
	# Restore campaign name
	if data.has("campaign_name"):
		local_campaign_config.campaign_name = data.campaign_name
	
	# Restore campaign type
	if data.has("campaign_type"):
		local_campaign_config.campaign_type = data.campaign_type

	# Restore difficulty level
	if data.has("difficulty_level"):
		local_campaign_config.difficulty_level = data.difficulty_level
		# Update UI dropdown to match
		if difficulty_option:
			for i in range(difficulty_option.get_item_count()):
				if difficulty_option.get_item_id(i) == data.difficulty_level:
					difficulty_option.select(i)
					break

	# Restore difficulty toggles
	if data.has("difficulty_toggles"):
		selected_difficulty_toggles.clear()
		var toggles_data = data.difficulty_toggles
		if toggles_data is Array:
			for tid in toggles_data:
				if tid is String:
					selected_difficulty_toggles.append(tid)
		local_campaign_config["difficulty_toggles"] = selected_difficulty_toggles.duplicate()
		# Update checkboxes
		for toggle_id in difficulty_toggle_checkboxes:
			var cb: CheckBox = difficulty_toggle_checkboxes[toggle_id]
			if cb:
				cb.set_pressed_no_signal(toggle_id in selected_difficulty_toggles)

	# Restore victory conditions
	if data.has("victory_conditions"):
		selected_victory_conditions = data.victory_conditions.duplicate()
	
	# Restore narrative options
	if data.has("story_track_enabled"):
		_story_track_enabled = data.story_track_enabled
		if story_track_checkbox:
			story_track_checkbox.set_pressed_no_signal(_story_track_enabled)
	if data.has("introductory_campaign"):
		_intro_campaign_enabled = data.introductory_campaign
		if intro_campaign_checkbox:
			intro_campaign_checkbox.set_pressed_no_signal(
				_intro_campaign_enabled)
	_update_narrative_combo_label()

	# Restore progressive difficulty options
	if data.has("progressive_difficulty_options"):
		var prog_opts: Array = data.progressive_difficulty_options
		local_campaign_config["progressive_difficulty_options"] = prog_opts
		if progressive_basic_checkbox:
			progressive_basic_checkbox.set_pressed_no_signal(
				ProgressiveDifficultyTrackerRef.ProgressionType.BASIC in prog_opts)
		if progressive_advanced_checkbox:
			progressive_advanced_checkbox.set_pressed_no_signal(
				ProgressiveDifficultyTrackerRef.ProgressionType.ADVANCED in prog_opts)
		if progressive_warning_label:
			progressive_warning_label.visible = prog_opts.size() >= 2

	# Restore completion status
	if data.has("is_complete"):
		local_campaign_config.is_complete = data.is_complete
	
	
	# Update UI with restored data
	_update_display()
	

func cleanup_panel() -> void:
	## Clean up panel state when navigating away
	
	# Reset local campaign config
	local_campaign_config = {
		"campaign_name": "",
		"campaign_type": "standard",
		"difficulty_level": GlobalEnums.DifficultyLevel.NORMAL,  # Default: STANDARD
		"victory_conditions": {},
		"story_track_enabled": false,
		"introductory_campaign": false,
		"is_complete": false
	}

	# Clear selected options
	selected_victory_conditions.clear()
	_story_track_enabled = false
	_intro_campaign_enabled = false
	selected_difficulty_toggles.clear()
	for toggle_id in difficulty_toggle_checkboxes:
		var cb: CheckBox = difficulty_toggle_checkboxes[toggle_id]
		if cb:
			cb.set_pressed_no_signal(false)

	# Reset UI components if available
	if campaign_name_input:
		campaign_name_input.text = ""
	if campaign_type_option:
		campaign_type_option.select(0)
	if difficulty_option:
		difficulty_option.select(1)  # Default to Standard (index 1)
	if story_track_checkbox:
		story_track_checkbox.set_pressed_no_signal(false)
	if intro_campaign_checkbox:
		intro_campaign_checkbox.set_pressed_no_signal(false)

	# Clear victory conditions checkboxes
	if victory_conditions_list:
		for child in victory_conditions_list.get_children():
			if child is CheckBox:
				child.button_pressed = false
	

## ============ FALLBACK UI CREATION METHODS ============

func _create_line_edit(name: String) -> LineEdit:
	## Create fallback LineEdit
	var line_edit = LineEdit.new()
	line_edit.name = name
	line_edit.placeholder_text = "Enter value..."
	return line_edit

func _create_option_button(name: String) -> OptionButton:
	## Create fallback OptionButton
	var option_button = OptionButton.new()
	option_button.name = name
	option_button.add_item("Default Option")
	return option_button

func _create_container(name: String) -> VBoxContainer:
	## Create fallback container
	var container = VBoxContainer.new()
	container.name = name
	return container

func _create_button(name: String, text: String) -> Button:
	## Create fallback Button
	var button = Button.new()
	button.name = name
	button.text = text
	return button

func _create_label(name: String, text: String) -> Label:
	## Create fallback Label
	var label = Label.new()
	label.name = name
	label.text = text
	return label

## Responsive Layout Overrides

func _apply_mobile_layout() -> void:
	## Mobile: Single column, 56dp targets, compact victory descriptions
	super._apply_mobile_layout()

	# Increase touch targets to TOUCH_TARGET_COMFORT (56dp)
	if campaign_type_option:
		campaign_type_option.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if story_track_checkbox:
		story_track_checkbox.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if intro_campaign_checkbox:
		intro_campaign_checkbox.custom_minimum_size.y = TOUCH_TARGET_COMFORT
	if campaign_name_input:
		campaign_name_input.custom_minimum_size.y = TOUCH_TARGET_COMFORT

	# Compact victory condition description for mobile
	if victory_condition_description:
		victory_condition_description.custom_minimum_size.y = 40

func _apply_tablet_layout() -> void:
	## Tablet: Two columns, 48dp targets, detailed victory descriptions
	super._apply_tablet_layout()

	# Standard touch targets at TOUCH_TARGET_MIN (48dp)
	if campaign_type_option:
		campaign_type_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if story_track_checkbox:
		story_track_checkbox.custom_minimum_size.y = TOUCH_TARGET_MIN
	if intro_campaign_checkbox:
		intro_campaign_checkbox.custom_minimum_size.y = TOUCH_TARGET_MIN
	if campaign_name_input:
		campaign_name_input.custom_minimum_size.y = TOUCH_TARGET_MIN

	# Detailed victory condition description for tablet
	if victory_condition_description:
		victory_condition_description.custom_minimum_size.y = 60

func _apply_desktop_layout() -> void:
	## Desktop: Multi-column, 48dp targets, full victory descriptions
	super._apply_desktop_layout()

	# Standard touch targets at TOUCH_TARGET_MIN (48dp)
	if campaign_type_option:
		campaign_type_option.custom_minimum_size.y = TOUCH_TARGET_MIN
	if story_track_checkbox:
		story_track_checkbox.custom_minimum_size.y = TOUCH_TARGET_MIN
	if intro_campaign_checkbox:
		intro_campaign_checkbox.custom_minimum_size.y = TOUCH_TARGET_MIN
	if campaign_name_input:
		campaign_name_input.custom_minimum_size.y = TOUCH_TARGET_MIN

	# Full victory condition description for desktop
	if victory_condition_description:
		victory_condition_description.custom_minimum_size.y = 80
