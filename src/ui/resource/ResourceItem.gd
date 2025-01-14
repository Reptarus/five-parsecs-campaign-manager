extends Button

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var resource_type: int = GameEnums.ResourceType.NONE
var current_amount: int = 0
var market_value: int = 0
var trend: int = 0  # -1: decreasing, 0: stable, 1: increasing

@onready var icon_texture: TextureRect = $HBoxContainer/IconTexture
@onready var name_label: Label = $HBoxContainer/NameLabel
@onready var amount_label: Label = $HBoxContainer/AmountLabel
@onready var trend_label: Label = $HBoxContainer/TrendLabel
@onready var market_label: Label = $HBoxContainer/MarketLabel

const TREND_SYMBOLS = {
	-1: "↓",
	0: "→",
	1: "↑"
}

const TREND_COLORS = {
	-1: Color(1, 0.4, 0.4),  # Red
	0: Color(1, 1, 1),      # White
	1: Color(0.4, 1, 0.4)   # Green
}

func setup(type: int, amount: int, m_value: int = 0, t: int = 0) -> void:
	resource_type = type
	current_amount = amount
	market_value = m_value
	trend = t
	
	# Update visuals
	var type_name = GameEnums.ResourceType.keys()[type].capitalize()
	name_label.text = type_name
	_update_labels()
	
	# Set icon if available
	var icon_path = "res://assets/icons/resources/" + type_name.to_lower() + ".png"
	if ResourceLoader.exists(icon_path):
		icon_texture.texture = load(icon_path)

func update_values(amount: int, m_value: int = 0, t: int = 0) -> void:
	current_amount = amount
	market_value = m_value
	trend = t
	_update_labels()

func _update_labels() -> void:
	amount_label.text = str(current_amount)
	
	if market_value > 0:
		market_label.text = "(" + str(market_value) + ")"
		market_label.modulate = TREND_COLORS[trend]
	else:
		market_label.text = ""
	
	trend_label.text = TREND_SYMBOLS[trend]
	trend_label.modulate = TREND_COLORS[trend]
	
	# Add tooltip
	tooltip_text = _generate_tooltip()

func _generate_tooltip() -> String:
	var type_name = GameEnums.ResourceType.keys()[resource_type].capitalize()
	var tooltip = type_name + "\n"
	tooltip += "Current: " + str(current_amount) + "\n"
	
	if market_value > 0:
		tooltip += "Market Value: " + str(market_value) + "\n"
		var diff = market_value - current_amount
		if diff != 0:
			tooltip += "Difference: " + ("+" if diff > 0 else "") + str(diff) + "\n"
	
	match trend:
		-1: tooltip += "Trend: Decreasing"
		0: tooltip += "Trend: Stable"
		1: tooltip += "Trend: Increasing"
	
	return tooltip