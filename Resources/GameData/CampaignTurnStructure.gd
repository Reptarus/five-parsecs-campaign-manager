class_name CampaignTurnStructure
extends Node

enum TurnStep {
    TRAVEL,
    WORLD_STEP,
    BATTLE,
    POST_BATTLE
}

enum WorldStep {
    UPKEEP,
    CREW_TASKS,
    JOB_OFFERS,
    EQUIPMENT,
    RUMORS,
    BATTLE_PREP
}

enum PostBattleStep {
    RIVAL_STATUS,
    PATRON_STATUS,
    QUEST_PROGRESS,
    PAYMENT,
    SALVAGE_TRADE,
    BATTLEFIELD_FINDS,
    SALVAGE_POI,
    INVASION_CHECK,
    INSTABILITY_CHECK,
    LOOT,
    INJURIES,
    EXPERIENCE,
    TRAINING,
    PURCHASES,
    CAMPAIGN_EVENT,
    CHARACTER_EVENT,
    GALACTIC_WAR
}

signal turn_step_completed(step: int)
signal world_step_completed(step: int)
signal post_battle_step_completed(step: int)

var current_step: TurnStep = TurnStep.TRAVEL
var current_world_step: WorldStep = WorldStep.UPKEEP
var current_post_battle_step: PostBattleStep = PostBattleStep.RIVAL_STATUS

@onready var game_state: Node = get_node("%GameState")  # Will be cast to GameState at runtime
@onready var mission_generator: Node = get_node("%MissionGenerator")  # Will be cast to MissionGenerator at runtime
@onready var equipment_manager: Node = get_node("%EquipmentManager")  # Will be cast to EquipmentManager at runtime
@onready var patron_job_manager: Node = get_node("%PatronJobManager")  # Will be cast to PatronJobManager at runtime

func start_campaign_turn() -> void:
    current_step = TurnStep.TRAVEL
    handle_travel_step()

func handle_step() -> void:
    match current_step:
        TurnStep.TRAVEL:
            handle_travel_step()
        TurnStep.WORLD_STEP:
            handle_world_step()
        TurnStep.BATTLE:
            handle_battle_step()
        TurnStep.POST_BATTLE:
            handle_post_battle_step()

func handle_travel_step() -> void:
    var travel_event = game_state.generate_travel_event()
    if travel_event:
        await handle_travel_event(travel_event)
    handle_new_world_arrival()
    advance_to_next_step()

func handle_world_step() -> void:
    match current_world_step:
        WorldStep.UPKEEP:
            handle_upkeep()
        WorldStep.CREW_TASKS:
            handle_crew_tasks()
        WorldStep.JOB_OFFERS:
            handle_job_offers()
        WorldStep.EQUIPMENT:
            handle_equipment()
        WorldStep.RUMORS:
            handle_rumors()
        WorldStep.BATTLE_PREP:
            handle_battle_prep()

func handle_post_battle_step() -> void:
    match current_post_battle_step:
        PostBattleStep.RIVAL_STATUS:
            handle_rival_status()
        PostBattleStep.PATRON_STATUS:
            handle_patron_status()
        PostBattleStep.GALACTIC_WAR:
            handle_galactic_war_progress()

func advance_to_next_step() -> void:
    var steps = TurnStep.values()
    var current_index = steps.find(current_step)
    if current_index < steps.size() - 1:
        current_step = steps[current_index + 1]
    else:
        current_step = TurnStep.TRAVEL
    turn_step_completed.emit(current_step)

func handle_travel_event(event: Dictionary) -> void:
    match event.type:
        "COMBAT":
            await handle_space_combat(event)
        "TRADE":
            handle_trade_opportunity(event)
        "HAZARD":
            handle_space_hazard(event)
        "DISCOVERY":
            handle_space_discovery(event)

func handle_new_world_arrival() -> void:
    # Check for rivals
    if game_state.check_for_rivals():
        game_state.trigger_rival_encounter()
    
    # Update local economy
    game_state.update_market_prices()
    
    # Check for special events
    if game_state.has_special_event():
        game_state.trigger_special_event()

func handle_upkeep() -> void:
    var upkeep_cost = game_state.calculate_upkeep()
    if game_state.can_afford(upkeep_cost):
        game_state.spend_credits(upkeep_cost)
        game_state.perform_ship_repairs()
    else:
        handle_failed_upkeep()
    
    current_world_step = WorldStep.CREW_TASKS
    world_step_completed.emit(current_world_step)

# Implementation of missing functions
func handle_battle_step() -> void:
    if game_state.current_mission:
        await game_state.start_battle()
    advance_to_next_step()

func handle_rival_status() -> void:
    game_state.update_rival_status()
    advance_post_battle_step()

func handle_patron_status() -> void:
    game_state.update_patron_status()
    advance_post_battle_step()

func handle_galactic_war_progress() -> void:
    game_state.update_galactic_war()
    advance_post_battle_step()

func handle_space_combat(event: Dictionary) -> void:
    await game_state.resolve_space_combat(event)

func handle_trade_opportunity(event: Dictionary) -> void:
    game_state.handle_trade_event(event)

func handle_space_hazard(event: Dictionary) -> void:
    game_state.handle_hazard_event(event)

func handle_space_discovery(event: Dictionary) -> void:
    game_state.handle_discovery_event(event)

func handle_failed_upkeep() -> void:
    game_state.apply_failed_upkeep_consequences()

func advance_post_battle_step() -> void:
    var steps = PostBattleStep.values()
    var current_index = steps.find(current_post_battle_step)
    if current_index < steps.size() - 1:
        current_post_battle_step = steps[current_index + 1]
    else:
        advance_to_next_step()
    post_battle_step_completed.emit(current_post_battle_step)

# Additional required functions
func handle_crew_tasks() -> void:
    game_state.process_crew_tasks()
    advance_world_step()

func handle_job_offers() -> void:
    game_state.process_job_offers()
    advance_world_step()

func handle_equipment() -> void:
    game_state.process_equipment_phase()
    advance_world_step()

func handle_rumors() -> void:
    game_state.process_rumors()
    advance_world_step()

func handle_battle_prep() -> void:
    game_state.prepare_for_battle()
    advance_world_step()

func advance_world_step() -> void:
    var steps = WorldStep.values()
    var current_index = steps.find(current_world_step)
    if current_index < steps.size() - 1:
        current_world_step = steps[current_index + 1]
    else:
        advance_to_next_step()
    world_step_completed.emit(current_world_step)