# Main.gd
extends Node

var current_scene: Node = null
var game_state: GameState = null

func _ready() -> void:
	game_state = GameState.new()
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)

func goto_scene(path: String) -> void:
	call_deferred("_deferred_goto_scene", path)

func _deferred_goto_scene(path: String) -> void:
	current_scene.free()
	var new_scene = load(path).instantiate()
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene
	
	if new_scene.has_method("set_game_state"):
		new_scene.set_game_state(game_state)
	
	# Fade transition
	var overlay = $TransitionOverlay
	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.5)
	await tween.finished
	tween = create_tween()
	tween.tween_property(overlay, "color:a", 0.0, 0.5)

func save_game() -> void:
	if game_state:
		var save_data = game_state.serialize()
		var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_game() -> void:
	if FileAccess.file_exists("user://savegame.json"):
		var file = FileAccess.open("user://savegame.json", FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()
		
		if parse_result == OK:
			var save_data = json.get_data()
			game_state = GameState.deserialize(save_data)
			goto_scene("res://scenes/CampaignDashboard.tscn")
