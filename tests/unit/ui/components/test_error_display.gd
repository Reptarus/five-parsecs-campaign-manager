@tool
extends "res://addons/gut/test.gd"

const GUT_TIMEOUT := 5.0
const TypeSafeMixin = preload("res://tests/fixtures/type_safe_test_mixin.gd")
const TestHelper = preload("res://tests/fixtures/test_helper.gd")
const ErrorDisplay: GDScript = preload("res://src/ui/components/ErrorDisplay.gd")
const ErrorLogger: GDScript = preload("res://src/core/systems/ErrorLogger.gd")

# Test variables with explicit types
var error_display: Node = null
var error_logger: Node = null
var error_updated_signal_emitted: bool = false
var last_error_data: Dictionary = {}

func before_each() -> void:
	await super.before_each()
	error_display = ErrorDisplay.new()
	error_logger = ErrorLogger.new()
	add_child(error_display)
	add_child(error_logger)
	error_display.initialize(error_logger)
	_reset_signals()
	_connect_signals()

func after_each() -> void:
	await super.after_each()
	error_display = null
	error_logger = null
	error_updated_signal_emitted = false
	last_error_data.clear()

func _reset_signals() -> void:
	error_updated_signal_emitted = false
	last_error_data = {}

func _connect_signals() -> void:
	if not error_display:
		push_error("Cannot connect signals: error display is null")
		return
		
	if error_display.has_signal("error_updated"):
		var err := error_display.connect("error_updated", _on_error_updated)
		if err != OK:
			push_error("Failed to connect error_updated signal")

func _on_error_updated(error_data: Dictionary) -> void:
	error_updated_signal_emitted = true
	last_error_data = error_data

func test_initial_setup() -> void:
	assert_not_null(error_display, "Error display should be initialized")
	assert_not_null(error_display.error_list, "Error list should exist")
	assert_not_null(error_display.error_details, "Error details should exist")
	assert_not_null(error_display.category_filter, "Category filter should exist")
	assert_not_null(error_display.severity_filter, "Severity filter should exist")
	assert_not_null(error_display.clear_resolved_button, "Clear resolved button should exist")
	assert_not_null(error_display.export_logs_button, "Export logs button should exist")
	
	# Check filter initialization
	var filters: Dictionary = TypeSafeMixin._safe_method_call_dict(error_display, "get_current_filters", [], {})
	assert_eq(filters.get("category", 0), -1, "Category filter should start at -1")
	assert_eq(filters.get("severity", 0), -1, "Severity filter should start at -1")
	assert_false(filters.get("show_resolved", true), "Show resolved should start false")

func test_error_logging() -> void:
	var test_error_message: String = "Test error message"
	var test_context: Dictionary = {"test": "context"}
	
	TypeSafeMixin._safe_method_call_bool(
		error_logger,
		"log_error",
		[test_error_message, ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR, test_context]
	)
	
	await get_tree().process_frame
	
	# Verify error appears in list
	var item_count: int = TypeSafeMixin._safe_method_call_int(error_display.error_list, "get_item_count", [], 0)
	assert_eq(item_count, 1, "Should have one error in list")
	
	var error_text: String = TypeSafeMixin._safe_method_call_string(error_display.error_list, "get_item_text", [0], "")
	assert_true(error_text.contains(test_error_message), "Error text should contain message")

