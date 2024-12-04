class_name PostBattleManager
extends StepManager

signal post_battle_completed(result: Dictionary)
signal loot_collected(items: Array)
signal experience_gained(crew_member: Character, amount: int)
signal reputation_changed(amount: int)
signal salvage_found(item: Dictionary, value: int)
signal poi_discovered(point: Dictionary)
signal instability_changed(new_level: int, effects: Array)

var psionic_system: Node  # Will be set to PsionicSystem at runtime
var salvage_system: Node  # Will be set to SalvageSystem at runtime
var instability_system: Node  # Will be set to InstabilitySystem at runtime
var rival_manager: Node  # Will be set to RivalManager at runtime
var patron_manager: Node  # Will be set to PatronManager at runtime
var quest_manager: Node  # Will be set to QuestManager at runtime
var loot_manager: Node  # Will be set to LootManager at runtime
var training_manager: Node  # Will be set to TrainingManager at runtime
var event_manager: Node  # Will be set to EventManager at runtime

func _init(_game_state: GameState) -> void:
    super(_game_state)
    _initialize_managers()
    steps = GlobalEnums.PostBattlePhase.values()

func _initialize_managers() -> void:
    psionic_system = Node.new()  # Will be replaced with proper type at runtime
    salvage_system = Node.new()  # Will be replaced with proper type at runtime
    instability_system = Node.new()  # Will be replaced with proper type at runtime
    rival_manager = Node.new()  # Will be replaced with proper type at runtime
    patron_manager = Node.new()  # Will be replaced with proper type at runtime
    quest_manager = Node.new()  # Will be replaced with proper type at runtime
    loot_manager = Node.new()  # Will be replaced with proper type at runtime
    training_manager = Node.new()  # Will be replaced with proper type at runtime
    event_manager = Node.new()  # Will be replaced with proper type at runtime

func _register_step_handlers() -> void:
    step_handlers = {
        GlobalEnums.PostBattlePhase.CASUALTIES: _handle_casualties,
        GlobalEnums.PostBattlePhase.LOOT: _handle_loot,
        GlobalEnums.PostBattlePhase.SALVAGE: _handle_salvage,
        GlobalEnums.PostBattlePhase.REPAIRS: _handle_repairs,
        GlobalEnums.PostBattlePhase.MORALE: _handle_morale,
        GlobalEnums.PostBattlePhase.EXPERIENCE: _handle_experience,
        GlobalEnums.PostBattlePhase.REPUTATION: _handle_reputation
    }

# Step Handlers
func _handle_casualties() -> void:
    var casualties = game_state.get_battle_casualties()
    for casualty in casualties:
        _process_casualty(casualty)

func _handle_loot() -> void:
    var loot = loot_manager.generate_loot(game_state.current_mission)
    game_state.add_loot(loot)
    loot_collected.emit(loot)

func _handle_salvage() -> void:
    if game_state.current_location:
        var salvage_results = salvage_system.check_points_of_interest(game_state.current_location)
        for result in salvage_results:
            match result.type:
                "ITEM":
                    salvage_found.emit(result.item, result.value)
                "POI":
                    poi_discovered.emit(result.point)

func _handle_repairs() -> void:
    var repair_cost = _calculate_repair_cost()
    if game_state.can_afford(repair_cost):
        game_state.spend_credits(repair_cost)
        game_state.repair_equipment()

func _handle_morale() -> void:
    var morale_change = _calculate_morale_change()
    game_state.adjust_crew_morale(morale_change)

func _handle_experience() -> void:
    for crew_member in game_state.get_active_crew():
        var exp_gained = _calculate_experience(crew_member)
        crew_member.gain_experience(exp_gained)
        experience_gained.emit(crew_member, exp_gained)

func _handle_reputation() -> void:
    var rep_change = _calculate_reputation_change()
    game_state.adjust_reputation(rep_change)
    reputation_changed.emit(rep_change)

# Helper Functions
func _process_casualty(casualty: Dictionary) -> void:
    var character = casualty.character
    match casualty.type:
        "DEAD":
            game_state.remove_crew_member(character)
        "INJURED":
            character.apply_injury(casualty.injury)
        "CAPTURED":
            game_state.capture_crew_member(character)

func _calculate_repair_cost() -> int:
    var base_cost = 100
    var damage_multiplier = game_state.get_total_damage() / 100.0
    return int(base_cost * damage_multiplier)

func _calculate_morale_change() -> int:
    var change = 0
    
    # Victory bonus
    if game_state.last_battle_victory:
        change += 1
    
    # Casualty penalty
    change -= game_state.get_battle_casualties().size()
    
    # Mission difficulty bonus
    if game_state.current_mission:
        change += game_state.current_mission.difficulty
        
    return change

func _calculate_experience(crew_member: Character) -> int:
    var base_exp = 100
    
    # Mission difficulty bonus
    if game_state.current_mission:
        base_exp *= (1.0 + game_state.current_mission.difficulty * 0.2)
    
    # Victory bonus
    if game_state.last_battle_victory:
        base_exp *= 1.5
        
    return int(base_exp)

func _calculate_reputation_change() -> int:
    var change = 0
    
    # Victory/Defeat base change
    change += 2 if game_state.last_battle_victory else -1
    
    # Mission type modifier
    if game_state.current_mission:
        change += game_state.current_mission.reputation_value
        
    # Casualty modifier
    change -= game_state.get_battle_casualties().size()
    
    return change 