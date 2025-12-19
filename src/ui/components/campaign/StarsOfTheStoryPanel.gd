extends PanelContainer
class_name StarsOfTheStoryPanel

## Stars of the Story Panel Component
## Displays emergency abilities from core rules p.67
## Each ability usable once per campaign (twice with Elite Ranks bonus)

# Design constants from BaseCampaignPanel
const SPACING_XS := 4
const SPACING_SM := 8
const SPACING_MD := 16
const SPACING_LG := 24
const SPACING_XL := 32
const FONT_SIZE_XS := 11
const FONT_SIZE_SM := 14
const FONT_SIZE_MD := 16
const FONT_SIZE_LG := 18
const FONT_SIZE_XL := 24

const TOUCH_TARGET_MIN := 48
const TOUCH_TARGET_COMFORT := 56

# Color palette - Deep Space Theme
const COLOR_BASE := Color("#1A1A2E")
const COLOR_ELEVATED := Color("#252542")
const COLOR_INPUT := Color("#1E1E36")
const COLOR_BORDER := Color("#3A3A5C")
const COLOR_ACCENT := Color("#2D5A7B")
const COLOR_ACCENT_HOVER := Color("#3A7199")
const COLOR_TEXT_PRIMARY := Color("#E0E0E0")
const COLOR_TEXT_SECONDARY := Color("#808080")
const COLOR_TEXT_DISABLED := Color("#404040")
const COLOR_SUCCESS := Color("#10B981")
const COLOR_WARNING := Color("#D97706")
const COLOR_DANGER := Color("#DC2626")

# Signals
signal ability_selected(ability: int)
signal ability_used(ability: int, result: Dictionary)

# System reference
var _stars_system: StarsOfTheStorySystem

# UI References
var _main_vbox: VBoxContainer
var _header_hbox: HBoxContainer
var _abilities_grid: GridContainer
var _ability_cards: Dictionary = {}  # StarAbility -> AbilityCard
var _info_label: Label


func _ready() -> void:
	_setup_ui()
	_apply_glass_style()


## Initialize panel with Stars of the Story system instance
##
## @param stars_system: StarsOfTheStorySystem instance to display
func initialize(stars_system: StarsOfTheStorySystem) -> void:
	_stars_system = stars_system
	
	if _stars_system:
		# Connect to system signals
		_stars_system.star_ability_used.connect(_on_ability_used)
		_stars_system.star_ability_recharged.connect(_on_ability_recharged)
		
		# Initial update
		refresh_display()


## Refresh the entire display from system state
func refresh_display() -> void:
	if not _stars_system:
		return
	
	# Update each ability card
	for ability in StarsOfTheStorySystem.StarAbility.values():
		if _ability_cards.has(ability):
			_update_ability_card(ability)
	
	# Update info label (null check since refresh_display can be called before _setup_ui)
	if _info_label:
		if not _stars_system.is_active():
			_info_label.text = "⚠ Stars of the Story NOT AVAILABLE (Insanity difficulty)"
			_info_label.add_theme_color_override("font_color", COLOR_DANGER)
		else:
			_info_label.text = "Emergency abilities - use wisely!"
			_info_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)


## Update display for a single ability
##
## @param ability: StarAbility enum value
func _update_ability_card(ability: int) -> void:
	if not _ability_cards.has(ability):
		return
	
	var card = _ability_cards[ability]
	var uses_remaining: int = _stars_system.get_uses_remaining(ability)
	var max_uses: int = _stars_system.get_max_uses(ability)
	var can_use: bool = _stars_system.can_use(ability)
	
	# Update uses label
	card["uses_label"].text = "%d/%d" % [uses_remaining, max_uses]
	
	# Update visual state
	if can_use:
		# Available state - green accent
		card["card_bg"].add_theme_color_override("bg_color", COLOR_ELEVATED)
		card["border"].add_theme_color_override("bg_color", COLOR_SUCCESS)
		card["name_label"].add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		card["uses_label"].add_theme_color_override("font_color", COLOR_SUCCESS)
		card["use_button"].disabled = false
		card["use_button"].modulate = Color.WHITE
	else:
		# Exhausted state - disabled appearance
		card["card_bg"].add_theme_color_override("bg_color", COLOR_BASE)
		card["border"].add_theme_color_override("bg_color", COLOR_TEXT_DISABLED)
		card["name_label"].add_theme_color_override("font_color", COLOR_TEXT_DISABLED)
		card["uses_label"].add_theme_color_override("font_color", COLOR_TEXT_DISABLED)
		card["use_button"].disabled = true
		card["use_button"].modulate = Color(0.5, 0.5, 0.5, 1.0)


