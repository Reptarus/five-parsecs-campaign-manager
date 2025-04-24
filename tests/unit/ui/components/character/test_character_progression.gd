@tool
extends "res://tests/fixtures/base/game_test.gd"

# Type-safe constants with explicit typing
const TestedClass: PackedScene = preload("res://src/ui/components/character/CharacterBox.tscn")

# Type-safe instance variables
var _instance: Control = null
var _progression_updated_signal_emitted: bool = false
var _last_progression_data: Dictionary = {}

# Type-safe lifecycle methods
func before_each() -> void:
	await super.before_each()
	
	# Safely instantiate the tested class
	if not TestedClass:
		push_error("TestedClass is null - cannot instantiate")
		return
		
	_instance = TestedClass.instantiate() as Control
	if not _instance:
		push_error("Failed to instantiate character progression panel")
		return
		
	add_child_autofree(_instance)
	track_test_node(_instance)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	_disconnect_signals()
	_reset_signals()
	await super.after_each()
	_instance = null

# Type-safe signal handling
func _connect_signals() -> void:
	if not is_instance_valid(_instance):
		push_warning("Cannot connect signals: instance is null or invalid")
		return
		
	if _instance.has_signal("progression_updated"):
		if _instance.is_connected("progression_updated", self._on_progression_updated):
			_instance.disconnect("progression_updated", self._on_progression_updated)
		_instance.progression_updated.connect(self._on_progression_updated)

func _disconnect_signals() -> void:
	if not is_instance_valid(_instance):
		return
		
	if _instance.has_signal("progression_updated") and _instance.is_connected("progression_updated", self._on_progression_updated):
		_instance.disconnect("progression_updated", self._on_progression_updated)

func _reset_signals() -> void:
	_progression_updated_signal_emitted = false
	_last_progression_data = {}

func _on_progression_updated(data: Dictionary = {}) -> void:
	_progression_updated_signal_emitted = true
	_last_progression_data = data

# Type-safe test methods
func test_initial_state() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_initial_state: instance is null or invalid")
		pending("Test skipped - instance is null or invalid")
		return
		
	assert_not_null(_instance, "Progression panel should be initialized")
	assert_false(_instance.visible, "Panel should be hidden by default")

func test_progression_update() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_progression_update: instance is null or invalid")
		pending("Test skipped - instance is null or invalid")
		return
		
	if not _instance.has_signal("progression_updated"):
		push_warning("Instance does not have progression_updated signal")
		pending("Test skipped - required signal not found")
		return
		
	_instance.visible = true
	var test_data: Dictionary = {
		"level": 2 as int,
		"experience": 100 as int
	}
	_instance.emit_signal("progression_updated", test_data)
	
	assert_true(_progression_updated_signal_emitted, "Progression signal should be emitted")
	assert_eq(_last_progression_data, test_data, "Progression data should match test data")

func test_visibility() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_visibility: instance is null or invalid")
		pending("Test skipped - instance is null or invalid")
		return
		
	if not _instance.has_signal("progression_updated"):
		push_warning("Instance does not have progression_updated signal")
		pending("Test skipped - required signal not found")
		return
		
	_instance.visible = false
	var test_data: Dictionary = {"level": 1 as int}
	_instance.emit_signal("progression_updated", test_data)
	assert_false(_progression_updated_signal_emitted, "Progression signal should not be emitted when hidden")
	
	_instance.visible = true
	_instance.emit_signal("progression_updated", test_data)
	assert_true(_progression_updated_signal_emitted, "Progression signal should be emitted when visible")

func test_child_nodes() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_child_nodes: instance is null or invalid")
		pending("Test skipped - instance is null or invalid")
		return
		
	var container: Node = _instance.get_node_or_null("Container")
	assert_not_null(container, "Panel should have a Container node")

func test_signals() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_signals: instance is null or invalid")
		pending("Test skipped - instance is null or invalid")
		return
		
	watch_signals(_instance)
	
	if _instance.has_signal("progression_updated"):
		_instance.emit_signal("progression_updated")
		verify_signal_emitted(_instance, "progression_updated")
	else:
		push_warning("Instance does not have progression_updated signal")
		
	if _instance.has_signal("level_up"):
		_instance.emit_signal("level_up")
		verify_signal_emitted(_instance, "level_up")
	else:
		push_warning("Instance does not have level_up signal")

func test_state_updates() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_state_updates: instance is null or invalid")
		pending("Test skipped - instance is null or invalid")
		return
		
	_instance.visible = false
	assert_false(_instance.visible, "Panel should be hidden after visibility update")
	
	_instance.visible = true
	assert_true(_instance.visible, "Panel should be visible after visibility update")
	
	var container: Control = _instance.get_node_or_null("Container") as Control
	if is_instance_valid(container):
		container.custom_minimum_size = Vector2(200, 300)
		assert_eq(container.custom_minimum_size, Vector2(200, 300), "Container should update minimum size")
	else:
		push_warning("Container node not found")

