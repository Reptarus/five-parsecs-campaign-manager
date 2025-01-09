extends "res://addons/gut/test.gd"

var CombatLogController = preload("res://src/ui/components/combat/log/combat_log_controller.tscn")
var controller: Node
var mock_resolver: Node
var mock_manager: Node
var mock_override_ctrl: Node
var mock_rules_panel: Node

func before_each() -> void:
	controller = CombatLogController.instantiate()
	add_child_autofree(controller)
	
	mock_resolver = Node.new()
	mock_resolver.add_user_signal("dice_roll_requested")
	mock_resolver.add_user_signal("dice_roll_completed")
	mock_resolver.add_user_signal("override_requested")
	mock_resolver.add_user_signal("modifier_applied")
	
	mock_manager = Node.new()
	mock_manager.add_user_signal("combat_state_changed")
	mock_manager.add_user_signal("combat_action_completed")
	mock_manager.add_user_signal("critical_hit")
	
	mock_override_ctrl = Node.new()
	mock_override_ctrl.add_user_signal("override_applied")
	mock_override_ctrl.add_user_signal("override_cancelled")
	mock_override_ctrl.request_override = func(context: String, value: int): pass
	
	mock_rules_panel = Node.new()
	mock_rules_panel.add_user_signal("rule_added")
	mock_rules_panel.add_user_signal("rule_modified")
	mock_rules_panel.add_user_signal("rule_removed")
	
	controller.setup_combat_system(mock_resolver, mock_manager, mock_override_ctrl, mock_rules_panel)
	await get_tree().process_frame

func test_initial_state() -> void:
	assert_false(controller.combat_log.visible, "Combat log should start hidden")
	assert_eq(controller.active_filters.size(), 0, "Should start with no filters")

func test_log_combat_event() -> void:
	controller.log_combat_event("test", "Test message", {"key": "value"})
	assert_eq(controller.combat_log.log_entries.size(), 1, "Should add log entry")

func test_filter_events() -> void:
	controller.update_filters(["test"])
	
	controller.log_combat_event("test", "Test message")
	controller.log_combat_event("other", "Other message")
	
	assert_eq(controller.combat_log.log_entries.size(), 1, "Should only log filtered events")

func test_dice_roll_events() -> void:
	mock_resolver.emit_signal("dice_roll_requested", "attack", {"bonus": 2})
	assert_eq(controller.combat_log.log_entries.size(), 1, "Should log roll request")
	
	mock_resolver.emit_signal("dice_roll_completed", "attack", 6)
	assert_eq(controller.combat_log.log_entries.size(), 2, "Should log roll result")

func test_override_events() -> void:
	mock_resolver.emit_signal("override_requested", "attack", 3)
	assert_eq(controller.combat_log.log_entries.size(), 1, "Should log override request")
	
	mock_override_ctrl.emit_signal("override_applied", "attack", 4)
	assert_eq(controller.combat_log.log_entries.size(), 2, "Should log override application")
	
	mock_override_ctrl.emit_signal("override_cancelled", "attack")
	assert_eq(controller.combat_log.log_entries.size(), 3, "Should log override cancellation")

func test_combat_state_events() -> void:
	mock_manager.emit_signal("combat_state_changed", {"phase": "attack"})
	assert_eq(controller.combat_log.log_entries.size(), 1, "Should log state change")
	
	mock_manager.emit_signal("combat_action_completed", {"type": "attack"})
	assert_eq(controller.combat_log.log_entries.size(), 2, "Should log action completion")
	
	mock_manager.emit_signal("critical_hit", "Player", "Enemy", 2.0)
	assert_eq(controller.combat_log.log_entries.size(), 3, "Should log critical hit")

func test_house_rule_events() -> void:
	mock_rules_panel.emit_signal("rule_added", {"name": "Test Rule"})
	assert_eq(controller.combat_log.log_entries.size(), 1, "Should log rule addition")
	
	mock_rules_panel.emit_signal("rule_modified", {"name": "Test Rule"})
	assert_eq(controller.combat_log.log_entries.size(), 2, "Should log rule modification")
	
	mock_rules_panel.emit_signal("rule_removed", "test_rule")
	assert_eq(controller.combat_log.log_entries.size(), 3, "Should log rule removal")

func test_context_actions() -> void:
	watch_signals(controller)
	var test_entry = {"type": "roll", "details": {"context": "attack", "result": 4}}
	
	controller.handle_context_action("verify", test_entry)
	assert_signal_emitted(controller, "verification_requested")
	
	controller.handle_context_action("override", test_entry)
	# Should call request_override on mock_override_ctrl
	
	controller.handle_context_action("custom", test_entry)
	assert_signal_emitted(controller, "context_action_requested")

func test_export_log() -> void:
	controller.log_combat_event("test", "Test message")
	var exported = controller.export_log()
	
	assert_true(exported.has("timestamp"), "Should include timestamp")
	assert_true(exported.has("entries"), "Should include entries")
	assert_eq(exported.entries.size(), 1, "Should export all entries")

func test_clear_log() -> void:
	controller.log_combat_event("test", "Test message")
	controller.clear_log()
	
	assert_eq(controller.combat_log.log_entries.size(), 0, "Should clear all entries")