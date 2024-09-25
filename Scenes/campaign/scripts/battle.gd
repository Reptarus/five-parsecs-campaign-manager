extends Control

var game_state: GameStateManager
var current_mission: Mission

@onready var combat_manager: Node = $CombatManager
@onready var move_button: Button = $SidePanel/VBoxContainer/ActionButtons/MoveButton
@onready var attack_button: Button = $SidePanel/VBoxContainer/ActionButtons/AttackButton
@onready var end_turn_button: Button = $SidePanel/VBoxContainer/ActionButtons/EndTurnButton

func _ready():
    game_state = get_node("/root/GameState")
    if game_state == null:
        push_error("Failed to get GameStateManager")
        return
    
    current_mission = game_state.current_mission
    if current_mission == null:
        push_error("No current mission set in GameStateManager")
        return
    
    if combat_manager == null:
        push_error("CombatManager node not found")
        return
    
    combat_manager.initialize(game_state, current_mission)
    combat_manager.connect("combat_started", _on_combat_started)
    combat_manager.connect("combat_ended", _on_combat_ended)
    combat_manager.connect("turn_started", _on_turn_started)
    
    move_button.connect("pressed", _on_move_button_pressed)
    attack_button.connect("pressed", _on_attack_button_pressed)
    end_turn_button.connect("pressed", _on_end_turn_button_pressed)

func _on_combat_ended(player_victory: bool):
    if player_victory:
        current_mission.complete()
    else:
        current_mission.fail()
    
    # Transition to post-battle scene
    get_tree().change_scene_to_file("res://Scenes/campaign/PostBattleScene.tscn")