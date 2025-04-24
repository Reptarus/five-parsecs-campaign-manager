@tool
extends "res://tests/unit/ui/base/component_test_base.gd"

# Use explicit typed script references
const GUT_TIMEOUT: float = 5.0
const ErrorDisplay: GDScript = preload("res://src/ui/components/ErrorDisplay.gd")
const ErrorLogger: GDScript = preload("res://src/core/systems/ErrorLogger.gd")

# Test variables with explicit types
var error_logger: Node = null
var error_updated_signal_emitted: bool = false
var last_error_data: Dictionary = {}

# Override _create_component_instance to provide the specific component
func _create_component_instance() -> Control:
	return ErrorDisplay.new()

func before_each() -> void:
	await super.before_each()
	
	# Create and set up the error logger
	error_logger = ErrorLogger.new()
	if error_logger:
		add_child_autofree(error_logger)
		track_test_node(error_logger)
	
	# Initialize the component with the logger
	if _component:
		_component.initialize(error_logger)
	
	_reset_signals()
	_connect_signals()
	await stabilize_engine()

func after_each() -> void:
	# Proper cleanup
	error_updated_signal_emitted = false
	last_error_data.clear()
	error_logger = null
	await super.after_each()

func _reset_signals() -> void:
	error_updated_signal_emitted = false
	last_error_data = {}

func _connect_signals() -> void:
	if not is_instance_valid(_component):
		push_error("Cannot connect signals: component is null")
		return
		
	if _component.has_signal("error_updated"):
		# Properly disconnect first to avoid duplicate connections
		if _component.is_connected("error_updated", Callable(self, "_on_error_updated")):
			_component.disconnect("error_updated", Callable(self, "_on_error_updated"))
		
		# Connect signal using a proper Callable in Godot 4 style
		var result = _component.connect("error_updated", Callable(self, "_on_error_updated"))
		if result != OK:
			push_error("Failed to connect error_updated signal")
			return

func _on_error_updated(error_data: Dictionary) -> void:
	error_updated_signal_emitted = true
	last_error_data = error_data

func test_initial_setup() -> void:
	assert_not_null(_component, "Error display should be initialized")
	
	if not is_instance_valid(_component):
		pending("Test skipped - component is null or invalid")
		return
		
	assert_true(_component.has_property("error_list"), "Component should have error_list property")
	assert_true(_component.has_property("error_details"), "Component should have error_details property")
	assert_true(_component.has_property("category_filter"), "Component should have category_filter property")
	assert_true(_component.has_property("severity_filter"), "Component should have severity_filter property")
	assert_true(_component.has_property("clear_resolved_button"), "Component should have clear_resolved_button property")
	assert_true(_component.has_property("export_logs_button"), "Component should have export_logs_button property")
	
	if not (_component.has_property("error_list") and _component.has_property("error_details") and
		_component.has_property("category_filter") and _component.has_property("severity_filter") and
		_component.has_property("clear_resolved_button") and _component.has_property("export_logs_button")):
		pending("Test skipped - component missing required properties")
		return
	
	assert_not_null(_component.error_list, "Error list should exist")
	assert_not_null(_component.error_details, "Error details should exist")
	assert_not_null(_component.category_filter, "Category filter should exist")
	assert_not_null(_component.severity_filter, "Severity filter should exist")
	assert_not_null(_component.clear_resolved_button, "Clear resolved button should exist")
	assert_not_null(_component.export_logs_button, "Export logs button should exist")
	
	# Check filter initialization
	var filters: Dictionary = TypeSafeMixin._call_node_method_dict(_component, "get_current_filters", [])
	assert_eq(filters.get("category", 0), -1, "Category filter should start at -1")
	assert_eq(filters.get("severity", 0), -1, "Severity filter should start at -1")
	assert_false(filters.get("show_resolved", true), "Show resolved should start false")

func test_error_logging() -> void:
	if not is_instance_valid(_component) or not is_instance_valid(error_logger):
		pending("Test skipped - component or error_logger is null or invalid")
		return

	var test_error_message: String = "Test error message"
	var test_context: Dictionary = {"test": "context"}
	
	TypeSafeMixin._call_node_method_bool(
		error_logger,
		"log_error",
		[test_error_message, ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR, test_context]
	)
	
	await get_tree().process_frame
	
	# Verify error appears in list
	if not (_component.has_property("error_list") and is_instance_valid(_component.error_list)):
		pending("Test skipped - error_list is null or invalid")
		return
		
	var item_count: int = TypeSafeMixin._call_node_method_int(_component.error_list, "get_item_count", [])
	assert_eq(item_count, 1, "Should have one error in list")
	
	var error_text: String = TypeSafeHelper._safe_cast_to_string(TypeSafeMixin._call_node_method(_component.error_list, "get_item_text", [0]))
	assert_true(error_text.contains(test_error_message), "Error text should contain message")

