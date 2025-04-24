# This file should be referenced via preload
# Use explicit preloads instead of global class names
@tool
extends Control

## Error display component for visual error management
##
## Provides a UI for viewing, filtering, resolving, and exporting errors
## from the ErrorLogger system.

# Explicit script references with type annotations
const Self: GDScript = preload("res://src/ui/components/ErrorDisplay.gd")
const ErrorLogger: GDScript = preload("res://src/core/systems/ErrorLogger.gd")

# UI elements with type annotations
@onready var error_list: ItemList = $Panel/MarginContainer/VBoxContainer/Content/ErrorList if has_node("Panel/MarginContainer/VBoxContainer/Content/ErrorList") else null
@onready var error_details: RichTextLabel = $Panel/MarginContainer/VBoxContainer/Content/ErrorDetails if has_node("Panel/MarginContainer/VBoxContainer/Content/ErrorDetails") else null
@onready var category_filter: OptionButton = $Panel/MarginContainer/VBoxContainer/Filters/CategoryFilter if has_node("Panel/MarginContainer/VBoxContainer/Filters/CategoryFilter") else null
@onready var severity_filter: OptionButton = $Panel/MarginContainer/VBoxContainer/Filters/SeverityFilter if has_node("Panel/MarginContainer/VBoxContainer/Filters/SeverityFilter") else null
@onready var clear_resolved_button: Button = $Panel/MarginContainer/VBoxContainer/Actions/ClearResolved if has_node("Panel/MarginContainer/VBoxContainer/Actions/ClearResolved") else null
@onready var export_logs_button: Button = $Panel/MarginContainer/VBoxContainer/Actions/ExportLogs if has_node("Panel/MarginContainer/VBoxContainer/Actions/ExportLogs") else null

# State variables with type annotations
var error_logger: Node = null
var _selected_error_id: String = ""
var _current_filters: Dictionary = {
	"category": - 1, # All categories
	"severity": - 1, # All severities
	"show_resolved": false
}

# Signal for error updates
signal error_updated(error_data: Dictionary)

## Initialize the UI
func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	_setup_filters()
	_connect_signals()
	_refresh_error_list()

## Initialize with an error logger
## @param logger The error logger to use
func initialize(logger: Node) -> void:
	if not logger:
		push_error("Null logger provided to ErrorDisplay")
		return
		
	if not logger is ErrorLogger:
		push_error("Invalid logger type provided to ErrorDisplay")
		return
		
	error_logger = logger
	
	# Disconnect existing signals to avoid duplicates
	_disconnect_logger_signals()
	
	# Connect signals with proper error handling
	if error_logger.has_signal("error_logged"):
		var result = error_logger.connect("error_logged", Callable(self, "_on_error_logged"))
		if result != OK:
			push_error("Failed to connect error_logged signal")
	else:
		push_error("Logger does not have error_logged signal")
	
	if error_logger.has_signal("error_resolved"):
		var result = error_logger.connect("error_resolved", Callable(self, "_on_error_resolved"))
		if result != OK:
			push_error("Failed to connect error_resolved signal")
		
	if error_logger.has_signal("error_cleared"):
		var result = error_logger.connect("error_cleared", Callable(self, "_refresh_error_list"))
		if result != OK:
			push_error("Failed to connect error_cleared signal")
	
	# Initial refresh
	_refresh_error_list()

## Check if the object has the specified property
## @param property_name The name of the property to check
## @return Whether the property exists
func has_property(property_name: String) -> bool:
	# Check if the property is a recognized member variable
	if property_name == "error_list" or property_name == "error_details" or \
	   property_name == "category_filter" or property_name == "severity_filter" or \
	   property_name == "clear_resolved_button" or property_name == "export_logs_button" or \
	   property_name == "error_logger" or property_name == "_selected_error_id" or \
	   property_name == "_current_filters":
		return true
	
	# Check if it's a property defined via @export or in the class
	if property_name in self:
		return true
	
	# Check if the property exists as a node in our tree
	if has_node(property_name):
		return true
		
	return false

