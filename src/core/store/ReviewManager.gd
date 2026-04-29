extends Node

## ReviewManager - Cross-platform in-app review prompts.
## Autoloaded singleton. Do NOT add class_name (autoload provides global name).
##
## Supports:
## - Android/iOS: InappReviewPlugin (Google Play Review API / StoreKit)
## - Steam: Opens store page via Steam overlay
## - Offline: No-op (desktop without Steam, editor)
##
## Review timing: prompts after MIN_TURNS_BEFORE_REVIEW campaign turns,
## respects REVIEW_COOLDOWN_DAYS between prompts. Persists to ConfigFile.

signal review_flow_completed()
signal review_flow_failed(reason: String)

## Replace with real Steam App ID before release.
const STEAM_APP_ID := "STEAM_APP_ID_PLACEHOLDER"

## Minimum campaign turns before first review prompt.
const MIN_TURNS_BEFORE_REVIEW := 5
## Days between review prompts.
const REVIEW_COOLDOWN_DAYS := 30
## Persistence path.
const PREFS_PATH := "user://review_prefs.cfg"

var _review_node: Node = null  # InappReview instance (Android/iOS)
var _steam: Object = null
var _platform: String = ""  # "mobile", "steam", "offline"
var _last_review_timestamp: int = 0
var _turns_completed: int = 0
var _review_in_progress: bool = false
## Flag set after a DLC purchase — prompt review on next turn completion.
var _purchased_recently: bool = false

var _platform_initialized: bool = false

func _ready() -> void:
	_platform = _detect_platform()
	# Lazy-init: defer the plugin/Steam singleton wiring until first use.
	# Signal connections + prefs MUST run now so turn-completion auto-prompts work.
	_load_prefs()
	_connect_game_signals()

# ── Platform detection ─────────────────────────────────────────────

func _detect_platform() -> String:
	var os_name := OS.get_name()
	match os_name:
		"Android", "iOS":
			if Engine.has_singleton("InappReviewPlugin"):
				return "mobile"
			return "offline"
		"Windows", "Linux", "macOS":
			if Engine.has_singleton("Steam"):
				return "steam"
			return "offline"
		_:
			return "offline"

func _ensure_platform_initialized() -> void:
	if _platform_initialized:
		return
	_platform_initialized = true
	_init_platform()

func _init_platform() -> void:
	match _platform:
		"mobile":
			# Create InappReview child node — it connects to the native plugin
			var review_script: GDScript = load(
				"res://addons/InappReviewPlugin/InappReview.gd") as GDScript
			if review_script:
				_review_node = review_script.new() as Node
				if _review_node:
					_review_node.name = "InappReview"
					add_child(_review_node)
					# Connect review signals
					if _review_node.has_signal("review_info_generated"):
						_review_node.review_info_generated.connect(
							_on_review_info_generated)
					if _review_node.has_signal("review_info_generation_failed"):
						_review_node.review_info_generation_failed.connect(
							_on_review_info_generation_failed)
					if _review_node.has_signal("review_flow_launched"):
						_review_node.review_flow_launched.connect(
							_on_review_flow_launched)
					if _review_node.has_signal("review_flow_launch_failed"):
						_review_node.review_flow_launch_failed.connect(
							_on_review_flow_launch_failed)
				else:
					push_warning("ReviewManager: Failed to create InappReview node")
			else:
				push_warning("ReviewManager: InappReview.gd not found")
		"steam":
			_steam = Engine.get_singleton("Steam")

# ── Public API ─────────────────────────────────────────────────────

func is_review_available() -> bool:
	## Returns true if the platform supports review prompts.
	return _platform != "offline"

func can_request_review() -> bool:
	## Returns true if eligible for a review prompt (cooldown + min turns).
	if not is_review_available():
		return false
	if _review_in_progress:
		return false
	if _turns_completed < MIN_TURNS_BEFORE_REVIEW:
		return false
	if _last_review_timestamp > 0:
		var now := int(Time.get_unix_time_from_system())
		var elapsed_days := (now - _last_review_timestamp) / 86400
		if elapsed_days < REVIEW_COOLDOWN_DAYS:
			return false
	return true

