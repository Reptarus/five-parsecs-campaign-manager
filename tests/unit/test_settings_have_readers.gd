extends GdUnitTestSuite
## Sprint 7b: the Settings screen offers only settings something reads.
##
## THE DEFECT THIS PINS. Screen Shake and Touch Sensitivity were rows on the
## Settings screen, saved to user://options.cfg, and changed nothing. Screen
## Shake's one reader gated TweenFX.shake(), which nothing calls, and
## touch_sensitivity had no reader at all. Moving either control changed
## nothing. The rows are gone, and a value an older build saved is erased on load,
## so the file stops describing a setting the app does not have.
##
## Correction, kept because it is the trap: the Screen Shake gate DID exist, in a
## project edit to addons/TweenFX/TweenFX.gd. Nothing calls shake(), so the toggle
## still changed nothing, but deleting the getter alone would have left that gate
## calling a method that no longer exists. The gate now follows Reduced Motion.
##
## THE MIRROR, found the same day. Battle Events (Core Rules p.116, "optional")
## and Critical Hit (Compendium p.100, "an additional optional rule") had live
## readers in the battle screen and no control, so one was stuck on and the other
## stuck off. And Reset to Defaults left the Connections rows and the table-size
## picker showing their old values over a file that held the defaults.

const SettingsManagerScript := preload("res://src/autoload/SettingsManager.gd")
const MANAGER_PATH := "res://src/autoload/SettingsManager.gd"
const SCREEN_PATH := "res://src/ui/screens/settings/SettingsScreen.gd"
const TWEENFX_PATH := "res://addons/TweenFX/TweenFX.gd"

## What a reader of a retired key looks like in source. `"auto_save"` is quoted
## so the zero-caller notify_auto_save() toast helper does not match.
const RETIRED_WORDS := ["screen_shake", "touch_sensitivity", "\"auto_save\"",
	"is_auto_save_enabled", "auto_save_enabled", "func auto_save("]

## Keys the Settings screen does not write, each with the file that does.
const WRITTEN_ELSEWHERE := {
	"gameplay/last_tracking_tier": ["res://src/ui/screens/battle/PreBattleUI.gd",
		"sm.set_last_tracking_tier("],
	"gameplay/last_combat_mode": ["res://src/ui/screens/battle/PreBattleUI.gd",
		"sm.set_last_combat_mode("],
	"support/reporter_contact": ["res://src/ui/components/common/BugReportDialog.gd",
		"const SETTINGS_KEY := \"reporter_contact\""],
}


func _text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).override_failure_message("premise: %s opens" % path).is_not_null()
	return f.get_as_text() if f else ""


func _function_body(source: String, header: String) -> String:
	var start := source.find(header)
	if start < 0:
		return ""
	var stop := source.find("\nfunc ", start + header.length())
	return source.substr(start, (stop - start) if stop > 0 else -1)


func _names_a_retired_key(line: String) -> bool:
	for word: String in RETIRED_WORDS:
		if line.contains(word):
			return true
	return false


func _scripts_under(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scripts_under(dir_path.path_join(sub), out)
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))


func test_dropping_erases_only_the_retired_keys() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("gameplay", "screen_shake", false)
	cfg.set_value("mobile", "touch_sensitivity", 1.4)
	cfg.set_value("gameplay", "auto_save", false)
	cfg.set_value("gameplay", "show_tooltips", false)
	cfg.set_value("mobile", "haptic_feedback", false)
	assert_bool(SettingsManagerScript.drop_retired_keys(cfg)).is_true()
	assert_bool(cfg.has_section_key("gameplay", "screen_shake")).is_false()
	assert_bool(cfg.has_section_key("mobile", "touch_sensitivity")).is_false()
	assert_bool(cfg.has_section_key("gameplay", "auto_save")).is_false()
	assert_bool(cfg.get_value("gameplay", "show_tooltips", true)).override_failure_message(
		"a live setting keeps the player's value").is_false()
	assert_bool(cfg.get_value("mobile", "haptic_feedback", true)).is_false()
	assert_bool(SettingsManagerScript.drop_retired_keys(cfg)).override_failure_message(
		"a second pass finds nothing to drop, so the file is not re-saved").is_false()


func test_loading_a_saved_file_drops_the_retired_keys() -> void:
	var body := _function_body(_text(MANAGER_PATH), "func _load_with_migration() -> void:")
	assert_str(body).override_failure_message("premise: the load function is found").is_not_empty()
	assert_str(body).contains("if drop_retired_keys(_config):")
	assert_int(body.find("if drop_retired_keys(_config):")).override_failure_message(
		"the drop runs before the legacy-section return, or most loads skip it").is_less(
			body.find("if not _config.has_section(LEGACY_SECTION):"))


