extends GdUnitTestSuite
## The Bug Hunt / Tactics / Planetfall launch dialog on the main menu (UX-4).
##
## It was three hand copies, so a touch, keyboard or backdrop fix landed in one and
## never reached the other two. These cases hold the one helper to the routing each
## copy had: Continue and Load hand the save's path to the mode's own loader, New
## goes to the mode's own creation route, and the backdrop goes away.

const MenuScene := preload("res://src/ui/screens/mainmenu/MainMenu.tscn")

const MODES := {
	"bug_hunt": "Bug Hunt",
	"tactics": "Tactics",
	"planetfall": "Planetfall",
}

var _consent_backup := {}


## Records what a dialog button ran, so a press can be checked without loading a save
## or leaving the menu.
class Recorder extends RefCounted:
	var loads: Array = []
	var news := 0
	func on_load(path: String) -> void:
		loads.append(path)
	func on_new() -> void:
		news += 1


## The real handlers, with the dispatch recorded instead of run. A detached instance:
## the wrappers touch nothing in the scene, so no _ready() is needed.
class MenuProbe extends "res://src/ui/screens/mainmenu/MainMenu.gd":
	var launched: Array = []
	func _launch_mode(mode_id: String) -> void:
		launched.append(mode_id)


## Same consent stub as test_main_menu_coming_soon.gd: in-memory fields only, so the
## menu builds instead of routing to the EULA, and no consent is written to disk.
func before() -> void:
	var consent: Node = Engine.get_main_loop().root.get_node_or_null("/root/LegalConsentManager")
	if consent == null:
		return
	_consent_backup = {
		"eula_accepted": consent.eula_accepted,
		"eula_accepted_version": consent.eula_accepted_version,
		"privacy_accepted": consent.privacy_accepted,
		"privacy_accepted_version": consent.privacy_accepted_version,
	}
	consent.eula_accepted = true
	consent.eula_accepted_version = consent.EULA_VERSION
	consent.privacy_accepted = true
	consent.privacy_accepted_version = consent.PRIVACY_VERSION


func after() -> void:
	var consent: Node = Engine.get_main_loop().root.get_node_or_null("/root/LegalConsentManager")
	if consent == null or _consent_backup.is_empty():
		return
	for key: String in _consent_backup:
		consent.set(key, _consent_backup[key])


func _menu() -> Node:
	var m: Node = auto_free(MenuScene.instantiate())
	add_child(m)
	return m


func _saves(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append({"name": "Save %d" % i, "turn": i + 1, "path": "user://saves/s%d.save" % i})
	return out


func _buttons(dialog: Node) -> Array:
	return dialog.find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return not b.text.is_empty() and b.text != "Cancel")


func _settle() -> void:
	# close_then acts 0.05 s after the press.
	await get_tree().create_timer(0.15).timeout
	await get_tree().process_frame


func test_each_mode_has_its_own_title_route_and_loader() -> void:
	var m := _menu()
	for mode: String in MODES:
		var spec: Dictionary = m._MODE_LAUNCH[mode]
		assert_str(str(spec["title"])).is_equal(MODES[mode])
		assert_str(str(spec["creation"])).override_failure_message(
			"%s would start the wrong mode's creation" % mode).is_equal(mode + "_creation")
		var loader: Callable = m._mode_loader(mode)
		assert_bool(loader.is_valid()).is_true()
		assert_str(str(loader.get_method())).override_failure_message(
			"%s would load its save through another mode's loader" % mode) \
			.is_equal("_load_%s_save" % mode)
	assert_int((m._MODE_LAUNCH as Dictionary).size()).is_equal(MODES.size())


func test_each_menu_button_launches_its_own_mode() -> void:
	var probe: MenuProbe = auto_free(MenuProbe.new())
	probe._on_bug_hunt_pressed()
	probe._on_tactics_pressed()
	probe._on_planetfall_pressed()
	assert_array(probe.launched).is_equal(["bug_hunt", "tactics", "planetfall"])


func test_the_dialog_offers_continue_three_loads_and_new() -> void:
	var m := _menu()
	var rec := Recorder.new()
	var dialog: AcceptDialog = m._show_mode_launch_dialog(
		"Tactics", _saves(6), rec.on_new, rec.on_load)
	assert_str(dialog.title).is_equal("Tactics")
	var texts: Array = _buttons(dialog).map(func(b: Button) -> String: return b.text)
	assert_array(texts).is_equal([
		"Continue: Save 0 (Turn 1)",
		"Load: Save 1 (Turn 2)",
		"Load: Save 2 (Turn 3)",
		"Load: Save 3 (Turn 4)",
		"New Tactics Campaign",
	])
	assert_bool(m._active_dialogs.has(dialog)).is_true()


func test_continue_loads_the_newest_save() -> void:
	var m := _menu()
	var rec := Recorder.new()
	var dialog: AcceptDialog = m._show_mode_launch_dialog(
		"Bug Hunt", _saves(3), rec.on_new, rec.on_load)
	(_buttons(dialog)[0] as Button).pressed.emit()
	await _settle()
	assert_array(rec.loads).is_equal(["user://saves/s0.save"])
	assert_int(rec.news).is_equal(0)
	assert_object(m.find_child("__mode_launch_backdrop", true, false)).is_null()


func test_load_passes_that_rows_save() -> void:
	var m := _menu()
	var rec := Recorder.new()
	var dialog: AcceptDialog = m._show_mode_launch_dialog(
		"Planetfall", _saves(3), rec.on_new, rec.on_load)
	(_buttons(dialog)[2] as Button).pressed.emit()
	await _settle()
	assert_array(rec.loads).is_equal(["user://saves/s2.save"])
	assert_int(rec.news).is_equal(0)


func test_new_starts_creation_and_drops_the_backdrop() -> void:
	var m := _menu()
	var rec := Recorder.new()
	var dialog: AcceptDialog = m._show_mode_launch_dialog(
		"Bug Hunt", _saves(1), rec.on_new, rec.on_load)
	var buttons := _buttons(dialog)
	assert_int(buttons.size()).is_equal(2)
	(buttons.back() as Button).pressed.emit()
	await _settle()
	assert_int(rec.news).is_equal(1)
	assert_array(rec.loads).is_empty()
	assert_object(m.find_child("__mode_launch_backdrop", true, false)).is_null()


func test_cancel_drops_the_backdrop_and_runs_nothing() -> void:
	var m := _menu()
	var rec := Recorder.new()
	var dialog: AcceptDialog = m._show_mode_launch_dialog(
		"Tactics", _saves(2), rec.on_new, rec.on_load)
	assert_object(m.find_child("__mode_launch_backdrop", true, false)).is_not_null()
	dialog.canceled.emit()
	await _settle()
	assert_object(m.find_child("__mode_launch_backdrop", true, false)).is_null()
	assert_array(rec.loads).is_empty()
	assert_int(rec.news).is_equal(0)
