extends Control

# TODO: Connect to a real mission management system
signal mission_selected(mission_index)

func _ready() -> void:
	# Hide the panel by default, it should be shown by a manager
	$PopupPanel.hide()

func popup_missions(missions: Array) -> void:
	# TODO: Populate the UI with actual mission data
	# For now, we just show the panel
	print("Popup missions: ", missions)
	$PopupPanel.popup_centered()

func _on_mission_selected(mission_index: int) -> void:
	print("Mission selected: ", mission_index)
	emit_signal("mission_selected", mission_index)
	$PopupPanel.hide()

func _on_close_pressed() -> void:
	print("Mission selection closed")
	$PopupPanel.hide() 