func test_error_filtering() -> void:
	# Add errors with different categories and severities
	TypeSafeMixin._safe_method_call_bool(
		error_logger,
		"log_error",
		["System error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR]
	)
	
	TypeSafeMixin._safe_method_call_bool(
		error_logger,
		"log_error",
		["Network warning", ErrorLogger.ErrorCategory.NETWORK, ErrorLogger.ErrorSeverity.WARNING]
	)
	
	await get_tree().process_frame
	
	# Test category filter
	TypeSafeMixin._safe_method_call_bool(error_display, "set_category_filter", [ErrorLogger.ErrorCategory.VALIDATION])
	await get_tree().process_frame
	
	var filtered_count: int = TypeSafeMixin._safe_method_call_int(error_display.error_list, "get_item_count", [], 0)
	assert_eq(filtered_count, 1, "Should show only validation errors")
	
	# Test severity filter
	TypeSafeMixin._safe_method_call_bool(error_display, "set_category_filter", [-1]) # Reset category filter
	TypeSafeMixin._safe_method_call_bool(error_display, "set_severity_filter", [ErrorLogger.ErrorSeverity.WARNING])
	await get_tree().process_frame
	
	filtered_count = TypeSafeMixin._safe_method_call_int(error_display.error_list, "get_item_count", [], 0)
	assert_eq(filtered_count, 1, "Should show only warnings")

func test_error_resolution() -> void:
	TypeSafeMixin._safe_method_call_bool(
		error_logger,
		"log_error",
		["Test error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR]
	)
	
	await get_tree().process_frame
	
	var initial_count: int = TypeSafeMixin._safe_method_call_int(error_display.error_list, "get_item_count", [], 0)
	assert_eq(initial_count, 1, "Should start with one error")
	
	TypeSafeMixin._safe_method_call_bool(error_logger, "resolve_error", ["test_error", "Fixed"])
	TypeSafeMixin._safe_method_call_bool(error_display, "set_show_resolved", [false])
	await get_tree().process_frame
	
	var hidden_count: int = TypeSafeMixin._safe_method_call_int(error_display.error_list, "get_item_count", [], 0)
	assert_eq(hidden_count, 0, "Should hide resolved errors")
	
	TypeSafeMixin._safe_method_call_bool(error_display, "set_show_resolved", [true])
	await get_tree().process_frame
	
	var shown_count: int = TypeSafeMixin._safe_method_call_int(error_display.error_list, "get_item_count", [], 0)
	assert_eq(shown_count, 1, "Should show resolved errors")

func test_error_details() -> void:
	var test_message: String = "Test error message"
	var test_context: Dictionary = {"key": "value"}
	
	TypeSafeMixin._safe_method_call_bool(
		error_logger,
		"log_error",
		[test_message, ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR, test_context]
	)
	
	await get_tree().process_frame
	
	TypeSafeMixin._safe_method_call_bool(error_display, "show_error_details", ["test_error"])
	
	var details_text: String = TypeSafeMixin._safe_method_call_string(error_display.error_details, "get_text", [], "")
	assert_true(details_text.contains(test_message), "Details should contain error message")
	assert_true(details_text.contains("VALIDATION"), "Details should contain category")
	assert_true(details_text.contains("ERROR"), "Details should contain severity")
	assert_true(details_text.contains("key: value"), "Details should contain context")

func test_clear_resolved() -> void:
	TypeSafeMixin._safe_method_call_bool(
		error_logger,
		"log_error",
		["Error 1", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR]
	)
	
	TypeSafeMixin._safe_method_call_bool(
		error_logger,
		"log_error",
		["Error 2", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR]
	)
	
	await get_tree().process_frame
	
	TypeSafeMixin._safe_method_call_bool(error_logger, "resolve_error", ["error1", "Fixed"])
	TypeSafeMixin._safe_method_call_bool(error_display, "set_show_resolved", [true])
	await get_tree().process_frame
	
	var initial_count: int = TypeSafeMixin._safe_method_call_int(error_display.error_list, "get_item_count", [], 0)
	assert_eq(initial_count, 2, "Should show all errors")
	
	TypeSafeMixin._safe_method_call_bool(error_display, "clear_resolved_errors", [])
	await get_tree().process_frame
	
	var final_count: int = TypeSafeMixin._safe_method_call_int(error_display.error_list, "get_item_count", [], 0)
	assert_eq(final_count, 1, "Should remove resolved errors")

func test_severity_icon() -> void:
	var severities: Dictionary = {
		ErrorLogger.ErrorSeverity.INFO: "ℹ",
		ErrorLogger.ErrorSeverity.WARNING: "⚠",
		ErrorLogger.ErrorSeverity.ERROR: "⛔",
		ErrorLogger.ErrorSeverity.CRITICAL: "☠"
	}
	
	for severity in severities:
		var icon: String = TypeSafeMixin._safe_method_call_string(error_display, "get_severity_icon", [severity], "")
		assert_eq(icon, severities[severity], "Should return correct severity icon")

func test_error_sorting() -> void:
	TypeSafeMixin._safe_method_call_bool(
		error_logger,
		"log_error",
		["Old error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR]
	)
	
	TypeSafeMixin._safe_method_call_bool(
		error_logger,
		"log_error",
		["New error", ErrorLogger.ErrorCategory.VALIDATION, ErrorLogger.ErrorSeverity.ERROR]
	)
	
	await get_tree().process_frame
	
	var first_error_text: String = TypeSafeMixin._safe_method_call_string(error_display.error_list, "get_item_text", [0], "")
	assert_true(first_error_text.contains("New error"), "Should show newest error first")