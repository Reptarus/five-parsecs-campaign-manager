extends PanelContainer
class_name QuestProgressTracker

## Quest Progress Tracker - Post-Battle Quest System (Five Parsecs p.119)
## Displays quest progress rolls with visual outcomes and travel requirements
## Signal architecture: call-down-signal-up pattern
## Touch-friendly with 48px minimum height

# ============ SIGNALS (Up Communication) ============
signal quest_finale_ready(quest_name: String)  # Quest reached finale (roll 7+)

# ============ ENUMS ============
enum QuestOutcome {
	DEAD_END,      # ≤3: Dead end, quest continues but no progress
	PROGRESS,      # 4-6: Progress made, gain 1 Quest Rumor
	FINALE_READY   # 7+: Finale ready, can trigger next battle
}

# ============ CONSTANTS (Design System) ============
const SPACING_SM := 8
const SPACING_MD := 16

const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18

# Colors from BaseCampaignPanel
const COLOR_SECONDARY := Color("#111827")
const COLOR_BORDER := Color("#374151")
const COLOR_TERTIARY := Color("#1f2937")

const COLOR_TEXT_PRIMARY := Color("#f3f4f6")
const COLOR_TEXT_SECONDARY := Color("#9ca3af")

const COLOR_WARNING := Color("#f59e0b")  # Amber - Dead end
const COLOR_SUCCESS := Color("#10b981")  # Green - Progress
const COLOR_ACCENT := Color("#3b82f6")   # Blue - Finale ready

# ============ PROPERTIES ============
var quest_data: Dictionary = {}
var current_outcome: QuestOutcome = QuestOutcome.DEAD_END

# ============ ONREADY NODE REFERENCES ============
@onready var _quest_title: Label = null
@onready var _progress_bar: ProgressBar = null
@onready var _dice_icon: ColorRect = null
@onready var _roll_value: Label = null
@onready var _modifier_label: Label = null
@onready var _outcome_label: Label = null
@onready var _next_step_label: Label = null

# ============ LIFECYCLE ============
func _ready() -> void:
	_setup_panel_style()
	_build_layout()

	# Update display if data was set before _ready
	if not quest_data.is_empty():
		_update_display()

# ============ PUBLIC INTERFACE (Call Down) ============
func setup(data: Dictionary) -> void:
	"""
	Configure quest progress display.

	Required fields:
	- quest_name: String - Name of the quest
	- base_roll: int - D6 roll result (1-6)
	- rumors: int - Number of Quest Rumors (added to roll)
	- modifier: int - Battle outcome modifier (-2 if lost)
	- total: int - Final total (base_roll + rumors + modifier)
	- outcome: QuestOutcome - Calculated outcome enum
	- travel_required: bool - Must travel to continue quest
	- progress_percent: float - Visual progress (0-100)
	"""
	if data.is_empty():
		push_warning("QuestProgressTracker: Empty quest data provided")
		return

	quest_data = data
	current_outcome = data.get("outcome", QuestOutcome.DEAD_END)

	# Update display immediately if nodes exist (after _ready)
	if _quest_title != null:
		_update_display()

# ============ PRIVATE METHODS ============
func _setup_panel_style() -> void:
	"""Apply panel styling with subtle glass morphism"""
	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 0.8)
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(SPACING_MD)
	add_theme_stylebox_override("panel", style)

func _build_layout() -> void:
	"""Build quest tracker layout"""
	# Main vertical container
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", SPACING_SM)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.name = "MainVBox"
	add_child(vbox)

	# Quest title (FONT_SIZE_LG = 18)
	_quest_title = Label.new()
	_quest_title.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	_quest_title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_quest_title.text = "Quest Progress"
	_quest_title.name = "QuestTitle"
	vbox.add_child(_quest_title)

	# Progress bar
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size.y = 8
	_progress_bar.show_percentage = false
	_progress_bar.name = "ProgressBar"
	_style_progress_bar()
	vbox.add_child(_progress_bar)

	# Roll result container (HBoxContainer)
	var roll_result_hbox := HBoxContainer.new()
	roll_result_hbox.add_theme_constant_override("separation", SPACING_SM)
	roll_result_hbox.name = "RollResult"
	vbox.add_child(roll_result_hbox)

	# Dice icon (24x24 ColorRect)
	_dice_icon = ColorRect.new()
	_dice_icon.custom_minimum_size = Vector2(24, 24)
	_dice_icon.color = COLOR_ACCENT
	_dice_icon.name = "DiceIcon"
	roll_result_hbox.add_child(_dice_icon)

	# Roll value label
	_roll_value = Label.new()
	_roll_value.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_roll_value.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_roll_value.text = "D6 + Rumors = 0"
	_roll_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roll_value.name = "RollValue"
	roll_result_hbox.add_child(_roll_value)

	# Modifier label (shown only if modifier != 0)
	_modifier_label = Label.new()
	_modifier_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_modifier_label.add_theme_color_override("font_color", Color("#ef4444"))  # Red
	_modifier_label.text = ""
	_modifier_label.visible = false
	_modifier_label.name = "ModifierLabel"
	roll_result_hbox.add_child(_modifier_label)

	# Outcome label (color-coded)
	_outcome_label = Label.new()
	_outcome_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	_outcome_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_outcome_label.text = "Calculating..."
	_outcome_label.name = "OutcomeLabel"
	vbox.add_child(_outcome_label)

	# Next step label (travel requirement)
	_next_step_label = Label.new()
	_next_step_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_next_step_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_next_step_label.text = ""
	_next_step_label.visible = false
	_next_step_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_next_step_label.name = "NextStepLabel"
	vbox.add_child(_next_step_label)