func _setup_ui() -> void:
	"""Build the Stars of the Story panel UI"""
	custom_minimum_size = Vector2(400, 0)
	
	# Main container with padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", SPACING_MD)
	margin.add_theme_constant_override("margin_right", SPACING_MD)
	margin.add_theme_constant_override("margin_top", SPACING_MD)
	margin.add_theme_constant_override("margin_bottom", SPACING_MD)
	add_child(margin)
	
	_main_vbox = VBoxContainer.new()
	_main_vbox.add_theme_constant_override("separation", SPACING_LG)
	margin.add_child(_main_vbox)
	
	# Header: Star Icon + "Stars of the Story"
	_header_hbox = HBoxContainer.new()
	_header_hbox.add_theme_constant_override("separation", SPACING_SM)
	_main_vbox.add_child(_header_hbox)
	
	var star_icon = Label.new()
	star_icon.text = "⭐"
	star_icon.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	_header_hbox.add_child(star_icon)
	
	var title_label = Label.new()
	title_label.text = "STARS OF THE STORY"
	title_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_hbox.add_child(title_label)
	
	# Info label
	_info_label = Label.new()
	_info_label.text = "Emergency abilities - use wisely!"
	_info_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	_info_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_vbox.add_child(_info_label)
	
	# Grid of ability cards (2 columns)
	_abilities_grid = GridContainer.new()
	_abilities_grid.columns = 2
	_abilities_grid.add_theme_constant_override("h_separation", SPACING_MD)
	_abilities_grid.add_theme_constant_override("v_separation", SPACING_MD)
	_main_vbox.add_child(_abilities_grid)
	
	# Create ability cards
	_create_ability_card(StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD)
	_create_ability_card(StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE)
	_create_ability_card(StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO)
	_create_ability_card(StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND)


## Create an ability card UI element
##
## @param ability: StarAbility enum value
func _create_ability_card(ability: int) -> void:
	# Card container
	var card_container = PanelContainer.new()
	card_container.custom_minimum_size = Vector2(280, 160)
	_abilities_grid.add_child(card_container)
	
	# Card background (will be styled)
	var card_bg = ColorRect.new()
	card_bg.color = COLOR_ELEVATED
	card_container.add_child(card_bg)
	
	# Border accent (left edge)
	var border = ColorRect.new()
	border.custom_minimum_size = Vector2(4, 0)
	border.color = COLOR_SUCCESS
	border.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Inner margin
	var inner_margin = MarginContainer.new()
	inner_margin.add_theme_constant_override("margin_left", SPACING_MD)
	inner_margin.add_theme_constant_override("margin_right", SPACING_MD)
	inner_margin.add_theme_constant_override("margin_top", SPACING_SM)
	inner_margin.add_theme_constant_override("margin_bottom", SPACING_SM)
	card_container.add_child(inner_margin)
	
	# Card content
	var card_vbox = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", SPACING_SM)
	inner_margin.add_child(card_vbox)
	
	# Header row: Name + Uses
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", SPACING_SM)
	card_vbox.add_child(header_row)
	
	var name_label = Label.new()
	name_label.text = _stars_system.get_ability_name(ability) if _stars_system else _get_default_ability_name(ability)
	name_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header_row.add_child(name_label)
	
	var uses_label = Label.new()
	uses_label.text = "1/1"
	uses_label.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	uses_label.add_theme_color_override("font_color", COLOR_SUCCESS)
	header_row.add_child(uses_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = _stars_system.get_ability_description(ability) if _stars_system else ""
	desc_label.add_theme_font_size_override("font_size", FONT_SIZE_SM)
	desc_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(desc_label)
	
	# Use button
	var use_button = Button.new()
	use_button.text = "Use Ability"
	use_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	use_button.pressed.connect(_on_use_button_pressed.bind(ability))
	card_vbox.add_child(use_button)
	
	# Apply button styling
	_style_button(use_button)
	
	# Store card references
	_ability_cards[ability] = {
		"container": card_container,
		"card_bg": card_bg,
		"border": border,
		"name_label": name_label,
		"uses_label": uses_label,
		"desc_label": desc_label,
		"use_button": use_button
	}


## Apply glass morphism style to panel
func _apply_glass_style() -> void:
	# Panel background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(COLOR_BASE.r, COLOR_BASE.g, COLOR_BASE.b, 0.95)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)


## Apply button styling
func _style_button(button: Button) -> void:
	# Normal state
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = COLOR_ACCENT
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", style_normal)
	
	# Hover state
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = COLOR_ACCENT_HOVER
	style_hover.corner_radius_top_left = 4
	style_hover.corner_radius_top_right = 4
	style_hover.corner_radius_bottom_left = 4
	style_hover.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("hover", style_hover)
	
	# Disabled state
	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = COLOR_TEXT_DISABLED
	style_disabled.corner_radius_top_left = 4
	style_disabled.corner_radius_top_right = 4
	style_disabled.corner_radius_bottom_left = 4
	style_disabled.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("disabled", style_disabled)
	
	# Font color
	button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", COLOR_TEXT_DISABLED)
	button.add_theme_font_size_override("font_size", FONT_SIZE_MD)


## Get default ability name (fallback if system not initialized)
func _get_default_ability_name(ability: int) -> String:
	match ability:
		StarsOfTheStorySystem.StarAbility.IT_WASNT_THAT_BAD:
			return "It Wasn't That Bad!"
		StarsOfTheStorySystem.StarAbility.DRAMATIC_ESCAPE:
			return "Dramatic Escape"
		StarsOfTheStorySystem.StarAbility.ITS_TIME_TO_GO:
			return "It's Time To Go"
		StarsOfTheStorySystem.StarAbility.RAINY_DAY_FUND:
			return "Rainy Day Fund"
		_:
			return "Unknown Ability"


## Signal handlers

func _on_use_button_pressed(ability: int) -> void:
	"""Handle use button press - emit signal for parent to handle"""
	if not _stars_system or not _stars_system.can_use(ability):
		return
	
	ability_selected.emit(ability)


func _on_ability_used(ability: int, details: Dictionary) -> void:
	"""Handle ability used event from system"""
	_update_ability_card(ability)
	ability_used.emit(ability, details)


func _on_ability_recharged(ability: int, new_uses: int) -> void:
	"""Handle ability recharged event (from Elite Ranks bonus)"""
	_update_ability_card(ability)
