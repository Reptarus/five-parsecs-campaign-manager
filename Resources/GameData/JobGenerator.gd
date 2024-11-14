class_name JobGenerator
extends MissionGeneratorBase

signal job_generated(job: Mission)
signal generation_failed(error: String)

const MIN_REWARD: int = 100
const MAX_REWARD: int = 10000
const DIFFICULTY_MULTIPLIER: float = 1.5

var location_modifiers: Dictionary = {}  # Location: float
var faction_bonuses: Dictionary = {}  # GlobalEnums.FactionType: float

func generate_job(location: Location, difficulty: int) -> Mission:
    if location == null:
        push_error("Location is required for job generation")
        generation_failed.emit("Invalid location")
        return null
        
    if difficulty < 1:
        push_error("Invalid difficulty level")
        generation_failed.emit("Invalid difficulty")
        return null
        
    var job_data: Dictionary = {
        "mission_type": select_job_type(location),
        "difficulty": difficulty,
        "reward": calculate_reward(difficulty, location),
        "location": location,
        "requirements": generate_requirements(difficulty)
    }
    
    var job: Mission = Mission.new()
    job.initialize(job_data)
    if validate_job(job):
        job_generated.emit(job)
        return job
    return null

func validate_job(job: Mission) -> bool:
    if job.mission_type == GlobalEnums.MissionType.OPPORTUNITY or job.location == null or job.difficulty < 1:
        push_error("Invalid job data")
        generation_failed.emit("Job validation failed")
        return false
    return true

func select_job_type(location: Location) -> int:
    # Default to OPPORTUNITY type mission
    return GlobalEnums.MissionType.OPPORTUNITY

func calculate_reward(difficulty: int, location: Location) -> int:
    var base_reward = MIN_REWARD + (difficulty * DIFFICULTY_MULTIPLIER)
    var location_modifier = location_modifiers.get(location, 1.0)
    return int(clamp(base_reward * location_modifier, MIN_REWARD, MAX_REWARD))

func generate_requirements(difficulty: int) -> Array:
    # Placeholder logic for generating job requirements based on difficulty
    return ["requirement_1", "requirement_2"]
