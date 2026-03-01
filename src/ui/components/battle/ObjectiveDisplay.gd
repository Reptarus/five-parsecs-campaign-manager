class_name FPCM_ObjectiveDisplay
extends PanelContainer

## Objective Display Panel
##
## Shows current battle objective with victory conditions and setup instructions.
## Allows rolling for objectives and tracking progress.

const MissionObjectiveSystem = preload("res://src/core/battle/MissionObjectiveSystem.gd")
const FiveParsecsCampaignPanel = preload("res://src/ui/screens/campaign/panels/BaseCampaignPanel.gd")

# Signals
signal objective_rolled(objective: MissionObjectiveSystem.Objective)
signal objective_acknowledged()

# UI References
@onready var title_label: Label = $VBox/TitleLabel
@onready var mission_type_label: Label = $VBox/MissionTypeLabel
@onready var roll_display: Label = $VBox/RollDisplay
@onready var objective_name_label: Label = $VBox/ObjectiveNameLabel
@onready var description_label: RichTextLabel = $VBox/DescriptionLabel
@onready var victory_label: RichTextLabel = $VBox/VictoryLabel
@onready var placement_label: Label = $VBox/PlacementLabel
@onready var button_container: HBoxContainer = $VBox/ButtonContainer

# System
var objective_system: MissionObjectiveSystem
var current_objective: MissionObjectiveSystem.Objective
var current_mission_type: String = "opportunity"
var current_roll: int = 0

func _ready() -> void:
	objective_system = MissionObjectiveSystem.new()
	_setup_panel_style()
	_setup_buttons()
	hide()

func _setup_panel_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = FiveParsecsCampaignPanel.COLOR_ELEVATED  # Design system: card backgrounds
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_width_left = 3  # Accent border (objective indicator)
	style.border_color = Color.MEDIUM_PURPLE  # Keep purple for mission specialty
	style.set_content_margin_all(FiveParsecsCampaignPanel.SPACING_MD)  # Design system: 16px
	add_theme_stylebox_override("panel", style)

func _setup_buttons() -> void:
	if not button_container:
		return

	# Clear existing
	for child in button_container.get_children():
		child.queue_free()

	# Continue button
	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.pressed.connect(_on_acknowledge_pressed)
	button_container.add_child(continue_btn)

	# Reroll button
	var reroll_btn := Button.new()
	reroll_btn.text = "Reroll"
	reroll_btn.pressed.connect(_on_reroll_pressed)
	button_container.add_child(reroll_btn)

## Roll objective for mission type
func roll_objective(mission_type: String) -> void:
	current_mission_type = mission_type.to_lower().replace(" ", "_")
	current_roll = randi_range(1, 100)
	current_objective = objective_system.get_objective_for_roll(current_roll, current_mission_type)

	_update_display()
	objective_rolled.emit(current_objective)
	show()

## Display a specific objective
func display_objective(objective: MissionObjectiveSystem.Objective, roll: int = 0) -> void:
	current_objective = objective
	current_roll = roll
	_update_display()
	show()

func _update_display() -> void:
	if not current_objective:
		return

	# Mission type
	if mission_type_label:
		mission_type_label.text = "Mission Type: %s" % current_mission_type.capitalize()

	# Roll display
	if roll_display and current_roll > 0:
		roll_display.text = "Rolled: %d" % current_roll
		roll_display.visible = true
	elif roll_display:
		roll_display.visible = false

	# Objective name
	if objective_name_label:
		objective_name_label.text = current_objective.name
		objective_name_label.modulate = Color.MEDIUM_PURPLE

	# Description
	if description_label:
		description_label.bbcode_enabled = true
		description_label.text = "[color=white]%s[/color]" % current_objective.description

	# Victory condition
	if victory_label:
		victory_label.bbcode_enabled = true
		victory_label.text = "[b]Victory:[/b] %s" % current_objective.victory_condition

	# Placement
	if placement_label:
		placement_label.text = "Setup: %s" % current_objective.placement_rules
		placement_label.add_theme_color_override("font_color", UIColors.COLOR_TEXT_SECONDARY)

## Get current objective
func get_current_objective() -> MissionObjectiveSystem.Objective:
	return current_objective

func _on_acknowledge_pressed() -> void:
	objective_acknowledged.emit()
	hide()

func _on_reroll_pressed() -> void:
	roll_objective(current_mission_type)
