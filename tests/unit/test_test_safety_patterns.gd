@tool
extends FiveParsecsEnemyTest

# Test constants
const TEST_SAFETY_PATTERNS = {
    "BASIC": {
        "name": "Basic Pattern",
        "enabled": true,
        "rules": ["Type Safety", "Resource Tracking"]
    },
    "ADVANCED": {
        "name": "Advanced Pattern",
        "enabled": false,
        "rules": ["Signal Safety", "Memory Management"]
    }
}

# ... existing code ... 