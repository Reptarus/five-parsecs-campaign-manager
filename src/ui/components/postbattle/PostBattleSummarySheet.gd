extends PanelContainer
class_name PostBattleSummarySheet

## Post-Battle Summary Sheet - Complete session summary (final screen)
## Shows mission outcome, stats, crew changes, loot, and campaign impacts
## Integrates all post-battle results into comprehensive summary view

# ============================================================================
# SIGNALS
# ============================================================================

signal continue_pressed()

# ============================================================================
# CONSTANTS
# ============================================================================

# Design System (from BaseCampaignPanel)
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const SPACING_XL := 32
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18
const FONT_SIZE_XL := 24
const TOUCH_TARGET_COMFORT := 56

# Color Palette
const COLOR_PRIMARY := Color("#0a0d14")      # Darkest background
const COLOR_SECONDARY := Color("#111827")    # Card backgrounds
const COLOR_TERTIARY := Color("#1f2937")     # Elevated elements
const COLOR_BORDER := Color("#374151")       # Borders

const COLOR_SUCCESS := Color("#10b981")      # Victory, positive changes
const COLOR_DANGER := Color("#ef4444")       # Defeat, deaths, warnings
const COLOR_WARNING := Color("#f59e0b")      # Injuries, cautions
const COLOR_CYAN := Color("#06b6d4")         # Info, neutral changes

const COLOR_TEXT_PRIMARY := Color("#f3f4f6")   # Bright white text
const COLOR_TEXT_SECONDARY := Color("#9ca3af") # Gray secondary text

# ============================================================================
# ONREADY REFERENCES
# ============================================================================

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var main_vbox: VBoxContainer = $ScrollContainer/MainVBox

@onready var header_section: VBoxContainer = $ScrollContainer/MainVBox/HeaderSection
@onready var mission_title: Label = $ScrollContainer/MainVBox/HeaderSection/MissionTitle
@onready var outcome_label: Label = $ScrollContainer/MainVBox/HeaderSection/OutcomeLabel

@onready var stats_section: GridContainer = $ScrollContainer/MainVBox/StatsSection
@onready var rounds_label: Label = $ScrollContainer/MainVBox/StatsSection/RoundsLabel
@onready var enemies_defeated_label: Label = $ScrollContainer/MainVBox/StatsSection/EnemiesDefeatedLabel
@onready var casualties_label: Label = $ScrollContainer/MainVBox/StatsSection/CasualtiesLabel
@onready var credits_earned_label: Label = $ScrollContainer/MainVBox/StatsSection/CreditsEarnedLabel

@onready var crew_changes_section: VBoxContainer = $ScrollContainer/MainVBox/CrewChangesSection
@onready var crew_section_header: Label = $ScrollContainer/MainVBox/CrewChangesSection/SectionHeader
@onready var injuries_container: VBoxContainer = $ScrollContainer/MainVBox/CrewChangesSection/InjuriesContainer
@onready var xp_gains_container: VBoxContainer = $ScrollContainer/MainVBox/CrewChangesSection/XPGainsContainer
@onready var deaths_container: VBoxContainer = $ScrollContainer/MainVBox/CrewChangesSection/DeathsContainer

@onready var loot_section: VBoxContainer = $ScrollContainer/MainVBox/LootSection
@onready var loot_section_header: Label = $ScrollContainer/MainVBox/LootSection/SectionHeader
@onready var loot_container: VBoxContainer = $ScrollContainer/MainVBox/LootSection/LootContainer

@onready var campaign_changes_section: VBoxContainer = $ScrollContainer/MainVBox/CampaignChangesSection
@onready var campaign_section_header: Label = $ScrollContainer/MainVBox/CampaignChangesSection/SectionHeader
@onready var rivals_label: Label = $ScrollContainer/MainVBox/CampaignChangesSection/RivalsLabel
@onready var patrons_label: Label = $ScrollContainer/MainVBox/CampaignChangesSection/PatronsLabel
@onready var quest_label: Label = $ScrollContainer/MainVBox/CampaignChangesSection/QuestLabel
@onready var invasion_warning: Label = $ScrollContainer/MainVBox/CampaignChangesSection/InvasionWarning