## Disconnect logger signals
func _disconnect_logger_signals() -> void:
	if not error_logger:
		return
		
	if error_logger.has_signal("error_logged") and error_logger.is_connected("error_logged", Callable(self, "_on_error_logged")):
		error_logger.disconnect("error_logged", Callable(self, "_on_error_logged"))
		
	if error_logger.has_signal("error_resolved") and error_logger.is_connected("error_resolved", Callable(self, "_on_error_resolved")):
		error_logger.disconnect("error_resolved", Callable(self, "_on_error_resolved"))
		
	if error_logger.has_signal("error_cleared") and error_logger.is_connected("error_cleared", Callable(self, "_refresh_error_list")):
		error_logger.disconnect("error_cleared", Callable(self, "_refresh_error_list"))

## Set up filter UI controls
func _setup_filters() -> void:
	if not category_filter or not severity_filter:
		push_warning("Filter controls not found in ErrorDisplay")
		return
		
	# Setup category filter
	category_filter.clear()
	category_filter.add_item("All Categories", -1)
	
	var categories = ErrorLogger.ErrorCategory
	for category in categories.values():
		if category >= 0 and category < categories.size():
			var category_name = categories.keys()[category]
			category_filter.add_item(category_name, category)
	
	# Setup severity filter
	severity_filter.clear()
	severity_filter.add_item("All Severities", -1)
	
	var severities = ErrorLogger.ErrorSeverity
	for severity in severities.values():
		if severity >= 0 and severity < severities.size():
			var severity_name = severities.keys()[severity]
			severity_filter.add_item(severity_name, severity)

## Connect UI control signals
func _connect_signals() -> void:
	# Check each control individually and show appropriate warning if missing
	if not error_list:
		push_warning("Error list not found in ErrorDisplay")
	else:
		# Disconnect existing signals first
		if error_list.is_connected("item_selected", Callable(self, "_on_error_selected")):
			error_list.disconnect("item_selected", Callable(self, "_on_error_selected"))
		# Connect signals
		error_list.item_selected.connect(_on_error_selected)
		
	if not category_filter:
		push_warning("Category filter not found in ErrorDisplay")
	else:
		if category_filter.is_connected("item_selected", Callable(self, "_on_category_filter_changed")):
			category_filter.disconnect("item_selected", Callable(self, "_on_category_filter_changed"))
		category_filter.item_selected.connect(_on_category_filter_changed)
		
	if not severity_filter:
		push_warning("Severity filter not found in ErrorDisplay")
	else:
		if severity_filter.is_connected("item_selected", Callable(self, "_on_severity_filter_changed")):
			severity_filter.disconnect("item_selected", Callable(self, "_on_severity_filter_changed"))
		severity_filter.item_selected.connect(_on_severity_filter_changed)
		
	if not clear_resolved_button:
		push_warning("Clear resolved button not found in ErrorDisplay")
	else:
		if clear_resolved_button.is_connected("pressed", Callable(self, "_on_clear_resolved_pressed")):
			clear_resolved_button.disconnect("pressed", Callable(self, "_on_clear_resolved_pressed"))
		clear_resolved_button.pressed.connect(_on_clear_resolved_pressed)
		
	if not export_logs_button:
		push_warning("Export logs button not found in ErrorDisplay")
	else:
		if export_logs_button.is_connected("pressed", Callable(self, "_on_export_logs_pressed")):
			export_logs_button.disconnect("pressed", Callable(self, "_on_export_logs_pressed"))
		export_logs_button.pressed.connect(_on_export_logs_pressed)

