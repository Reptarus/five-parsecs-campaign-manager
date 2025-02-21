@tool
extends FiveParsecsEnemyTest

# Test constants
const TEST_OVERRIDE_STATES = {
    "ENABLED": {
        "visible": true,
        "override_active": true,
        "selected_option": 0
    },
    "DISABLED": {
        "visible": false,
        "override_active": false,
        "selected_option": -1
    }
}

# ... existing code ... 