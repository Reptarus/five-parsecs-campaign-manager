@tool
extends FiveParsecsEnemyTest

# Test constants
const TEST_LOG_ENTRIES = {
    "ATTACK": {
        "type": "ATTACK",
        "source": "Player",
        "target": "Enemy",
        "damage": 10
    },
    "HEAL": {
        "type": "HEAL",
        "source": "Medic",
        "target": "Player",
        "amount": 20
    }
}

# ... existing code ... 