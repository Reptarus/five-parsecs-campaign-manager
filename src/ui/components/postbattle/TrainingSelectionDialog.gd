extends PanelContainer
class_name TrainingSelectionDialog

## Training Selection Dialog for Post-Battle Phase
## Implements Five Parsecs training system with approval roll mechanic
## Reference: Core Rules - Advanced Training section

# Signals
# Sprint 26.3: Character-Everywhere - use Character type instead of Resource
signal training_completed(character: Character, training_type: String)
signal dialog_closed()

# Design System Constants (from BaseCampaelPanel)
const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const SPACING_XL := 32
const TOUCH_TARGET_MIN := 48
const TOUCH_TARGET_COMFORT := 56
const FONT_SIZE_XS := 11
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18
const FONT_SIZE_XL := 24

const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_INPUT := Color("#1E1E36")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_ACCENT_HOVER := Color("#3A7199")
const COLOR_FOCUS := Color("#4FC3F7")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_TEXT_DISABLED := Color("#404040")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")

# Training costs and descriptions (from AdvancementSystem.gd)
const TRAINING_TYPES := {
	"pilot": {
		"name": "Pilot",
		"cost": 20,
		"description": "Ship operations bonuses and piloting skills"
	},
	"medical": {
		"name": "Medical",
		"cost": 20,
		"description": "Healing actions and medical skill +2"
	},
	"mechanic": {
		"name": "Mechanic",
		"cost": 15,
		"description": "Equipment repair and repair skill +2"
	},
	"broker": {
		"name": "Broker",
		"cost": 15,
		"description": "Trade bonuses for buying and selling"
	},
	"security": {
		"name": "Security",
		"cost": 10,
		"description": "Combat bonuses and defensive abilities"
	},
	"merchant": {
		"name": "Merchant",
		"cost": 10,
		"description": "Market bonuses and trade opportunities"
	},
	"bot_tech": {
		"name": "Bot Tech",
		"cost": 10,
		"description": "Bot management and bot skill +2"
	},
	"engineer": {
		"name": "Engineer",
		"cost": 15,
		"description": "Ship upgrade bonuses and engineering"
	}
}

## Sprint 20.2: Fixed constants to match backend (Core Rules p.123)
const ENROLLMENT_FEE := 1    # 1 credit application fee per Core Rules
const APPROVAL_THRESHOLD := 4  # 2D6 roll, 4+ required for approval
const APPROVAL_DICE := "2D6"   # Dice type for approval roll display

# State
var available_crew: Array[Resource] = []
var selected_character: Resource = null
var selected_training_type: String = ""
var can_afford_enrollment: bool = false

# Node references
@onready var title_label: Label = %TitleLabel
@onready var character_selector: OptionButton = %CharacterSelector
@onready var training_list: VBoxContainer = %TrainingList
@onready var cost_display: HBoxContainer = %CostDisplay
@onready var xp_cost_label: Label = %XPCostLabel
@onready var credits_cost_label: Label = %CreditsCostLabel
@onready var roll_button: Button = %RollButton
@onready var result_display: Label = %ResultDisplay
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_update_ui_state()

func _setup_ui() -> void:
	"""Setup UI styling using design system"""
	# Panel background
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_BASE
	panel_style.border_color = COLOR_BORDER
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(SPACING_XL)
	add_theme_stylebox_override("panel", panel_style)
	
	# Title styling
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	
	# Style buttons
	_style_button(roll_button, COLOR_ACCENT)
	_style_button(close_button, COLOR_ELEVATED)
	
	# Character selector styling
	character_selector.custom_minimum_size.y = TOUCH_TARGET_MIN
	
	# Cost display styling
	xp_cost_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	credits_cost_label.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	
	# Result display styling
	result_display.add_theme_font_size_override("font_size", FONT_SIZE_MD)
	result_display.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _style_button(button: Button, bg_color: Color) -> void:
	"""Apply consistent button styling"""
	button.custom_minimum_size.y = TOUCH_TARGET_MIN
	
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = bg_color
	normal_style.set_corner_radius_all(4)
	normal_style.set_content_margin_all(SPACING_MD)
	button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = COLOR_ACCENT_HOVER
	hover_style.set_corner_radius_all(4)
	hover_style.set_content_margin_all(SPACING_MD)
	button.add_theme_stylebox_override("hover", hover_style)

func _connect_signals() -> void:
	"""Connect UI signals"""
	character_selector.item_selected.connect(_on_character_selected)
	roll_button.pressed.connect(_on_roll_pressed)
	close_button.pressed.connect(_on_close_pressed)

func setup(crew: Array, current_credits: int) -> void:
	"""Initialize dialog with crew data and credit availability"""
	available_crew = crew
	can_afford_enrollment = current_credits >= ENROLLMENT_FEE
	
	_populate_character_list()
	_populate_training_list()
	_update_ui_state()

func _populate_character_list() -> void:
	"""Populate character dropdown with available crew"""
	character_selector.clear()
	
	for character in available_crew:
		# Sprint 26.3: Character-Everywhere - use Character properties with fallback
		var char_name: String = character.character_name if "character_name" in character else "Unknown"
		# Note: Character class uses "experience" property, not "experience_points"
		var current_xp: int = character.experience if "experience" in character else 0
		var display_text := "%s (%d XP)" % [char_name, current_xp]
		character_selector.add_item(display_text)
	
	if available_crew.size() > 0:
		character_selector.selected = 0
		selected_character = available_crew[0]

