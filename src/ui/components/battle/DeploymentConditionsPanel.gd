class_name FPCM_DeploymentConditionsPanel
extends PanelContainer

## Deployment Conditions Panel
##
## Displays the rolled deployment condition for pre-battle setup.
## Shows condition title, description, effects summary, and action buttons.

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
	style.bg_color = Color(0.1, 0.12, 0.18, 0.95)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 3
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color.ORANGE
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

func _setup_buttons() -> void:
	if not button_container:
		return

	# Clear existing
	for child in button_container.get_children():
		child.queue_free()

	# Acknowledge button
	var ack_btn := Button.new()
	ack_btn.text = "Continue"
	ack_btn.pressed.connect(_on_acknowledge_pressed)
	button_container.add_child(ack_btn)

	# Details button
	var details_btn := Button.new()
	details_btn.text = "Details"
	details_btn.pressed.connect(_on_details_pressed)
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
		# Color based on severity
		if current_condition.condition_id == "NO_CONDITION":
			title_label.modulate = Color.GREEN
		elif current_condition.condition_id in ["SURPRISE_ENCOUNTER"]:
			title_label.modulate = Color.CYAN # Beneficial
		else:
			title_label.modulate = Color.ORANGE # Challenging

	# Description
	if description_label:
		description_label.text = current_condition.description

	# Effects summary
	if effects_label:
		var effects_text := conditions_system.get_condition_effects_summary(current_condition)
		effects_label.text = effects_text

	# Roll display
	if roll_display and current_roll > 0:
		roll_display.text = "Rolled: %d" % current_roll
		roll_display.visible = true
	elif roll_display:
		roll_display.visible = false

	# Mission type
	if mission_type_label:
		var type_name := _get_mission_type_name(current_mission_type)
		mission_type_label.text = "Mission: %s" % type_name

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
