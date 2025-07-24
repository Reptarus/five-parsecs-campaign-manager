@tool
extends Control
class_name QuestTrackerWidget

## Quest Tracker Widget - Active quest tracking with progress indicators
## Follows dice system contextual information display patterns
## Provides Universal Safety framework for quest management

# Universal Safety patterns
const BaseInformationCard = preload("res://src/base/ui/BaseInformationCard.gd")
const EnhancedCampaignSignals = preload("res://src/core/signals/EnhancedCampaignSignals.gd")

# UI References
@onready var quest_container: VBoxContainer = %QuestContainer
@onready var quest_summary: Label = %QuestSummary
@onready var quest_filter_panel: Control = %QuestFilterPanel
@onready var quest_progress_overview: Control = %QuestProgressOverview

# Data management
var active_quests: Array[Dictionary] = []
var completed_quests: Array[Dictionary] = []
var selected_quest: String = ""
var quest_performance_data: Dictionary = {}

# Signal connections
var enhanced_signals: EnhancedCampaignSignals

func _ready() -> void:
	_setup_quest_tracker()
	_connect_enhanced_signals()
	_apply_responsive_layout()

func _setup_quest_tracker() -> void:
	# Initialize quest tracking components
	if not quest_container:
		push_warning("QuestTrackerWidget: Quest container not found")
		return
	
	# Setup quest filtering
	_setup_quest_filtering()
	
	# Setup progress tracking
	_setup_progress_tracking()

func _connect_enhanced_signals() -> void:
	# Connect to enhanced campaign signals
	enhanced_signals = EnhancedCampaignSignals.new()
	
	# Connect quest-related signals
	enhanced_signals.connect_signal_safely("quest_started", self, "_on_quest_started")
	enhanced_signals.connect_signal_safely("quest_completed", self, "_on_quest_completed")
	enhanced_signals.connect_signal_safely("quest_failed", self, "_on_quest_failed")
	enhanced_signals.connect_signal_safely("quest_progress_made", self, "_on_quest_progress_made")

func _apply_responsive_layout() -> void:
	# Apply responsive design patterns
	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size.x < viewport_size.y:
		_apply_portrait_layout()
	else:
		_apply_landscape_layout()

func _apply_portrait_layout() -> void:
	# Mobile-first compact layout
	if quest_container:
		quest_container.custom_minimum_size.y = 150
		quest_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if quest_summary:
		quest_summary.text = _generate_compact_quest_summary()

func _apply_landscape_layout() -> void:
	# Desktop detailed layout
	if quest_container:
		quest_container.custom_minimum_size.y = 250
		quest_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if quest_summary:
		quest_summary.text = _generate_detailed_quest_summary()

## Main quest display update function
func update_quest_display(new_active_quests: Array) -> void:
	active_quests = new_active_quests
	
	# Clear existing quest cards safely (Universal safety pattern)
	_clear_quest_cards()
	
	# Create enhanced quest cards following dice system patterns
	for quest in active_quests:
		var quest_card = _create_quest_card(quest)
		if quest_card:
			quest_container.add_child(quest_card)
	
	# Update summary and progress data
	_update_quest_summary()
	_update_progress_overview()

func _clear_quest_cards() -> void:
	if not quest_container:
		return
	
	# Clear existing quest cards safely
	for child in quest_container.get_children():
		child.queue_free()

func _create_quest_card(quest_data: Dictionary) -> Control:
	# Create quest card following dice system design
	var quest_card = BaseInformationCard.new()
	
	# Setup with safety validation
	quest_card.setup_with_safety_validation(quest_data)
	
	# Apply visual styling from dice system
	_apply_quest_card_styling(quest_card, quest_data)
	
	# Set context label and progress indicator
	quest_card.set_context_label("Quest: %s" % quest_data.get("name", "Unknown Quest"))
	_set_progress_indicator(quest_card, quest_data.get("progress", 0), quest_data.get("total_steps", 1))
	
	# Connect quest card signals
	quest_card.card_selected.connect(_on_quest_card_selected)
	quest_card.card_action_requested.connect(_on_quest_action_requested)
	
	return quest_card

