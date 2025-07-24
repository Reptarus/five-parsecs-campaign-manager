@tool
extends Control
class_name CrewTaskCard

## Enhanced Crew Task Card Component - Visual feedback and 60 FPS animations
## Follows dice system visual feedback patterns and Universal Safety Framework
## Provides comprehensive crew task management with real-time status updates

# Universal Safety patterns
const BaseInformationCard = preload("res://src/base/ui/BaseInformationCard.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")
const CrewTaskManager = preload("res://src/core/managers/CrewTaskManager.gd")
const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# UI components
@onready var task_container: Control = %TaskContainer
@onready var character_portrait: TextureRect = %CharacterPortrait
@onready var character_name_label: Label = %CharacterNameLabel
@onready var task_type_label: Label = %TaskTypeLabel
@onready var task_status_label: Label = %TaskStatusLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var assign_button: Button = %AssignButton
@onready var complete_button: Button = %CompleteButton
@onready var cancel_button: Button = %CancelButton
@onready var task_details: RichTextLabel = %TaskDetails
@onready var animation_player: AnimationPlayer = %AnimationPlayer

# Data management
var character_data: Dictionary = {}
var task_data: Dictionary = {}
var is_task_active: bool = false
var task_progress: float = 0.0
var animation_tween: Tween

# Visual feedback states
enum CardState {
	IDLE,
	SELECTED,
	ASSIGNED,
	IN_PROGRESS,
	COMPLETED,
	FAILED,
	DISABLED
}

var current_state: CardState = CardState.IDLE

# Signal connections
var enhanced_signals: EnhancedCampaignSignals
var crew_task_manager: CrewTaskManager

# Animation configuration
const ANIMATION_DURATION: float = 0.3
const HOVER_SCALE: Vector2 = Vector2(1.05, 1.05)
const NORMAL_SCALE: Vector2 = Vector2.ONE
const PULSE_INTENSITY: float = 0.1

signal task_card_selected(character_data: Dictionary, task_type: int)
signal task_card_assignment_requested(character_data: Dictionary, task_type: int)
signal task_card_completion_requested(character_data: Dictionary)
signal task_card_cancellation_requested(character_data: Dictionary)

func _ready() -> void:
	_setup_crew_task_card()
	_connect_enhanced_signals()
	_setup_animations()

func _setup_crew_task_card() -> void:
	# Initialize animation system
	animation_tween = create_tween()
	animation_tween.set_loops()
	
	# Setup visual feedback
	_apply_card_styling()
	_setup_interactive_elements()

func _connect_enhanced_signals() -> void:
	# Connect to enhanced campaign signals
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Connect task-related signals
	enhanced_signals.connect_signal_safely("crew_task_assigned", self, "_on_task_assigned")
	enhanced_signals.connect_signal_safely("crew_task_completed", self, "_on_task_completed")
	enhanced_signals.connect_signal_safely("crew_task_progress_updated", self, "_on_task_progress_updated")
	enhanced_signals.connect_signal_safely("crew_task_failed", self, "_on_task_failed")

func _setup_animations() -> void:
	# Setup hover animations
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Setup button animations
	if assign_button:
		assign_button.pressed.connect(_on_assign_button_pressed)
		assign_button.mouse_entered.connect(_on_button_hover.bind(assign_button))
		assign_button.mouse_exited.connect(_on_button_unhover.bind(assign_button))
	
	if complete_button:
		complete_button.pressed.connect(_on_complete_button_pressed)
		complete_button.mouse_entered.connect(_on_button_hover.bind(complete_button))
		complete_button.mouse_exited.connect(_on_button_unhover.bind(complete_button))
	
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_button_pressed)
		cancel_button.mouse_entered.connect(_on_button_hover.bind(cancel_button))
		cancel_button.mouse_exited.connect(_on_button_unhover.bind(cancel_button))

func _setup_interactive_elements() -> void:
	# Setup touch-friendly button sizes
	var button_size = Vector2(120, 44)
	if assign_button:
		assign_button.custom_minimum_size = button_size
	if complete_button:
		complete_button.custom_minimum_size = button_size
	if cancel_button:
		cancel_button.custom_minimum_size = button_size

## Main API functions
func setup_character_task_card(character: Dictionary, available_tasks: Array = []) -> void:
	character_data = character.duplicate(true)
	_update_character_display()
	_update_available_tasks(available_tasks)
	_transition_to_state(CardState.IDLE)

