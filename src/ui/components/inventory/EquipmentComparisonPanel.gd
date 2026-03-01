extends PanelContainer
class_name EquipmentComparisonPanel
## Side-by-side equipment comparison panel for Trade Phase
##
## Shows two items with stat comparison, highlighting which is better.
## Used in TradePhasePanel when comparing market items vs inventory.

signal comparison_closed

var _left_item: Dictionary = {}
var _right_item: Dictionary = {}
var _left_label: RichTextLabel
var _right_label: RichTextLabel
var _title_label: Label
var _close_button: Button

func _ready() -> void:
	# Build UI
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	add_child(vbox)

	# Title bar
	var title_bar := HBoxContainer.new()
	vbox.add_child(title_bar)
	_title_label = Label.new()
	_title_label.text = "Equipment Comparison"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(_title_label)
	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(32, 32)
	_close_button.pressed.connect(_on_close)
	title_bar.add_child(_close_button)

	# Comparison columns
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	_left_label = RichTextLabel.new()
	_left_label.bbcode_enabled = true
	_left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_label.fit_content = true
	hbox.add_child(_left_label)

	var separator := VSeparator.new()
	hbox.add_child(separator)

	_right_label = RichTextLabel.new()
	_right_label.bbcode_enabled = true
	_right_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_label.fit_content = true
	hbox.add_child(_right_label)

	# Styling
	custom_minimum_size = Vector2(400, 250)

func compare(item_a: Dictionary, item_b: Dictionary) -> void:
	## Show comparison between two items. Left = current, Right = candidate.
	_left_item = item_a
	_right_item = item_b
	_refresh_display()
	visible = true

func _refresh_display() -> void:
	var left_name: String = _left_item.get("name", "Empty Slot")
	var right_name: String = _right_item.get("name", "Empty Slot")

	_left_label.text = ""
	_right_label.text = ""

	_left_label.append_text("[b]%s[/b]\n(Current)\n\n" % left_name)
	_right_label.append_text("[b]%s[/b]\n(Candidate)\n\n" % right_name)

	# Compare numeric stats
	var stat_keys := ["damage", "range", "shots", "value", "combat_skill", "toughness", "speed", "accuracy"]
	for key in stat_keys:
		var left_val: int = _left_item.get(key, 0)
		var right_val: int = _right_item.get(key, 0)
		if left_val == 0 and right_val == 0:
			continue
		var left_color := _get_compare_color(left_val, right_val)
		var right_color := _get_compare_color(right_val, left_val)
		_left_label.append_text("[color=%s]%s: %d[/color]\n" % [left_color, key.capitalize(), left_val])
		_right_label.append_text("[color=%s]%s: %d[/color]\n" % [right_color, key.capitalize(), right_val])

	# Compare traits
	var left_traits: Array = _left_item.get("traits", [])
	var right_traits: Array = _right_item.get("traits", [])
	if not left_traits.is_empty() or not right_traits.is_empty():
		_left_label.append_text("\n[b]Traits:[/b] %s" % (", ".join(left_traits) if not left_traits.is_empty() else "None"))
		_right_label.append_text("\n[b]Traits:[/b] %s" % (", ".join(right_traits) if not right_traits.is_empty() else "None"))

func _get_compare_color(this_val: int, other_val: int) -> String:
	if this_val > other_val:
		return "#10B981"  # Green - better
	elif this_val < other_val:
		return "#DC2626"  # Red - worse
	return "#E0E0E0"  # Neutral

func _on_close() -> void:
	visible = false
	comparison_closed.emit()
