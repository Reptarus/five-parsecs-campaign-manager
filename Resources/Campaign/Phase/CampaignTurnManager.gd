class_name CampaignTurnManager
extends Node

signal turn_action_completed(action_type: String, result: Dictionary)
signal turn_resources_updated(resources: Dictionary)
signal turn_status_changed(status: Dictionary)

var game_state: GameState
var campaign_manager: CampaignManager

# Turn-specific tracking
var current_actions: Array[String] = []
var available_actions: Array[String] = []
var action_results: Dictionary = {}
var turn_resources: Dictionary = {
    "action_points": 3,
    "movement_points": 2,
    "special_actions": 1
}

func _init(_game_state: GameState, _campaign_manager: CampaignManager) -> void:
    game_state = _game_state
    campaign_manager = _campaign_manager
    reset_turn_resources()

func reset_turn_resources() -> void:
    turn_resources = {
        "action_points": 3,
        "movement_points": 2,
        "special_actions": 1
    }
    turn_resources_updated.emit(turn_resources)

func can_perform_action(action_type: String) -> bool:
    match action_type:
        "MOVE":
            return turn_resources.movement_points > 0
        "STANDARD":
            return turn_resources.action_points > 0
        "SPECIAL":
            return turn_resources.special_actions > 0
        _:
            return false

func perform_action(action_type: String, action_data: Dictionary) -> bool:
    if not can_perform_action(action_type):
        return false
    
    var result = _process_action(action_type, action_data)
    if result.success:
        _consume_action_resources(action_type)
        current_actions.append(action_type)
        action_results[action_type] = result
        
        turn_action_completed.emit(action_type, result)
        turn_resources_updated.emit(turn_resources)
        _update_turn_status()
        
        return true
    return false

func _process_action(action_type: String, action_data: Dictionary) -> Dictionary:
    var result = {"success": false, "message": ""}
    
    match action_type:
        "MOVE":
            result = _handle_movement(action_data)
        "TRADE":
            result = _handle_trade(action_data)
        "EXPLORE":
            result = _handle_exploration(action_data)
        "COMBAT":
            result = _handle_combat(action_data)
        "DIPLOMACY":
            result = _handle_diplomacy(action_data)
        _:
            result.message = "Unknown action type"
    
    return result

func _consume_action_resources(action_type: String) -> void:
    match action_type:
        "MOVE":
            turn_resources.movement_points -= 1
        "STANDARD":
            turn_resources.action_points -= 1
        "SPECIAL":
            turn_resources.special_actions -= 1

func _update_turn_status() -> void:
    var status = {
        "actions_taken": current_actions,
        "resources_remaining": turn_resources,
        "can_end_turn": _can_end_turn(),
        "required_actions_remaining": _get_required_actions()
    }
    turn_status_changed.emit(status)

func _can_end_turn() -> bool:
    return _get_required_actions().is_empty()

func _get_required_actions() -> Array[String]:
    var required = []
    
    # Check for mandatory actions based on game state
    if game_state.current_mission and not "COMBAT" in current_actions:
        required.append("COMBAT")
    if game_state.has_urgent_diplomacy and not "DIPLOMACY" in current_actions:
        required.append("DIPLOMACY")
    
    return required

# Action handlers
func _handle_movement(data: Dictionary) -> Dictionary:
    # Implementation of movement logic
    return {"success": true, "message": "Movement completed"}

func _handle_trade(data: Dictionary) -> Dictionary:
    # Implementation of trade logic
    return {"success": true, "message": "Trade completed"}

func _handle_exploration(data: Dictionary) -> Dictionary:
    # Implementation of exploration logic
    return {"success": true, "message": "Exploration completed"}

func _handle_combat(data: Dictionary) -> Dictionary:
    # Implementation of combat logic
    return {"success": true, "message": "Combat completed"}

func _handle_diplomacy(data: Dictionary) -> Dictionary:
    # Implementation of diplomacy logic
    return {"success": true, "message": "Diplomacy completed"} 