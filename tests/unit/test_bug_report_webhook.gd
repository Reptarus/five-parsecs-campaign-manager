extends GdUnitTestSuite
## The Discord payload is built statically and asserted here without touching
## the network. Two things must hold: the embed matches the After Midnight
## Tavern conventions so both projects read alike in Discord, and Discord's
## hard caps (1024 per field value, 4096 per description) are never exceeded —
## an oversized embed is rejected wholesale, which would silently lose reports.
##
## gdUnit4 v6.0.3 compatible.

const WebhookClass = preload("res://src/core/support/BugReportWebhook.gd")


func _sample(what: String = "Enemy count read 9 when the table says 6.") -> Dictionary:
	return {
		"category": "Wrong rule or number",
		"what_happened": what,
		"steps": "1. Start a battle\n2. Look at the count",
		"reporter_contact": "tester@example.com",
		"context": {
			"app_version": "0.9.7-dev", "build_type": "debug",
			"platform": "Android", "device_model": "Pixel 8",
			"current_scene": "campaign_dashboard", "campaign_mode": "five_parsecs",
			"phase": "BATTLE", "turn_cpm": 4,
			"timestamp": "2026-07-27T09:00:00",
		},
		"log_tail": PackedStringArray(["line 1", "line 2", "line 3"]),
	}


func _embed(report: Dictionary) -> Dictionary:
	var payload: Dictionary = WebhookClass.build_payload(report)
	return payload["embeds"][0]


# --- Shape matches the tcgprecon alerting conventions -----------------------

func test_payload_is_a_single_embed() -> void:
	var payload: Dictionary = WebhookClass.build_payload(_sample())
	assert_bool(payload.has("embeds")).is_true()
	assert_int((payload["embeds"] as Array).size()).is_equal(1)


func test_embed_carries_title_description_colour_and_footer() -> void:
	var e := _embed(_sample("Specific failure text."))
	assert_bool(str(e["title"]).contains("Wrong rule or number")).is_true()
	assert_str(str(e["description"])).is_equal("Specific failure text.")
	assert_int(int(e["color"])).is_equal(WebhookClass.COLOR_BUG)
	assert_bool(str(e["footer"]["text"]).contains("closed alpha")).is_true()
	assert_str(str(e["timestamp"])).is_equal("2026-07-27T09:00:00")


func test_embed_reports_the_triage_context() -> void:
	# These four are what makes a report actionable without a follow-up question.
	var e := _embed(_sample())
	var joined := ""
	for f in (e["fields"] as Array):
		joined += "%s=%s;" % [str(f["name"]), str(f["value"])]
	assert_bool(joined.contains("0.9.7-dev")).is_true()
	assert_bool(joined.contains("Pixel 8")).is_true()
	assert_bool(joined.contains("campaign_dashboard")).is_true()
	assert_bool(joined.contains("BATTLE")).is_true()


func test_optional_fields_are_omitted_when_blank() -> void:
	var report := _sample()
	report["steps"] = ""
	report["reporter_contact"] = ""
	report["log_tail"] = PackedStringArray()
	var names := ""
	for f in (_embed(report)["fields"] as Array):
		names += str(f["name"]) + ";"
	assert_bool(names.contains("Steps to reproduce")).is_false()
	assert_bool(names.contains("From")).is_false()
	assert_bool(names.contains("Log tail")).is_false()


# --- Discord's hard caps ----------------------------------------------------

func test_description_stays_under_the_discord_cap() -> void:
	var e := _embed(_sample("x".repeat(10000)))
	assert_int(str(e["description"]).length()).is_less_equal(WebhookClass.DESC_LIMIT)


func test_every_field_value_stays_under_the_discord_cap() -> void:
	var report := _sample()
	report["steps"] = "y".repeat(10000)
	var big_log := PackedStringArray()
	for i in 400:
		big_log.append("log line %d with a fair amount of padding text" % i)
	report["log_tail"] = big_log
	for f in (_embed(report)["fields"] as Array):
		assert_int(str(f["value"]).length()).is_less_equal(WebhookClass.FIELD_LIMIT)


func test_only_the_log_tail_goes_to_discord_not_the_whole_log() -> void:
	# The full log rides on the clipboard and the saved JSON; Discord gets a
	# readable excerpt so the embed stays inside the cap.
	var report := _sample()
	var big_log := PackedStringArray()
	for i in 200:
		big_log.append("line %d" % i)
	report["log_tail"] = big_log
	var value := ""
	var name := ""
	for f in (_embed(report)["fields"] as Array):
		if str(f["name"]).begins_with("Log tail"):
			name = str(f["name"])
			value = str(f["value"])
	assert_bool(value.contains("line 199")).is_true()  # the newest lines
	assert_bool(value.contains("line 0\n")).is_false()  # not the oldest
	assert_bool(name.contains("200 lines")).is_true()  # full count in the header


# --- Degrades safely when unconfigured --------------------------------------

func test_is_configured_is_false_without_a_url() -> void:
	# The repo must never ship a webhook URL; support_config.cfg is gitignored,
	# so in a clean checkout this is false and the reporter falls back to
	# save + clipboard.
	var configured: bool = WebhookClass.is_configured()
	var url: String = WebhookClass.get_webhook_url()
	assert_bool(configured).is_equal(url.begins_with("https://"))


func test_config_file_extension_survives_the_android_include_filter() -> void:
	# REGRESSION: the config was originally `.env.local`, which matches NONE of
	# the Android preset's include_filter globs
	# ("*.tscn, *.json, *.gd, *.tres, *.cfg, *.md, *.txt"). It would have been
	# absent from the APK, so the webhook would silently never fire on device
	# while working perfectly on desktop. The extension is load-bearing.
	assert_bool(WebhookClass.CONFIG_FILE.ends_with(".cfg")).is_true()


func test_missing_config_file_is_not_an_error() -> void:
	# A clean checkout has no support_config.cfg at all. Reading it must return
	# "" rather than pushing an error, or every dev build spams the console.
	if FileAccess.file_exists(WebhookClass.CONFIG_FILE):
		return  # a local config exists; nothing to assert here
	assert_str(WebhookClass.get_webhook_url()).is_equal("")
	assert_bool(WebhookClass.is_configured()).is_false()


func test_post_report_returns_false_when_unconfigured() -> void:
	if WebhookClass.is_configured():
		return  # a local .env.local exists; nothing to assert here
	var poster: Node = auto_free(WebhookClass.new())
	add_child(poster)
	await get_tree().process_frame
	assert_bool(poster.post_report(_sample())).is_false()


func test_build_payload_tolerates_a_missing_context() -> void:
	var payload: Dictionary = WebhookClass.build_payload({"what_happened": "bare"})
	assert_object(payload).is_not_null()
	assert_int((payload["embeds"] as Array).size()).is_equal(1)
