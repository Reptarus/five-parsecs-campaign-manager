@tool
extends Control
class_name CrewTaskCardManager

## Crew Task Card Manager - Feature 9 Integration Component
## Manages multiple CrewTaskCard components and connects them to the campaign system
## Follows Universal Safety Framework and 60 FPS performance patterns

const CrewTaskCard = preload("res://src/ui/components/crew/CrewTaskCard.gd")
const CrewTaskManager = preload("res://src/core/managers/CrewTaskManager.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")
# GlobalEnums available as autoload singleton

# UI container for task cards
@onready var task_cards_container: Container = %TaskCardsContainer
@onready var scroll_container: ScrollContainer = %ScrollContainer

# System connections
var crew_task_manager: CrewTaskManager
var enhanced_signals: EnhancedCampaignSignals

# Task card management
var active_task_cards: Dictionary = {}  # character_id -> CrewTaskCard
var card_pool: Array[CrewTaskCard] = []  # Object pooling for performance
var crew_data: Array[Dictionary] = []

# Animation and visual feedback
var animation_tween: Tween
var card_creation_queue: Array[Dictionary] = []

# Configuration
@export var max_pooled_cards: int = 12
@export var card_spacing: int = 10
@export var cards_per_row: int = 3
@export var enable_card_pooling: bool = true
@export var auto_refresh_interval: float = 2.0

# Refresh timer
var refresh_timer: Timer

signal crew_task_card_created(character_id: String, card: CrewTaskCard)
signal crew_task_card_destroyed(character_id: String)
signal crew_task_assignment_requested(character_id: String, task_type: int)
signal crew_task_completion_requested(character_id: String)
signal all_cards_updated()

func _ready() -> void:
	_setup_crew_task_card_manager()
	_setup_animation_system()
	_setup_auto_refresh()

func _setup_crew_task_card_manager() -> void:
	# Initialize enhanced signals
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Setup container properties
	if task_cards_container:
		if task_cards_container is GridContainer:
			task_cards_container.columns = cards_per_row
		
		# Setup responsive spacing
		_update_container_spacing()
	
	# Initialize object pool
	if enable_card_pooling:
		_initialize_card_pool()

func _setup_animation_system() -> void:
	animation_tween = create_tween()
	animation_tween.set_loops()

func _setup_auto_refresh() -> void:
	refresh_timer = Timer.new()
	refresh_timer.wait_time = auto_refresh_interval
	refresh_timer.timeout.connect(_on_auto_refresh_timeout)
	add_child(refresh_timer)
	refresh_timer.start()

func _connect_crew_task_manager(manager: CrewTaskManager) -> void:
	crew_task_manager = manager
	
	# Connect to crew task manager signals
	if crew_task_manager:
		crew_task_manager.task_assigned.connect(_on_task_assigned)
		crew_task_manager.task_completed.connect(_on_task_completed)
		crew_task_manager.task_failed.connect(_on_task_failed)

## Main API functions
func setup_with_crew_data(crew_list: Array[Dictionary]) -> void:
	crew_data = crew_list.duplicate(true)
	_refresh_all_cards()

func connect_to_crew_task_manager(manager: CrewTaskManager) -> void:
	_connect_crew_task_manager(manager)

func update_character_data(character_id: String, updated_data: Dictionary) -> void:
	# Update crew data
	for i in range(crew_data.size()):
		if crew_data[i].get("id") == character_id:
			crew_data[i] = updated_data.duplicate(true)
			break
	
	# Update existing card
	if active_task_cards.has(character_id):
		var card = active_task_cards[character_id]
		card.setup_character_task_card(updated_data)

func assign_task_to_character(character_id: String, task_type: int) -> bool:
	if not active_task_cards.has(character_id):
		push_error("No task card found for character: " + character_id)
		return false
	
	var card = active_task_cards[character_id]
	var character_data = _get_character_data_by_id(character_id)
	
	if character_data.is_empty():
		return false
	
	# Validate task assignment through crew task manager
	if crew_task_manager:
		var validation = crew_task_manager.validate_task_assignment(character_data, task_type)
		if not validation.valid:
			_show_task_assignment_error(character_id, validation.reason)
			return false
	
	# Assign task to card
	card.assign_task(task_type)
	crew_task_assignment_requested.emit(character_id, task_type)
	
	return true

