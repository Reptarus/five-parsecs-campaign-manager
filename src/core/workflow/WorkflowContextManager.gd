extends Node

## Production Workflow Context Manager
## Handles type-safe cross-scene data persistence with comprehensive error handling
## This is an autoload singleton - no class_name needed

# Production-grade context definition
class WorkflowContext:
	var workflow_step: int
	var campaign_data: Dictionary
	var completion_callback: Callable
	var error_callback: Callable
	var metadata: Dictionary
	
	func _init(step: int, data: Dictionary, on_complete: Callable = Callable(), on_error: Callable = Callable()):
		workflow_step = step
		campaign_data = data.duplicate()
		completion_callback = on_complete
		error_callback = on_error
		metadata = {
			"created_at": Time.get_ticks_msec(),
			"source_scene": "",
			"target_scene": "",
			"context_version": "1.0"
		}

# Singleton state management
var current_context: WorkflowContext = null
var context_history: Array[WorkflowContext] = []
const MAX_HISTORY_SIZE: int = 10

# Production monitoring signals
signal context_updated(context: WorkflowContext)
signal context_cleared()
signal context_error(error_message: String)

func _ready():
	"""Initialize context manager with production monitoring"""
	print("WorkflowContextManager: Production context manager initialized")
	_setup_monitoring()

func _setup_monitoring():
	"""Setup context monitoring for production debugging"""
	context_updated.connect(_on_context_updated)
	context_cleared.connect(_on_context_cleared)
	context_error.connect(_on_context_error)

func set_context(context_data: Dictionary) -> bool:
	"""Set workflow context with validation and error handling"""
	if not _validate_context_data(context_data):
		context_error.emit("Invalid context data provided")
		return false
	
	# Create type-safe context
	var step = context_data.get("workflow_step", 0)
	var data = context_data.get("campaign_data", {})
	var completion_cb = context_data.get("completion_callback", Callable())
	var error_cb = context_data.get("error_callback", Callable())
	
	# Store previous context in history
	if current_context:
		_add_to_history(current_context)
	
	# Set new context
	current_context = WorkflowContext.new(step, data, completion_cb, error_cb)
	current_context.metadata["source_scene"] = _get_current_scene_name()
	
	print("WorkflowContextManager: Context set for step %d with data keys: %s" % [step, data.keys()])
	context_updated.emit(current_context)
	
	return true

func get_context() -> WorkflowContext:
	"""Get current workflow context with null safety"""
	return current_context

func has_context() -> bool:
	"""Check if valid workflow context exists"""
	return current_context != null

func clear_context() -> void:
	"""Clear current workflow context"""
	if current_context:
		_add_to_history(current_context)
		current_context = null
		context_cleared.emit()
		print("WorkflowContextManager: Context cleared")

func complete_workflow_step(step_data: Dictionary) -> bool:
	"""Complete current workflow step and trigger callback"""
	if not current_context:
		context_error.emit("No active context for step completion")
		return false
	
	if not current_context.completion_callback.is_valid():
		context_error.emit("No valid completion callback configured")
		return false
	
	print("WorkflowContextManager: Completing workflow step %d" % current_context.workflow_step)
	
	# Call completion callback
	current_context.completion_callback.call(step_data)
	
	return true

func report_workflow_error(error_message: String) -> bool:
	"""Report workflow error and trigger error callback"""
	if not current_context:
		context_error.emit("No active context for error reporting")
		return false
	
	print("WorkflowContextManager: Workflow error reported: %s" % error_message)
	
	if current_context.error_callback.is_valid():
		current_context.error_callback.call(error_message)
	
	context_error.emit(error_message)
	return true

# Private implementation methods
func _validate_context_data(data: Dictionary) -> bool:
	"""Validate context data structure"""
	var required_keys = ["workflow_step", "campaign_data"]
	
	for key in required_keys:
		if not data.has(key):
			print("WorkflowContextManager: Missing required key: %s" % key)
			return false
	
	return true

func _add_to_history(context: WorkflowContext) -> void:
	"""Add context to history with size management"""
	context_history.append(context)
	
	# Maintain history size limit
	if context_history.size() > MAX_HISTORY_SIZE:
		context_history.pop_front()

func _get_current_scene_name() -> String:
	"""Get current scene name for debugging"""
	var current_scene = get_tree().current_scene
	return current_scene.name if current_scene else "Unknown"

# Monitoring callbacks
func _on_context_updated(context: WorkflowContext):
	"""Handle context updates for monitoring"""
	print("WorkflowContextManager: 📊 Context updated - Step: %d, Data keys: %s" % 
		[context.workflow_step, context.campaign_data.keys()])

func _on_context_cleared():
	"""Handle context clearing for monitoring"""
	print("WorkflowContextManager: 🧹 Context cleared")

func _on_context_error(error_message: String):
	"""Handle context errors for monitoring"""
	print("WorkflowContextManager: 🚨 Context error: %s" % error_message)

# Debug API for development
func get_debug_info() -> Dictionary:
	"""Get comprehensive debug information"""
	return {
		"has_active_context": has_context(),
		"current_step": current_context.workflow_step if current_context else -1,
		"context_data_keys": current_context.campaign_data.keys() if current_context else [],
		"history_size": context_history.size(),
		"callbacks_valid": {
			"completion": current_context.completion_callback.is_valid() if current_context else false,
			"error": current_context.error_callback.is_valid() if current_context else false
		}
	}

# Public API methods for scene integration
func get_campaign_data() -> Dictionary:
	"""Get campaign data from current context"""
	if current_context:
		return current_context.campaign_data.duplicate()
	return {}

func update_campaign_data(new_data: Dictionary) -> bool:
	"""Update campaign data in current context"""
	if not current_context:
		context_error.emit("No active context to update")
		return false
	
	# Merge new data into existing campaign data
	for key in new_data:
		current_context.campaign_data[key] = new_data[key]
	
	print("WorkflowContextManager: Campaign data updated with keys: %s" % new_data.keys())
	context_updated.emit(current_context)
	return true

func get_workflow_step() -> int:
	"""Get current workflow step"""
	if current_context:
		return current_context.workflow_step
	return -1

func set_scene_metadata(key: String, value: Variant) -> void:
	"""Set metadata for current scene"""
	if current_context:
		current_context.metadata[key] = value