func assign_task(task_type: int, task_details: Dictionary = {}) -> void:
	task_data = {
		"type": task_type,
		"details": task_details,
		"start_time": Time.get_ticks_msec(),
		"progress": 0.0
	}
	
	is_task_active = true
	_update_task_display()
	_transition_to_state(CardState.ASSIGNED)
	
	# Animate assignment
	_animate_task_assignment()

func update_task_progress(progress: float) -> void:
	task_progress = clamp(progress, 0.0, 1.0)
	
	if progress_bar:
		# Animate progress bar update
		var tween = create_tween()
		tween.tween_property(progress_bar, "value", task_progress * 100.0, 0.2)
	
	if task_progress >= 1.0:
		_transition_to_state(CardState.COMPLETED)
	elif task_progress > 0.0:
		_transition_to_state(CardState.IN_PROGRESS)

func complete_task(success: bool = true) -> void:
	is_task_active = false
	
	if success:
		_transition_to_state(CardState.COMPLETED)
		_animate_task_completion()
	else:
		_transition_to_state(CardState.FAILED)
		_animate_task_failure()
	
	# Clear task data after animation
	await get_tree().create_timer(1.0).timeout
	_clear_task_data()

func cancel_task() -> void:
	is_task_active = false
	_clear_task_data()
	_transition_to_state(CardState.IDLE)
	_animate_task_cancellation()

## Visual feedback functions
func _update_character_display() -> void:
	if character_name_label and character_data.has("name"):
		character_name_label.text = character_data.get("name", "Unknown")
	
	if character_portrait and character_data.has("portrait"):
		var portrait_path = character_data.get("portrait", "")
		if ResourceLoader.exists(portrait_path):
			character_portrait.texture = load(portrait_path)
	
	# Update character status indicators
	_update_character_status_display()

func _update_character_status_display() -> void:
	var status_text = ""
	var status_color = BaseInformationCard.INFO_COLOR
	
	if character_data.get("is_wounded", false):
		status_text += "[Wounded] "
		status_color = BaseInformationCard.WARNING_COLOR
	
	if character_data.get("is_stunned", false):
		status_text += "[Stunned] "
		status_color = BaseInformationCard.DANGER_COLOR
	
	if character_data.get("is_busy", false):
		status_text += "[Busy] "
		status_color = BaseInformationCard.WARNING_COLOR
	
	if status_text.is_empty():
		status_text = "[Available]"
		status_color = BaseInformationCard.SUCCESS_COLOR
	
	if task_status_label:
		task_status_label.text = status_text.strip_edges()
		task_status_label.add_theme_color_override("font_color", status_color)

func _update_task_display() -> void:
	if not task_data.has("type"):
		return
	
	var task_type = task_data.get("type", 0)
	var task_name = _get_task_name(task_type)
	var task_description = _get_task_description(task_type)
	
	if task_type_label:
		task_type_label.text = task_name
	
	if task_details:
		task_details.text = task_description
	
	# Update progress bar visibility
	if progress_bar:
		progress_bar.visible = is_task_active
		progress_bar.value = task_progress * 100.0
	
	# Phase 3: Setup crew task icons based on task type
	_setup_task_icons(task_type)

func _update_available_tasks(available_tasks: Array) -> void:
	# Update UI to show available task options
	# This could be expanded to show a dropdown or list of available tasks
	var has_available_tasks = not available_tasks.is_empty()
	
	if assign_button:
		assign_button.disabled = not has_available_tasks or is_task_active

func _transition_to_state(new_state: CardState) -> void:
	var old_state = current_state
	current_state = new_state
	
	_update_visual_state()
	_update_button_states()
	
	# Trigger state transition animation
	_animate_state_transition(old_state, new_state)

func _update_visual_state() -> void:
	var card_color = Color.WHITE
	var border_color = Color.TRANSPARENT
	
	match current_state:
		CardState.IDLE:
			card_color = Color.WHITE
			border_color = BaseInformationCard.INFO_COLOR
		CardState.SELECTED:
			card_color = Color(1.1, 1.1, 1.0) # Slight yellow tint
			border_color = BaseInformationCard.INFO_COLOR
		CardState.ASSIGNED:
			card_color = Color(1.0, 1.1, 1.0) # Slight green tint
			border_color = BaseInformationCard.SUCCESS_COLOR
		CardState.IN_PROGRESS:
			card_color = Color(1.0, 1.0, 1.1) # Slight blue tint
			border_color = BaseInformationCard.INFO_COLOR
		CardState.COMPLETED:
			card_color = Color(1.0, 1.2, 1.0) # Green tint
			border_color = BaseInformationCard.SUCCESS_COLOR
		CardState.FAILED:
			card_color = Color(1.2, 1.0, 1.0) # Red tint
			border_color = BaseInformationCard.DANGER_COLOR
		CardState.DISABLED:
			card_color = Color(0.7, 0.7, 0.7) # Gray tint
			border_color = Color.GRAY
	
	# Apply visual changes
	modulate = card_color
	
	# Note: Border color application would need a custom method
	# or a border element in the scene tree
	# set_border_color(border_color)  # Removed - method doesn't exist

