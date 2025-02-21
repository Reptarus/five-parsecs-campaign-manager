@tool
extends FiveParsecsEnemyTest

# Test constants
const TEST_VALIDATION_STATES = {
    "VALID": {
        "visible": true,
        "validation_passed": true,
        "error_count": 0
    },
    "INVALID": {
        "visible": true,
        "validation_passed": false,
        "error_count": 3
    }
}

# ... existing code ... 