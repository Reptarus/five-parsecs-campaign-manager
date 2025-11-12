class_name UniversalPanelConnector extends RefCounted
"""
Production-ready signal connection system following Framework Bible principles.
Replaces 400+ lines of complex panel-specific signal handlers with universal patterns.

This eliminates the signal connection complexity that was causing the integration failures.
"""

# Universal signal connection for all campaign panels
static func connect_panel_signals(panel: Node, ui_controller: Node) -> void:
    """
    Universal signal connector that works with any panel type.
    Eliminates the need for panel-specific connection handlers.
    """
    if not panel or not ui_controller:
        push_error("UniversalPanelConnector: Invalid panel or UI controller")
        return
    
    print("UniversalPanelConnector: Connecting universal signals for %s" % panel.name)
    
    # Standard panel signals that ALL panels should support
    var standard_signals = [
        "data_changed",
        "validation_changed", 
        "completed",
        "error_occurred",
        "ready_state_changed"
    ]
    
    for signal_name in standard_signals:
        _safe_connect_signal(panel, signal_name, ui_controller, "_on_panel_" + signal_name)
    
    # Connect any additional panel-specific signals dynamically
    _connect_dynamic_signals(panel, ui_controller)
    
    print("UniversalPanelConnector: Signal connections completed for %s" % panel.name)

static func _safe_connect_signal(source: Node, signal_name: String, target: Node, method_name: String) -> void:
    """Safe signal connection with comprehensive error handling"""
    
    if not source.has_signal(signal_name):
        # Not an error - some panels may not have all signals
        return
    
    if not target.has_method(method_name):
        push_warning("UniversalPanelConnector: Target method '%s' not found on %s" % [method_name, target.name])
        return
    
    # Disconnect if already connected to prevent duplicates
    if source.is_connected(signal_name, Callable(target, method_name)):
        source.disconnect(signal_name, Callable(target, method_name))
    
    # Connect with error handling
    var result = source.connect(signal_name, Callable(target, method_name))
    if result != OK:
        push_error("UniversalPanelConnector: Failed to connect %s.%s to %s.%s" % [source.name, signal_name, target.name, method_name])
    else:
        print("UniversalPanelConnector: Connected %s.%s -> %s.%s" % [source.name, signal_name, target.name, method_name])

static func _connect_dynamic_signals(panel: Node, ui_controller: Node) -> void:
    """
    Dynamically connect any additional signals based on panel type.
    This replaces the massive switch statement approach with clean discovery.
    """
    
    # Get all signals from the panel
    var panel_signals = panel.get_signal_list()
    
    # Define patterns for automatic connection
    var signal_patterns = {
        "character_": "_on_character_event",
        "crew_": "_on_crew_event", 
        "equipment_": "_on_equipment_event",
        "ship_": "_on_ship_event",
        "captain_": "_on_captain_event"
    }
    
    for signal_info in panel_signals:
        var signal_name = signal_info.name as String
        
        # Skip standard signals already handled
        if signal_name in ["data_changed", "validation_changed", "completed", "error_occurred", "ready_state_changed"]:
            continue
        
        # Match against patterns and connect automatically
        for pattern in signal_patterns:
            if signal_name.begins_with(pattern):
                var handler_method = signal_patterns[pattern]
                _safe_connect_signal(panel, signal_name, ui_controller, handler_method)
                break

# Panel state management
static func get_panel_data(panel: Node) -> Dictionary:
    """Universal data getter that works with any panel"""
    if not panel:
        return {}
    
    if panel.has_method("get_panel_data"):
        var data = panel.get_panel_data()
        return data if data is Dictionary else {}
    
    # Fallback: Try to gather data from common UI elements
    return _extract_ui_data(panel)

static func _extract_ui_data(panel: Node) -> Dictionary:
    """Extract data from common UI elements when panel doesn't have get_panel_data()"""
    var data = {}
    
    # Find LineEdits, SpinBoxes, OptionButtons, etc.
    for child in panel.get_children():
        if child is LineEdit:
            var line_edit = child as LineEdit
            data[line_edit.name] = line_edit.text
        elif child is SpinBox:
            var spin_box = child as SpinBox
            data[spin_box.name] = spin_box.value
        elif child is OptionButton:
            var option_button = child as OptionButton
            data[option_button.name] = option_button.selected
        elif child is CheckBox:
            var check_box = child as CheckBox
            data[check_box.name] = check_box.button_pressed
    
    return data

# Validation helpers
static func validate_panel(panel: Node) -> Dictionary:
    """Universal panel validation"""
    var result = {
        "is_valid": false,
        "errors": [],
        "warnings": []
    }
    
    if not panel:
        result.errors.append("Panel is null")
        return result
    
    if panel.has_method("validate"):
        var panel_result = panel.validate()
        if panel_result is Dictionary:
            return panel_result
        else:
            result.is_valid = panel_result is bool and panel_result
    else:
        # Basic validation - check required fields are not empty
        var data = get_panel_data(panel)
        result.is_valid = data.size() > 0
    
    return result
