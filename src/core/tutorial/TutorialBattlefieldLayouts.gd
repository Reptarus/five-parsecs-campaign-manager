class_name TutorialBattlefieldLayouts
extends Resource

const TUTORIAL_LAYOUTS := {
    "movement_basics": {
        "grid_size": Vector2i(10, 10),
        "player_start": Vector2(2, 5),
        "terrain": [
            {"type": "COVER", "position": Vector2(4, 5)},
            {"type": "COVER", "position": Vector2(6, 5)},
            {"type": "COVER", "position": Vector2(4, 3)},
            {"type": "COVER", "position": Vector2(4, 7)}
        ],
        "objectives": [
            {"type": "MOVE_TO", "position": Vector2(8, 5)}
        ],
        "enemies": []
    },
    "combat_basics": {
        "grid_size": Vector2i(12, 12),
        "player_start": Vector2(2, 6),
        "terrain": [
            {"type": "COVER", "position": Vector2(4, 6)},
            {"type": "COVER", "position": Vector2(8, 6)},
            {"type": "BUILDING", "position": Vector2(6, 4)},
            {"type": "BUILDING", "position": Vector2(6, 8)}
        ],
        "objectives": [],
        "enemies": [
            {"type": "Basic", "position": Vector2(10, 6)}
        ]
    },
    "tactical_cover": {
        "grid_size": Vector2i(15, 15),
        "player_start": Vector2(2, 7),
        "terrain": [
            {"type": "COVER", "position": Vector2(4, 7)},
            {"type": "COVER", "position": Vector2(7, 7)},
            {"type": "COVER", "position": Vector2(10, 7)},
            {"type": "BUILDING", "position": Vector2(7, 4)},
            {"type": "BUILDING", "position": Vector2(7, 10)},
            {"type": "ELEVATED", "position": Vector2(13, 7)}
        ],
        "objectives": [
            {"type": "CONTROL", "position": Vector2(7, 7)}
        ],
        "enemies": [
            {"type": "Basic", "position": Vector2(12, 6)},
            {"type": "Basic", "position": Vector2(12, 8)}
        ]
    },
    "advanced_tactics": {
        "grid_size": Vector2i(20, 20),
        "player_start": Vector2(2, 10),
        "terrain": [
            {"type": "COVER", "position": Vector2(5, 10)},
            {"type": "COVER", "position": Vector2(8, 10)},
            {"type": "BUILDING", "position": Vector2(12, 8)},
            {"type": "BUILDING", "position": Vector2(12, 12)},
            {"type": "ELEVATED", "position": Vector2(15, 10)},
            {"type": "HAZARD", "position": Vector2(10, 10)}
        ],
        "objectives": [
            {"type": "ACQUIRE", "position": Vector2(18, 10)}
        ],
        "enemies": [
            {"type": "Elite", "position": Vector2(16, 9)},
            {"type": "Basic", "position": Vector2(16, 11)},
            {"type": "Basic", "position": Vector2(14, 10)}
        ]
    }
}

static func get_layout(tutorial_step: String) -> Dictionary:
    return TUTORIAL_LAYOUTS.get(tutorial_step, TUTORIAL_LAYOUTS.movement_basics) 