## Refresh the error list UI
func _refresh_error_list() -> void:
	if not error_logger:
		return
	
	# Try to refresh UI references if needed
	if not is_instance_valid(error_list):
		push_warning("Error list not found in ErrorDisplay._refresh_error_list")
		error_list = $Panel/MarginContainer/VBoxContainer/Content/ErrorList if has_node("Panel/MarginContainer/VBoxContainer/Content/ErrorList") else null
		if not is_instance_valid(error_list):
			push_error("Error list still not found after refresh attempt in ErrorDisplay._refresh_error_list")
			return
	
	error_list.clear()
	
	# Call the logger to get active errors
	var errors: Array = []
	if error_logger.has_method("get_active_errors"):
		errors = error_logger.get_active_errors()
	
	# Apply filters
	var filtered_errors = errors.filter(func(error: Dictionary) -> bool:
		if _current_filters.category != -1 and error.category != _current_filters.category:
			return false
		if _current_filters.severity != -1 and error.severity != _current_filters.severity:
			return false
		if not _current_filters.show_resolved and error.resolved:
			return false
		return true
	)
	
	# Sort by timestamp (newest first)
	filtered_errors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.timestamp > b.timestamp
	)
	
	# Add to list
	for error in filtered_errors:
		var severity_icon = _get_severity_icon(error.severity)
		var timestamp_part = _format_timestamp(error.timestamp)
		var error_text = "[%s] %s %s" % [timestamp_part, severity_icon, error.message]
		error_list.add_item(error_text)
		
		var idx = error_list.get_item_count() - 1
		error_list.set_item_metadata(idx, error.id)
		
		if error.resolved:
			error_list.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))

## Format a timestamp for display
## @param timestamp The timestamp to format
## @return The formatted timestamp
func _format_timestamp(timestamp: String) -> String:
	# If the timestamp contains a space, extract the time part
	if timestamp.contains(" "):
		return timestamp.split(" ")[1]
	return timestamp

## Get an icon for a severity level
## @param severity The severity level
## @return The icon string
func _get_severity_icon(severity: int) -> String:
	var severities = ErrorLogger.ErrorSeverity
	
	match severity:
		severities.INFO:
			return "ℹ"
		severities.WARNING:
			return "⚠"
		severities.ERROR:
			return "⛔"
		severities.CRITICAL:
			return "☠"
		_:
			return ""

## Update the error details panel
## @param error_id The error ID to show details for
func _update_error_details(error_id: String) -> void:
	if not error_logger or error_id.is_empty():
		if error_details:
			error_details.text = ""
		return
	
	# Find the error by ID in the active errors
	var error: Dictionary = {}
	var active_errors = error_logger.get_active_errors()
	
	for err in active_errors:
		if err.id == error_id:
			error = err
			break
	
	if error.is_empty():
		if error_details:
			error_details.text = ""
		return
	
	# Build the details text
	var details = "[b]Error Details:[/b]\n"
	details += "ID: %s\n" % error.id
	details += "Timestamp: %s\n" % error.timestamp
	
	var categories = ErrorLogger.ErrorCategory
	if error.category >= 0 and error.category < categories.size():
		details += "Category: %s\n" % categories.keys()[error.category]
	else:
		details += "Category: Unknown (%s)\n" % error.category
	
	var severities = ErrorLogger.ErrorSeverity
	if error.severity >= 0 and error.severity < severities.size():
		details += "Severity: %s\n" % severities.keys()[error.severity]
	else:
		details += "Severity: Unknown (%s)\n" % error.severity
		
	details += "Message: %s\n\n" % error.message
	
	if error.context and not error.context.is_empty():
		details += "[b]Context:[/b]\n"
		for key in error.context:
			details += "%s: %s\n" % [key, str(error.context[key])]
	
	if error.stack_trace and error.stack_trace.size() > 0:
		details += "\n[b]Stack Trace:[/b]\n"
		for frame in error.stack_trace:
			if frame is Dictionary:
				var source = frame.get("source", "Unknown")
				var line = frame.get("line", 0)
				var function = frame.get("function", "Unknown")
				details += "- %s:%d - %s\n" % [source, line, function]
			else:
				details += "- %s\n" % str(frame)
	
	if error.resolved:
		details += "\n[b]Resolution:[/b]\n"
		details += "Resolved at: %s\n" % error.resolution_timestamp
		if not error.resolution_notes.is_empty():
			details += "Notes: %s\n" % error.resolution_notes
	
	# Safely set the text property
	if error_details:
		error_details.text = details
	
	# Emit signal for test access
	error_updated.emit(error)

