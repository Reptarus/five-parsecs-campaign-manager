@tool
extends "res://tests/unit/ui/base/component_test_base.gd"

const GUT_TIMEOUT := 5.0
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
	error_logger = ErrorLogger.new()
	add_child(error_logger)
	track_test_node(error_logger)
	_component.initialize(error_logger)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	await super.after_each()
	error_logger = null
	error_updated_signal_emitted = false
	last_error_data.clear()

func _reset_signals() -> void:
	error_updated_signal_emitted = false
	last_error_data = {}

func _connect_signals() -> void:
	if not _component:
		push_error("Cannot connect signals: component is null")
		return
		
	if _component.has_signal("error_updated"):
		var err := _component.connect("error_updated", _on_error_updated)
		if err != OK:
			push_error("Failed to connect error_updated signal")

func _on_error_updated(error_data: Dictionary) -> void:
	error_updated_signal_emitted = true
	last_error_data = error_data

func test_initial_setup() -> void:
	assert_not_null(_component, "Error display should be initialized")
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
	var test_error_message: String = "Test error message"
	var test_context: Dictionary = {"test": "context"}
	
	TypeSafeMixin._call_node_method_bool(
		error_logger,
		"log_error",
		[test_error_message, ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR, test_context]
	)
	
	await get_tree().process_frame
	
	# Verify error appears in list
	var item_count: int = TypeSafeMixin._call_node_method_int(_component.error_list, "get_item_count", [])
	assert_eq(item_count, 1, "Should have one error in list")
	
	var error_text: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_component.error_list, "get_item_text", [0]))
	assert_true(error_text.contains(test_error_message), "Error text should contain message")

func test_error_filtering() -> void:
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
	
	var filtered_count: int = TypeSafeMixin._call_node_method_int(_component.error_list, "get_item_count", [])
	assert_eq(filtered_count, 1, "Should show only validation errors")
	
	# Test severity filter
	TypeSafeMixin._call_node_method_bool(_component, "set_category_filter", [-1]) # Reset category filter
	TypeSafeMixin._call_node_method_bool(_component, "set_severity_filter", [ErrorLogger.ErrorSeverity.WARNING])
	await get_tree().process_frame
	
	filtered_count = TypeSafeMixin._call_node_method_int(_component.error_list, "get_item_count", [])
	assert_eq(filtered_count, 1, "Should show only warnings")

func test_error_resolution() -> void:
	TypeSafeMixin._call_node_method_bool(
		error_logger,
		"log_error",
		["Test error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR]
	)
	
	await get_tree().process_frame
	
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
	var test_message: String = "Test error message"
	var test_context: Dictionary = {"key": "value"}
	
	TypeSafeMixin._call_node_method_bool(
		error_logger,
		"log_error",
		[test_message, ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR, test_context]
	)
	
	await get_tree().process_frame
	
	TypeSafeMixin._call_node_method_bool(_component, "show_error_details", ["test_error"])
	
	var details_text: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_component.error_details, "get_text", []))
	assert_true(details_text.contains(test_message), "Details should contain error message")
	assert_true(details_text.contains("VALIDATION"), "Details should contain category")
	assert_true(details_text.contains("ERROR"), "Details should contain severity")
	assert_true(details_text.contains("key: value"), "Details should contain context")

func test_clear_resolved() -> void:
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
	
	var initial_count: int = TypeSafeMixin._call_node_method_int(_component.error_list, "get_item_count", [])
	assert_eq(initial_count, 2, "Should show all errors")
	
	TypeSafeMixin._call_node_method_bool(_component, "clear_resolved_errors", [])
	await get_tree().process_frame
	
	var final_count: int = TypeSafeMixin._call_node_method_int(_component.error_list, "get_item_count", [])
	assert_eq(final_count, 1, "Should remove resolved errors")

func test_severity_icon() -> void:
	var severities: Dictionary = {
		ErrorLogger.ErrorSeverity.INFO: "ℹ",
		ErrorLogger.ErrorSeverity.WARNING: "⚠",
		ErrorLogger.ErrorSeverity.ERROR: "⛔",
		ErrorLogger.ErrorSeverity.CRITICAL: "☠"
	}
	
	for severity in severities:
		var icon: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_component, "get_severity_icon", [severity]))
		assert_eq(icon, severities[severity], "Should return correct severity icon")

func test_error_sorting() -> void:
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
	
	var first_error_text: String = TypeSafeMixin._safe_cast_to_string(TypeSafeMixin._call_node_method(_component.error_list, "get_item_text", [0]))
	assert_true(first_error_text.contains("New error"), "Should show newest error first")