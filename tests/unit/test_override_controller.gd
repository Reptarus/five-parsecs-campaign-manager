@tool
extends FiveParsecsEnemyTest

# Test constants
const TEST_OVERRIDE_SETTINGS = {
    "BASIC": {
        "name": "Basic Override",
        "enabled": true,
        "settings": {
            "difficulty": GameEnums.DifficultyLevel.NORMAL,
            "permadeath": true
        }
    },
    "ADVANCED": {
        "name": "Advanced Override",
        "enabled": false,
        "settings": {
            "difficulty": GameEnums.DifficultyLevel.HARD,
            "permadeath": false
        }
    }
}

# ... existing code ... 