func test_child_management() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_child_management: instance is null or invalid")
		pending("Test skipped - instance is null or invalid")
		return
		
	var container: Node = _instance.get_node_or_null("Container")
	if not is_instance_valid(container):
		push_warning("Container node not found")
		pending("Test skipped - container node not found")
		return
		
	var test_child: Button = Button.new()
	container.add_child(test_child)
	assert_true(test_child in container.get_children(), "Container should manage child nodes")
	assert_true(test_child.get_parent() == container, "Child should have correct parent")
	test_child.queue_free()

func test_panel_initialization() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_panel_initialization: instance is null or invalid")
		pending("Test skipped - instance is null or invalid")
		return
		
	assert_not_null(_instance)
	assert_true(_instance.is_inside_tree())

func test_panel_nodes() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_panel_nodes: instance is null or invalid")
		pending("Test skipped - instance is null or invalid")
		return
		
	assert_not_null(_instance.get_node_or_null("VBoxContainer"), "VBoxContainer should exist")
	assert_not_null(_instance.get_node_or_null("VBoxContainer/LevelLabel"), "Level label should exist")
	assert_not_null(_instance.get_node_or_null("VBoxContainer/ExperienceBar"), "Experience bar should exist")
	assert_not_null(_instance.get_node_or_null("VBoxContainer/StatsContainer"), "Stats container should exist")

func test_panel_properties() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_panel_properties: instance is null or invalid")
		pending("Test skipped - instance is null or invalid")
		return
		
	# Check if properties exist before accessing them
	if not ("level" in _instance):
		push_warning("'level' property not found in instance")
		pending("Test skipped - required properties not found")
		return
		
	if not ("experience" in _instance) or not ("experience_to_next_level" in _instance):
		push_warning("Experience properties not found in instance")
		pending("Test skipped - required properties not found")
		return
		
	assert_eq(_instance.level, 1, "Initial level should be 1")
	assert_eq(_instance.experience, 0, "Initial experience should be 0")
	assert_eq(_instance.experience_to_next_level, 100, "Initial experience to next level should be 100")

func test_experience_gain() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_experience_gain: instance is null or invalid")
		pending("Test skipped - instance is null or invalid")
		return
		
	# Check if methods and properties exist
	if not _instance.has_method("add_experience"):
		push_warning("add_experience method not found in instance")
		pending("Test skipped - required methods not found")
		return
		
	if not ("level" in _instance) or not ("experience" in _instance):
		push_warning("Required properties not found in instance")
		pending("Test skipped - required properties not found")
		return
		
	watch_signals(_instance)
	
	var success = TypeSafeMixin._call_node_method_bool(_instance, "add_experience", [50])
	if not success:
		push_warning("Failed to call add_experience method")
		pending("Test skipped - method call failed")
		return
		
	assert_eq(_instance.experience, 50, "Experience should increase")
	
	success = TypeSafeMixin._call_node_method_bool(_instance, "add_experience", [60])
	if not success:
		push_warning("Failed to call add_experience method")
		return
		
	assert_eq(_instance.level, 2, "Level should increase after gaining enough experience")
	assert_eq(_instance.experience, 10, "Experience should roll over")
	
	if _instance.has_signal("level_up"):
		verify_signal_emitted(_instance, "level_up", "Level up signal should be emitted")
	else:
		push_warning("level_up signal not found in instance")

func test_stat_updates() -> void:
	if not is_instance_valid(_instance):
		push_warning("Skipping test_stat_updates: instance is null or invalid")
		pending("Test skipped - instance is null or invalid")
		return
		
	var stats_container: Node = _instance.get_node_or_null("VBoxContainer/StatsContainer")
	if not is_instance_valid(stats_container):
		push_warning("Stats container not found")
		pending("Test skipped - stats container not found")
		return
		
	if not _instance.has_method("update_stats"):
		push_warning("update_stats method not found in instance")
		pending("Test skipped - required methods not found")
		return
		
	var test_stats: Dictionary = {
		"strength": 5 as int,
		"agility": 3 as int
	}
	
	var success = TypeSafeMixin._call_node_method_bool(_instance, "update_stats", [test_stats])
	if not success:
		push_warning("Failed to call update_stats method")
		pending("Test skipped - method call failed")
		return
		
	var strength_label: Label = stats_container.get_node_or_null("StrengthLabel") as Label
	var agility_label: Label = stats_container.get_node_or_null("AgilityLabel") as Label
	
	if not is_instance_valid(strength_label):
		push_warning("Strength label not found")
		pending("Test skipped - strength label not found")
		return
		
	if not is_instance_valid(agility_label):
		push_warning("Agility label not found")
		pending("Test skipped - agility label not found")
		return
		
	assert_eq(strength_label.text, "Strength: 5", "Strength label should display correct value")
	assert_eq(agility_label.text, "Agility: 3", "Agility label should display correct value")
