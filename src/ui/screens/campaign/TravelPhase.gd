# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control

const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const GameStateManager = preload("res://src/core/managers/GameStateManager.gd")
const PatronJobManager = preload("res://src/core/campaign/PatronJobManager.gd")

enum TravelStep {
	UPKEEP,
	PATRON_CHECK,
	MISSION_START
}

@export var tab_container: TabContainer
@export var back_button: Button
@export var log_book: TextEdit
@export var patrons_list: Control
@export var mission_details: Control

## Desktop/landscape width of the central PanelContainer (matches the .tscn
## custom_minimum_size.x). Relaxed to 0 only when collapsed to a single column
## so the 600px floor never clips a narrow (e.g. 375px) phone viewport.
const PANEL_MAX_WIDTH := 600.0
const PANEL_EDGE_MARGIN := 48.0

var current_step: TravelStep = TravelStep.UPKEEP
var game_state: FiveParsecsGameState
var game_state_manager: GameStateManager
var patron_job_manager: PatronJobManager

signal step_completed
signal phase_completed

func _ready() -> void:
	# Use GameState autoload directly (GameStateManager.get_game_state() is always null)
	var gs = get_node_or_null("/root/GameState")
	if gs:
		game_state = gs
	else:
		push_error("TravelPhase: GameState autoload not found")
		return

	game_state_manager = get_node_or_null("/root/GameStateManager")

	# PatronJobManager is not an autoload and GameStateManager has no getter for it.
	# Leave patron_job_manager null — patron features are not yet wired.

	_setup_current_step()

	# Responsive width: connect to layout_class_changed (rotation/resize) and apply
	# once now. Desktop/landscape behavior is unchanged (keeps the 600px floor);
	# only single-column collapse relaxes min_x so 375px viewports don't clip.
	var rm = get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_signal("layout_class_changed"):
		if not rm.layout_class_changed.is_connected(_on_layout_class_changed):
			rm.layout_class_changed.connect(_on_layout_class_changed)
	_apply_responsive_panel_width()

## Recompute the central PanelContainer min width for the current layout class.
## Single-column (phone/portrait) -> 0 so the panel can shrink to the viewport.
## Otherwise keep the desktop floor, capped at viewport - margin so it never
## exceeds an unusually narrow landscape window.
func _apply_responsive_panel_width() -> void:
	var panel := get_node_or_null("CenterContainer/PanelContainer") as Control
	if not panel:
		return

	var min_x := PANEL_MAX_WIDTH
	var rm = get_node_or_null("/root/ResponsiveManager")
	if rm and rm.has_method("should_collapse_to_single_column") \
			and rm.should_collapse_to_single_column():
		min_x = 0.0
	else:
		# Cap to the available viewport width so a narrow landscape window
		# still fits the panel without clipping.
		var avail := get_viewport_rect().size.x - PANEL_EDGE_MARGIN
		if avail > 0.0:
			min_x = minf(PANEL_MAX_WIDTH, avail)

	panel.custom_minimum_size.x = min_x

func _on_layout_class_changed(_effective_columns: int) -> void:
	_apply_responsive_panel_width()

func _setup_current_step() -> void:
	match current_step:
		TravelStep.UPKEEP:
			# Implement the logic for the UPKEEP step
			pass
		TravelStep.PATRON_CHECK:
			process_patron_check()
		TravelStep.MISSION_START:
			# Implement the logic for the MISSION_START step
			pass

func process_patron_check() -> void:
	if not patron_job_manager:
		step_completed.emit()
		return
	var available_patrons = patron_job_manager.get_available_patrons()
	for patron in available_patrons:
		_display_result(patrons_list, patron.get_description())
	step_completed.emit()

func _display_result(container: Control, description: String) -> void:
	if not container:
		return
	var label = Label.new()
	label.text = description
	container.add_child(label)
