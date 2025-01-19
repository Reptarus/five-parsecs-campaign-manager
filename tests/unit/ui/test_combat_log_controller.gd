@tool
extends "res://tests/test_base.gd"

const CombatLogController := preload("res://src/ui/components/combat/log/combat_log_controller.tscn")

var controller: Node
var mock_combat_manager: Node

func before_each() -> void:
    super.before_each()
    controller = CombatLogController.instantiate()
    mock_combat_manager = Node.new()
    mock_combat_manager.name = "CombatManager"
    add_child(mock_combat_manager)
    add_child(controller)

func after_each() -> void:
    super.after_each()
    controller = null
    mock_combat_manager = null

func test_initialization() -> void:
    assert_not_null(controller, "Combat log controller should be initialized")
    assert_true(controller.has_method("log_combat_event"), "Should have log_combat_event method")
    assert_true(controller.has_method("clear_log"), "Should have clear_log method")

func test_log_combat_event() -> void:
    var test_event = {
        "type": GameEnums.EventCategory.COMBAT,
        "source": "Test Unit",
        "target": "Enemy Unit",
        "details": {
            "damage": 5,
            "hit_location": "Torso"
        }
    }
    controller.log_combat_event(test_event)
    assert_eq(controller.combat_log.size(), 1, "Should add event to combat log")
    assert_eq(controller.combat_log[0].type, GameEnums.EventCategory.COMBAT, "Should store event type")

func test_log_multiple_events() -> void:
    var test_events = [
        {
            "type": GameEnums.EventCategory.COMBAT,
            "source": "Unit 1",
            "target": "Enemy 1",
            "details": {"damage": 3}
        },
        {
            "type": GameEnums.EventCategory.TACTICAL,
            "source": "Unit 2",
            "details": {"distance": 2}
        }
    ]
    
    for event in test_events:
        controller.log_combat_event(event)
    
    assert_eq(controller.combat_log.size(), 2, "Should store multiple events")
    assert_eq(controller.combat_log[0].type, GameEnums.EventCategory.COMBAT, "Should store first event type")
    assert_eq(controller.combat_log[1].type, GameEnums.EventCategory.TACTICAL, "Should store second event type")

func test_clear_log() -> void:
    var test_event = {
        "type": GameEnums.EventCategory.COMBAT,
        "source": "Test Unit",
        "target": "Enemy Unit",
        "details": {"damage": 5}
    }
    controller.log_combat_event(test_event)
    controller.clear_log()
    assert_eq(controller.combat_log.size(), 0, "Should clear combat log")

func test_auto_logging() -> void:
    watch_signals(controller)
    controller.auto_logging = true
    mock_combat_manager.combat_event_occurred.emit({
        "type": GameEnums.EventCategory.COMBAT,
        "source": "Test Unit",
        "target": "Enemy Unit",
        "details": {"damage": 5}
    })
    assert_signal_emitted(controller, "log_updated")
    assert_eq(controller.combat_log.size(), 1, "Should automatically log combat events")

func test_disable_auto_logging() -> void:
    controller.auto_logging = false
    mock_combat_manager.combat_event_occurred.emit({
        "type": GameEnums.EventCategory.COMBAT,
        "source": "Test Unit",
        "target": "Enemy Unit",
        "details": {"damage": 5}
    })
    assert_eq(controller.combat_log.size(), 0, "Should not log events when auto-logging is disabled")

func test_filter_events() -> void:
    var test_events = [
        {
            "type": GameEnums.EventCategory.COMBAT,
            "source": "Unit 1",
            "target": "Enemy 1",
            "details": {"damage": 3}
        },
        {
            "type": GameEnums.EventCategory.TACTICAL,
            "source": "Unit 1",
            "details": {"distance": 2}
        },
        {
            "type": GameEnums.EventCategory.COMBAT,
            "source": "Unit 2",
            "target": "Enemy 2",
            "details": {"damage": 4}
        }
    ]
    
    for event in test_events:
        controller.log_combat_event(event)
    
    var combat_events = controller.filter_events(GameEnums.EventCategory.COMBAT)
    assert_eq(combat_events.size(), 2, "Should filter combat events")
    assert_eq(combat_events[0].source, "Unit 1", "Should preserve event details")
    
    var tactical_events = controller.filter_events(GameEnums.EventCategory.TACTICAL)
    assert_eq(tactical_events.size(), 1, "Should filter tactical events")
    assert_eq(tactical_events[0].source, "Unit 1", "Should preserve event details")

func test_get_events_by_unit() -> void:
    var test_events = [
        {
            "type": GameEnums.EventCategory.COMBAT,
            "source": "Unit 1",
            "target": "Enemy 1",
            "details": {"damage": 3}
        },
        {
            "type": GameEnums.EventCategory.TACTICAL,
            "source": "Unit 1",
            "details": {"distance": 2}
        },
        {
            "type": GameEnums.EventCategory.COMBAT,
            "source": "Unit 2",
            "target": "Enemy 2",
            "details": {"damage": 4}
        }
    ]
    
    for event in test_events:
        controller.log_combat_event(event)
    
    var unit1_events = controller.get_events_by_unit("Unit 1")
    assert_eq(unit1_events.size(), 2, "Should get all events for Unit 1")
    
    var unit2_events = controller.get_events_by_unit("Unit 2")
    assert_eq(unit2_events.size(), 1, "Should get all events for Unit 2")