func _update_button_states() -> void:
	if not assign_button or not complete_button or not cancel_button:
		return
	
	match current_state:
		CardState.IDLE:
			assign_button.visible = true
			assign_button.disabled = false
			complete_button.visible = false
			cancel_button.visible = false
		CardState.ASSIGNED, CardState.IN_PROGRESS:
			assign_button.visible = false
			complete_button.visible = true
			complete_button.disabled = false
			cancel_button.visible = true
			cancel_button.disabled = false
		CardState.COMPLETED, CardState.FAILED:
			assign_button.visible = true
			assign_button.disabled = false
			complete_button.visible = false
			cancel_button.visible = false
		CardState.DISABLED:
			assign_button.disabled = true
			complete_button.disabled = true
			cancel_button.disabled = true

## Animation functions
func _animate_task_assignment() -> void:
	if not animation_tween:
		return
	
	# Scale pulse animation
	animation_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	animation_tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	
	# Color flash
	var original_modulate = modulate
	animation_tween.tween_property(self, "modulate", BaseInformationCard.SUCCESS_COLOR, 0.1)
	animation_tween.tween_property(self, "modulate", original_modulate, 0.2)

func _animate_task_completion() -> void:
	if not animation_tween:
		return
	
	# Success animation - scale up and color flash
	animation_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.15)
	animation_tween.tween_property(self, "scale", Vector2.ONE, 0.25)
	
	# Green flash for success
	var original_modulate = modulate
	animation_tween.tween_property(self, "modulate", Color.GREEN, 0.15)
	animation_tween.tween_property(self, "modulate", original_modulate, 0.25)

func _animate_task_failure() -> void:
	if not animation_tween:
		return
	
	# Failure animation - shake and red flash
	var original_position = position
	for i in range(3):
		animation_tween.tween_property(self, "position", original_position + Vector2(5, 0), 0.05)
		animation_tween.tween_property(self, "position", original_position - Vector2(5, 0), 0.05)
	animation_tween.tween_property(self, "position", original_position, 0.05)
	
	# Red flash for failure
	var original_modulate = modulate
	animation_tween.tween_property(self, "modulate", Color.RED, 0.1)
	animation_tween.tween_property(self, "modulate", original_modulate, 0.2)

func _animate_task_cancellation() -> void:
	if not animation_tween:
		return
	
	# Fade out and in animation
	animation_tween.tween_property(self, "modulate:a", 0.5, 0.15)
	animation_tween.tween_property(self, "modulate:a", 1.0, 0.15)

func _animate_state_transition(old_state: CardState, new_state: CardState) -> void:
	if not animation_tween:
		return
	
	# Subtle transition animation
	animation_tween.tween_property(self, "scale", Vector2(1.02, 1.02), 0.1)
	animation_tween.tween_property(self, "scale", Vector2.ONE, 0.1)

## Input handlers
func _on_mouse_entered() -> void:
	if current_state == CardState.DISABLED:
		return
	
	# Hover effect
	if animation_tween:
		animation_tween.tween_property(self, "scale", HOVER_SCALE, ANIMATION_DURATION)

func _on_mouse_exited() -> void:
	if current_state == CardState.DISABLED:
		return
	
	# Return to normal scale
	if animation_tween:
		animation_tween.tween_property(self, "scale", NORMAL_SCALE, ANIMATION_DURATION)

func _on_button_hover(button: Button) -> void:
	if button and not button.disabled:
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.1)

func _on_button_unhover(button: Button) -> void:
	if button:
		var tween = create_tween()
		tween.tween_property(button, "scale", Vector2.ONE, 0.1)

func _on_assign_button_pressed() -> void:
	task_card_assignment_requested.emit(character_data, 0) # Default task type
	_transition_to_state(CardState.SELECTED)

func _on_complete_button_pressed() -> void:
	task_card_completion_requested.emit(character_data)

