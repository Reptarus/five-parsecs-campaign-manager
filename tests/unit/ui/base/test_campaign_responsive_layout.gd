@tool
extends "res://tests/unit/ui/base/component_test_base.gd"

# Use explicit preloads instead of global class names
const CampaignResponsiveLayout: GDScript = preload("res://src/ui/components/base/CampaignResponsiveLayout.gd")
# TypeSafeMixin is already imported in the parent class

# Test variables with explicit types
var layout_changed_signal_emitted: bool = false
var last_layout: String = ""
# _test_nodes is already declared in the parent class

# Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	if not CampaignResponsiveLayout:
		push_error("CampaignResponsiveLayout script is null")
		return null
		
	var component = CampaignResponsiveLayout.new()
	if component:
		# Ensure the component has the needed structure for tests
		component.size = Vector2(100, 100) # Give it an initial size
	return component

func before_each() -> void:
	await super.before_each()
	
	# Create the component if not already created by parent
	if not is_instance_valid(_component):
		_component = _create_component_instance()
		if _component:
			add_child_autofree(_component)
			track_test_node(_component)
	
	_reset_signals()
	_connect_signals()
	await stabilize_engine()

func after_each() -> void:
	layout_changed_signal_emitted = false
	last_layout = ""
	await super.after_each()

func _reset_signals() -> void:
	layout_changed_signal_emitted = false
	last_layout = ""

func _connect_signals() -> void:
	if not is_instance_valid(_component):
		push_error("Cannot connect signals: component is null")
		return
		
	if _component.has_signal("layout_changed"):
		# Disconnect first to avoid duplicate connections
		if _component.layout_changed.is_connected(_on_layout_changed):
			_component.layout_changed.disconnect(_on_layout_changed)
		_component.layout_changed.connect(_on_layout_changed)

func _on_layout_changed(new_layout: String) -> void:
	layout_changed_signal_emitted = true
	last_layout = new_layout

func test_initial_setup() -> void:
	assert_not_null(_component, "Layout should be initialized")
	
	if not is_instance_valid(_component):
		pending("Test skipped - component is null or invalid")
		return
		
	assert_true(_component is Control, "Layout should be a Control node")
	assert_true(_component.size.x > 0, "Layout should have width")
	assert_true(_component.size.y > 0, "Layout should have height")

func test_layout_changes() -> void:
	if not is_instance_valid(_component):
		pending("Test skipped - component is null or invalid")
		return
	
	# Test phone layout
	_component.size = Vector2(360, 640)
	await get_tree().process_frame
	assert_true(layout_changed_signal_emitted, "Layout changed signal should be emitted")
	assert_eq(last_layout, "phone", "Layout should be phone")
	
	# Test tablet layout
	_component.size = Vector2(768, 1024)
	await get_tree().process_frame
	assert_eq(last_layout, "tablet", "Layout should be tablet")
	
	# Test desktop layout
	_component.size = Vector2(1920, 1080)
	await get_tree().process_frame
	assert_eq(last_layout, "desktop", "Layout should be desktop")

func test_orientation_changes() -> void:
	if not is_instance_valid(_component):
		pending("Test skipped - component is null or invalid")
		return
		
	if not _component.has_method("get_is_portrait"):
		pending("Test skipped - required methods missing")
		return
	
	# Test phone portrait
	_component.size = Vector2(360, 640)
	await get_tree().process_frame
	assert_true(TypeSafeMixin._call_node_method_bool(_component, "get_is_portrait", []), "Should be portrait")
	
	# Test phone landscape
	_component.size = Vector2(640, 360)
	await get_tree().process_frame
	assert_false(TypeSafeMixin._call_node_method_bool(_component, "get_is_portrait", []), "Should be landscape")

