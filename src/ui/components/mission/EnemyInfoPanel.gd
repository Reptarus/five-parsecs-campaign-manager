# This file should be referenced via preload
# Use explicit preloads instead of global class names
extends Control

const Self := "res://src/ui/components/mission/EnemyInfoPanel.gd" # Use string path instead of preload

@onready var enemy_list := $EnemyList
@onready var threat_level := $ThreatLevel
@onready var special_rules := $SpecialRules

func setup(enemy_data: Dictionary) -> void:
	## Display single enemy type with stats (Core Rules pp.91-94)
	_clear_lists()

	# Primary type name + stats
	var type_name: String = enemy_data.get("type", "Unknown")
	var name_label := Label.new()
	name_label.text = type_name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override(
		"font_color", Color("#DC2626"))
	enemy_list.add_child(name_label)

	# Stat line
	var spd: int = enemy_data.get("speed", 0)
	var cmb: int = enemy_data.get("combat_skill", 0)
	var tgh: int = enemy_data.get("toughness", 0)
	var ai_str: String = str(enemy_data.get("ai", ""))
	var panic_str: String = str(enemy_data.get("panic", ""))
	if spd > 0 or cmb > 0 or tgh > 0:
		var stat_label := Label.new()
		stat_label.text = (
			"SPD:%d  CMB:+%d  TGH:%d  AI:%s  Panic:%s"
			% [spd, cmb, tgh, ai_str, panic_str])
		stat_label.add_theme_font_size_override("font_size", 12)
		stat_label.add_theme_color_override(
			"font_color", Color("#4FC3F7"))
		enemy_list.add_child(stat_label)

	# Count
	var total: int = enemy_data.get("count", 0)
	if total > 0:
		var count_label := Label.new()
		count_label.text = "Count: %d" % total
		enemy_list.add_child(count_label)

	# Role breakdown from units array
	var units: Array = enemy_data.get("units", [])
	for unit in units:
		if unit is Dictionary and unit.get("role", "") != "standard":
			var role_item := _create_role_item(unit)
			enemy_list.add_child(role_item)

	threat_level.text = "Threat Level: " + _get_threat_text(
		enemy_data.get("threat_level", 1))

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
	var item = HBoxContainer.new()
	var type_label = Label.new()
	type_label.text = enemy.get("type", "Unknown Enemy")
	item.add_child(type_label)
	var count_label = Label.new()
	count_label.text = "x%d" % enemy.get("count", 1)
	item.add_child(count_label)
	return item

func _create_role_item(unit: Dictionary) -> Control:
	## Display a non-standard role (Lieutenant/Specialist)
	var item = HBoxContainer.new()
	item.add_theme_constant_override("separation", 8)
	var role_label = Label.new()
	var role: String = unit.get("role", "standard")
	var uname: String = unit.get("name", "")
	role_label.text = "%s (%s)" % [uname, role.capitalize()]
	role_label.add_theme_font_size_override("font_size", 12)
	role_label.add_theme_color_override(
		"font_color", Color("#f59e0b"))
	item.add_child(role_label)
	return item

func _create_rule_item(rule: Dictionary) -> Control:
	var item = VBoxContainer.new()
    
	var title = Label.new()
	title.text = rule.get("name", "Unknown Rule")
	item.add_child(title)
    
	var description = Label.new()
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