func _apply_quest_card_styling(quest_card: Control, quest_data: Dictionary) -> void:
	# Apply color coding based on quest status (dice system colors)
	var quest_type = quest_data.get("type", "standard")
	var difficulty = quest_data.get("difficulty", "normal")
	var time_remaining = quest_data.get("time_remaining", 0)
	
	# Color coding based on quest type and urgency
	match quest_type:
		"urgent":
			quest_card.add_theme_color_override("font_color", BaseInformationCard.DANGER_COLOR)
		"bonus":
			quest_card.add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
		"main":
			quest_card.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
		_:
			quest_card.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)
	
	# Additional styling for time-sensitive quests
	if time_remaining > 0 and time_remaining < 3:
		quest_card.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)

func _set_progress_indicator(quest_card: Control, progress: int, total_steps: int) -> void:
	# Create progress indicator following dice system visual patterns
	var progress_ratio = float(progress) / float(total_steps) if total_steps > 0 else 0.0
	
	# Apply progress color coding
	if progress_ratio >= 0.8:
		quest_card.add_theme_color_override("font_color", BaseInformationCard.SUCCESS_COLOR)
	elif progress_ratio >= 0.5:
		quest_card.add_theme_color_override("font_color", BaseInformationCard.INFO_COLOR)
	elif progress_ratio >= 0.2:
		quest_card.add_theme_color_override("font_color", BaseInformationCard.WARNING_COLOR)
	else:
		quest_card.add_theme_color_override("font_color", BaseInformationCard.NEUTRAL_COLOR)

func _update_quest_summary() -> void:
	if not quest_summary:
		return
	
	var total_quests = active_quests.size()
	var completed_quests = 0
	var urgent_quests = 0
	var total_progress = 0.0
	
	for quest in active_quests:
		var progress = quest.get("progress", 0)
		var total_steps = quest.get("total_steps", 1)
		var quest_type = quest.get("type", "standard")
		
		if progress >= total_steps:
			completed_quests += 1
		
		if quest_type == "urgent":
			urgent_quests += 1
		
		total_progress += float(progress) / float(total_steps) if total_steps > 0 else 0.0
	
	var avg_progress = total_progress / total_quests if total_quests > 0 else 0.0
	
	# Update summary with contextual information
	quest_summary.text = "Quests: %d Active, %d Urgent (Avg Progress: %.1f%%)" % [
		total_quests, urgent_quests, avg_progress * 100
	]

func _update_progress_overview() -> void:
	if not quest_progress_overview:
		return
	
	# Update progress visualization
	var progress_data = _calculate_quest_progress()
	quest_progress_overview.update_progress_display(progress_data)

func _calculate_quest_progress() -> Dictionary:
	var progress = {
		"total_quests": active_quests.size(),
		"completed_quests": 0,
		"in_progress_quests": 0,
		"urgent_quests": 0,
		"average_progress": 0.0,
		"quest_types": {}
	}
	
	var total_progress = 0.0
	
	for quest in active_quests:
		var quest_progress = quest.get("progress", 0)
		var total_steps = quest.get("total_steps", 1)
		var quest_type = quest.get("type", "standard")
		
		# Count by completion status
		if quest_progress >= total_steps:
			progress.completed_quests += 1
		else:
			progress.in_progress_quests += 1
		
		# Count urgent quests
		if quest_type == "urgent":
			progress.urgent_quests += 1
		
		# Track quest types
		if not progress.quest_types.has(quest_type):
			progress.quest_types[quest_type] = 0
		progress.quest_types[quest_type] += 1
		
		# Calculate progress ratio
		var progress_ratio = float(quest_progress) / float(total_steps) if total_steps > 0 else 0.0
		total_progress += progress_ratio
	
	# Calculate average progress
	progress.average_progress = total_progress / active_quests.size() if active_quests.size() > 0 else 0.0
	
	return progress

