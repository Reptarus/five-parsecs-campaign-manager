@tool
extends FiveParsecsEnemyTest

# Test constants
const TEST_TEMPLATES = {
    "BASIC": {
        "name": "Basic Mission",
        "type": GameEnums.MissionType.PATROL,
        "objectives": ["Patrol Area", "Report Activity"],
        "rewards": {
            "credits": 100,
            "reputation": 1
        }
    },
    "ADVANCED": {
        "name": "Advanced Mission",
        "type": GameEnums.MissionType.RAID,
        "objectives": ["Infiltrate Base", "Secure Intel", "Extract"],
        "rewards": {
            "credits": 200,
            "reputation": 2
        }
    }
}

# ... existing code ... 