extends Resource

signal error_logged(error: Dictionary)

enum ErrorCategory {
    VALIDATION,
    STATE,
    PHASE_TRANSITION,
    COMBAT,
    NETWORK,
    PERSISTENCE
}

enum ErrorSeverity {
    INFO,
    WARNING,
    ERROR,
    CRITICAL
}

var error_history: Array[Dictionary] = []
const MAX_ERROR_HISTORY = 100

func log_error(message: String, category: ErrorCategory, severity: ErrorSeverity, context: Dictionary = {}) -> void:
    var error = {
        "message": message,
        "category": category,
        "severity": severity,
        "context": context,
        "timestamp": Time.get_unix_time_from_system()
    }
    
    error_history.append(error)
    
    # Trim history if needed
    if error_history.size() > MAX_ERROR_HISTORY:
        error_history = error_history.slice(- MAX_ERROR_HISTORY)
    
    error_logged.emit(error)

func get_error_history() -> Array[Dictionary]:
    return error_history

func clear_error_history() -> void:
    error_history.clear()