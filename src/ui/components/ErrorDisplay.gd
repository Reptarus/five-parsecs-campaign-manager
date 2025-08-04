class_name FPCM_ErrorDisplay
extends Control

const ErrorLogger = preload("res://src/core/systems/ErrorLogger.gd")

@onready var error_list: ItemList = get_node_or_null("ErrorList")
@onready var error_details: RichTextLabel = get_node_or_null("ErrorDetails")
@onready var category_filter: OptionButton = get_node_or_null("Filters/CategoryFilter")
@onready var severity_filter: OptionButton = get_node_or_null("Filters/SeverityFilter")
@onready var clear_resolved_button: Button = get_node_or_null("Actions/ClearResolved")
@onready var export_logs_button: Button = get_node_or_null("Actions/ExportLogs")

var error_logger: ErrorLogger
var _selected_error_id: String = ""
var _current_filters: Dictionary = {
	"category": - 1, # All categories
	"severity": - 1, # All severities
	"show_resolved": false
}

func _ready() -> void:
	if category_filter and severity_filter:
		_setup_filters()
	if error_list and error_details:
		_connect_signals()
		_refresh_error_list()
	else:
		push_warning("ErrorDisplay: Required UI nodes not found")
func initialize(logger: ErrorLogger) -> void:
	error_logger = logger
	error_logger.error_logged.connect(_on_error_logged)
	error_logger.error_resolved.connect(_on_error_resolved)
	_refresh_error_list()

func _setup_filters() -> void:
	if not category_filter or not severity_filter:
		return
	# Setup category filter
	category_filter.add_item("AllCategories", -1)
	for category in ErrorLogger.ErrorCategory.values():
		category_filter.add_item(ErrorLogger.ErrorCategory.keys()[category], category)

	# Setup severity filter
	severity_filter.add_item("AllSeverities", -1)
	for severity in ErrorLogger.ErrorSeverity.values():
		severity_filter.add_item(ErrorLogger.ErrorSeverity.keys()[severity], severity)

func _connect_signals() -> void:
	if error_list:
		error_list.item_selected.connect(_on_error_selected)
	if category_filter:
		category_filter.item_selected.connect(_on_category_filter_changed)
	if severity_filter:
		severity_filter.item_selected.connect(_on_severity_filter_changed)
	if clear_resolved_button:
		clear_resolved_button.pressed.connect(_on_clear_resolved_pressed)
	if export_logs_button:
		export_logs_button.pressed.connect(_on_export_logs_pressed)

func _refresh_error_list() -> void:
	if not error_logger or not error_list:
		return

	error_list.clear()
	var errors = error_logger.get_active_errors()

	# Apply filters
	errors = errors.filter(func(error: Dictionary) -> bool:
		if _current_filters.category != -1 and error.get("category", 0) != _current_filters.category:
			return false
		if _current_filters.severity != -1 and error.get("severity", 0) != _current_filters.severity:
			return false
		if not _current_filters.show_resolved and error.get("resolved", false):
			return false
		return true
	)

	# Sort by timestamp (newest first)
	errors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: 
		return a.get("timestamp", 0.0) > b.get("timestamp", 0.0))

	# Add to list
	for error: Dictionary in errors:
		var _severity_icon = _get_severity_icon(error.get("severity", 0))
		var timestamp_str: String = str(error.get("timestamp", "Unknown"))
		var error_text: String = "[%s] %s" % [timestamp_str, error.get("message", "No message")]
		error_list.add_item(error_text)

		var idx = error_list.get_item_count() - 1
		error_list.set_item_metadata(idx, error.get("id", ""))

		if error.get("resolved", false):
			error_list.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))

func _get_severity_icon(severity: ErrorLogger.ErrorSeverity) -> String:
	match severity:
		ErrorLogger.ErrorSeverity.INFO:
			return "ℹ"
		ErrorLogger.ErrorSeverity.WARNING:
			return "⚠"
		ErrorLogger.ErrorSeverity.ERROR:
			return "⛔"
		ErrorLogger.ErrorSeverity.CRITICAL:
			return "☠"
		_:
			return ""
func _update_error_details(error_id: String) -> void:
	if not error_logger or not error_id:
		error_details.text = ""
		return

	var error: Dictionary = error_logger._active_errors.get(error_id, {})
	if error.is_empty():
		error_details.text = ""
		return

	var details: String = "[b]Error Details:[/b]\n"
	details += "ID: %s\n" % error.get("_id", "Unknown")
	details += "Timestamp: %s\n" % error.get("timestamp", "Unknown")
	details += "Category: %s\n" % ErrorLogger.ErrorCategory.keys()[error.get("category", 0)]
	details += "Severity: %s\n" % ErrorLogger.ErrorSeverity.keys()[error.get("severity", 0)]
	details += "Message: %s\n\n" % error.get("message", "No message")

	var context: Dictionary = error.get("context", {})
	if not context.is_empty():
		details += "[b]Context:[/b]\n"
		for key in context:
			details += "%s: %s\n" % [key, str(context[key])]

	var stack_trace: Array = error.get("stack_trace", [])
	if not stack_trace.is_empty():
		details += "\n[b]Stack Trace:[/b]\n"
		for frame in stack_trace:
			if frame is Dictionary:
				details += "- %s:%d - %s\n" % [frame.get("source", "Unknown"), frame.get("line", 0), frame.get("function", "Unknown")]

	if error.get("resolved", false):
		details += "\n[b]Resolution:[/b]\n"
		details += "Resolved at: %s\n" % error.get("resolution_timestamp", "Unknown")
		var resolution_notes: String = error.get("resolution_notes", "")
		if not resolution_notes.is_empty():
			details += "Notes: %s\n" % resolution_notes

	error_details.text = details

func _on_error_logged(_error: Dictionary) -> void:
	_refresh_error_list()

func _on_error_resolved(_error_id: String) -> void:
	_refresh_error_list()
	if _selected_error_id == _error_id:
		_update_error_details(_error_id)

func _on_error_selected(index: int) -> void:
	_selected_error_id = error_list.get_item_metadata(index)
	_update_error_details(_selected_error_id)

func _on_category_filter_changed(index: int) -> void:
	_current_filters.category = category_filter.get_item_metadata(index)
	_refresh_error_list()

func _on_severity_filter_changed(index: int) -> void:
	_current_filters.severity = severity_filter.get_item_metadata(index)
	_refresh_error_list()

func _on_clear_resolved_pressed() -> void:
	error_logger.clear_resolved_errors()
	_refresh_error_list()

func _on_export_logs_pressed() -> void:
	# TODO: Implement log export functionality
	pass
