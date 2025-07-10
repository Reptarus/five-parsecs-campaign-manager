class_name FPCM_EnemyInfoPanel
extends Control

@onready var enemy_list := $EnemyList
@onready var threat_level := $ThreatLevel
@onready var special_rules := $SpecialRules

func setup(enemy_data: Dictionary) -> void:
	_clear_lists()

	var enemies = enemy_data.get("units", [])
	for enemy in enemies:
		var enemy_item: Control = _create_enemy_item(enemy)
		enemy_list.add_child(enemy_item)

	threat_level.text = "Threat Level: " + _get_threat_text(enemy_data.get("threat_level", 1))

	var rules = enemy_data.get("special_rules", [])
	for rule in rules:
		var rule_item = _create_rule_item(rule)
		special_rules.add_child(rule_item)

func _clear_lists() -> void:
	for child in enemy_list.get_children():
		child.queue_free()
	for child in special_rules.get_children():
		child.queue_free()

func _create_enemy_item(enemy: Dictionary) -> Control:
	var item := HBoxContainer.new()

	var type_label := Label.new()

	type_label.text = enemy.get("type", "Unknown Enemy")
	item.add_child(type_label)

	var count_label := Label.new()

	count_label.text = "x%d" % enemy.get("count", 1)
	item.add_child(count_label)

	return item

func _create_rule_item(rule: Dictionary) -> Control:
	var item := VBoxContainer.new()

	var title := Label.new()

	title.text = rule.get("name", "Unknown Rule")
	item.add_child(title)

	var description := Label.new()

	description.text = rule.get("description", "")
	item.add_child(description)

	return item

func _get_threat_text(level: int) -> String:
	match level:
		0: return "Low"
		1: return "Medium"
		2: return "High"
		3: return "Extreme"
		_: return "Unknown"

## Safe property access helper - eliminates UNSAFE_METHOD_ACCESS warnings
## Based on Godot 4.4 best practices for safe property access
func safe_get_property(obj: Variant, property: String, default_value: Variant = null) -> Variant:
	if obj == null:
		return default_value
	if obj is Object and obj.has_method("get"):
		var value: Variant = obj.get(property)
		return value if value != null else default_value
	elif obj is Dictionary:
		return obj.get(property, default_value)
	return default_value
## Safe method call helper - eliminates UNSAFE_METHOD_ACCESS warnings
func safe_call_method(obj: Variant, method_name: String, args: Array = []) -> Variant:
	if obj == null:
		return null
	if obj is Object and obj.has_method(method_name):
		return obj.callv(method_name, args)
	return null