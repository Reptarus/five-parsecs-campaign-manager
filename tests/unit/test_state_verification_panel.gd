@tool
extends FiveParsecsEnemyTest

# Test constants
const TEST_VERIFICATION_STATES = {
    "VALID": {
        "visible": true,
        "state_valid": true,
        "error_count": 0
    },
    "INVALID": {
        "visible": true,
        "state_valid": false,
        "error_count": 2
    }
}

# ... existing code ... 