func request_review() -> void:
	## Trigger the platform-specific review flow.
	## On mobile: 2-step generate_review_info → launch_review_flow.
	## On Steam: opens store page in overlay.
	## Respects cooldown — call can_request_review() to check eligibility.
	if _review_in_progress:
		return
	_ensure_platform_initialized()
	match _platform:
		"mobile":
			if _review_node and _review_node.has_method("generate_review_info"):
				_review_in_progress = true
				_review_node.generate_review_info()
			else:
				review_flow_failed.emit("InappReview node not available")
		"steam":
			_open_steam_store_page()
			_record_review_prompt()
			review_flow_completed.emit()
		_:
			review_flow_failed.emit("Reviews not available on this platform")

func notify_turn_completed(turn_number: int) -> void:
	## Called when a campaign turn completes. Increments counter and
	## auto-prompts a review if the player is eligible.
	_turns_completed = maxi(_turns_completed, turn_number)
	_save_prefs()
	# Auto-prompt if eligible (and recently purchased DLC, or just due)
	if can_request_review():
		if _purchased_recently or _turns_completed >= MIN_TURNS_BEFORE_REVIEW:
			_purchased_recently = false
			request_review()

func get_platform_name() -> String:
	return _platform

# ── Signal wiring to game systems ──────────────────────────────────

func _connect_game_signals() -> void:
	# CampaignPhaseManager — campaign turn completion
	var cpm := get_node_or_null("/root/CampaignPhaseManager")
	if cpm and cpm.has_signal("campaign_turn_completed"):
		cpm.campaign_turn_completed.connect(notify_turn_completed)

	# StoreManager — post-purchase flag for review timing
	var sm := get_node_or_null("/root/StoreManager")
	if sm and sm.has_signal("purchase_completed"):
		sm.purchase_completed.connect(_on_dlc_purchased)

func _on_dlc_purchased(_dlc_id: String) -> void:
	# Don't prompt immediately after purchase — set flag for next turn
	_purchased_recently = true

# ── Mobile review flow callbacks ───────────────────────────────────

func _on_review_info_generated() -> void:
	# Step 2: review info is ready, now launch the review dialog
	if _review_node and _review_node.has_method("launch_review_flow"):
		_review_node.launch_review_flow()

func _on_review_info_generation_failed() -> void:
	_review_in_progress = false
	review_flow_failed.emit("Failed to generate review info")

func _on_review_flow_launched() -> void:
	_review_in_progress = false
	_record_review_prompt()
	review_flow_completed.emit()

func _on_review_flow_launch_failed() -> void:
	_review_in_progress = false
	review_flow_failed.emit("Failed to launch review flow")

# ── Steam ──────────────────────────────────────────────────────────

func _open_steam_store_page() -> void:
	if _steam and _steam.has_method("activateGameOverlayToWebPage"):
		_steam.activateGameOverlayToWebPage(
			"https://store.steampowered.com/app/%s/" % STEAM_APP_ID)
	else:
		push_warning("ReviewManager: Steam overlay not available")

# ── Persistence ────────────────────────────────────────────────────

func _record_review_prompt() -> void:
	_last_review_timestamp = int(Time.get_unix_time_from_system())
	_save_prefs()

func _save_prefs() -> void:
	var config := ConfigFile.new()
	config.set_value("review", "last_prompt_timestamp", _last_review_timestamp)
	config.set_value("review", "turns_completed", _turns_completed)
	config.save(PREFS_PATH)

func _load_prefs() -> void:
	var config := ConfigFile.new()
	var err := config.load(PREFS_PATH)
	if err != OK:
		return
	_last_review_timestamp = config.get_value(
		"review", "last_prompt_timestamp", 0) as int
	_turns_completed = config.get_value(
		"review", "turns_completed", 0) as int