@onready var continue_button: Button = $ScrollContainer/MainVBox/ContinueButton

# ============================================================================
# PRIVATE VARIABLES
# ============================================================================

var _summary_data: Dictionary = {}
var _invasion_timer: Timer = null

# ============================================================================
# LIFECYCLE METHODS
# ============================================================================

func _ready() -> void:
	# Connect button signal
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)

	# Apply design system styling
	_apply_design_system_styling()

	print("PostBattleSummarySheet: Ready")

func _exit_tree() -> void:
	# Clean up invasion warning timer if exists
	if _invasion_timer and is_instance_valid(_invasion_timer):
		_invasion_timer.queue_free()

# ============================================================================
# PUBLIC INTERFACE
# ============================================================================

func setup(summary_data: Dictionary) -> void:
	"""
	Setup summary sheet with post-battle results.

	Expected data structure:
	{
		"mission_title": String,
		"victory": bool,
		"rounds": int,
		"enemies_defeated": int,
		"casualties": int,
		"credits_earned": int,
		"injuries": Array[Dictionary] (character_name, injury_type, recovery_time),
		"xp_gains": Array[Dictionary] (character_name, xp_gained, new_total),
		"deaths": Array[String] (character names),
		"loot": Array[Dictionary] (item_name, type, value),
		"rivals_change": int (+1, -1, or 0),
		"patrons_change": int (+1 or 0),
		"quest_progress": String (optional),
		"invasion_pending": bool
	}
	"""
	_summary_data = summary_data

	# Populate header
	_setup_header()

	# Populate stats
	_setup_stats()

	# Populate crew changes
	_setup_crew_changes()

	# Populate loot
	_setup_loot()

	# Populate campaign changes
	_setup_campaign_changes()

	print("PostBattleSummarySheet: Setup complete - Victory: %s" % summary_data.get("victory", false))

# ============================================================================
# PRIVATE HELPER METHODS - SETUP
# ============================================================================

func _setup_header() -> void:
	"""Setup mission title and victory/defeat outcome"""
	if mission_title:
		mission_title.text = _summary_data.get("mission_title", "Mission Complete")

	if outcome_label:
		var is_victory: bool = _summary_data.get("victory", false)
		outcome_label.text = "VICTORY!" if is_victory else "DEFEAT"
		outcome_label.add_theme_color_override("font_color", COLOR_SUCCESS if is_victory else COLOR_DANGER)

func _setup_stats() -> void:
	"""Setup battle statistics grid"""
	if rounds_label:
		var rounds: int = _summary_data.get("rounds", 0)
		rounds_label.text = "Rounds: %d" % rounds

	if enemies_defeated_label:
		var defeated: int = _summary_data.get("enemies_defeated", 0)
		enemies_defeated_label.text = "Enemies Defeated: %d" % defeated

	if casualties_label:
		var casualties: int = _summary_data.get("casualties", 0)
		casualties_label.text = "Casualties: %d" % casualties
		# Color code based on severity
		if casualties > 0:
			casualties_label.add_theme_color_override("font_color", COLOR_WARNING if casualties < 3 else COLOR_DANGER)

	if credits_earned_label:
		var credits: int = _summary_data.get("credits_earned", 0)
		credits_earned_label.text = "Credits Earned: %d" % credits
		if credits > 0:
			credits_earned_label.add_theme_color_override("font_color", COLOR_SUCCESS)

