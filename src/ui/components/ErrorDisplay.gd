class_name ErrorDisplay
extends Control

const ErrorLogger = preload("res://src/core/systems/ErrorLogger.gd")

@onready var error_list: ItemList = $ErrorList
@onready var error_details: RichTextLabel = $ErrorDetails
@onready var category_filter: OptionButton = $Filters/CategoryFilter
@onready var severity_filter: OptionButton = $Filters/SeverityFilter
@onready var clear_resolved_button: Button = $Actions/ClearResolved
@onready var export_logs_button: Button = $Actions/ExportLogs

var error_logger: ErrorLogger
var _selected_error_id: String = ""
var _current_filters: Dictionary = {
    "category": - 1, # All categories
    "severity": - 1, # All severities
    "show_resolved": false
}

func _ready() -> void:
    _setup_filters()
    _connect_signals()
    _refresh_error_list()

func initialize(logger: ErrorLogger) -> void:
    error_logger = logger
    error_logger.error_logged.connect(_on_error_logged)
    error_logger.error_resolved.connect(_on_error_resolved)
    _refresh_error_list()

func _setup_filters() -> void:
    # Setup category filter
    category_filter.add_item("All Categories", -1)
    for category in ErrorLogger.ErrorCategory.values():
        category_filter.add_item(ErrorLogger.ErrorCategory.keys()[category], category)
    
    # Setup severity filter
    severity_filter.add_item("All Severities", -1)
    for severity in ErrorLogger.ErrorSeverity.values():
        severity_filter.add_item(ErrorLogger.ErrorSeverity.keys()[severity], severity)

func _connect_signals() -> void:
    error_list.item_selected.connect(_on_error_selected)
    category_filter.item_selected.connect(_on_category_filter_changed)
    severity_filter.item_selected.connect(_on_severity_filter_changed)
    clear_resolved_button.pressed.connect(_on_clear_resolved_pressed)
    export_logs_button.pressed.connect(_on_export_logs_pressed)

func _refresh_error_list() -> void:
    if not error_logger:
        return
    
    error_list.clear()
    var errors = error_logger.get_active_errors()
    
    # Apply filters
    errors = errors.filter(func(error: Dictionary) -> bool:
        if _current_filters.category != -1 and error.category != _current_filters.category:
            return false
        if _current_filters.severity != -1 and error.severity != _current_filters.severity:
            return false
        if not _current_filters.show_resolved and error.resolved:
            return false
        return true
    )
    
    # Sort by timestamp (newest first)
    errors.sort_custom(func(a, b): return a.timestamp > b.timestamp)
    
    # Add to list
    for error in errors:
        var severity_icon = _get_severity_icon(error.severity)
        var error_text = "[%s] %s" % [error.timestamp.split(" ")[1], error.message]
        error_list.add_item(error_text)
        
        var idx = error_list.get_item_count() - 1
        error_list.set_item_metadata(idx, error.id)
        
        if error.resolved:
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
    
    var error = error_logger._active_errors.get(error_id)
    if not error:
        error_details.text = ""
        return
    
    var details = "[b]Error Details:[/b]\n"
    details += "ID: %s\n" % error.id
    details += "Timestamp: %s\n" % error.timestamp
    details += "Category: %s\n" % ErrorLogger.ErrorCategory.keys()[error.category]
    details += "Severity: %s\n" % ErrorLogger.ErrorSeverity.keys()[error.severity]
    details += "Message: %s\n\n" % error.message
    
    if error.context:
        details += "[b]Context:[/b]\n"
        for key in error.context:
            details += "%s: %s\n" % [key, str(error.context[key])]
    
    if error.stack_trace:
        details += "\n[b]Stack Trace:[/b]\n"
        for frame in error.stack_trace:
            details += "- %s:%d - %s\n" % [frame.source, frame.line, frame.function]
    
    if error.resolved:
        details += "\n[b]Resolution:[/b]\n"
        details += "Resolved at: %s\n" % error.resolution_timestamp
        if error.resolution_notes:
            details += "Notes: %s\n" % error.resolution_notes
    
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