func complete_character_task(character_id: String, success: bool = true) -> void:
	if active_task_cards.has(character_id):
		var card = active_task_cards[character_id]
		card.complete_task(success)
		crew_task_completion_requested.emit(character_id)

func cancel_character_task(character_id: String) -> void:
	if active_task_cards.has(character_id):
		var card = active_task_cards[character_id]
		card.cancel_task()

func update_task_progress(character_id: String, progress: float) -> void:
	if active_task_cards.has(character_id):
		var card = active_task_cards[character_id]
		card.update_task_progress(progress)

func get_available_tasks_for_character(character_id: String) -> Array[int]:
	var character_data = _get_character_data_by_id(character_id)
	if character_data.is_empty() or not crew_task_manager:
		return []
	
	return crew_task_manager.get_available_tasks_for_crew_member(character_data)

## Card management functions
func _refresh_all_cards() -> void:
	# Clear existing cards
	_clear_all_cards()
	
	# Create cards for all crew members
	for character_data in crew_data:
		_create_card_for_character(character_data)
	
	all_cards_updated.emit()

func _create_card_for_character(character_data: Dictionary) -> CrewTaskCard:
	var character_id = character_data.get("id", "")
	if character_id.is_empty():
		push_error("Character data missing ID")
		return null
	
	var card: CrewTaskCard
	
	# Use object pooling if enabled
	if enable_card_pooling and not card_pool.is_empty():
		card = card_pool.pop_back()
	else:
		# Create new card
		var card_scene = preload("res://src/ui/components/crew/CrewTaskCard.tscn")
		card = card_scene.instantiate()
	
	if not card:
		push_error("Failed to create CrewTaskCard")
		return null
	
	# Setup card
	card.setup_character_task_card(character_data, get_available_tasks_for_character(character_id))
	
	# Connect card signals
	_connect_card_signals(card, character_id)
	
	# Add to container
	if task_cards_container:
		task_cards_container.add_child(card)
	
	# Store reference
	active_task_cards[character_id] = card
	
	# Animate card appearance
	_animate_card_creation(card)
	
	crew_task_card_created.emit(character_id, card)
	
	return card

func _destroy_card_for_character(character_id: String) -> void:
	if not active_task_cards.has(character_id):
		return
	
	var card = active_task_cards[character_id]
	
	# Animate card removal
	_animate_card_removal(card)
	
	# Wait for animation
	await get_tree().create_timer(0.3).timeout
	
	# Remove from container
	if card.get_parent():
		card.get_parent().remove_child(card)
	
	# Return to pool or free
	if enable_card_pooling and card_pool.size() < max_pooled_cards:
		card_pool.append(card)
	else:
		card.queue_free()
	
	# Remove reference
	active_task_cards.erase(character_id)
	
	crew_task_card_destroyed.emit(character_id)

func _clear_all_cards() -> void:
	for character_id in active_task_cards.keys():
		_destroy_card_for_character(character_id)

func _connect_card_signals(card: CrewTaskCard, character_id: String) -> void:
	# Connect card signals to manager
	card.task_card_assignment_requested.connect(_on_card_assignment_requested.bind(character_id))
	card.task_card_completion_requested.connect(_on_card_completion_requested.bind(character_id))
	card.task_card_cancellation_requested.connect(_on_card_cancellation_requested.bind(character_id))
	card.task_card_selected.connect(_on_card_selected.bind(character_id))

## Animation functions
func _animate_card_creation(card: CrewTaskCard) -> void:
	if not animation_tween or not card:
		return
	
	# Start with zero scale and alpha
	card.scale = Vector2.ZERO
	card.modulate.a = 0.0
	
	# Animate to full visibility
	animation_tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.3)
	animation_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.3)

func _animate_card_removal(card: CrewTaskCard) -> void:
	if not animation_tween or not card:
		return
	
	# Animate to zero scale and alpha
	animation_tween.parallel().tween_property(card, "scale", Vector2.ZERO, 0.3)
	animation_tween.parallel().tween_property(card, "modulate:a", 0.0, 0.3)