func _setup_crew_changes() -> void:
	"""Setup crew changes section (injuries, XP, deaths)"""
	# Clear existing content
	_clear_container(injuries_container)
	_clear_container(xp_gains_container)
	_clear_container(deaths_container)

	# Populate injuries
	var injuries: Array = _summary_data.get("injuries", [])
	if injuries.size() > 0:
		var injury_header := _create_subsection_header("Injuries", "⚕️")
		injuries_container.add_child(injury_header)

		for injury in injuries:
			var injury_label := Label.new()
			var character_name: String = injury.get("character_name", "Unknown")
			var injury_type: String = injury.get("injury_type", "Unknown Injury")
			var recovery: int = injury.get("recovery_time", 0)
			injury_label.text = "  • %s: %s (%d turns recovery)" % [character_name, injury_type, recovery]
			injury_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
			injury_label.add_theme_color_override("font_color", COLOR_WARNING)
			injuries_container.add_child(injury_label)

	# Populate XP gains
	var xp_gains: Array = _summary_data.get("xp_gains", [])
	if xp_gains.size() > 0:
		var xp_header := _create_subsection_header("Experience Gained", "⭐")
		xp_gains_container.add_child(xp_header)

		for xp_gain in xp_gains:
			var xp_label := Label.new()
			var character_name: String = xp_gain.get("character_name", "Unknown")
			var xp_gained: int = xp_gain.get("xp_gained", 0)
			var new_total: int = xp_gain.get("new_total", 0)
			xp_label.text = "  • %s: +%d XP (Total: %d)" % [character_name, xp_gained, new_total]
			xp_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
			xp_label.add_theme_color_override("font_color", COLOR_CYAN)
			xp_gains_container.add_child(xp_label)

	# Populate deaths
	var deaths: Array = _summary_data.get("deaths", [])
	if deaths.size() > 0:
		var death_header := _create_subsection_header("Casualties (KIA)", "💀")
		deaths_container.add_child(death_header)

		for character_name in deaths:
			var death_label := Label.new()
			death_label.text = "  • %s - Killed In Action" % character_name
			death_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
			death_label.add_theme_color_override("font_color", COLOR_DANGER)
			deaths_container.add_child(death_label)

func _setup_loot() -> void:
	"""Setup loot collected section"""
	_clear_container(loot_container)

	var loot_items: Array = _summary_data.get("loot", [])
	if loot_items.size() == 0:
		var no_loot := Label.new()
		no_loot.text = "No loot collected"
		no_loot.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		no_loot.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		loot_container.add_child(no_loot)
		return

	# Create grid for loot items (2 columns: item, value)
	var loot_grid := GridContainer.new()
	loot_grid.columns = 2
	loot_grid.add_theme_constant_override("h_separation", SPACING_MD)
	loot_grid.add_theme_constant_override("v_separation", SPACING_SM)

	for item in loot_items:
		# Item name with type icon
		var item_label := Label.new()
		var item_name: String = item.get("item_name", "Unknown Item")
		var item_type: String = item.get("type", "gear")
		var icon := _get_item_icon(item_type)
		item_label.text = "%s %s" % [icon, item_name]
		item_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		item_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		loot_grid.add_child(item_label)

		# Item value
		var value_label := Label.new()
		var value: int = item.get("value", 0)
		value_label.text = "%d CR" % value
		value_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
		value_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		loot_grid.add_child(value_label)

	loot_container.add_child(loot_grid)

func _setup_campaign_changes() -> void:
	"""Setup campaign changes section (rivals, patrons, quests, invasion)"""
	# Rivals
	if rivals_label:
		var rivals_change: int = _summary_data.get("rivals_change", 0)
		if rivals_change > 0:
			rivals_label.text = "⚔️ New Rival acquired (+%d)" % rivals_change
			rivals_label.add_theme_color_override("font_color", COLOR_DANGER)
		elif rivals_change < 0:
			rivals_label.text = "✓ Rival eliminated (-%d)" % abs(rivals_change)
			rivals_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		else:
			rivals_label.text = "Rivals: No change"
			rivals_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

	# Patrons
	if patrons_label:
		var patrons_change: int = _summary_data.get("patrons_change", 0)
		if patrons_change > 0:
			patrons_label.text = "🤝 New Patron contact (+%d)" % patrons_change
			patrons_label.add_theme_color_override("font_color", COLOR_SUCCESS)
		else:
			patrons_label.text = "Patrons: No change"
			patrons_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

	# Quest progress
	if quest_label:
		var quest_progress: String = _summary_data.get("quest_progress", "")
		if quest_progress.is_empty():
			quest_label.text = "Quest: No active quest"
			quest_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		else:
			quest_label.text = "📜 Quest: %s" % quest_progress
			quest_label.add_theme_color_override("font_color", COLOR_CYAN)

	# Invasion warning
	if invasion_warning:
		var invasion_pending: bool = _summary_data.get("invasion_pending", false)
		if invasion_pending:
			invasion_warning.text = "⚠️ WARNING: INVASION IMMINENT - Prepare defenses!"
			invasion_warning.add_theme_color_override("font_color", COLOR_DANGER)
			invasion_warning.visible = true
			_start_invasion_pulse()
		else:
			invasion_warning.visible = false

