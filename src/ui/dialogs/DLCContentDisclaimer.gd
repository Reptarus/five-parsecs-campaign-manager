extends AcceptDialog

## One-time disclaimer shown when enabling expansion features during
## campaign creation. Informs the player that DLC content will
## permanently mark the save as requiring that expansion.

signal accepted
signal rejected

func _ready() -> void:
	title = "Expansion Content Notice"
	dialog_hide_on_ok = true
	min_size = Vector2i(450, 0)

func show_for_pack(pack_name: String) -> void:
	dialog_text = (
		"Enabling features from %s will add expansion content"
		+ " to this campaign.\n\n"
		+ "Once expansion content enters your save file, this"
		+ " campaign will require the expansion to play with full"
		+ " functionality. You can always load the save, but some"
		+ " features may be unavailable without the expansion."
	) % pack_name
	ok_button_text = "I Understand, Enable"
	add_button("Cancel", true, "cancel_dlc")
	confirmed.connect(_on_accepted, CONNECT_ONE_SHOT)
	custom_action.connect(_on_custom_action, CONNECT_ONE_SHOT)
	canceled.connect(_on_rejected, CONNECT_ONE_SHOT)
	popup_centered()

func _on_accepted() -> void:
	accepted.emit()
	queue_free()

func _on_custom_action(action: StringName) -> void:
	if action == &"cancel_dlc":
		rejected.emit()
		hide()
		queue_free()

func _on_rejected() -> void:
	rejected.emit()
	queue_free()
