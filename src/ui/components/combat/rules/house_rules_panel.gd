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
		_setup_signals()
		_load_rule_templates()
		_update_rules_list()
#endregion

#region Setup Methods
func _setup_signals() -> void:
	rules_list.item_selected.connect(_on_rule_selected)
	rule_editor.rule_saved.connect(_on_rule_saved)
	rule_editor.rule_deleted.connect(_on_rule_deleted)
	validation_panel.validation_completed.connect(_on_validation_completed)

func _load_rule_templates() -> void:
	# TODO: Load additional templates from config file
	pass

func _update_rules_list() -> void:
	rules_list.clear()
	for rule_id in active_rules:
		var rule = active_rules[rule_id]
		rules_list.add_item(rule.name, null, true)
		rules_list.set_item_metadata(-1, rule_id)
#endregion

#region Rule Management Methods
func add_rule(rule_data: Dictionary) -> String:
	var rule_id = str(Time.get_unix_time_from_system())
	active_rules[rule_id] = rule_data
	rule_added.emit(rule_data)
	_update_rules_list()
	return rule_id

func modify_rule(rule_id: String, rule_data: Dictionary) -> void:
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
#endregion

#region Rule Validation and Application
func validate_rule(rule: Dictionary, context: String) -> bool:
	if not rule.has("type") or not rule_templates.has(rule.type):
		return false
	
	var template = rule_templates[rule.type]
	if not template.has("validator"):
		return true
	
	validation_requested.emit(rule, context)
	return template.validator.call(rule.value, {})

func apply_rule(rule_id: String, context: String) -> void:
	if active_rules.has(rule_id):
		var rule = active_rules[rule_id]
		if validate_rule(rule, context):
			rule_applied.emit(rule_id, context)
#endregion

#region Signal Handlers
func _on_rule_selected(index: int) -> void:
	var rule_id = rules_list.get_item_metadata(index)
	if active_rules.has(rule_id):
		rule_editor.load_rule(rule_id, active_rules[rule_id])

func _on_rule_saved(rule_id: String, rule_data: Dictionary) -> void:
	if rule_id.is_empty():
		add_rule(rule_data)
	else:
		modify_rule(rule_id, rule_data)

func _on_rule_deleted(rule_id: String) -> void:
	remove_rule(rule_id)

func _on_validation_completed(rule: Dictionary, context: String, is_valid: bool) -> void:
	if is_valid:
		validation_panel.show_success("Rule validation passed")
	else:
		validation_panel.show_error("Rule validation failed")
#endregion