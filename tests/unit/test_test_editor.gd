@tool
extends FiveParsecsEnemyTest

# Test constants
const TEST_EDITOR_STATES = {
    "EMPTY": {
        "visible": true,
        "has_changes": false,
        "selected_line": -1
    },
    "MODIFIED": {
        "visible": true,
        "has_changes": true,
        "selected_line": 10
    }
}

# ... existing code ... 