## Signal handlers
func _on_quest_started(quest_data: Dictionary) -> void:
	# Add new quest to active quests
	active_quests.append(quest_data)
	update_quest_display(active_quests)

func _on_quest_completed(quest_data: Dictionary, rewards: Dictionary) -> void:
	# Move quest from active to completed
	for i in range(active_quests.size()):
		if active_quests[i].get("id") == quest_data.get("id"):
			var completed_quest = active_quests[i]
			completed_quest["rewards"] = rewards
			completed_quests.append(completed_quest)
			active_quests.remove_at(i)
			break
	
	update_quest_display(active_quests)

func _on_quest_failed(quest_data: Dictionary, reason: String) -> void:
	# Handle failed quest
	for i in range(active_quests.size()):
		if active_quests[i].get("id") == quest_data.get("id"):
			var failed_quest = active_quests[i]
			failed_quest["failure_reason"] = reason
			completed_quests.append(failed_quest)
			active_quests.remove_at(i)
			break
	
	update_quest_display(active_quests)

func _on_quest_progress_made(quest_id: String, step_completed: String) -> void:
	# Update quest progress
	for quest in active_quests:
		if quest.get("id") == quest_id:
			quest["progress"] = quest.get("progress", 0) + 1
			quest["last_completed_step"] = step_completed
			break
	
	update_quest_display(active_quests)

func _on_quest_card_selected(card_data: Dictionary) -> void:
	selected_quest = card_data.get("quest_id", "")
	enhanced_signals.emit_safe_signal("quest_selected", [selected_quest])

func _on_quest_action_requested(action: String, data: Variant) -> void:
	enhanced_signals.emit_safe_signal("quick_action_requested", [action, data])

## Quest filtering functionality
func _setup_quest_filtering() -> void:
	# Initialize quest filtering system
	pass

func filter_quests_by_type(quest_type: String) -> void:
	var filtered_quests: Array[Dictionary] = []
	
	for quest in active_quests:
		if quest.get("type") == quest_type:
			filtered_quests.append(quest)
	
	update_quest_display(filtered_quests)

func filter_quests_by_difficulty(difficulty: String) -> void:
	var filtered_quests: Array[Dictionary] = []
	
	for quest in active_quests:
		if quest.get("difficulty") == difficulty:
			filtered_quests.append(quest)
	
	update_quest_display(filtered_quests)

func show_all_quests() -> void:
	update_quest_display(active_quests)

## Progress tracking functionality
func _setup_progress_tracking() -> void:
	# Initialize progress tracking system
	quest_performance_data = {}

func get_quest_performance() -> Dictionary:
	return _calculate_quest_progress()

func get_completed_quests() -> Array:
	return completed_quests

## Helper functions
func _generate_compact_quest_summary() -> String:
	var active_count = active_quests.size()
	var urgent_count = 0
	
	for quest in active_quests:
		if quest.get("type") == "urgent":
			urgent_count += 1
	
	return "Quests: %d Active (%d Urgent)" % [active_count, urgent_count]

func _generate_detailed_quest_summary() -> String:
	var total_quests = active_quests.size()
	var completed_count = 0
	var urgent_count = 0
	var total_progress = 0.0
	
	for quest in active_quests:
		var progress = quest.get("progress", 0)
		var total_steps = quest.get("total_steps", 1)
		var quest_type = quest.get("type", "standard")
		
		if progress >= total_steps:
			completed_count += 1
		
		if quest_type == "urgent":
			urgent_count += 1
		
		total_progress += float(progress) / float(total_steps) if total_steps > 0 else 0.0
	
	var avg_progress = total_progress / total_quests if total_quests > 0 else 0.0
	
	return "Quest Status: %d/%d Complete | %d Urgent | %.1f%% Avg Progress" % [
		completed_count, total_quests, urgent_count, avg_progress * 100
	]

## Public API for external access
func get_active_quests() -> Array:
	return active_quests

func get_selected_quest() -> String:
	return selected_quest

func get_quest_performance_data() -> Dictionary:
	return quest_performance_data

func refresh_display() -> void:
	update_quest_display(active_quests)