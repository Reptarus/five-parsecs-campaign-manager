@tool
extends PanelContainer

#region Signals
signal rule_added(rule: Dictionary)
signal rule_modified(rule: Dictionary)
signal rule_removed(rule_id: String)
signal rule_applied(rule_id: String, context: String)
signal validation_requested(rule: Dictionary, context: String)
#endregion

#region Node References
@onready var rules_list: ItemList = %RulesList
@onready var rule_editor: PanelContainer = %RuleEditor
@onready var validation_panel: PanelContainer = %ValidationPanel
#endregion

#region Properties
var active_rules: Dictionary = {}
var rule_templates: Dictionary = {
	"combat_modifier": {
		"name": "Combat Modifier",
		"type": "modifier",
		"fields": ["value", "condition", "target"],
		"validator": func(value: int, state: Dictionary) -> bool: return value >= -3 and value <= 3
	},
	"resource_modifier": {
		"name": "Resource Modifier",
		"type": "resource",
		"fields": ["resource_type", "value", "condition"],
		"validator": func(value: int, state: Dictionary) -> bool: return value >= -5 and value <= 5
	},
	"state_condition": {
		"name": "State Condition",
		"type": "condition",
		"fields": ["state_key", "operator", "value"],
		"validator": func(value: Variant, state: Dictionary) -> bool: return true # Complex validation based on state
	}
}
#endregion

#region Lifecycle Methods
func _ready() -> void:
	if not Engine.is_editor_hint():
		_validate_components()
		_setup_signals()
		_load_rule_templates()
		_update_rules_list()
#endregion

#region Setup Methods
## Validates all required components are present
func _validate_components() -> bool:
	var all_valid = true
	
	if not is_instance_valid(rules_list):
		push_error("HouseRulesPanel: rules_list not found")
		all_valid = false
	
	if not is_instance_valid(rule_editor):
		push_error("HouseRulesPanel: rule_editor not found")
		all_valid = false
	
	if not is_instance_valid(validation_panel):
		push_error("HouseRulesPanel: validation_panel not found")
		all_valid = false
		
	return all_valid

func _setup_signals() -> void:
	if not _validate_components():
		push_warning("HouseRulesPanel: Cannot set up signals - missing components")
		return
	
	if is_instance_valid(rules_list):
		rules_list.item_selected.connect(_on_rule_selected)
	
	if is_instance_valid(rule_editor) and rule_editor.has_signal("rule_saved"):
		rule_editor.rule_saved.connect(_on_rule_saved)
	
	if is_instance_valid(rule_editor) and rule_editor.has_signal("rule_deleted"):
		rule_editor.rule_deleted.connect(_on_rule_deleted)
	
	if is_instance_valid(validation_panel) and validation_panel.has_signal("validation_completed"):
		validation_panel.validation_completed.connect(_on_validation_completed)

func _load_rule_templates() -> void:
	# TODO: Load additional templates from config file
	pass

func _update_rules_list() -> void:
	if not is_instance_valid(rules_list):
		return
		
	rules_list.clear()
	for rule_id in active_rules:
		var rule = active_rules[rule_id]
		if rule.has("name"):
			rules_list.add_item(rule.name, null, true)
			rules_list.set_item_metadata(-1, rule_id)
#endregion

#region Rule Management Methods
func add_rule(rule_data: Dictionary) -> String:
	# Validate rule data before adding
	if not _is_valid_rule_data(rule_data):
		push_warning("HouseRulesPanel: Attempted to add invalid rule data")
		return ""
		
	var rule_id = str(Time.get_unix_time_from_system())
	active_rules[rule_id] = rule_data
	
	# Emit signal only if rule is valid
	rule_added.emit(rule_data)
	_update_rules_list()
	return rule_id

func modify_rule(rule_id: String, rule_data: Dictionary) -> void:
	# Validate rule data before modifying
	if not _is_valid_rule_data(rule_data):
		push_warning("HouseRulesPanel: Attempted to modify with invalid rule data")
		return
		
	if active_rules.has(rule_id):
		active_rules[rule_id] = rule_data
		rule_modified.emit(rule_data)
		_update_rules_list()

func remove_rule(rule_id: String) -> void:
	if active_rules.has(rule_id):
		active_rules.erase(rule_id)
		rule_removed.emit(rule_id)
		_update_rules_list()

func get_active_rules() -> Array[Dictionary]:
	var rules: Array[Dictionary] = []
	for rule in active_rules.values():
		rules.append(rule)
	return rules

## Checks if rule data has required fields
func _is_valid_rule_data(rule_data: Dictionary) -> bool:
	if not rule_data.has("type") or typeof(rule_data.type) != TYPE_STRING:
		return false
		
	if not rule_data.has("name") or typeof(rule_data.name) != TYPE_STRING:
		return false
		
	return true
#endregion

#region Rule Validation and Application
func validate_rule(rule: Dictionary, context: String) -> bool:
	if not _is_valid_rule_data(rule):
		push_warning("HouseRulesPanel: Attempted to validate an invalid rule")
		return false
		
	if not rule.has("type") or not rule_templates.has(rule.type):
		return false
	
	var template = rule_templates[rule.type]
	if not template.has("validator"):
		return true
	
	# Emit validation signal
	validation_requested.emit(rule, context)
	
	var validator = template.validator
	if typeof(validator) == TYPE_CALLABLE:
		var value = _get_rule_value(rule)
		return validator.call(value, {})
	
	return false

func apply_rule(rule_id: String, context: String) -> void:
	if active_rules.has(rule_id):
		var rule = active_rules[rule_id]
		if validate_rule(rule, context):
			rule_applied.emit(rule_id, context)

## Gets the numerical value from a rule
func _get_rule_value(rule_data: Dictionary) -> int:
	# Safely check if fields property exists and handle the case when it doesn't
	if not rule_data.has("fields"):
		return 0
		
	# If fields exists, iterate through them safely
	if typeof(rule_data.fields) == TYPE_ARRAY:
		for field in rule_data.fields:
			if typeof(field) == TYPE_DICTIONARY and field.has("name") and field.name == "value":
				if field.has("value") and (typeof(field.value) == TYPE_INT or typeof(field.value) == TYPE_FLOAT):
					return int(field.value)
	return 0
#endregion

#region Signal Handlers
func _on_rule_selected(index: int) -> void:
	if not is_instance_valid(rules_list) or not is_instance_valid(rule_editor):
		return
		
	if index < 0 or index >= rules_list.get_item_count():
		push_warning("HouseRulesPanel: Invalid rule selection index")
		return
		
	var rule_id = rules_list.get_item_metadata(index)
	if active_rules.has(rule_id):
		if rule_editor.has_method("load_rule"):
			rule_editor.load_rule(rule_id, active_rules[rule_id])
		else:
			push_warning("HouseRulesPanel: rule_editor missing load_rule method")

func _on_rule_saved(rule_id: String, rule_data: Dictionary) -> void:
	if rule_id.is_empty():
		add_rule(rule_data)
	else:
		modify_rule(rule_id, rule_data)

func _on_rule_deleted(rule_id: String) -> void:
	remove_rule(rule_id)

func _on_validation_completed(rule: Dictionary, context: String, is_valid: bool) -> void:
	if not is_instance_valid(validation_panel):
		return
		
	if is_valid:
		if validation_panel.has_method("show_success"):
			validation_panel.show_success("Rule validation passed")
	else:
		if validation_panel.has_method("show_error"):
			validation_panel.show_error("Rule validation failed")
#endregion