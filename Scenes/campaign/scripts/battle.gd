# Battle.gd
class_name Battle
extends Resource

const BattleClass = preload("res://Scenes/campaign/scripts/battle.gd")

var held_field: bool = false
var opponent: Character
var killed_unique_individual: bool = false

func _init(_opponent: Character) -> void:
	opponent = _opponent

var current_round = 0

func _ready():
	# logic stuff
	pass
	

func _on_next_round_pressed():
	current_round += 1
	# TODO: Implement battle round logic
	print("Round ", current_round, " not implemented yet")
	update_display()

func _on_end_battle_pressed():
	#get_node("/root/Main").load_scene("res://scenes/campaign/PostBattle.tscn")
	pass

func update_display():
	#$MarginContainer/VBoxContainer/RoundLabel.text = "Round: " + str(current_round)
	# TODO: Update other battle information
	pass
