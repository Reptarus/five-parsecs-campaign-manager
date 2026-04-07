extends Node

## Tracks user acceptance of EULA, privacy policy, and analytics consent.
## Provides data export and deletion for GDPR/CCPA compliance.
## Persists state to user://legal_consent.cfg.

signal consent_updated

const CONSENT_FILE := "user://legal_consent.cfg"
const EULA_VERSION := "1.0"
const PRIVACY_VERSION := "1.0"

# Consent state
var eula_accepted: bool = false
var eula_accepted_version: String = ""
var eula_accepted_timestamp: String = ""
var privacy_accepted: bool = false
var privacy_accepted_version: String = ""
var privacy_accepted_timestamp: String = ""
var analytics_consent: bool = false


func _ready() -> void:
	_load_consent()


func needs_legal_consent() -> bool:
	if not eula_accepted:
		return true
	if eula_accepted_version != EULA_VERSION:
		return true
	if not privacy_accepted:
		return true
	if privacy_accepted_version != PRIVACY_VERSION:
		return true
	return false


func accept_eula() -> void:
	eula_accepted = true
	eula_accepted_version = EULA_VERSION
	eula_accepted_timestamp = Time.get_datetime_string_from_system(true)
	_save_consent()
	consent_updated.emit()


func accept_privacy() -> void:
	privacy_accepted = true
	privacy_accepted_version = PRIVACY_VERSION
	privacy_accepted_timestamp = Time.get_datetime_string_from_system(true)
	_save_consent()
	consent_updated.emit()


func set_analytics_consent(enabled: bool) -> void:
	analytics_consent = enabled
	_save_consent()
	consent_updated.emit()


func get_analytics_consent() -> bool:
	return analytics_consent


func export_user_data() -> Dictionary:
	## Collects all user:// files into a manifest dictionary for GDPR portability.
	var manifest := {
		"export_date": Time.get_datetime_string_from_system(true),
		"app_version": ProjectSettings.get_setting("application/config/version", "unknown"),
		"files": []
	}

	var user_dir := DirAccess.open("user://")
	if not user_dir:
		return manifest

	_collect_files_recursive(user_dir, "user://", manifest["files"])
	return manifest


func delete_all_user_data() -> void:
	## Deletes all user:// files and resets consent state.
	## Caller is responsible for showing confirmation dialog first.
	var user_dir := DirAccess.open("user://")
	if not user_dir:
		return

	_delete_recursive(user_dir, "user://")

	# Reset in-memory state
	eula_accepted = false
	eula_accepted_version = ""
	eula_accepted_timestamp = ""
	privacy_accepted = false
	privacy_accepted_version = ""
	privacy_accepted_timestamp = ""
	analytics_consent = false

	consent_updated.emit()


# --- Private ---

func _load_consent() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONSENT_FILE)
	if err != OK:
		return

	eula_accepted = config.get_value("eula", "accepted", false)
	eula_accepted_version = config.get_value("eula", "version", "")
	eula_accepted_timestamp = config.get_value("eula", "timestamp", "")
	privacy_accepted = config.get_value("privacy", "accepted", false)
	privacy_accepted_version = config.get_value("privacy", "version", "")
	privacy_accepted_timestamp = config.get_value("privacy", "timestamp", "")
	analytics_consent = config.get_value("analytics", "consent", false)


func _save_consent() -> void:
	var config := ConfigFile.new()
	config.set_value("eula", "accepted", eula_accepted)
	config.set_value("eula", "version", eula_accepted_version)
	config.set_value("eula", "timestamp", eula_accepted_timestamp)
	config.set_value("privacy", "accepted", privacy_accepted)
	config.set_value("privacy", "version", privacy_accepted_version)
	config.set_value("privacy", "timestamp", privacy_accepted_timestamp)
	config.set_value("analytics", "consent", analytics_consent)
	config.save(CONSENT_FILE)


func _collect_files_recursive(dir: DirAccess, base_path: String, files_array: Array) -> void:
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := base_path.path_join(file_name)
		if dir.current_is_dir():
			var sub_dir := DirAccess.open(full_path)
			if sub_dir:
				_collect_files_recursive(sub_dir, full_path, files_array)
		else:
			var file_info := {
				"path": full_path,
				"size_bytes": FileAccess.get_file_as_bytes(full_path).size()
			}
			files_array.append(file_info)
		file_name = dir.get_next()
	dir.list_dir_end()


func _delete_recursive(dir: DirAccess, base_path: String) -> void:
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := base_path.path_join(file_name)
		if dir.current_is_dir():
			var sub_dir := DirAccess.open(full_path)
			if sub_dir:
				_delete_recursive(sub_dir, full_path)
			dir.remove(file_name)
		else:
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