func _style_progress_bar() -> void:
	"""Apply design system styling to progress bar"""
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = COLOR_TERTIARY
	bg_style.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = COLOR_ACCENT
	fill_style.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("fill", fill_style)

func _update_display() -> void:
	"""Update all UI elements from quest_data"""
	if not is_inside_tree():
		return

	# Quest title
	var quest_name: String = quest_data.get("quest_name", "Unknown Quest")
	_quest_title.text = quest_name

	# Progress bar
	var progress: float = quest_data.get("progress_percent", 0.0)
	_progress_bar.value = progress

	# Roll calculation breakdown
	var base_roll: int = quest_data.get("base_roll", 1)
	var rumors: int = quest_data.get("rumors", 0)
	var modifier: int = quest_data.get("modifier", 0)
	var total: int = quest_data.get("total", base_roll + rumors + modifier)

	# Update roll value text
	_roll_value.text = "D6 (%d) + Rumors (%d) = %d" % [base_roll, rumors, total]

	# Show modifier if battle was lost
	if modifier != 0:
		_modifier_label.text = "%+d (Lost battle)" % modifier
		_modifier_label.visible = true
	else:
		_modifier_label.visible = false

	# Determine outcome and update label with color
	var outcome: QuestOutcome = quest_data.get("outcome", _calculate_outcome(total))
	_update_outcome_display(outcome)

	# Travel requirement
	var travel_required: bool = quest_data.get("travel_required", false)
	if travel_required:
		_next_step_label.text = "Must travel to continue quest"
		_next_step_label.visible = true
	else:
		_next_step_label.visible = false

	# Emit finale signal if quest is ready
	if outcome == QuestOutcome.FINALE_READY:
		quest_finale_ready.emit(quest_name)

func _calculate_outcome(total: int) -> QuestOutcome:
	"""Calculate quest outcome from total roll (Five Parsecs p.119)"""
	if total <= 3:
		return QuestOutcome.DEAD_END
	elif total <= 6:
		return QuestOutcome.PROGRESS
	else:  # 7+
		return QuestOutcome.FINALE_READY

func _update_outcome_display(outcome: QuestOutcome) -> void:
	"""Update outcome label with color-coded text"""
	match outcome:
		QuestOutcome.DEAD_END:
			_outcome_label.text = "⚠ Dead End - Quest continues, no progress"
			_outcome_label.add_theme_color_override("font_color", COLOR_WARNING)
			_dice_icon.color = COLOR_WARNING

		QuestOutcome.PROGRESS:
			_outcome_label.text = "✓ Progress! Gained 1 Quest Rumor"
			_outcome_label.add_theme_color_override("font_color", COLOR_SUCCESS)
			_dice_icon.color = COLOR_SUCCESS

		QuestOutcome.FINALE_READY:
			_outcome_label.text = "★ Finale Ready! Quest climax next battle"
			_outcome_label.add_theme_color_override("font_color", COLOR_ACCENT)
			_dice_icon.color = COLOR_ACCENT
			# Add subtle glow effect for finale
			_add_finale_glow()

func _add_finale_glow() -> void:
	"""Add subtle glow effect when finale is ready"""
	# Create glow effect on outcome label
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(COLOR_ACCENT.r, COLOR_ACCENT.g, COLOR_ACCENT.b, 0.1)
	glow_style.set_corner_radius_all(8)
	glow_style.set_content_margin_all(8)
	glow_style.border_color = COLOR_ACCENT
	glow_style.set_border_width_all(1)

	# Apply glow to panel
	var current_style: StyleBox = get_theme_stylebox("panel")
	if current_style is StyleBoxFlat:
		var enhanced_style := (current_style as StyleBoxFlat).duplicate()
		enhanced_style.border_color = COLOR_ACCENT
		enhanced_style.set_border_width_all(2)
		add_theme_stylebox_override("panel", enhanced_style)
