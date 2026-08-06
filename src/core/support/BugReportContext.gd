extends RefCounted
class_name BugReportContext

## Collects the runtime context attached to a tester bug report.
##
## All-static, no UI dependency, so it is unit-testable headless. Every read is
## null-guarded: this runs at the moment something has already gone wrong, and
## it must never be the thing that crashes the app it is reporting on.
##
## Autoloads are reached via `Engine.get_main_loop().root.get_node_or_null()`
## because a RefCounted is not in the scene tree and cannot call get_node().
##
## See docs/sop/visual-runtime-verification.md for how a report is verified.

## Default engine log path. `project.godot [logging] file_logging/enable_file_logging`
## is true with no path override, so Godot writes here. Resolved through
## ProjectSettings at call time so an override is picked up automatically.
const DEFAULT_LOG_PATH := "user://logs/godot.log"

const DEFAULT_LOG_TAIL_LINES := 100


## Returns an autoload node or null. Safe from a detached RefCounted.
static func _autoload(node_name: String) -> Node:
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	var root := (loop as SceneTree).root
	if root == null:
		return null
	return root.get_node_or_null("/root/" + node_name)


## Full context dictionary. Never raises; missing sources are simply absent
## or reported as "unknown".
static func collect() -> Dictionary:
	var ctx := {}
	_collect_build(ctx)
	_collect_device(ctx)
	_collect_location(ctx)
	_collect_campaign(ctx)
	ctx["timestamp"] = Time.get_datetime_string_from_system(true)
	return ctx


static func _collect_build(ctx: Dictionary) -> void:
	ctx["app_version"] = str(
		ProjectSettings.get_setting("application/config/version", "unknown")
	)
	ctx["build_type"] = "debug" if OS.is_debug_build() else "release"
	var engine_info: Dictionary = Engine.get_version_info()
	ctx["engine"] = str(engine_info.get("string", "unknown"))


static func _collect_device(ctx: Dictionary) -> void:
	ctx["platform"] = OS.get_name()
	# Never called anywhere else in this project. On Android/iOS this is the
	# device model; on desktop it returns "GenericDevice".
	ctx["device_model"] = OS.get_model_name()
	ctx["window_size"] = str(DisplayServer.window_get_size())
	ctx["screen_size"] = str(DisplayServer.screen_get_size())

	var rm := _autoload("ResponsiveManager")
	if rm and rm.has_method("get_effective_columns"):
		ctx["effective_columns"] = int(rm.get_effective_columns())
	if rm and rm.has_method("is_portrait"):
		ctx["orientation"] = "portrait" if rm.is_portrait() else "landscape"


static func _collect_location(ctx: Dictionary) -> void:
	# SceneRouter.current_scene goes stale when a screen bypasses navigate_to(),
	# so fall back to the live scene's file path (what SceneRouter._ready does).
	var router := _autoload("SceneRouter")
	var scene_key := ""
	if router and router.has_method("get_current_scene"):
		scene_key = str(router.get_current_scene())
	if scene_key.is_empty():
		var loop := Engine.get_main_loop()
		if loop is SceneTree:
			var live: Node = (loop as SceneTree).current_scene
			if live:
				scene_key = live.scene_file_path if not live.scene_file_path.is_empty() else live.name
	ctx["current_scene"] = scene_key if not scene_key.is_empty() else "unknown"

	if router and router.has_method("get_navigation_history"):
		var history: Array = router.get_navigation_history()
		if history.size() > 5:
			history = history.slice(history.size() - 5)
		ctx["navigation_history"] = ", ".join(PackedStringArray(history))


static func _collect_campaign(ctx: Dictionary) -> void:
	# CampaignPhaseManager fields are plain vars, safe with no campaign loaded.
	var cpm := _autoload("CampaignPhaseManager")
	if cpm:
		var phase: int = int(cpm.get("current_phase"))
		ctx["phase"] = _phase_name(phase)
		ctx["sub_phase"] = int(cpm.get("current_sub_phase"))
		ctx["transition_in_progress"] = bool(cpm.get("transition_in_progress"))
		ctx["turn_cpm"] = int(cpm.get("turn_number"))

	var gs := _autoload("GameState")
	if gs and gs.has_method("get_turn_number"):
		ctx["turn_gamestate"] = int(gs.get_turn_number())

	var campaign = null
	if gs and gs.has_method("get_current_campaign"):
		campaign = gs.get_current_campaign()
	if campaign == null:
		ctx["campaign_mode"] = "none"
		return

	# The _campaign_mode idiom from CampaignScreenBase.gd:143-148.
	# str()-wrapped because BaseCampaign declares campaign_type as an int.
	var mode := "five_parsecs"
	if "campaign_type" in campaign:
		mode = str(campaign.campaign_type)
	ctx["campaign_mode"] = mode

	# Read the raw fields. get_campaign_id() is a mutating getter that assigns
	# when empty, which a diagnostic read must not do.
	if "campaign_name" in campaign:
		ctx["campaign_name"] = str(campaign.campaign_name)
	if "campaign_id" in campaign:
		ctx["campaign_id"] = str(campaign.campaign_id)

	# progress_data["turns_played"] is the authoritative counter per
	# GameState.gd:1364-1379. Divergence between the three is itself a signal.
	if "progress_data" in campaign and campaign.progress_data is Dictionary:
		ctx["turn_progress_data"] = int(campaign.progress_data.get("turns_played", -1))

	var analytics := _autoload("CampaignAnalytics")
	if analytics:
		var session: Variant = analytics.get("session_data")
		if session is Dictionary:
			ctx["session_id"] = str((session as Dictionary).get("session_id", ""))


static func _phase_name(phase: int) -> String:
	if GameEnums.PHASE_NAMES.has(phase):
		return str(GameEnums.PHASE_NAMES[phase])
	return "phase_%d" % phase


## Returns the last `max_lines` lines of the engine log, or an empty array if
## the log is unavailable. The engine holds this file open while running; a
## read-only open alongside that is fine, but any failure is swallowed.
##
## NOTE: DebugScreen._log_buffer looks like the right source but is never
## written to from anywhere in src/, so it is always empty. This reads the
## real engine log instead.
static func read_log_tail(max_lines: int = DEFAULT_LOG_TAIL_LINES) -> PackedStringArray:
	var out := PackedStringArray()
	if max_lines <= 0:
		return out

	var path := str(
		ProjectSettings.get_setting("debug/file_logging/log_path", DEFAULT_LOG_PATH)
	)
	if path.is_empty():
		path = DEFAULT_LOG_PATH
	if not FileAccess.file_exists(path):
		return out

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out

	var ring := PackedStringArray()
	while not f.eof_reached():
		var line := f.get_line()
		ring.append(line)
		if ring.size() > max_lines:
			ring.remove_at(0)
	f.close()

	# Drop trailing blank lines so the report does not end in whitespace.
	while ring.size() > 0 and ring[ring.size() - 1].strip_edges().is_empty():
		ring.remove_at(ring.size() - 1)
	return ring
