extends Node
class_name BugReportWebhook

## Posts a tester bug report to a Discord channel via webhook.
##
## Payload shape and colour conventions match the After Midnight Tavern
## alerting module (`tcgprecon/src/lib/discord/alerts.ts`), so both projects
## read the same way in Discord.
##
## THE GUARANTEE: this never blocks and never loses a report. BugReportStore
## has already written the report to disk before this is called, so a failed
## POST costs nothing. Mirrors the tcgprecon rule "all functions swallow
## errors — alerts must never block order processing".
##
## SECURITY NOTE: unlike tcgprecon, which posts server-side from a Worker, this
## app SHIPS TO TESTERS. Any webhook URL compiled into the build is extractable
## from the APK, and whoever extracts it can post arbitrary content to that
## channel. Use a DEDICATED webhook pointed at a private alpha channel so it can
## be revoked in isolation. Never reuse a storefront/orders webhook here.
##
## The URL is read from a gitignored `.cfg` at the project root.
## Absent URL == feature simply off; the report still saves and copies.
##
## WHY A .cfg AND NOT .env.local: Godot packs non-resource files into an export
## only if they match the preset's `include_filter`, which on the Android preset
## is `*.tscn, *.json, *.gd, *.tres, *.cfg, *.md, *.txt`. A file named
## `.env.local` matches none of those, so it would be absent from the APK and
## the webhook would silently never fire on device while working fine on
## desktop. `.cfg` matches, and mirrors `addons/talo/settings.cfg`.

const CONFIG_FILE := "res://support_config.cfg"
const CONFIG_SECTION := "discord"
const CONFIG_KEY := "bug_reports_webhook"

## Discord embed colour, matching tcgprecon's COLOR.ERROR (0xef4444, red).
const COLOR_BUG := 0xef4444

## Discord hard-caps an embed field value at 1024 chars and the whole embed
## description at 4096. Truncate rather than have the POST rejected wholesale.
const FIELD_LIMIT := 1000
const DESC_LIMIT := 3500

signal post_completed(success: bool, status_code: int)

var _http: HTTPRequest


## Returns the configured webhook URL, or "" when unset.
## ConfigFile.load() works against res:// inside an exported PCK/APK, unlike
## FileAccess on some platforms, so this reads correctly on device.
static func get_webhook_url() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_FILE) != OK:
		return ""
	return str(cfg.get_value(CONFIG_SECTION, CONFIG_KEY, ""))


static func is_configured() -> bool:
	return get_webhook_url().begins_with("https://")


## Fire-and-forget POST. Caller adds this node to the tree; it frees itself
## when the request completes. Returns false if it could not even start.
func post_report(report: Dictionary) -> bool:
	var url := get_webhook_url()
	if not url.begins_with("https://"):
		# Not an error: the webhook is simply not configured in this build.
		post_completed.emit(false, 0)
		return false

	_http = HTTPRequest.new()
	# The settings overlay pauses the tree; the POST must still complete.
	_http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	var body := JSON.stringify(build_payload(report))
	var err := _http.request(
		url,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		push_warning("BugReportWebhook: request() failed with %d" % err)
		post_completed.emit(false, 0)
		queue_free()
		return false
	return true


func _on_request_completed(
	_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray
) -> void:
	# Discord returns 204 No Content on success.
	var ok := response_code >= 200 and response_code < 300
	if not ok:
		push_warning("BugReportWebhook: Discord returned %d" % response_code)
	post_completed.emit(ok, response_code)
	queue_free()


## Builds the Discord embed. Static and pure so it can be asserted on without
## any network access.
static func build_payload(report: Dictionary) -> Dictionary:
	var ctx: Dictionary = report.get("context", {}) if report.get("context") is Dictionary else {}

	var fields: Array = [
		{
			"name": "Version",
			"value": "%s (%s)" % [
				str(ctx.get("app_version", "?")), str(ctx.get("build_type", "?"))
			],
			"inline": true,
		},
		{
			"name": "Platform",
			"value": "%s / %s" % [
				str(ctx.get("platform", "?")), str(ctx.get("device_model", "?"))
			],
			"inline": true,
		},
		{"name": "Screen", "value": str(ctx.get("current_scene", "?")), "inline": true},
		{
			"name": "Campaign",
			"value": "%s — %s, turn %s" % [
				str(ctx.get("campaign_mode", "?")),
				str(ctx.get("phase", "?")),
				str(ctx.get("turn_cpm", "?")),
			],
			"inline": false,
		},
	]

	var steps := str(report.get("steps", "")).strip_edges()
	if not steps.is_empty():
		fields.append({
			"name": "Steps to reproduce",
			"value": _truncate(steps, FIELD_LIMIT),
			"inline": false,
		})

	var contact := str(report.get("reporter_contact", "")).strip_edges()
	if not contact.is_empty():
		fields.append({"name": "From", "value": _truncate(contact, 200), "inline": false})

	var log_lines: Variant = report.get("log_tail", [])
	var log_count := 0
	if log_lines is PackedStringArray:
		log_count = (log_lines as PackedStringArray).size()
	elif log_lines is Array:
		log_count = (log_lines as Array).size()
	if log_count > 0:
		fields.append({
			"name": "Log tail (last %d lines)" % log_count,
			"value": _truncate("```\n%s\n```" % _last_lines(log_lines, 12), FIELD_LIMIT),
			"inline": false,
		})

	return {
		"embeds": [{
			"title": "Bug Report — %s" % str(report.get("category", "Other")),
			"description": _truncate(str(report.get("what_happened", "")), DESC_LIMIT),
			"color": COLOR_BUG,
			"fields": fields,
			"timestamp": str(ctx.get("timestamp", Time.get_datetime_string_from_system(true))),
			"footer": {"text": "Five Parsecs Campaign Manager — closed alpha"},
		}]
	}


## Only the tail of the log goes to Discord; the full log is in the saved JSON
## and on the tester's clipboard. Keeps the embed under Discord's field cap.
static func _last_lines(log_lines: Variant, count: int) -> String:
	var arr: Array = []
	if log_lines is PackedStringArray:
		for l in (log_lines as PackedStringArray):
			arr.append(str(l))
	elif log_lines is Array:
		for l in (log_lines as Array):
			arr.append(str(l))
	if arr.size() > count:
		arr = arr.slice(arr.size() - count)
	return "\n".join(PackedStringArray(arr))


static func _truncate(text: String, limit: int) -> String:
	if text.length() <= limit:
		return text
	return text.substr(0, limit - 3) + "..."
