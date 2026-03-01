class_name FPCM_DeploymentConditionsPanel
extends PanelContainer

## Deployment Conditions Panel
##
## Displays the rolled deployment condition for pre-battle setup.
## Shows condition title, description, effects summary, and action buttons.

## Design System Constants (from UIColors)
const COLOR_PRIMARY := UIColors.COLOR_PRIMARY
const COLOR_SECONDARY := UIColors.COLOR_SECONDARY
const COLOR_TERTIARY := UIColors.COLOR_TERTIARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const COLOR_BLUE := UIColors.COLOR_BLUE
const COLOR_EMERALD := UIColors.COLOR_EMERALD
const COLOR_AMBER := UIColors.COLOR_AMBER
const COLOR_RED := UIColors.COLOR_RED
const COLOR_CYAN := UIColors.COLOR_CYAN
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY

const SPACING_SM := UIColors.SPACING_SM
const SPACING_MD := UIColors.SPACING_MD
const SPACING_LG := UIColors.SPACING_LG

const DeploymentConditionsSystem = preload("res://src/core/battle/DeploymentConditionsSystem.gd")

# Signals
signal condition_acknowledged()
signal reroll_requested()
signal details_requested(condition_id: String)

# UI References
@onready var title_label: Label = $VBox/TitleLabel
@onready var description_label: RichTextLabel = $VBox/DescriptionLabel
@onready var effects_label: Label = $VBox/EffectsLabel
@onready var roll_display: Label = $VBox/RollDisplay
@onready var mission_type_label: Label = $VBox/MissionTypeLabel
@onready var button_container: HBoxContainer = $VBox/ButtonContainer

# System reference
var conditions_system: DeploymentConditionsSystem
var current_condition: DeploymentConditionsSystem.DeploymentCondition
var current_roll: int = 0
var current_mission_type: DeploymentConditionsSystem.MissionType

func _ready() -> void:
	conditions_system = DeploymentConditionsSystem.new()
	_setup_panel_style()
	_setup_buttons()
	hide()

func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	# Glass morphism background
	style.bg_color = Color(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 0.8)
	style.set_corner_radius_all(16)
	# Subtle border
	style.border_color = Color(COLOR_BORDER.r, COLOR_BORDER.g, COLOR_BORDER.b, 0.5)
	style.set_border_width_all(1)
	# Generous padding
	style.set_content_margin_all(SPACING_LG)
	add_theme_stylebox_override("panel", style)

func _setup_buttons() -> void:
	if not button_container:
		return

	# Clear existing
	for child in button_container.get_children():
		child.queue_free()

	# Acknowledge button (primary action)
	var ack_btn := Button.new()
	ack_btn.text = "Continue"
	ack_btn.custom_minimum_size.y = 48  # Touch target
	ack_btn.pressed.connect(_on_acknowledge_pressed)
	
	# Style as primary button
	var primary_style := StyleBoxFlat.new()
	primary_style.bg_color = COLOR_BLUE
	primary_style.set_corner_radius_all(6)
	primary_style.set_content_margin_all(SPACING_MD)
	ack_btn.add_theme_stylebox_override("normal", primary_style)
	
	var primary_hover := primary_style.duplicate() as StyleBoxFlat
	primary_hover.bg_color = COLOR_BLUE.lightened(0.2)
	ack_btn.add_theme_stylebox_override("hover", primary_hover)
	
	button_container.add_child(ack_btn)

	# Details button (secondary action)
	var details_btn := Button.new()
	details_btn.text = "Details"
	details_btn.custom_minimum_size.y = 48  # Touch target
	details_btn.pressed.connect(_on_details_pressed)
	
	# Style as secondary button
	var secondary_style := StyleBoxFlat.new()
	secondary_style.bg_color = Color.TRANSPARENT
	secondary_style.border_color = COLOR_BORDER
	secondary_style.set_border_width_all(2)
	secondary_style.set_corner_radius_all(6)
	secondary_style.set_content_margin_all(SPACING_MD)
	details_btn.add_theme_stylebox_override("normal", secondary_style)
	
	button_container.add_child(details_btn)

## Roll and display a new deployment condition
func roll_condition(mission_type: DeploymentConditionsSystem.MissionType) -> void:
	current_mission_type = mission_type
	current_roll = randi_range(1, 100)
	current_condition = conditions_system.get_condition_for_roll(current_roll, mission_type)

	_update_display()
	show()

## Display a specific condition (for testing or manual selection)
func display_condition(condition: DeploymentConditionsSystem.DeploymentCondition, roll: int = 0) -> void:
	current_condition = condition
	current_roll = roll
	_update_display()
	show()

func _update_display() -> void:
	if not current_condition:
		return

	# Title with condition name
	if title_label:
		title_label.text = current_condition.title
		# Color based on severity (semantic colors from design system)
		if current_condition.condition_id == "NO_CONDITION":
			title_label.add_theme_color_override("font_color", COLOR_EMERALD)
		elif current_condition.condition_id in ["SURPRISE_ENCOUNTER"]:
			title_label.add_theme_color_override("font_color", COLOR_CYAN)  # Beneficial
		else:
			title_label.add_theme_color_override("font_color", COLOR_AMBER)  # Challenging

	# Description
	if description_label:
		description_label.text = current_condition.description
		description_label.add_theme_color_override("default_color", COLOR_TEXT_PRIMARY)

	# Effects summary
	if effects_label:
		var effects_text := conditions_system.get_condition_effects_summary(current_condition)
		effects_label.text = effects_text
		effects_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

	# Roll display
	if roll_display and current_roll > 0:
		roll_display.text = "Rolled: %d" % current_roll
		roll_display.add_theme_color_override("font_color", COLOR_BLUE)
		roll_display.visible = true
	elif roll_display:
		roll_display.visible = false

	# Mission type
	if mission_type_label:
		var type_name := _get_mission_type_name(current_mission_type)
		mission_type_label.text = "Mission: %s" % type_name
		mission_type_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)

## Get current condition for external use
func get_current_condition() -> DeploymentConditionsSystem.DeploymentCondition:
	return current_condition

## Get effects dictionary for battle state modification
func get_condition_effects() -> Dictionary:
	if current_condition:
		return current_condition.effects
	return {}

func _get_mission_type_name(mission_type: DeploymentConditionsSystem.MissionType) -> String:
	match mission_type:
		DeploymentConditionsSystem.MissionType.OPPORTUNITY: return "Opportunity"
		DeploymentConditionsSystem.MissionType.PATRON: return "Patron"
		DeploymentConditionsSystem.MissionType.RIVAL: return "Rival"
		DeploymentConditionsSystem.MissionType.QUEST: return "Quest"
		_: return "Unknown"

func _on_acknowledge_pressed() -> void:
	condition_acknowledged.emit()
	hide()

func _on_details_pressed() -> void:
	if current_condition:
		details_requested.emit(current_condition.condition_id)
		_show_details_popup()

func _show_details_popup() -> void:
	if not current_condition:
		return

	var popup := AcceptDialog.new()
	popup.title = "Deployment Condition Details"
	popup.dialog_text = "%s\n\n%s\n\nEffects:\n%s" % [
		current_condition.title,
		current_condition.description,
		conditions_system.get_condition_effects_summary(current_condition)
	]
	popup.size = Vector2(400, 250)

	get_tree().current_scene.add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(popup.queue_free)