## Handler for error_logged signal
## @param error_data The error data
func _on_error_logged(error_data: Dictionary) -> void:
	if not is_instance_valid(error_list):
		push_warning("Error list is null in _on_error_logged")
		# Attempt to refresh error list reference
		error_list = $Panel/MarginContainer/VBoxContainer/Content/ErrorList if has_node("Panel/MarginContainer/VBoxContainer/Content/ErrorList") else null
		if not is_instance_valid(error_list):
			push_error("Error list is still null after refresh attempt in _on_error_logged")
			return
	
	_refresh_error_list()
	
	# Emit signal for test access, ensuring error_data is valid
	if error_data and error_data is Dictionary:
		error_updated.emit(error_data)

## Handler for error_resolved signal
## @param error_id The resolved error ID
func _on_error_resolved(error_id: String) -> void:
	_refresh_error_list()
	if _selected_error_id == error_id:
		_update_error_details(error_id)

## Handler for error_selected signal
## @param index The selected item index
func _on_error_selected(index: int) -> void:
	if not error_list:
		push_warning("Error list not found in ErrorDisplay._on_error_selected")
		return
		
	if index < 0 or index >= error_list.get_item_count():
		return
		
	_selected_error_id = error_list.get_item_metadata(index)
	_update_error_details(_selected_error_id)

## Handler for category_filter_changed signal
## @param index The selected category index
func _on_category_filter_changed(index: int) -> void:
	if not category_filter:
		push_warning("Category filter not found in ErrorDisplay._on_category_filter_changed")
		return
		
	if index < 0 or index >= category_filter.get_item_count():
		return
		
	_current_filters.category = category_filter.get_item_metadata(index)
	_refresh_error_list()

## Handler for severity_filter_changed signal
## @param index The selected severity index
func _on_severity_filter_changed(index: int) -> void:
	if not severity_filter:
		push_warning("Severity filter not found in ErrorDisplay._on_severity_filter_changed")
		return
		
	if index < 0 or index >= severity_filter.get_item_count():
		return
		
	_current_filters.severity = severity_filter.get_item_metadata(index)
	_refresh_error_list()

## Handler for clear_resolved_pressed signal
func _on_clear_resolved_pressed() -> void:
	if not error_logger:
		return
		
	if error_logger.has_method("clear_resolved_errors"):
		error_logger.clear_resolved_errors()
	
	_refresh_error_list()

## Handler for export_logs_pressed signal
func _on_export_logs_pressed() -> void:
	# TODO: Implement log export functionality
	pass

# Public methods for test access

## Get the current filters
## @return The current filters
func get_current_filters() -> Dictionary:
	return _current_filters.duplicate()

## Show error details for a specific error
## @param error_id The error ID
## @return Whether the error details were shown
func show_error_details(error_id: String) -> bool:
	if not error_logger or error_id.is_empty():
		return false
	
	_selected_error_id = error_id
	_update_error_details(error_id)
	return true

## Set whether to show resolved errors
## @param show Whether to show resolved errors
## @return Whether the setting was applied
func set_show_resolved(show: bool) -> bool:
	_current_filters.show_resolved = show
	_refresh_error_list()
	return true

## Set the category filter
## @param category The category to filter by
## @return Whether the filter was applied
func set_category_filter(category: int) -> bool:
	_current_filters.category = category
	_refresh_error_list()
	return true

## Set the severity filter
## @param severity The severity to filter by
## @return Whether the filter was applied
func set_severity_filter(severity: int) -> bool:
	_current_filters.severity = severity
	_refresh_error_list()
	return true

## Clear resolved errors
## @return Whether the errors were cleared
func clear_resolved_errors() -> bool:
	if not error_logger:
		return false
	
	if error_logger.has_method("clear_resolved_errors"):
		error_logger.clear_resolved_errors()
	
	_refresh_error_list()
	return true

## Get the severity icon for a given severity
## @param severity The severity level
## @return The icon string
func get_severity_icon(severity: int) -> String:
	return _get_severity_icon(severity)