func _populate_training_list() -> void:
	"""Create training option buttons"""
	# Clear existing children
	for child in training_list.get_children():
		child.queue_free()
	
	# Create button for each training type
	for training_key in TRAINING_TYPES.keys():
		var training_data: Dictionary = TRAINING_TYPES[training_key]
		var button := _create_training_button(training_key, training_data)
		training_list.add_child(button)

func _create_training_button(training_key: String, training_data: Dictionary) -> Button:
	"""Create a styled training selection button"""
	var button := Button.new()
	button.custom_minimum_size.y = TOUCH_TARGET_MIN
	button.toggle_mode = true
	button.button_group = _get_or_create_button_group()
	
	# Button text with cost
	var button_text := "%s (%d XP)" % [training_data["name"], training_data["cost"]]
	button.text = button_text
	button.tooltip_text = training_data["description"]
	
	# Button styling
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = COLOR_ELEVATED
	normal_style.border_color = COLOR_BORDER
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.set_corner_radius_all(4)
	normal_style.set_content_margin_all(SPACING_MD)
	button.add_theme_stylebox_override("normal", normal_style)
	
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = COLOR_ACCENT
	pressed_style.set_corner_radius_all(4)
	pressed_style.set_content_margin_all(SPACING_MD)
	button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Connect signal
	button.toggled.connect(func(toggled_on: bool): _on_training_selected(training_key, toggled_on))
	
	return button

var _training_button_group: ButtonGroup = null
func _get_or_create_button_group() -> ButtonGroup:
	"""Get or create button group for training selection"""
	if not _training_button_group:
		_training_button_group = ButtonGroup.new()
	return _training_button_group

func _on_character_selected(index: int) -> void:
	"""Handle character selection change"""
	if index >= 0 and index < available_crew.size():
		selected_character = available_crew[index]
		_update_ui_state()

func _on_training_selected(training_key: String, toggled_on: bool) -> void:
	"""Handle training type selection"""
	if toggled_on:
		selected_training_type = training_key
		_update_cost_display()
		_update_ui_state()

func _update_cost_display() -> void:
	"""Update cost display labels"""
	if selected_training_type.is_empty():
		xp_cost_label.text = "XP Cost: -"
		credits_cost_label.text = "Enrollment: -"
		return
	
	var training_data: Dictionary = TRAINING_TYPES[selected_training_type]
	var xp_cost: int = training_data["cost"]
	
	xp_cost_label.text = "XP Cost: %d" % xp_cost
	credits_cost_label.text = "Enrollment: %d credits" % ENROLLMENT_FEE
	
	# Color code based on affordability
	if selected_character:
		# Sprint 26.3: Use "experience" property (not "experience_points")
		var current_xp: int = selected_character.experience if "experience" in selected_character else 0
		var can_afford_xp := current_xp >= xp_cost
		
		xp_cost_label.add_theme_color_override("font_color", COLOR_SUCCESS if can_afford_xp else COLOR_DANGER)
		credits_cost_label.add_theme_color_override("font_color", COLOR_SUCCESS if can_afford_enrollment else COLOR_DANGER)

func _update_ui_state() -> void:
	"""Update button states based on selections and affordability"""
	var has_selection := selected_character != null and not selected_training_type.is_empty()
	var can_afford_xp := false
	
	if has_selection and selected_character:
		# Sprint 26.3: Use "experience" property (not "experience_points")
		var current_xp: int = selected_character.experience if "experience" in selected_character else 0
		var training_data: Dictionary = TRAINING_TYPES[selected_training_type]
		var xp_cost: int = training_data["cost"]
		can_afford_xp = current_xp >= xp_cost

		# Check if character already has this training
		var current_training: Array = selected_character.training if "training" in selected_character else []
		var already_has_training := selected_training_type in current_training
		
		if already_has_training:
			roll_button.disabled = true
			result_display.text = "Character already has this training"
			result_display.add_theme_color_override("font_color", COLOR_WARNING)
			return
	
	roll_button.disabled = not (has_selection and can_afford_xp and can_afford_enrollment)
	result_display.text = ""
	
	if not can_afford_enrollment and has_selection:
		result_display.text = "Insufficient credits for enrollment fee"
		result_display.add_theme_color_override("font_color", COLOR_DANGER)
	elif not can_afford_xp and has_selection:
		result_display.text = "Insufficient XP for training"
		result_display.add_theme_color_override("font_color", COLOR_DANGER)

func _on_roll_pressed() -> void:
	"""Handle approval roll button press - Sprint 20.2 fixed to use 2D6, 4+"""
	if not selected_character or selected_training_type.is_empty():
		return

	# Roll 2D6 for approval (Core Rules: 4+ required)
	var dice_manager = get_node_or_null("/root/DiceManager")
	var roll_result: int = 0
	if dice_manager and dice_manager.has_method("roll_d6"):
		roll_result = dice_manager.roll_d6("Training Approval (die 1)") + dice_manager.roll_d6("Training Approval (die 2)")
	else:
		roll_result = randi_range(1, 6) + randi_range(1, 6)

	var approved := roll_result >= APPROVAL_THRESHOLD

	if approved:
		result_display.text = "%s Roll: %d - Training APPROVED!" % [APPROVAL_DICE, roll_result]
		result_display.add_theme_color_override("font_color", COLOR_SUCCESS)

		# Emit signal for backend processing
		training_completed.emit(selected_character, selected_training_type)

		# Disable roll button to prevent double-training
		roll_button.disabled = true
	else:
		result_display.text = "%s Roll: %d - Training DENIED (need %d+)" % [APPROVAL_DICE, roll_result, APPROVAL_THRESHOLD]
		result_display.add_theme_color_override("font_color", COLOR_DANGER)

func _on_close_pressed() -> void:
	"""Handle close button press"""
	dialog_closed.emit()
	queue_free()

