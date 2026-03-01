class_name CampaignCreationFeatureFlags
extends RefCounted

## Feature flags for Campaign Creation system
## Controls feature rollouts and emergency disabling

# Feature flag enumeration - moved to top level for static access
enum {
	SECURITY_FOUNDATION,
	NEW_ANIMATION_SAFETY,
	ANIMATION_SAFETY,
	UI_STATE_MACHINE,
	PANEL_VALIDATION,
	ROLLBACK_SYSTEM
}

# Feature flags state - maps enum values to boolean states
static var _flags: Dictionary = {
	SECURITY_FOUNDATION: true,
	NEW_ANIMATION_SAFETY: true,
	ANIMATION_SAFETY: true,
	UI_STATE_MACHINE: true,
	PANEL_VALIDATION: true,
	ROLLBACK_SYSTEM: true
}

static func emergency_disable_all() -> void:
	## Emergency disable all feature flags for safety
	for flag in _flags:
		_flags[flag] = false
	print("CampaignCreationFeatureFlags: All features disabled for safety")

static func is_enabled(flag: Variant) -> bool:
	## Check if a feature flag is enabled - accepts enum or string
	if flag is String:
		# Legacy string support - convert to enum if possible
		match flag:
			"security_foundation":
				return _flags.get(SECURITY_FOUNDATION, false)
			"new_animation_safety":
				return _flags.get(NEW_ANIMATION_SAFETY, false)
			"animation_safety":
				return _flags.get(ANIMATION_SAFETY, false)
			"ui_state_machine":
				return _flags.get(UI_STATE_MACHINE, false)
			"panel_validation":
				return _flags.get(PANEL_VALIDATION, false)
			"rollback_system":
				return _flags.get(ROLLBACK_SYSTEM, false)
			_:
				return false
	else:
		# Enum value
		return _flags.get(flag, false)

static func enable_flag(flag: Variant) -> void:
	## Enable a specific feature flag - accepts enum or string
	if flag is String:
		# Legacy string support - convert to enum if possible
		match flag:
			"security_foundation":
				_flags[SECURITY_FOUNDATION] = true
			"new_animation_safety":
				_flags[NEW_ANIMATION_SAFETY] = true
			"animation_safety":
				_flags[ANIMATION_SAFETY] = true
			"ui_state_machine":
				_flags[UI_STATE_MACHINE] = true
			"panel_validation":
				_flags[PANEL_VALIDATION] = true
			"rollback_system":
				_flags[ROLLBACK_SYSTEM] = true
	else:
		# Enum value
		_flags[flag] = true

static func disable_flag(flag: Variant) -> void:
	## Disable a specific feature flag - accepts enum or string
	if flag is String:
		# Legacy string support - convert to enum if possible
		match flag:
			"security_foundation":
				_flags[SECURITY_FOUNDATION] = false
			"new_animation_safety":
				_flags[NEW_ANIMATION_SAFETY] = false
			"animation_safety":
				_flags[ANIMATION_SAFETY] = false
			"ui_state_machine":
				_flags[UI_STATE_MACHINE] = false
			"panel_validation":
				_flags[PANEL_VALIDATION] = false
			"rollback_system":
				_flags[ROLLBACK_SYSTEM] = false
	else:
		# Enum value
		_flags[flag] = false