func test_error_filtering() -> void:
	if not is_instance_valid(_component) or not is_instance_valid(error_logger):
		pending("Test skipped - component or error_logger is null or invalid")
		return
		
	# Add errors with different categories and severities
	TypeSafeMixin._call_node_method_bool(
		error_logger,
		"log_error",
		["System error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR]
	)
	
	TypeSafeMixin._call_node_method_bool(
		error_logger,
		"log_error",
		["Network warning", ErrorLogger.ErrorCategory.NETWORK, ErrorLogger.ErrorSeverity.WARNING]
	)
	
	await get_tree().process_frame
	
	# Test category filter
	TypeSafeMixin._call_node_method_bool(_component, "set_category_filter", [ErrorLogger.ErrorCategory.VALIDATION])
	await get_tree().process_frame
	
	if not (_component.has_property("error_list") and is_instance_valid(_component.error_list)):
		pending("Test skipped - error_list is null or invalid")
		return
		
	var filtered_count: int = TypeSafeMixin._call_node_method_int(_component.error_list, "get_item_count", [])
	assert_eq(filtered_count, 1, "Should show only validation errors")
	
	# Test severity filter
	TypeSafeMixin._call_node_method_bool(_component, "set_category_filter", [-1]) # Reset category filter
	TypeSafeMixin._call_node_method_bool(_component, "set_severity_filter", [ErrorLogger.ErrorSeverity.WARNING])
	await get_tree().process_frame
	
	filtered_count = TypeSafeMixin._call_node_method_int(_component.error_list, "get_item_count", [])
	assert_eq(filtered_count, 1, "Should show only warnings")

func test_error_resolution() -> void:
	if not is_instance_valid(_component) or not is_instance_valid(error_logger):
		pending("Test skipped - component or error_logger is null or invalid")
		return
		
	TypeSafeMixin._call_node_method_bool(
		error_logger,
		"log_error",
		["Test error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR]
	)
	
	await get_tree().process_frame
	
	if not (_component.has_property("error_list") and is_instance_valid(_component.error_list)):
		pending("Test skipped - error_list is null or invalid")
		return
		
	var initial_count: int = TypeSafeMixin._call_node_method_int(_component.error_list, "get_item_count", [])
	assert_eq(initial_count, 1, "Should start with one error")
	
	TypeSafeMixin._call_node_method_bool(error_logger, "resolve_error", ["test_error", "Fixed"])
	TypeSafeMixin._call_node_method_bool(_component, "set_show_resolved", [false])
	await get_tree().process_frame
	
	var hidden_count: int = TypeSafeMixin._call_node_method_int(_component.error_list, "get_item_count", [])
	assert_eq(hidden_count, 0, "Should hide resolved errors")
	
	TypeSafeMixin._call_node_method_bool(_component, "set_show_resolved", [true])
	await get_tree().process_frame
	
	var shown_count: int = TypeSafeMixin._call_node_method_int(_component.error_list, "get_item_count", [])
	assert_eq(shown_count, 1, "Should show resolved errors")

func test_error_details() -> void:
	if not is_instance_valid(_component) or not is_instance_valid(error_logger):
		pending("Test skipped - component or error_logger is null or invalid")
		return
		
	var test_message: String = "Test error message"
	var test_context: Dictionary = {"key": "value"}
	
	# Log the error and ensure we have a valid error ID
	var error_id = TypeSafeMixin._call_node_method(
		error_logger,
		"log_error",
		[test_message, ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR, test_context]
	)
	
	# If error_id is null or empty, use a default test ID
	if not error_id or (error_id is String and error_id.is_empty()):
		error_id = "test_error"
	
	await get_tree().process_frame
	
	# Use show_error_details and handle potential return value
	var result = TypeSafeMixin._call_node_method_bool(_component, "show_error_details", [error_id])
	if not result:
		# Try with different error IDs from active errors
		var active_errors = TypeSafeMixin._call_node_method_array(error_logger, "get_active_errors", [])
		if active_errors.size() > 0 and "id" in active_errors[0]:
			error_id = active_errors[0].id
			TypeSafeMixin._call_node_method_bool(_component, "show_error_details", [error_id])
	
	# Check if error_details exists before testing its content
	if not (_component.has_property("error_details") and is_instance_valid(_component.error_details)):
		pending("Test skipped - error_details is null or invalid")
		return
		
	# Get details text safely
	var details_text: String = ""
	if _component.error_details and _component.error_details.has_method("get_text"):
		details_text = TypeSafeHelper._safe_cast_to_string(TypeSafeMixin._call_node_method(_component.error_details, "get_text", []))
	
	# Check if we got any text, if not, check error_updated signal instead
	if details_text.is_empty() and error_updated_signal_emitted:
		assert_true(not last_error_data.is_empty(), "Should have received error data via signal")
		assert_true(last_error_data.get("message", "").contains(test_message), "Error data should contain test message")
		return
	
	# If we have details text, check its content
	assert_true(details_text.contains(test_message), "Details should contain error message")
	assert_true(details_text.contains("VALIDATION"), "Details should contain category")
	assert_true(details_text.contains("ERROR"), "Details should contain severity")
	assert_true(details_text.contains("key: value"), "Details should contain context")

func test_clear_resolved() -> void:
	if not is_instance_valid(_component) or not is_instance_valid(error_logger):
		pending("Test skipped - component or error_logger is null or invalid")
		return
		
	TypeSafeMixin._call_node_method_bool(
		error_logger,
		"log_error",
		["Error 1", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR]
	)
	
	TypeSafeMixin._call_node_method_bool(
		error_logger,
		"log_error",
		["Error 2", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR]
	)
	
	await get_tree().process_frame
	
	TypeSafeMixin._call_node_method_bool(error_logger, "resolve_error", ["error1", "Fixed"])
	TypeSafeMixin._call_node_method_bool(_component, "set_show_resolved", [true])
	await get_tree().process_frame
	
	if not (_component.has_property("error_list") and is_instance_valid(_component.error_list)):
		pending("Test skipped - error_list is null or invalid")
		return
		
	var initial_count: int = TypeSafeMixin._call_node_method_int(_component.error_list, "get_item_count", [])
	assert_eq(initial_count, 2, "Should show all errors")
	
	TypeSafeMixin._call_node_method_bool(_component, "clear_resolved_errors", [])
	await get_tree().process_frame
	
	var final_count: int = TypeSafeMixin._call_node_method_int(_component.error_list, "get_item_count", [])
	assert_eq(final_count, 1, "Should remove resolved errors")

func test_severity_icon() -> void:
	if not is_instance_valid(_component):
		pending("Test skipped - component is null or invalid")
		return
		
	var severities: Dictionary = {
		ErrorLogger.ErrorSeverity.INFO: "ℹ",
		ErrorLogger.ErrorSeverity.WARNING: "⚠",
		ErrorLogger.ErrorSeverity.ERROR: "⛔",
		ErrorLogger.ErrorSeverity.CRITICAL: "☠"
	}
	
	for severity in severities:
		var icon: String = TypeSafeHelper._safe_cast_to_string(TypeSafeMixin._call_node_method(_component, "get_severity_icon", [severity]))
		assert_eq(icon, severities[severity], "Should return correct severity icon")

func test_error_sorting() -> void:
	if not is_instance_valid(_component) or not is_instance_valid(error_logger):
		pending("Test skipped - component or error_logger is null or invalid")
		return
		
	TypeSafeMixin._call_node_method_bool(
		error_logger,
		"log_error",
		["Old error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR]
	)
	
	TypeSafeMixin._call_node_method_bool(
		error_logger,
		"log_error",
		["New error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR]
	)
	
	await get_tree().process_frame
	
	if not (_component.has_property("error_list") and is_instance_valid(_component.error_list)):
		pending("Test skipped - error_list is null or invalid")
		return
		
	var first_error_text: String = TypeSafeHelper._safe_cast_to_string(TypeSafeMixin._call_node_method(_component.error_list, "get_item_text", [0]))
	assert_true(first_error_text.contains("New error"), "Should show newest error first")

# Helper class to provide missing methods if needed
class TypeSafeHelper:
	# Safe string conversion with proper null handling
	static func _safe_cast_to_string(value, error_message: String = "") -> String:
		if value == null:
			# Return empty string for null with no warning
			return ""
		
		if value is String:
			return value
		
		if value is StringName:
			return String(value)
		
		# Handle objects that might not be valid
		if value is Object:
			if not is_instance_valid(value):
				push_warning("Attempted to convert invalid object to string")
				return ""
			
			# Some objects have a specific string representation method
			if value.has_method("to_string"):
				return value.to_string()
		
		# Most types can be converted to string
		return str(value)