func test_breakpoints() -> void:
	if not is_instance_valid(_component):
		pending("Test skipped - component is null or invalid")
		return
		
	if not _component.has_method("get_breakpoints"):
		pending("Test skipped - required methods missing")
		return
	
	var breakpoints: Dictionary = TypeSafeMixin._call_node_method_dict(_component, "get_breakpoints", [], {})
	assert_true(breakpoints.has("phone"), "Should have phone breakpoint")
	assert_true(breakpoints.has("tablet"), "Should have tablet breakpoint")
	assert_true(breakpoints.has("desktop"), "Should have desktop breakpoint")
	
	assert_true(breakpoints.phone > 0, "Phone breakpoint should be positive")
	assert_true(breakpoints.tablet > breakpoints.phone, "Tablet breakpoint should be larger than phone")
	assert_true(breakpoints.desktop > breakpoints.tablet, "Desktop breakpoint should be larger than tablet")

func test_layout_queries() -> void:
	if not is_instance_valid(_component):
		pending("Test skipped - component is null or invalid")
		return
		
	if not (_component.has_method("is_phone") and
		   _component.has_method("is_tablet") and
		   _component.has_method("is_desktop")):
		pending("Test skipped - required methods missing")
		return
	
	_component.size = Vector2(360, 640)
	await get_tree().process_frame
	
	assert_true(TypeSafeMixin._call_node_method_bool(_component, "is_phone", []), "Should be phone layout")
	assert_false(TypeSafeMixin._call_node_method_bool(_component, "is_tablet", []), "Should not be tablet layout")
	assert_false(TypeSafeMixin._call_node_method_bool(_component, "is_desktop", []), "Should not be desktop layout")

# Add inherited component tests
func test_component_structure() -> void:
	if not is_instance_valid(_component):
		pending("Test skipped - component is null or invalid")
		return
		
	await super.test_component_structure()
	
	# Additional CampaignResponsiveLayout-specific structure tests
	assert_true(_component.has_method("is_phone"), "Should have is_phone method")
	assert_true(_component.has_method("is_tablet"), "Should have is_tablet method")
	assert_true(_component.has_method("is_desktop"), "Should have is_desktop method")
	assert_true(_component.has_method("get_is_portrait"), "Should have get_is_portrait method")

func test_component_theme() -> void:
	if not is_instance_valid(_component):
		pending("Test skipped - component is null or invalid")
		return
		
	await super.test_component_theme()
	
	# Additional CampaignResponsiveLayout-specific theme tests
	if _component.has_method("has_theme_constant"):
		assert_true(_component.has_theme_constant("phone_breakpoint"), "Should have phone breakpoint constant")
		assert_true(_component.has_theme_constant("tablet_breakpoint"), "Should have tablet breakpoint constant")
		assert_true(_component.has_theme_constant("desktop_breakpoint"), "Should have desktop breakpoint constant")

func test_component_accessibility() -> void:
	if not is_instance_valid(_component):
		pending("Test skipped - component is null or invalid")
		return
		
	await super.test_component_accessibility()
	
	# Additional CampaignResponsiveLayout-specific accessibility tests
	assert_true(_component.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Should ignore mouse events as it's a layout container")
	assert_true(_component.clip_contents,
		"Should clip contents for better visual clarity")

# New methods for proper test resource management
func track_test_node(node: Node) -> void:
	if not node:
		push_error("Cannot track null node")
		return
	
	if not _test_nodes.has(node):
		_test_nodes.append(node)

func _cleanup_test_resources() -> void:
	for i in range(_test_nodes.size() - 1, -1, -1):
		var node: Node = _test_nodes[i]
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
		_test_nodes.remove_at(i)

# This method is similar to the one in game_test.gd
func add_child_autofree(node: Node, call_ready: bool = true) -> void:
	if not node:
		push_error("Cannot add null node")
		return
	
	if node.get_parent() != null:
		push_warning("Node '%s' already has a parent '%s'. Removing from current parent before adding." % [node.name, node.get_parent().name])
		node.get_parent().remove_child(node)
	
	add_child(node, call_ready)
	track_test_node(node) # Ensure the node gets freed during cleanup
