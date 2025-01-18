@tool
extends "res://tests/test_base.gd"

const CombatLogPanel := preload("res://src/ui/components/combat/log/combat_log_panel.tscn")
const TestHelper := preload("res://tests/fixtures/test_helper.gd")

var panel: Node

func before_each() -> void:
    super.before_each()
    panel = CombatLogPanel.instantiate()
    add_child(panel)

func after_each() -> void:
    super.after_each()
    panel = null

func test_initialization() -> void:
    assert_not_null(panel, "Combat log panel should be initialized")
    assert_true(panel.has_method("add_log_entry"), "Should have add_log_entry method")
    assert_true(panel.has_method("clear_log"), "Should have clear_log method")

func test_add_log_entry() -> void:
    var test_entry = {
        "type": GameEnums.EventCategory.COMBAT,
        "source": "Test Unit",
        "target": "Enemy Unit",
        "details": {
            "damage": 5,
            "hit_location": "Torso"
        }
    }
    panel.add_log_entry(test_entry)
    assert_eq(panel.log_entries.size(), 1, "Should add entry to log")
    assert_eq(panel.log_entries[0].type, GameEnums.EventCategory.COMBAT, "Should store entry type")

func test_add_multiple_entries() -> void:
    var test_entries = [
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
    
    for entry in test_entries:
        panel.add_log_entry(entry)
    
    assert_eq(panel.log_entries.size(), 2, "Should store multiple entries")
    assert_eq(panel.log_entries[0].type, GameEnums.EventCategory.COMBAT, "Should store first entry type")
    assert_eq(panel.log_entries[1].type, GameEnums.EventCategory.TACTICAL, "Should store second entry type")

func test_clear_log() -> void:
    var test_entry = {
        "type": GameEnums.EventCategory.COMBAT,
        "source": "Test Unit",
        "target": "Enemy Unit",
        "details": {"damage": 5}
    }
    panel.add_log_entry(test_entry)
    panel.clear_log()
    assert_eq(panel.log_entries.size(), 0, "Should clear log entries")

func test_filter_entries() -> void:
    var test_entries = [
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
    
    for entry in test_entries:
        panel.add_log_entry(entry)
    
    var combat_entries = panel.filter_entries(GameEnums.EventCategory.COMBAT)
    assert_eq(combat_entries.size(), 2, "Should filter combat entries")
    assert_eq(combat_entries[0].source, "Unit 1", "Should preserve entry details")
    
    var tactical_entries = panel.filter_entries(GameEnums.EventCategory.TACTICAL)
    assert_eq(tactical_entries.size(), 1, "Should filter tactical entries")
    assert_eq(tactical_entries[0].source, "Unit 1", "Should preserve entry details")

func test_get_entries_by_unit() -> void:
    var test_entries = [
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
    
    for entry in test_entries:
        panel.add_log_entry(entry)
    
    var unit1_entries = panel.get_entries_by_unit("Unit 1")
    assert_eq(unit1_entries.size(), 2, "Should get all entries for Unit 1")
    
    var unit2_entries = panel.get_entries_by_unit("Unit 2")
    assert_eq(unit2_entries.size(), 1, "Should get all entries for Unit 2")

func test_auto_scroll() -> void:
    panel.auto_scroll = true
    var test_entry = {
        "type": GameEnums.EventCategory.COMBAT,
        "source": "Test Unit",
        "target": "Enemy Unit",
        "details": {"damage": 5}
    }
    panel.add_log_entry(test_entry)
    assert_true(panel.is_scrolled_to_bottom(), "Should auto-scroll to bottom")

func test_disable_auto_scroll() -> void:
    panel.auto_scroll = false
    var test_entry = {
        "type": GameEnums.EventCategory.COMBAT,
        "source": "Test Unit",
        "target": "Enemy Unit",
        "details": {"damage": 5}
    }
    panel.add_log_entry(test_entry)
    assert_false(panel.is_scrolled_to_bottom(), "Should not auto-scroll when disabled")

func test_max_entries() -> void:
    panel.max_entries = 2
    var test_entries = [
        {
            "type": GameEnums.EventCategory.COMBAT,
            "source": "Unit 1",
            "details": {"damage": 3}
        },
        {
            "type": GameEnums.EventCategory.COMBAT,
            "source": "Unit 2",
            "details": {"damage": 4}
        },
        {
            "type": GameEnums.EventCategory.COMBAT,
            "source": "Unit 3",
            "details": {"damage": 5}
        }
    ]
    
    for entry in test_entries:
        panel.add_log_entry(entry)
    
    assert_eq(panel.log_entries.size(), 2, "Should maintain max entries limit")
    assert_eq(panel.log_entries[0].source, "Unit 2", "Should remove oldest entry")
    assert_eq(panel.log_entries[1].source, "Unit 3", "Should keep newest entry")