func _animate_card_update(card: CrewTaskCard) -> void:
	if not animation_tween or not card:
		return
	
	# Subtle pulse animation
	animation_tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.1)
	animation_tween.tween_property(card, "scale", Vector2.ONE, 0.1)

## Signal handlers
func _on_task_assigned(character: Dictionary, task: int) -> void:
	var character_id = character.get("id", "")
	if active_task_cards.has(character_id):
		var card = active_task_cards[character_id]
		card.assign_task(task)

func _on_task_completed(character: Dictionary, task: int, success: bool) -> void:
	var character_id = character.get("id", "")
	if active_task_cards.has(character_id):
		var card = active_task_cards[character_id]
		card.complete_task(success)

func _on_task_failed(character: Dictionary, task: int, reason: String) -> void:
	var character_id = character.get("id", "")
	if active_task_cards.has(character_id):
		var card = active_task_cards[character_id]
		card.complete_task(false)

func _on_card_assignment_requested(character_id: String, character_data: Dictionary, task_type: int) -> void:
	assign_task_to_character(character_id, task_type)

func _on_card_completion_requested(character_id: String, character_data: Dictionary) -> void:
	complete_character_task(character_id, true)

func _on_card_cancellation_requested(character_id: String, character_data: Dictionary) -> void:
	cancel_character_task(character_id)

func _on_card_selected(character_id: String, character_data: Dictionary, task_type: int) -> void:
	# Handle card selection for task assignment UI
	crew_task_assignment_requested.emit(character_id, task_type)

func _on_auto_refresh_timeout() -> void:
	# Refresh all cards with latest data
	for character_id in active_task_cards.keys():
		var character_data = _get_character_data_by_id(character_id)
		if not character_data.is_empty():
			update_character_data(character_id, character_data)

## Utility functions
func _get_character_data_by_id(character_id: String) -> Dictionary:
	for character_data in crew_data:
		if character_data.get("id") == character_id:
			return character_data
	return {}

func _show_task_assignment_error(character_id: String, reason: String) -> void:
	# Show error notification
	if enhanced_signals:
		enhanced_signals.emit_signal_safely("notification_displayed", {
			"type": "error",
			"title": "Task Assignment Failed",
			"message": reason,
			"character_id": character_id
		})

func _update_container_spacing() -> void:
	if not task_cards_container:
		return
	
	# Update spacing based on viewport size
	var viewport_size = get_viewport().get_visible_rect().size
	var spacing = card_spacing
	
	if viewport_size.x < 800:  # Mobile/compact layout
		spacing = card_spacing / 2
		cards_per_row = 2
	else:
		cards_per_row = 3
	
	if task_cards_container is GridContainer:
		task_cards_container.columns = cards_per_row
	
	if task_cards_container.has_theme_constant_override("h_separation"):
		task_cards_container.add_theme_constant_override("h_separation", spacing)
		task_cards_container.add_theme_constant_override("v_separation", spacing)

func _initialize_card_pool() -> void:
	# Pre-create a pool of cards for performance
	for i in range(max_pooled_cards):
		var card_scene = preload("res://src/ui/components/crew/CrewTaskCard.tscn")
		var card = card_scene.instantiate()
		if card:
			card_pool.append(card)

## Public API for external access
func get_active_cards() -> Dictionary:
	return active_task_cards

func get_card_for_character(character_id: String) -> CrewTaskCard:
	return active_task_cards.get(character_id)

func has_active_task(character_id: String) -> bool:
	if not active_task_cards.has(character_id):
		return false
	
	var card = active_task_cards[character_id]
	return card.is_task_assigned()

func get_task_summary() -> Dictionary:
	var summary = {
		"total_cards": active_task_cards.size(),
		"active_tasks": 0,
		"available_characters": 0,
		"characters_with_tasks": []
	}
	
	for character_id in active_task_cards.keys():
		var card = active_task_cards[character_id]
		if card.is_task_assigned():
			summary.active_tasks += 1
			summary.characters_with_tasks.append(character_id)
		else:
			summary.available_characters += 1
	
	return summary

func refresh_cards() -> void:
	_refresh_all_cards()

func set_cards_enabled(enabled: bool) -> void:
	for card in active_task_cards.values():
		card.set_enabled(enabled)
