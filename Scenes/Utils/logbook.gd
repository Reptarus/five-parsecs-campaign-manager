# Logbook.gd
extends Control

var current_entry = ""

func _ready():
	$MarginContainer/VBoxContainer/EntryList.connect("item_selected", Callable(self, "_on_entry_selected"))
	$MarginContainer/VBoxContainer/NewEntryButton.connect("pressed", Callable(self, "_on_new_entry_pressed"))
	$MarginContainer/VBoxContainer/SaveEntryButton.connect("pressed", Callable(self, "_on_save_entry_pressed"))
	$MarginContainer/VBoxContainer/DeleteEntryButton.connect("pressed", Callable(self, "_on_delete_entry_pressed"))
	$MarginContainer/VBoxContainer/BackButton.connect("pressed", Callable(self, "_on_back_pressed"))

	# TODO: Load existing entries and populate EntryList

func _on_entry_selected(index):
	current_entry = $MarginContainer/VBoxContainer/EntryList.get_item_text(index)
	# TODO: Load selected entry content
	$MarginContainer/VBoxContainer/EntryContent.text = "Entry content placeholder"

func _on_new_entry_pressed():
	$MarginContainer/VBoxContainer/EntryContent.text = ""
	current_entry = ""

func _on_save_entry_pressed():
	var content = $MarginContainer/VBoxContainer/EntryContent.text
	if current_entry == "":
		# TODO: Create new entry
		print("New entry creation not implemented yet")
	else:
		# TODO: Update existing entry
		print("Entry update not implemented yet")

func _on_delete_entry_pressed():
	if current_entry != "":
		# TODO: Delete selected entry
		print("Entry deletion not implemented yet")

func _on_back_pressed():
	get_node("/root/Main").load_scene("res://scenes/campaign/CampaignDashboard.tscn")
