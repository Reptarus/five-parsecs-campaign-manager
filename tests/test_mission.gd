extends "res://tests/test_base.gd"

const Mission = preload("res://src/core/systems/Mission.gd")

var mission: Mission

func before_each() -> void:
    super.before_each()
    # Initialize and track mission resource
    mission = Mission.new()
    track_test_resource(mission)
    
    # Setup default mission parameters
    mission.mission_name = "Test Mission"
    mission.mission_type = GameEnums.MissionType.RED_ZONE
    mission.difficulty = GameEnums.DifficultyLevel.NORMAL
    mission.objectives = [
        {
            "type": "SEARCH",
            "description": "Find the target",
            "completed": false,
            "is_primary": true
        },
        {
            "type": "SECURE",
            "description": "Secure the area",
            "completed": false,
            "is_primary": false
        }
    ]
    mission.rewards = {
        "credits": 1000,
        "reputation": 2
    }

func after_each() -> void:
    super.after_each()

func test_mission_initialization() -> void:
    assert_not_null(mission.mission_id, "Mission should have an ID")
    assert_eq(mission.mission_name, "Test Mission", "Mission name should be set")
    assert_eq(mission.mission_type, GameEnums.MissionType.RED_ZONE, "Mission type should be set")
    assert_eq(mission.difficulty, GameEnums.DifficultyLevel.NORMAL, "Difficulty should be set")
    assert_eq(mission.objectives.size(), 2, "Should have 2 objectives")
    assert_false(mission.is_completed, "Mission should not be completed initially")

func test_requirement_validation() -> void:
    mission.required_skills = ["combat", "tech"]
    mission.required_equipment = ["armor"]
    mission.minimum_crew_size = 2
    
    # Test with insufficient capabilities
    var insufficient_capabilities := {
        "skills": ["combat"],
        "equipment": [],
        "crew_size": 1
    }
    var result1 = mission.validate_requirements(insufficient_capabilities)
    assert_false(result1["valid"], "Should fail with insufficient capabilities")
    assert_eq(result1["missing"].size(), 2, "Should have 2 missing requirements")
    
    # Test with sufficient capabilities
    var sufficient_capabilities := {
        "skills": ["combat", "tech", "medical"],
        "equipment": ["armor", "weapons"],
        "crew_size": 3
    }
    var result2 = mission.validate_requirements(sufficient_capabilities)
    assert_true(result2["valid"], "Should pass with sufficient capabilities")
    assert_eq(result2["missing"].size(), 0, "Should have no missing requirements")

func test_objective_completion() -> void:
    # Complete primary objective
    mission.complete_objective(0)
    assert_true(mission.objectives[0]["completed"], "Primary objective should be completed")
    assert_true(mission.is_completed, "Mission should be completed when primary objective is done")
    
    # Verify completion percentage
    assert_eq(mission.completion_percentage, 50.0, "Completion should be 50% with one objective done")
    
    # Complete secondary objective
    mission.complete_objective(1)
    assert_eq(mission.completion_percentage, 100.0, "Completion should be 100% with all objectives done")

func test_mission_failure() -> void:
    mission.fail_mission()
    assert_true(mission.is_failed, "Mission should be marked as failed")
    assert_false(mission.is_completed, "Failed mission should not be marked as completed")

func test_phase_changes() -> void:
    mission.change_phase("combat")
    assert_eq(mission.current_phase, "combat", "Phase should be updated")
    assert_eq(mission._get_status(), "combat", "Status should reflect current phase")

func test_reward_calculation() -> void:
    # Test basic reward calculation
    var base_rewards = mission.calculate_final_rewards()
    assert_eq(base_rewards.size(), 0, "Should not give rewards for incomplete mission")
    
    # Complete mission and test rewards
    mission.complete_objective(0)
    var final_rewards = mission.calculate_final_rewards()
    assert_eq(final_rewards["credits"], 1000, "Should get base credits")
    assert_eq(final_rewards["reputation"], 2, "Should get base reputation")
    
    # Test reward multipliers
    mission.resource_multiplier = 1.5
    mission.reputation_multiplier = 2.0
    final_rewards = mission.calculate_final_rewards()
    assert_eq(final_rewards["credits"], 1500, "Credits should be multiplied")
    assert_eq(final_rewards["reputation"], 4, "Reputation should be multiplied")
    
    # Complete all objectives and test bonus rewards
    mission.complete_objective(1)
    final_rewards = mission.calculate_final_rewards()
    assert_has(final_rewards, "bonus_credits", "Should have bonus credits for all objectives")
    assert_has(final_rewards, "bonus_reputation", "Should have bonus reputation for all objectives")

func test_special_rules() -> void:
    mission.add_special_rule("stealth_required")
    assert_true(mission.has_special_rule("stealth_required"), "Should have added special rule")
    
    mission.add_special_rule("stealth_required")
    assert_eq(mission.special_rules.size(), 1, "Should not duplicate special rules")

func test_objective_queries() -> void:
    var active = mission.get_active_objectives()
    assert_eq(active.size(), 2, "Should have 2 active objectives initially")
    
    mission.complete_objective(0)
    active = mission.get_active_objectives()
    assert_eq(active.size(), 1, "Should have 1 active objective after completion")
    
    var completed = mission.get_completed_objectives()
    assert_eq(completed.size(), 1, "Should have 1 completed objective")

func test_mission_summary() -> void:
    var summary = mission.get_summary()
    assert_has(summary, "id", "Summary should have mission ID")
    assert_has(summary, "name", "Summary should have mission name")
    assert_has(summary, "type", "Summary should have mission type")
    assert_has(summary, "difficulty", "Summary should have difficulty")
    assert_has(summary, "completion", "Summary should have completion percentage")
    assert_has(summary, "status", "Summary should have status")
    assert_has(summary, "objectives", "Summary should have objectives")
    assert_has(summary, "rewards", "Summary should have rewards")