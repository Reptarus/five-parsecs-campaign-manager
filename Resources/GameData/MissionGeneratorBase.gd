class_name MissionGeneratorBase
extends Resource

var game_state: GameState

const BASE_REWARD_CREDITS := 100
const DIFFICULTY_MULTIPLIER := 50
const REPUTATION_BASE := 1

func _init(_game_state: GameState) -> void:
    game_state = _game_state

func _create_base_mission() -> Mission:
    var mission = Mission.new()
    mission.location = game_state.current_location
    mission.time_limit = _generate_time_limit()
    mission.difficulty = _calculate_base_difficulty()
    mission.rewards = _calculate_base_rewards(mission.difficulty)
    mission.required_crew_size = _calculate_required_crew_size()
    return mission

func _calculate_base_difficulty() -> int:
    return randi() % 3 + 1  # 1 to 3 base difficulty

func _calculate_base_rewards(difficulty: int) -> Dictionary:
    return {
        "credits": BASE_REWARD_CREDITS * difficulty + randi() % (DIFFICULTY_MULTIPLIER * difficulty),
        "reputation": REPUTATION_BASE + floori(difficulty / 2.0)
    }

func _generate_time_limit() -> int:
    return randi() % 3 + 2  # 2 to 4 turns

func _calculate_required_crew_size() -> int:
    var base_size = max(2, game_state.current_ship.crew.size() - 1)
    return mini(base_size, 4)  # Cap at 4 crew members

func _validate_mission_requirements(mission: Mission) -> bool:
    var validation_manager = ValidationManager.new(game_state)
    var result = validation_manager.validate_mission_start(mission)
    return result.valid

func _modify_rewards(mission: Mission, modifier: float) -> void:
    mission.rewards["credits"] = int(mission.rewards["credits"] * modifier)
    mission.rewards["reputation"] = mini(5, int(mission.rewards["reputation"] * modifier))

func generate_benefit() -> String:
    return ["Fringe Benefit", "Connections", "Company Store", "Health Insurance", 
            "Security Team", "Persistent", "Negotiable"].pick_random()

func generate_hazard() -> String:
    return ["Dangerous Job", "Hot Job", "VIP", "Veteran Opposition", 
            "Low Priority", "Private Transport"].pick_random()

func generate_condition() -> String:
    return ["Vengeful", "Demanding", "Small Squad", "Full Squad", 
            "Clean", "Busy", "One-time Contract", "Reputation Required"].pick_random()
