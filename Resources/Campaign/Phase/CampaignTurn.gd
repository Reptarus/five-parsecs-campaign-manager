extends Node

const GameEnums = preload("res://Resources/Core/Systems/GlobalEnums.gd")
const CampaignManager = preload("res://Resources/CampaignManagement/CampaignManager.gd")
const WorldPhaseManager = preload("res://Resources/WorldPhase/WorldPhaseManager.gd")
const BattleManager = preload("res://Resources/Battle/Core/BattleManager.gd")
const PostBattleManager = preload("res://Resources/Campaign/Phase/PostBattleManager.gd")

signal turn_started
signal turn_ended
signal phase_changed(new_phase: GlobalEnums.CampaignPhase)

@export var campaign_manager: CampaignManager
var current_phase: GlobalEnums.CampaignPhase = GlobalEnums.CampaignPhase.SETUP
var is_phase_active: bool = false

var world_phase_manager: WorldPhaseManager
var battle_manager  # Removed type annotation
var post_battle_manager: PostBattleManager

func _ready() -> void:
    if not campaign_manager:
        push_error("CampaignManager is required for CampaignTurn")
        return
        
    if not world_phase_manager:
        world_phase_manager = WorldPhaseManager.new(campaign_manager.game_state, campaign_manager)
        world_phase_manager.name = "WorldPhaseManager"
        add_child(world_phase_manager)
        
    if not battle_manager:
        battle_manager = BattleManager.new(campaign_manager.game_state, campaign_manager)
        battle_manager.name = "BattleManager"
        add_child(battle_manager)
        
    if not post_battle_manager:
        post_battle_manager = PostBattleManager.new(campaign_manager.game_state, campaign_manager)
        post_battle_manager.name = "PostBattleManager"
        add_child(post_battle_manager)
        
    _connect_signals()

func _connect_signals() -> void:
    world_phase_manager.phase_completed.connect(_on_world_phase_completed)
    battle_manager.battle_ended.connect(_on_battle_phase_completed)
    post_battle_manager.phase_completed.connect(_on_post_battle_phase_completed)

func start_turn() -> void:
    turn_started.emit()
    current_phase = GlobalEnums.CampaignPhase.SETUP
    is_phase_active = true
    world_phase_manager.start_phase()

func advance_phase() -> void:
    match current_phase:
        GlobalEnums.CampaignPhase.SETUP:
            current_phase = GlobalEnums.CampaignPhase.BATTLE
            is_phase_active = true
            if campaign_manager.game_state.current_mission:
                battle_manager.start_battle(campaign_manager.game_state.current_mission)
            else:
                advance_phase()
        GlobalEnums.CampaignPhase.BATTLE:
            current_phase = GlobalEnums.CampaignPhase.POST_BATTLE
            is_phase_active = true
            post_battle_manager.start_phase()
        GlobalEnums.CampaignPhase.POST_BATTLE:
            end_turn()
    
    phase_changed.emit(current_phase)

func end_turn() -> void:
    is_phase_active = false
    current_phase = GlobalEnums.CampaignPhase.SETUP
    turn_ended.emit()

func _on_world_phase_completed() -> void:
    if current_phase == GlobalEnums.CampaignPhase.SETUP:
        advance_phase()

func _on_battle_phase_completed() -> void:
    if current_phase == GlobalEnums.CampaignPhase.BATTLE:
        advance_phase()

func _on_post_battle_phase_completed() -> void:
    if current_phase == GlobalEnums.CampaignPhase.POST_BATTLE:
        advance_phase()
  