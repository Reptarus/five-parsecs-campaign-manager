class_name TestPreBattle
extends Control

@onready var mission_info := $MissionInfo
@onready var enemy_info := $EnemyInfo
@onready var crew_selection := $CrewSelection

var test_mission := {
    "title": "Test Mission",
    "description": "This is a test mission for development purposes.",
    "difficulty": 1,
    "battle_type": 0,
    "rewards": {
        "credits": 1000,
        "items": [
            {"name": "Test Item 1"},
            {"name": "Test Item 2"}
        ],
        "reputation": 10
    }
}

var test_enemies := {
    "units": [
        {"type": "Test Enemy 1", "count": 2},
        {"type": "Test Enemy 2", "count": 1}
    ],
    "threat_level": 1,
    "special_rules": [
        {
            "name": "Test Rule",
            "description": "This is a test special rule."
        }
    ]
}

var test_crew := [
    {"name": "Test Character 1", "class": "Soldier"},
    {"name": "Test Character 2", "class": "Medic"},
    {"name": "Test Character 3", "class": "Engineer"},
    {"name": "Test Character 4", "class": "Scout"}
]

func _ready() -> void:
    mission_info.setup(test_mission)
    enemy_info.setup(test_enemies)
    crew_selection.setup(test_crew) 