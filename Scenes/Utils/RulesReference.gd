# RulesReference.gd
extends Control

var rules_data = {}

func _ready():
	$SearchBar.connect("text_changed", Callable(self, "_on_search_text_changed"))
	$RulesList.connect("item_selected", Callable(self, "_on_rule_selected"))
	$BackButton.connect("pressed", Callable(self, "_on_back_pressed"))
	
	load_rules_data()
	populate_rules_list()

func load_rules_data():
	var file = FileAccess.open("res://data/rules.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		if parse_result == OK:
			rules_data = json.get_data()
		file.close()

func populate_rules_list():
	$RulesList.clear()
	for rule in rules_data.keys():
		$RulesList.add_item(rule)

func _on_search_text_changed(new_text):
	$RulesList.clear()
	for rule in rules_data.keys():
		if new_text.to_lower() in rule.to_lower():
			$RulesList.add_item(rule)

func _on_rule_selected(index):
	var rule_name = $RulesList.get_item_text(index)
	$RuleContent.text = rules_data[rule_name]

func _on_back_pressed():
	get_node("/root/Main").load_scene("res://scenes/main_menu/MainMenu.tscn")
