@tool
extends GameTest

const TestedClass: PackedScene = preload("res://src/ui/components/character/CharacterBox.tscn")

var _instance: Control
var _progression_updated_signal_emitted := false
var _last_progression_data: Dictionary = {}

func before_each() -> void:
	await super.before_each()
	_instance = TestedClass.instantiate()
	add_child_autofree(_instance)
	track_test_node(_instance)
	_connect_signals()
	_reset_signals()

func after_each() -> void:
	_disconnect_signals()
	_reset_signals()
	await super.after_each()
	_instance = null

func _connect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("progression_updated"):
		_instance.connect("progression_updated", _on_progression_updated)

func _disconnect_signals() -> void:
	if not _instance:
		return
		
	if _instance.has_signal("progression_updated") and _instance.is_connected("progression_updated", _on_progression_updated):
		_instance.disconnect("progression_updated", _on_progression_updated)

func _reset_signals() -> void:
	_progression_updated_signal_emitted = false
	_last_progression_data = {}

func _on_progression_updated(data: Dictionary = {}) -> void:
	_progression_updated_signal_emitted = true
	_last_progression_data = data

# Test Cases
func test_initial_state() -> void:
	assert_not_null(_instance, "Progression panel should be initialized")
	assert_false(_instance.visible, "Panel should be hidden by default")

func test_progression_update() -> void:
	_instance.visible = true
	var test_data := {"level": 2, "experience": 100}
	_instance.emit_signal("progression_updated", test_data)
	
	assert_true(_progression_updated_signal_emitted, "Progression signal should be emitted")
	assert_eq(_last_progression_data, test_data, "Progression data should match test data")

func test_visibility() -> void:
	_instance.visible = false
	var test_data := {"level": 1}
	_instance.emit_signal("progression_updated", test_data)
	assert_false(_progression_updated_signal_emitted, "Progression signal should not be emitted when hidden")
	
	_instance.visible = true
	_instance.emit_signal("progression_updated", test_data)
	assert_true(_progression_updated_signal_emitted, "Progression signal should be emitted when visible")

func test_child_nodes() -> void:
	var container = _instance.get_node_or_null("Container")
	assert_not_null(container, "Panel should have a Container node")

func test_signals() -> void:
	watch_signals(_instance)
	_instance.emit_signal("progression_updated")
	verify_signal_emitted(_instance, "progression_updated")
	
	_instance.emit_signal("level_up")
	verify_signal_emitted(_instance, "level_up")

func test_state_updates() -> void:
	_instance.visible = false
	assert_false(_instance.visible, "Panel should be hidden after visibility update")
	
	_instance.visible = true
	assert_true(_instance.visible, "Panel should be visible after visibility update")
	
	var container = _instance.get_node_or_null("Container")
	if container:
		container.custom_minimum_size = Vector2(200, 300)
		assert_eq(container.custom_minimum_size, Vector2(200, 300), "Container should update minimum size")

func test_child_management() -> void:
	var container = _instance.get_node_or_null("Container")
	if container:
		var test_child = Button.new()
		container.add_child(test_child)
		assert_true(test_child in container.get_children(), "Container should manage child nodes")
		assert_true(test_child.get_parent() == container, "Child should have correct parent")
		test_child.queue_free()

func test_panel_initialization() -> void:
	assert_not_null(_instance)
	assert_true(_instance.is_inside_tree())

func test_panel_nodes() -> void:
	assert_not_null(_instance.get_node("VBoxContainer"))
	assert_not_null(_instance.get_node("VBoxContainer/LevelLabel"))
	assert_not_null(_instance.get_node("VBoxContainer/ExperienceBar"))
	assert_not_null(_instance.get_node("VBoxContainer/StatsContainer"))

func test_panel_properties() -> void:
	assert_eq(_instance.level, 1)
	assert_eq(_instance.experience, 0)
	assert_eq(_instance.experience_to_next_level, 100)

func test_experience_gain() -> void:
	_instance.add_experience(50)
	assert_eq(_instance.experience, 50)
	
	_instance.add_experience(60)
	assert_eq(_instance.level, 2)
	assert_eq(_instance.experience, 10)
	verify_signal_emitted(_instance, "level_up")

func test_stat_updates() -> void:
	var stats_container = _instance.get_node("VBoxContainer/StatsContainer")
	assert_not_null(stats_container)
	
	_instance.update_stats({"strength": 5, "agility": 3})
	var strength_label = stats_container.get_node("StrengthLabel")
	var agility_label = stats_container.get_node("AgilityLabel")
	
	assert_eq(strength_label.text, "Strength: 5")
	assert_eq(agility_label.text, "Agility: 3")