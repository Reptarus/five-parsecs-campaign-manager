@tool
extends Node
class_name BattleTutorialManager

const Self = preload("res://src/core/tutorial/BattleTutorialManager.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")
const Character = preload("res://src/core/character/Management/CharacterDataManager.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const UnifiedTerrainSystem = preload("res://src/core/terrain/UnifiedTerrainSystem.gd")
const SaveManager = preload("res://src/core/state/SaveManager.gd")
const BaseCombatManager = preload("res://src/base/combat/BaseCombatManager.gd")
# Load the BattleTutorialLayout class
const BattleTutorialLayoutScript = preload("res://src/core/tutorial/BattleTutorialLayout.gd")

# Signals
signal tutorial_started(layout_id: String)
signal tutorial_step_changed(step_data: Dictionary)
signal tutorial_completed(layout_id: String)
signal tutorial_cancelled()

# Member variables
var active_tutorial: Resource = null # Will hold BattleTutorialLayout instance
var is_tutorial_active: bool = false
var debug_mode: bool = false
var auto_advance: bool = false

# UI references
var tutorial_panel: Control = null
var highlight_overlay: Control = null

func _ready() -> void:
	# Initialize tutorial system
	pass

# Start a tutorial with the specified layout
func start_tutorial(layout_id: String = "basic_combat") -> bool:
	if is_tutorial_active:
		cancel_tutorial()
	
	# Use a more direct approach to avoid calling static methods on classes
	var layout_script = load("res://src/core/tutorial/BattleTutorialLayout.gd")
	if layout_script:
		var layout_instance = layout_script.new()
		if layout_instance.has_method("get_layout"):
			active_tutorial = layout_instance.get_layout(layout_id)
		
		# If that failed, try calling the script method directly
		if active_tutorial == null:
			# This uses the BattleTutorialLayoutScript constant we defined earlier
			active_tutorial = BattleTutorialLayoutScript.new(layout_id, "Combat Tutorial")
			
			# Manually add steps if this is the basic_combat tutorial
			if layout_id == "basic_combat":
				_setup_basic_combat_tutorial(active_tutorial)
	
	if active_tutorial == null:
		push_error("Failed to load tutorial layout: " + layout_id)
		return false
	
	is_tutorial_active = true
	
	# Reset to first step
	active_tutorial.reset()
	
	# Emit signal that tutorial has started
	tutorial_started.emit(layout_id)
	
	# Show first step
	show_current_step()
	
	return true

# Helper function to set up the basic combat tutorial
func _setup_basic_combat_tutorial(tutorial) -> void:
	tutorial.add_step(
		"welcome",
		"Welcome to Combat",
		"This tutorial will guide you through the basics of combat in Five Parsecs."
	)
	
	tutorial.add_step(
		"select_character",
		"Select a Character",
		"Click on one of your characters to select them."
	)
	
	tutorial.add_step(
		"move_character",
		"Move Character",
		"Click on a valid position to move your character."
	)
	
	tutorial.add_step(
		"attack",
		"Attack an Enemy",
		"Select an enemy within range to attack them."
	)
	
	tutorial.add_step(
		"end_turn",
		"End Your Turn",
		"When you're done with all actions, click the End Turn button."
	)

# Show the current tutorial step
func show_current_step() -> void:
	if not is_tutorial_active or active_tutorial == null:
		return
	
	var current_step = active_tutorial.get_current_step()
	if current_step == null or current_step.is_empty():
		push_error("No current step available")
		return
	
	# Emit signal for UI to update
	tutorial_step_changed.emit(current_step)
	
	# Update highlight if applicable
	update_highlight(current_step)

# Update the highlight overlay based on the current step
func update_highlight(step: Dictionary) -> void:
	if highlight_overlay == null or step.is_empty():
		return
	
	# Position the highlight overlay based on the step's target
	if step.has("target_node_path") and not step.target_node_path.is_empty():
		var target_node = get_node_or_null(step.target_node_path)
		if target_node != null and target_node is Control:
			var rect = Rect2(target_node.global_position, target_node.size)
			highlight_overlay.highlight_rect = rect
			highlight_overlay.visible = true
			return
	
	# Use the explicit highlight rect if provided
	if step.has("highlight_rect") and step.highlight_rect != Rect2():
		highlight_overlay.highlight_rect = step.highlight_rect
		highlight_overlay.visible = true
		return
	
	# No highlight for this step
	highlight_overlay.visible = false

# Advance to the next tutorial step
func advance_tutorial() -> bool:
	if not is_tutorial_active or active_tutorial == null:
		return false
	
	var success = active_tutorial.advance()
	if success:
		show_current_step()
		return true
	else:
		# We've reached the end of the tutorial
		complete_tutorial()
		return false

# Go back to the previous tutorial step
func previous_step() -> bool:
	if not is_tutorial_active or active_tutorial == null:
		return false
	
	var success = active_tutorial.go_back()
	if success:
		show_current_step()
		return true
	return false

# Complete the current tutorial
func complete_tutorial() -> void:
	if not is_tutorial_active or active_tutorial == null:
		return
	
	var layout_id = active_tutorial.layout_id
	is_tutorial_active = false
	active_tutorial = null
	
	# Hide highlight overlay
	if highlight_overlay != null:
		highlight_overlay.visible = false
	
	# Emit completion signal
	tutorial_completed.emit(layout_id)

# Cancel the current tutorial
func cancel_tutorial() -> void:
	if not is_tutorial_active:
		return
	
	is_tutorial_active = false
	active_tutorial = null
	
	# Hide highlight overlay
	if highlight_overlay != null:
		highlight_overlay.visible = false
	
	# Emit cancellation signal
	tutorial_cancelled.emit()

# Set the tutorial panel reference
func set_tutorial_panel(panel: Control) -> void:
	tutorial_panel = panel

# Set the highlight overlay reference
func set_highlight_overlay(overlay: Control) -> void:
	highlight_overlay = overlay

# Check if a tutorial is currently active
func is_tutorial_running() -> bool:
	return is_tutorial_active

# Get the current tutorial step information
func get_current_step_info() -> Dictionary:
	if not is_tutorial_active or active_tutorial == null:
		return {}
	
	var current_step = active_tutorial.get_current_step()
	if current_step == null or current_step.is_empty():
		return {}
	
	return {
		"id": current_step.get("id", ""),
		"title": current_step.get("title", ""),
		"description": current_step.get("description", "")
	}

# Enable/disable debug mode
func set_debug_mode(enabled: bool) -> void:
	debug_mode = enabled

# Enable/disable auto-advance mode
func set_auto_advance(enabled: bool) -> void:
	auto_advance = enabled

# Process tutorial action
func process_action(action_id: String) -> bool:
	if not is_tutorial_active or active_tutorial == null:
		return false
	
	var current_step = active_tutorial.get_current_step()
	if current_step == null or current_step.is_empty():
		return false
	
	# Check if the action matches what's required for the current step
	if current_step.has("required_action") and current_step.required_action == action_id:
		if auto_advance:
			return advance_tutorial()
		return true
	
	return false