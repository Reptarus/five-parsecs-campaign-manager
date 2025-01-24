extends "res://addons/gut/test.gd"

const ErrorDisplay = preload("res://src/ui/components/ErrorDisplay.gd")
const ErrorLogger = preload("res://src/core/systems/ErrorLogger.gd")

var error_display: ErrorDisplay
var error_logger: ErrorLogger

func before_each() -> void:
	error_logger = ErrorLogger.new()
	error_display = ErrorDisplay.new()
	add_child(error_display)
	error_display.initialize(error_logger)

func after_each() -> void:
	error_display.queue_free()
	error_logger.queue_free()

func test_initial_setup() -> void:
	assert_not_null(error_display)
	assert_not_null(error_display.error_list)
	assert_not_null(error_display.error_details)
	assert_not_null(error_display.category_filter)
	assert_not_null(error_display.severity_filter)
	assert_not_null(error_display.clear_resolved_button)
	assert_not_null(error_display.export_logs_button)
	
	# Check filter initialization
	assert_eq(error_display._current_filters.category, -1)
	assert_eq(error_display._current_filters.severity, -1)
	assert_false(error_display._current_filters.show_resolved)

func test_error_logging() -> void:
	var test_error_message = "Test error message"
	var test_context = {"test": "context"}
	
	error_logger.log_error(
		test_error_message,
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.ERROR,
		test_context
	)
	
	# Verify error appears in list
	assert_eq(error_display.error_list.get_item_count(), 1)
	var error_text = error_display.error_list.get_item_text(0)
	assert_true(error_text.contains(test_error_message))

func test_error_filtering() -> void:
	# Add errors with different categories and severities
	error_logger.log_error(
		"System error",
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.ERROR
	)
	error_logger.log_error(
		"Network warning",
		ErrorLogger.ErrorCategory.NETWORK,
		ErrorLogger.ErrorSeverity.WARNING
	)
	
	# Test category filter
	error_display._current_filters.category = ErrorLogger.ErrorCategory.VALIDATION
	error_display._refresh_error_list()
	assert_eq(error_display.error_list.get_item_count(), 1)
	
	# Test severity filter
	error_display._current_filters.category = -1 # Reset category filter
	error_display._current_filters.severity = ErrorLogger.ErrorSeverity.WARNING
	error_display._refresh_error_list()
	assert_eq(error_display.error_list.get_item_count(), 1)

func test_error_resolution() -> void:
	error_logger.log_error(
		"Test error",
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.ERROR
	)
	assert_eq(error_display.error_list.get_item_count(), 1)
	
	error_logger.resolve_error("test_error", "Fixed")
	error_display._current_filters.show_resolved = false
	error_display._refresh_error_list()
	assert_eq(error_display.error_list.get_item_count(), 0)
	
	error_display._current_filters.show_resolved = true
	error_display._refresh_error_list()
	assert_eq(error_display.error_list.get_item_count(), 1)

func test_error_details() -> void:
	var test_message = "Test error message"
	var test_context = {"key": "value"}
	
	error_logger.log_error(
		test_message,
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.ERROR,
		test_context
	)
	
	error_display._update_error_details("test_error")
	
	var details_text = error_display.error_details.text
	assert_true(details_text.contains(test_message))
	assert_true(details_text.contains("VALIDATION"))
	assert_true(details_text.contains("ERROR"))
	assert_true(details_text.contains("key: value"))

func test_clear_resolved() -> void:
	error_logger.log_error(
		"Error 1",
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.ERROR
	)
	error_logger.log_error(
		"Error 2",
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.ERROR
	)
	
	error_logger.resolve_error("error1", "Fixed")
	error_display._current_filters.show_resolved = true
	error_display._refresh_error_list()
	assert_eq(error_display.error_list.get_item_count(), 2)
	
	error_display._on_clear_resolved_pressed()
	assert_eq(error_display.error_list.get_item_count(), 1)

func test_severity_icon() -> void:
	var severities = {
		ErrorLogger.ErrorSeverity.INFO: "ℹ",
		ErrorLogger.ErrorSeverity.WARNING: "⚠",
		ErrorLogger.ErrorSeverity.ERROR: "⛔",
		ErrorLogger.ErrorSeverity.CRITICAL: "☠"
	}
	
	for severity in severities:
		var icon = error_display._get_severity_icon(severity)
		assert_eq(icon, severities[severity])

func test_error_sorting() -> void:
	error_logger.log_error(
		"Old error",
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.ERROR
	)
	error_logger.log_error(
		"New error",
		ErrorLogger.ErrorCategory.VALIDATION,
		ErrorLogger.ErrorSeverity.ERROR
	)
	
	error_display._refresh_error_list()
	
	# Verify newest error appears first
	var first_error_text = error_display.error_list.get_item_text(0)
	assert_true(first_error_text.contains("New error"))