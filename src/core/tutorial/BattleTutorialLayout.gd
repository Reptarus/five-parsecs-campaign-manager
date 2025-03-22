@tool
extends Resource
class_name BattleTutorialLayout

# Define the structure for a tutorial step as a Dictionary to avoid inner class caching issues
var steps: Array = [] # Array of Dictionaries
var current_step_index: int = 0
var layout_id: String = "default"
var layout_name: String = "Default Tutorial"

func _init(p_id: String = "default", p_name: String = "Default Tutorial") -> void:
	layout_id = p_id
	layout_name = p_name

# Add a step to the tutorial layout
func add_step(id: String, title: String, description: String,
				target_node_path: String = "", highlight_rect: Rect2 = Rect2(),
				required_action: String = "") -> void:
	steps.append({
		"id": id,
		"title": title,
		"description": description,
		"target_node_path": target_node_path,
		"highlight_rect": highlight_rect,
		"required_action": required_action
	})

# Get the current step
func get_current_step() -> Dictionary:
	if steps.is_empty() or current_step_index < 0 or current_step_index >= steps.size():
		return {}
	return steps[current_step_index]

# Advance to the next step
func advance() -> bool:
	if current_step_index < steps.size() - 1:
		current_step_index += 1
		return true
	return false

# Go back to the previous step
func go_back() -> bool:
	if current_step_index > 0:
		current_step_index -= 1
		return true
	return false

# Reset tutorial to the beginning
func reset() -> void:
	current_step_index = 0

# Convert to dictionary for serialization
func to_dict() -> Dictionary:
	var step_dicts = []
	for step in steps:
		step_dicts.append(step.duplicate())
	
	return {
		"layout_id": layout_id,
		"layout_name": layout_name,
		"steps": step_dicts,
		"current_step_index": current_step_index
	}

# Factory method to create a basic combat tutorial layout
# This is more reliable than trying to use the class itself
static func create_basic_combat_tutorial() -> Resource:
	# Load this script to create an instance
	var script = load("res://src/core/tutorial/BattleTutorialLayout.gd")
	var layout = script.new("basic_combat", "Combat Tutorial")
	
	# Add steps manually
	layout.add_step(
		"welcome",
		"Welcome to Combat",
		"This tutorial will guide you through the basics of combat in Five Parsecs."
	)
	
	layout.add_step(
		"select_character",
		"Select a Character",
		"Click on one of your characters to select them."
	)
	
	layout.add_step(
		"move_character",
		"Move Character",
		"Click on a valid position to move your character."
	)
	
	layout.add_step(
		"attack",
		"Attack an Enemy",
		"Select an enemy within range to attack them."
	)
	
	layout.add_step(
		"end_turn",
		"End Your Turn",
		"When you're done with all actions, click the End Turn button."
	)
	
	return layout

# Factory method to create tutorial layouts
# This is a safer way to avoid caching issues
static func create_layout(layout_type: String) -> Resource:
	match layout_type:
		"basic_combat":
			return create_basic_combat_tutorial()
		_:
			# For other layout types, create a basic empty layout
			var script = load("res://src/core/tutorial/BattleTutorialLayout.gd")
			return script.new(layout_type, layout_type.capitalize() + " Tutorial")
			
# For backward compatibility, but using a non-self-referential approach
func get_layout(layout_id: String = "basic_combat") -> Resource:
	# Use static methods instead of calling the class constructor
	return create_layout(layout_id)
