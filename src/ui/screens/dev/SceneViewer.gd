## SceneViewer - dev harness to preview SceneStage manifests in isolation.
##
## Run it directly (bypasses MainMenu):
##   godot --path <proj> res://src/ui/screens/dev/SceneViewer.tscn
## Optional user args after a standalone `--`:
##   scene_id=story_event_01    start on a specific manifest
##   autoshot                   capture a PNG to user:// then quit (for CI/MCP)
##
## Interactive keys: Left/Right cycle scenes, A toggles all actors, S saves a
## screenshot, Esc quits.
##
## Path-loaded (no class_name) and referenced by .tscn via path= so it needs no
## .uid file. Not shipped in normal flow; purely an art-iteration tool.
extends Control

const SceneStageScript = preload("res://src/ui/screens/narrative/SceneStage.gd")
const MANIFEST_DIR := "res://data/scenes/"

var _stage: Control = null
var _label: Label = null
var _scene_ids: Array[String] = []
var _index: int = 0
var _actors_visible: bool = true


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.09, 1.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_stage = SceneStageScript.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)

	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)

	_scene_ids = _scan_scene_ids()
	var requested := _arg("scene_id", "story_event_01")
	_index = maxi(0, _scene_ids.find(requested))
	_show_current()

	if "autoshot" in OS.get_cmdline_user_args():
		await _autoshot()


func _scan_scene_ids() -> Array[String]:
	var ids: Array[String] = []
	var d := DirAccess.open(MANIFEST_DIR)
	if d:
		for f in d.get_files():
			if f.ends_with(".json"):
				ids.append(f.get_basename())
	ids.sort()
	return ids


func _arg(key: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.split("=", true, 1)[1]
	return fallback


## Fill the current scene's character slots from a `test_crew=<species,...>`
## arg, mapping species to slots in manifest order. Direct assignment (no
## AdvisorSystem / Character objects) so the viewer tests SceneStage placement
## in isolation. Example: test_crew=hulker,swift,k_erin
func _apply_test_crew() -> void:
	var spec := _arg("test_crew", "")
	if spec.is_empty():
		return
	if not _stage.has_method("get_character_slots"):
		return
	var species_list: PackedStringArray = spec.split(",", false)
	var slots: Array = _stage.get_character_slots()
	if slots.is_empty() or species_list.is_empty():
		return
	var assignments: Array = []
	for i in mini(slots.size(), species_list.size()):
		var slot = slots[i]
		if not (slot is Dictionary):
			continue
		assignments.append({
			"slot_id": str(slot.get("id", "")),
			"species_id": species_list[i].strip_edges(),
			"character_id": "test_%d" % i,
		})
	if not assignments.is_empty():
		_stage.set_character_slots(assignments)


func _show_current() -> void:
	if _scene_ids.is_empty():
		_label.text = "No manifests in %s" % MANIFEST_DIR
		return
	var sid: String = _scene_ids[_index]
	_stage.set_scene(sid)
	_apply_test_crew()
	_actors_visible = true
	var n_actors: int = _stage.get_actor_ids().size()
	_label.text = "%s   (%d/%d)   actors: %d   [Left/Right cycle | A actors | S shot | Esc quit]" % [
		sid, _index + 1, _scene_ids.size(), n_actors]


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_ESCAPE:
		get_tree().quit()
		return
	if _scene_ids.is_empty():
		return
	match event.keycode:
		KEY_RIGHT:
			_index = (_index + 1) % _scene_ids.size()
			_show_current()
		KEY_LEFT:
			_index = (_index - 1 + _scene_ids.size()) % _scene_ids.size()
			_show_current()
		KEY_A:
			_actors_visible = not _actors_visible
			for aid in _stage.get_actor_ids():
				_stage.set_actor_visibility(aid, _actors_visible)
		KEY_S:
			_save_shot(_scene_ids[_index])


func _autoshot() -> void:
	for i in 10:
		await get_tree().process_frame
	_save_shot(_scene_ids[_index] if not _scene_ids.is_empty() else "none")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _save_shot(sid: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		print("SCENE_VIEWER_SHOT_FAILED: null image")
		return
	var path := "user://scene_viewer_%s.png" % sid
	img.save_png(path)
	print("SCENE_VIEWER_SHOT_SAVED: %s" % ProjectSettings.globalize_path(path))
