# CharacterStatsDisplay.gd
class_name CharacterStatsDisplay
extends Control

@export var character: Character

@onready var stats_container = $StatsContainer

func _ready() -> void:
	if character:
		update_stats_display()
		character.connect("stat_changed", Callable(self, "_on_stat_changed"))

func update_stats_display() -> void:
	for stat in Character.BASE_STATS:
		var label = stats_container.get_node(stat.capitalize() + "Label")
		if label:
			label.text = stat.capitalize() + ": " + str(character.get_stat(stat))

func _on_stat_changed(stat_name: String, new_value: int) -> void:
	var label = stats_container.get_node(stat_name.capitalize() + "Label")
	if label:
		label.text = stat_name.capitalize() + ": " + str(new_value)
