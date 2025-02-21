@tool
extends FiveParsecsEnemyTest

# Test constants
const TEST_RULES = {
    "BASIC": {
        "name": "Basic Rules",
        "enabled": true,
        "settings": {
            "permadeath": true,
            "story_track": true
        }
    },
    "ADVANCED": {
        "name": "Advanced Rules",
        "enabled": false,
        "settings": {
            "permadeath": false,
            "story_track": false
        }
    }
}

# ... existing code ... 