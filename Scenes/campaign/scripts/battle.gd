# Battle.gd
extends Control

var current_round = 0

func _ready():
	$MarginContainer/VBoxContainer/NextRoundButton.connect("pressed", Callable(self, "_on_next_round_pressed"))
	$MarginContainer/VBoxContainer/EndBattleButton.connect("pressed", Callable(self, "_on_end_battle_pressed"))

func _on_next_round_pressed():
	current_round += 1
	# TODO: Implement battle round logic
	print("Round ", current_round, " not implemented yet")
	update_display()

func _on_end_battle_pressed():
	get_node("/root/Main").load_scene("res://scenes/campaign/PostBattle.tscn")

func update_display():
	$MarginContainer/VBoxContainer/RoundLabel.text = "Round: " + str(current_round)
	# TODO: Update other battle information
