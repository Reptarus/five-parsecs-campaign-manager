@tool
extends FiveParsecsEnemyTest

# Test constants
const TEST_MISSION_CONFIGS = {
    "BASIC": {
        "type": GameEnums.MissionType.PATROL,
        "difficulty": GameEnums.DifficultyLevel.NORMAL,
        "rewards": {
            "credits": 100,
            "reputation": 1
        }
    },
    "ADVANCED": {
        "type": GameEnums.MissionType.RAID,
        "difficulty": GameEnums.DifficultyLevel.HARD,
        "rewards": {
            "credits": 200,
            "reputation": 2
        }
    }
}

# ... existing code ... 