func _on_cancel_button_pressed() -> void:
	task_card_cancellation_requested.emit(character_data)

## Signal handlers
func _on_task_assigned(character: Dictionary, task: int) -> void:
	if character.get("id") == character_data.get("id"):
		assign_task(task)

func _on_task_completed(character: Dictionary, task: int, success: bool) -> void:
	if character.get("id") == character_data.get("id"):
		complete_task(success)

func _on_task_progress_updated(character: Dictionary, progress: float) -> void:
	if character.get("id") == character_data.get("id"):
		update_task_progress(progress)

func _on_task_failed(character: Dictionary, task: int, reason: String) -> void:
	if character.get("id") == character_data.get("id"):
		complete_task(false)

## Utility functions
func _get_task_name(task_type: int) -> String:
	match task_type:
		GlobalEnums.CrewTaskType.FIND_PATRON:
			return "Find Patron"
		GlobalEnums.CrewTaskType.TRAIN:
			return "Train"
		GlobalEnums.CrewTaskType.TRADE:
			return "Trade"
		GlobalEnums.CrewTaskType.RECRUIT:
			return "Recruit"
		GlobalEnums.CrewTaskType.EXPLORE:
			return "Explore"
		GlobalEnums.CrewTaskType.TRACK:
			return "Track"
		GlobalEnums.CrewTaskType.REPAIR_KIT:
			return "Repair Kit"
		GlobalEnums.CrewTaskType.DECOY:
			return "Decoy"
		_:
			return "Unknown Task"

func _get_task_description(task_type: int) -> String:
	match task_type:
		GlobalEnums.CrewTaskType.FIND_PATRON:
			return "Search for potential patrons offering jobs and missions."
		GlobalEnums.CrewTaskType.TRAIN:
			return "Improve skills and combat readiness through training."
		GlobalEnums.CrewTaskType.TRADE:
			return "Engage in local commerce to earn credits."
		GlobalEnums.CrewTaskType.RECRUIT:
			return "Search for new crew members to join the team."
		GlobalEnums.CrewTaskType.EXPLORE:
			return "Explore the local area for opportunities and resources."
		GlobalEnums.CrewTaskType.TRACK:
			return "Track down specific targets or gather intelligence."
		GlobalEnums.CrewTaskType.REPAIR_KIT:
			return "Use repair kit to fix equipment and ship components."
		GlobalEnums.CrewTaskType.DECOY:
			return "Create distractions or false trails for tactical advantage."
		_:
			return "Unknown task type."

func _clear_task_data() -> void:
	task_data.clear()
	task_progress = 0.0
	
	if progress_bar:
		progress_bar.value = 0.0
		progress_bar.visible = false

func _apply_card_styling() -> void:
	# Apply Universal Safety Framework styling
	if has_method("add_theme_stylebox_override"):
		# This would apply consistent card styling
		pass

## Public API for external access
func get_character_data() -> Dictionary:
	return character_data

func get_task_data() -> Dictionary:
	return task_data

func is_task_assigned() -> bool:
	return is_task_active

func get_current_state() -> CardState:
	return current_state

func set_enabled(enabled: bool) -> void:
	if enabled:
		_transition_to_state(CardState.IDLE)
	else:
		_transition_to_state(CardState.DISABLED)

## Setup crew task icons based on task type for enhanced visual clarity
func _setup_task_icons(task_type: int) -> void:
	"""Setup icons for crew task buttons based on the specific task type"""
	# Phase 3: Crew Task Icons Integration
	
	var icon_resource: Resource = null
	
	# Match task type to appropriate icon
	match task_type:
		GlobalEnums.CrewTaskType.FIND_PATRON:
			icon_resource = preload("res://assets/basic icons/icon_task_find_patron.svg")
		GlobalEnums.CrewTaskType.TRACK:
			icon_resource = preload("res://assets/basic icons/icon_task_track_rival.svg")
		GlobalEnums.CrewTaskType.REPAIR_KIT:
			icon_resource = preload("res://assets/basic icons/icon_task_repair_kit.svg")
		_:
			# For other task types, don't add an icon
			return
	
	# Apply icon to assign button (primary action button)
	if assign_button and icon_resource:
		assign_button.icon = icon_resource
		assign_button.expand_icon = true
		assign_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		print("CrewTaskCard: Applied %s icon to assign button" % _get_task_name(task_type))
	
	# Also apply to complete button for visual consistency
	if complete_button and icon_resource:
		complete_button.icon = icon_resource
		complete_button.expand_icon = true
		complete_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT