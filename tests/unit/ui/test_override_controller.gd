@tool
extends "res://tests/test_base.gd"

const OverrideController := preload("res://src/ui/components/combat/overrides/override_controller.tscn")

var controller: Node
var mock_resolver: Node
var mock_manager: Node

func before_each() -> void:
    super.before_each()
    controller = OverrideController.instantiate()
    
    mock_resolver = Node.new()
    mock_resolver.name = "OverrideResolver"
    mock_resolver.add_user_signal("override_requested")
    mock_resolver.add_user_signal("dice_roll_completed")
    mock_resolver.apply_override = func(context: String, value: int): pass
    
    mock_manager = Node.new()
    mock_manager.name = "CombatManager"
    mock_manager.add_user_signal("combat_state_changed")
    mock_manager.add_user_signal("override_validation_requested")
    mock_manager.get_current_state = func() -> Dictionary: return {}
    
    add_child(mock_resolver)
    add_child(mock_manager)
    add_child(controller)
    
    controller.setup_combat_system(mock_resolver, mock_manager)
    await get_tree().process_frame

func after_each() -> void:
    super.after_each()
    controller = null
    mock_resolver = null
    mock_manager = null

func test_initial_state() -> void:
    assert_eq(controller.active_context, "", "Active context should start empty")
    assert_false(controller.override_panel.visible, "Override panel should start hidden")

func test_request_override() -> void:
    controller.request_override("attack_roll", 3)
    
    assert_eq(controller.active_context, "attack_roll", "Active context should be set")
    assert_true(controller.override_panel.visible, "Override panel should be visible")

func test_override_applied() -> void:
    watch_signals(controller)
    controller.request_override("attack_roll", 3)
    
    controller.override_panel.override_value_spinbox.value = 4
    controller.override_panel._on_apply_pressed()
    
    assert_signal_emitted(controller, "override_applied")
    assert_eq(controller.active_context, "attack_roll", "Context should remain set until override is complete")
    assert_eq(controller.override_panel.override_value_spinbox.value, 4, "Override value should be updated")

func test_override_cancelled() -> void:
    watch_signals(controller)
    controller.request_override("attack_roll", 3)
    
    controller.override_panel._on_cancel_pressed()
    
    assert_signal_emitted(controller, "override_cancelled")
    assert_eq(controller.active_context, "", "Active context should be cleared")
    assert_false(controller.override_panel.visible, "Override panel should be hidden")

func test_combat_override_requested() -> void:
    watch_signals(controller)
    mock_resolver.emit_signal("override_requested", "attack_roll", 3)
    
    assert_eq(controller.active_context, "attack_roll", "Should handle combat override request")
    assert_true(controller.override_panel.visible, "Should show override panel")

func test_dice_roll_completed() -> void:
    controller.request_override("attack_roll", 3)
    mock_resolver.emit_signal("dice_roll_completed", "attack_roll", 4)
    
    assert_false(controller.override_panel.visible, "Should hide panel when roll completes")

func test_validate_override_attack() -> void:
    mock_manager.get_current_state = func() -> Dictionary: return {"attack_bonus": 2}
    
    assert_true(controller.validate_override("attack_roll", 8), "Should allow valid attack roll")
    assert_false(controller.validate_override("attack_roll", 9), "Should reject invalid attack roll")

func test_validate_override_damage() -> void:
    mock_manager.get_current_state = func() -> Dictionary: return {"weapon_damage": 3}
    
    assert_true(controller.validate_override("damage_roll", 6), "Should allow valid damage roll")
    assert_false(controller.validate_override("damage_roll", 7), "Should reject invalid damage roll")

func test_validate_override_defense() -> void:
    mock_manager.get_current_state = func() -> Dictionary: return {"defense_value": 2}
    
    assert_true(controller.validate_override("defense_roll", 8), "Should allow valid defense roll")
    assert_false(controller.validate_override("defense_roll", 9), "Should reject invalid defense roll")

func test_combat_state_changed() -> void:
    mock_manager.get_current_state = func() -> Dictionary: return {"attack_bonus": 1}
    controller.request_override("attack_roll", 3)
    controller.override_panel.override_value_spinbox.value = 8
    
    mock_manager.emit_signal("combat_state_changed", {"attack_bonus": 1})
    
    assert_false(controller.override_panel.visible, "Should hide panel when value becomes invalid")

func test_override_validation_requested() -> void:
    mock_manager.get_current_state = func() -> Dictionary: return {"attack_bonus": 2}
    
    var result = controller._on_override_validation_requested("attack_roll", 8)
    assert_true(result, "Should validate correct override value")
    
    result = controller._on_override_validation_requested("attack_roll", 9)
    assert_false(result, "Should reject incorrect override value")