func test_no_default_restores_a_retired_key() -> void:
	assert_int(SettingsManagerScript.RETIRED_KEYS.size()).is_equal(3)
	# The legacy [options] migration runs after the drop, so a retired key there
	# would be written straight back.
	for legacy_key: String in SettingsManagerScript.LEGACY_KEY_MAP:
		var dest: Array = SettingsManagerScript.LEGACY_KEY_MAP[legacy_key]
		assert_bool(SettingsManagerScript.RETIRED_KEYS.has(dest)).override_failure_message(
			"the legacy migration restores %s/%s" % [dest[0], dest[1]]).is_false()
	for pair: Array in SettingsManagerScript.RETIRED_KEYS:
		var section: Dictionary = SettingsManagerScript.DEFAULTS.get(pair[0], {})
		assert_bool(section.has(pair[1])).override_failure_message(
			"Reset to Defaults would write %s/%s back" % [pair[0], pair[1]]).is_false()


func test_the_screen_offers_neither_control() -> void:
	var screen := _text(SCREEN_PATH)
	for word in ["Screen Shake", "Touch Sensitivity", "Auto-Save", "screen_shake",
			"touch_sensitivity", "auto_save"]:
		assert_bool(screen.contains(word)).override_failure_message(
			"SettingsScreen still names %s" % word).is_false()
	assert_str(screen).override_failure_message(
		"the card keeps its one live control, under a name that says what it holds").contains(
			"_create_section_card(\"Haptics\", parent)")


func test_the_shake_gate_follows_reduced_motion() -> void:
	var body := _function_body(_text(TWEENFX_PATH), "func shake(")
	assert_str(body).override_failure_message("premise: shake() is found").is_not_empty()
	assert_str(body).contains("if tm and tm.is_reduced_animation_enabled():")


## The addon is walked as well as src/: the shake gate lives in a project edit to
## TweenFX, and the first search for readers missed it by looking in src/ only.
func test_nothing_reads_a_retired_key() -> void:
	var scripts: Array[String] = []
	_scripts_under("res://src", scripts)
	assert_int(scripts.size()).override_failure_message("premise: src/ is walked").is_greater(400)
	assert_bool(TWEENFX_PATH in scripts).is_false()
	_scripts_under("res://addons/TweenFX", scripts)
	assert_bool(TWEENFX_PATH in scripts).override_failure_message(
		"premise: the TweenFX addon is walked").is_true()
	var hits: Array[String] = []
	for path in scripts:
		var lines := _text(path).split("\n")
		var in_retired_list := false  # inside SettingsManager's RETIRED_KEYS literal
		for i in lines.size():
			var line := lines[i]
			if path == MANAGER_PATH and line.begins_with("const RETIRED_KEYS"):
				in_retired_list = not line.ends_with("]")
				continue
			if in_retired_list:
				in_retired_list = line != "]"
				continue
			if not _names_a_retired_key(line):
				continue
			hits.append("%s:%d" % [path, i + 1])
	assert_array(hits).override_failure_message(
		"a retired key is read again; give it a real consumer and take it off RETIRED_KEYS: %s"
		% ", ".join(hits)).is_empty()


## The body of the function that calls reset_to_defaults(): the screen's Reset.
func _reset_body(screen: String) -> String:
	var at := screen.find("_sm.reset_to_defaults()")
	if at < 0:
		return ""
	var start := screen.rfind("\nfunc ", at)
	var stop := screen.find("\nfunc ", at)
	return screen.substr(start, (stop - start) if stop > 0 else -1)


func test_every_setting_has_a_control_or_a_named_writer() -> void:
	var screen := _text(SCREEN_PATH)
	var missing: Array[String] = []
	for section: String in SettingsManagerScript.DEFAULTS:
		for key: String in SettingsManagerScript.DEFAULTS[section]:
			var id := "%s/%s" % [section, key]
			if WRITTEN_ELSEWHERE.has(id):
				var where: Array = WRITTEN_ELSEWHERE[id]
				assert_str(_text(where[0])).override_failure_message(
					"%s is said to be written by %s" % [id, where[0]]).contains(where[1])
				continue
			if not screen.contains("\"%s\", \"%s\"" % [section, key]):
				missing.append(id)
	assert_array(missing).override_failure_message(
		"a setting a player cannot change is fixed at its default: %s" % ", ".join(missing)
	).is_empty()


func test_reset_redraws_every_control_it_resets() -> void:
	var screen := _text(SCREEN_PATH)
	var body := _reset_body(screen)
	assert_str(body).override_failure_message("premise: the Reset function is found").is_not_empty()
	var regex := RegEx.new()
	regex.compile("_bind_(toggle|slider)\\((_\\w+),")
	var bound := regex.search_all(screen)
	assert_int(bound.size()).override_failure_message(
		"premise: bound rows are found").is_greater(8)
	var stale: Array[String] = []
	for m in bound:
		var control: String = m.get_string(2)
		if not (body.contains(control + ".button_pressed =") or body.contains(control + ".value =")):
			stale.append(control)
	assert_array(stale).override_failure_message(
		"Reset writes the default and leaves these showing the old value: %s" % ", ".join(stale)
	).is_empty()
	assert_str(body).override_failure_message(
		"the table-size picker is not bound, so it is checked by name").contains(
			"_table_size_option.select(i)")
