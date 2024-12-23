class_name TutorialActionTracker
extends Node

var completed_actions: Dictionary = {}

func mark_action_complete(action: String) -> void:
    completed_actions[action] = true
    
func is_action_complete(action: String) -> bool:
    return completed_actions.get(action, false)
    
func clear_actions() -> void:
    completed_actions.clear()
    
func serialize() -> Dictionary:
    return completed_actions
    
func deserialize(data: Dictionary) -> void:
    completed_actions = data 