# ============================================================================
# PRIVATE HELPER METHODS - UTILITIES
# ============================================================================

func _apply_design_system_styling() -> void:
	"""Apply design system colors and fonts to UI elements"""
	# Main panel background
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PRIMARY
	panel_style.set_border_width_all(2)
	panel_style.border_color = COLOR_BORDER
	panel_style.set_corner_radius_all(16)
	panel_style.set_content_margin_all(SPACING_XL)
	add_theme_stylebox_override("panel", panel_style)

	# Mission title
	if mission_title:
		mission_title.add_theme_font_size_override("font_size", FONT_SIZE_XL)
		mission_title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

	# Outcome label
	if outcome_label:
		outcome_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)

	# Section headers
	for header in [crew_section_header, loot_section_header, campaign_section_header]:
		if header:
			header.add_theme_font_size_override("font_size", FONT_SIZE_LG)
			header.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

	# Stats labels
	for label in [rounds_label, enemies_defeated_label, casualties_label, credits_earned_label]:
		if label:
			label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
			label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

	# Campaign change labels
	for label in [rivals_label, patrons_label, quest_label]:
		if label:
			label.add_theme_font_size_override("font_size", FONT_SIZE_SM)

	# Continue button
	if continue_button:
		continue_button.custom_minimum_size.y = TOUCH_TARGET_COMFORT
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = COLOR_SUCCESS
		btn_style.set_corner_radius_all(8)
		btn_style.set_content_margin_all(SPACING_MD)
		continue_button.add_theme_stylebox_override("normal", btn_style)
		continue_button.add_theme_color_override("font_color", Color.WHITE)
		continue_button.add_theme_font_size_override("font_size", FONT_SIZE_LG)

func _clear_container(container: Container) -> void:
	"""Clear all children from container"""
	if not container:
		return
	for child in container.get_children():
		child.queue_free()

func _create_subsection_header(title: String, icon: String = "") -> Label:
	"""Create a subsection header label"""
	var header := Label.new()
	header.text = "%s %s" % [icon, title] if not icon.is_empty() else title
	header.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	header.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	return header

func _get_item_icon(item_type: String) -> String:
	"""Get emoji icon for item type"""
	match item_type:
		"weapon": return "⚔️"
		"armor": return "🛡️"
		"gear": return "🔧"
		"consumable": return "💊"
		"credits": return "💰"
		_: return "📦"

func _start_invasion_pulse() -> void:
	"""Start pulsing animation for invasion warning"""
	if not invasion_warning or not invasion_warning.visible:
		return

	# Create timer for pulsing effect
	_invasion_timer = Timer.new()
	_invasion_timer.wait_time = 0.5
	_invasion_timer.autostart = true
	add_child(_invasion_timer)

	var pulse_state: bool = false
	_invasion_timer.timeout.connect(func():
		if invasion_warning and invasion_warning.visible:
			pulse_state = !pulse_state
			invasion_warning.modulate = Color.WHITE if pulse_state else Color(1.0, 0.5, 0.5, 1.0)
	)

# ============================================================================
# SIGNAL HANDLERS
# ============================================================================

func _on_continue_pressed() -> void:
	"""Handle continue button press"""
	print("PostBattleSummarySheet: Continue pressed")
	continue_pressed.emit()
