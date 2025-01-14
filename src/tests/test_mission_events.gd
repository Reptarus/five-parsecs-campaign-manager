extends "res://addons/gut/test.gd"

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const EventManager = preload("res://src/core/managers/EventManager.gd")
const MissionGenerator = preload("res://src/core/systems/MissionGenerator.gd")
const TerrainSystem = preload("res://src/core/terrain/TerrainSystem.gd")
const RivalSystem = preload("res://src/core/rivals/RivalSystem.gd")
const PositionValidator = preload("res://src/core/systems/PositionValidator.gd")
const ResourceSystem = preload("res://src/core/systems/ResourceSystem.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

var _event_manager: EventManager
var _mission_generator: MissionGenerator
var _terrain_system: TerrainSystem
var _rival_system: RivalSystem
var _position_validator: PositionValidator
var _resource_system: ResourceSystem
var _game_state: FiveParsecsGameState

func before_each():
    _game_state = FiveParsecsGameState.new()
    _event_manager = EventManager.new()
    _mission_generator = MissionGenerator.new()
    _terrain_system = TerrainSystem.new()
    _rival_system = RivalSystem.new()
    _position_validator = PositionValidator.new()
    _resource_system = ResourceSystem.new()
    
    _event_manager.initialize(_game_state)
    _mission_generator.setup(
        _terrain_system,
        _rival_system,
        _position_validator,
        _resource_system,
        _event_manager
    )
    
    add_child(_event_manager)
    add_child(_mission_generator)

func after_each():
    _event_manager.queue_free()
    _mission_generator.queue_free()
    _terrain_system.queue_free()
    _rival_system.queue_free()
    _position_validator.queue_free()
    _resource_system.queue_free()
    _game_state.free()

func test_mission_event_integration():
    var mission = Mission.new()
    mission.mission_type = GameEnums.MissionType.RED_ZONE
    mission.difficulty = GameEnums.DifficultyLevel.NORMAL
    
    # Test event triggering
    _event_manager.trigger_mission_event("RIVAL_INTERFERENCE", mission)
    assert_true(mission.has_active_event("RIVAL_INTERFERENCE"), "Mission should have rival interference event")
    
    # Test difficulty modification
    var base_difficulty = mission.difficulty
    var effective_difficulty = mission.get_effective_difficulty()
    assert_gt(effective_difficulty, base_difficulty, "Event should increase mission difficulty")

func test_mission_reward_modification():
    var mission = Mission.new()
    mission.mission_type = GameEnums.MissionType.RED_ZONE
    mission.difficulty = GameEnums.DifficultyLevel.NORMAL
    mission.reward_range = Vector2(100, 200)
    
    # Get base rewards
    var base_rewards = _mission_generator._calculate_rewards(mission)
    var base_credits = base_rewards.credits
    
    # Trigger event that modifies rewards
    _event_manager.trigger_mission_event("CRITICAL_INTEL", mission)
    
    # Get modified rewards
    var modified_rewards = _mission_generator._calculate_rewards(mission)
    var modified_credits = modified_rewards.credits
    
    assert_gt(modified_credits, base_credits, "Event should increase mission rewards")
    assert_true(modified_rewards.has("intel"), "Critical intel event should add intel reward")

func test_mission_objective_modification():
    var mission = Mission.new()
    mission.mission_type = GameEnums.MissionType.RED_ZONE
    mission.difficulty = GameEnums.DifficultyLevel.NORMAL
    
    var initial_objectives = mission.objectives.size()
    
    # Trigger event that adds bonus objective
    _event_manager.trigger_mission_event("CRITICAL_INTEL", mission)
    
    assert_gt(mission.objectives.size(), initial_objectives, "Event should add bonus objective")
    
    # Verify bonus objective properties
    var bonus_objective = mission.objectives.back()
    assert_false(bonus_objective.is_primary, "Bonus objective should not be primary")

func test_mission_special_rules():
    var mission = Mission.new()
    mission.mission_type = GameEnums.MissionType.RED_ZONE
    mission.difficulty = GameEnums.DifficultyLevel.NORMAL
    
    var initial_rules = mission.special_rules.size()
    
    # Trigger event that adds hazard
    _event_manager.trigger_mission_event("ENVIRONMENTAL_HAZARD", mission)
    
    assert_gt(mission.special_rules.size(), initial_rules, "Event should add special rules")
    assert_true(mission.special_rules.has("HAZARD_LEVEL_2"), "Environmental hazard should add hazard level rule")

func test_mission_duration_calculation():
    var mission = Mission.new()
    mission.mission_type = GameEnums.MissionType.RED_ZONE
    mission.difficulty = GameEnums.DifficultyLevel.NORMAL
    
    var base_duration = mission.get_estimated_duration()
    
    # Trigger event that affects duration
    _event_manager.trigger_mission_event("ENVIRONMENTAL_HAZARD", mission)
    
    var modified_duration = mission.get_estimated_duration()
    assert_gt(modified_duration, base_duration, "Hazardous conditions should increase mission duration")

func test_multiple_events():
    var mission = Mission.new()
    mission.mission_type = GameEnums.MissionType.RED_ZONE
    mission.difficulty = GameEnums.DifficultyLevel.NORMAL
    
    # Trigger multiple events
    _event_manager.trigger_mission_event("RIVAL_INTERFERENCE", mission)
    _event_manager.trigger_mission_event("ENVIRONMENTAL_HAZARD", mission)
    
    assert_eq(mission.get_active_events().size(), 2, "Mission should track multiple active events")
    
    # Test cumulative effects
    var reward_multiplier = mission.get_reward_multiplier()
    assert_gt(reward_multiplier, 1.3, "Multiple events should stack reward multipliers")

func test_event_resolution():
    var mission = Mission.new()
    mission.mission_type = GameEnums.MissionType.RED_ZONE
    mission.difficulty = GameEnums.DifficultyLevel.NORMAL
    
    # Trigger and resolve events
    _event_manager.trigger_mission_event("RIVAL_INTERFERENCE", mission)
    var initial_difficulty = mission.get_effective_difficulty()
    
    # Simulate event resolution
    _event_manager._process_mission_events()
    
    # Advance game state turns to force event resolution
    _game_state.current_turn += 10
    _event_manager._process_mission_events()
    
    var final_difficulty = mission.get_effective_difficulty()
    assert_eq(final_difficulty, mission.difficulty, "Resolved event should remove difficulty modifier")