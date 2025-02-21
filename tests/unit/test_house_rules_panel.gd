@tool
extends FiveParsecsEnemyTest

# Test constants
const TEST_PANEL_STATES = {
    "DEFAULT": {
        "visible": true,
        "rules_enabled": true,
        "selected_tab": 0
    },
    "HIDDEN": {
        "visible": false,
        "rules_enabled": false,
        "selected_tab": -1
    }
}

# ... existing code ... 