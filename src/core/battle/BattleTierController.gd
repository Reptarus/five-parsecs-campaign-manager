class_name FPCM_BattleTierController
extends Resource

## Battle Tier Controller - Three-Tier Tracking System
##
## Controls which UI components and features are active during battle.
## Three tiers of companion assistance:
## - LOG_ONLY: Minimal tracking. Player handles the rules, app keeps notes.
## - ASSISTED: Prompts for rules, events, morale. Tracks unit status.
## - FULL_ORACLE: AI oracle tells player what enemies do on the physical table.
##
## Reference: Five Parsecs From Home - Tabletop Companion Philosophy
## "Every feature must answer: How does this help the player at the physical table?"

signal tier_changed(old_tier: int, new_tier: int)

enum TrackingTier {
	LOG_ONLY = 0,
	ASSISTED = 1,
	FULL_ORACLE = 2
}

## Components enabled per tier. StringName keys match component node names.
## Each tier includes all components from lower tiers.
const TIER_COMPONENTS: Dictionary = {
	TrackingTier.LOG_ONLY: [
		&"BattleJournal",
		&"DiceDashboard",
		&"BattleRoundHUD",
		&"CharacterStatusCard",
		&"CombatCalculator",
	],
	TrackingTier.ASSISTED: [
		# Includes all LOG_ONLY components plus:
		&"MoralePanicTracker",
		&"ActivationTrackerPanel",
		&"DeploymentConditionsPanel",
		&"InitiativeCalculator",
		&"EventResolutionPanel",
		&"ObjectiveDisplay",
		&"PreBattleChecklist",
	],
	TrackingTier.FULL_ORACLE: [
		# Includes all ASSISTED components plus:
		&"EnemyIntentPanel",
		&"EnemyGenerationWizard",
	],
}

## Feature flags per tier
const TIER_FEATURES: Dictionary = {
	TrackingTier.LOG_ONLY: {
		"auto_event_prompts": false,
		"morale_prompts": false,
		"ai_oracle": false,
		"escalation": false,
		"deployment_suggestions": false,
		"phase_reminders": false,
		"casualty_tracking": true,
		"dice_rolling": true,
	},
	TrackingTier.ASSISTED: {
		"auto_event_prompts": true,
		"morale_prompts": true,
		"ai_oracle": false,
		"escalation": true,
		"deployment_suggestions": true,
		"phase_reminders": true,
		"casualty_tracking": true,
		"dice_rolling": true,
	},
	TrackingTier.FULL_ORACLE: {
		"auto_event_prompts": true,
		"morale_prompts": true,
		"ai_oracle": true,
		"escalation": true,
		"deployment_suggestions": true,
		"phase_reminders": true,
		"casualty_tracking": true,
		"dice_rolling": true,
	},
}

## Tier display info for UI
const TIER_INFO: Dictionary = {
	TrackingTier.LOG_ONLY: {
		"name": "Log Only",
		"description": "Minimal tracking. You handle the rules - I'll keep notes and roll dice.",
		"icon_hint": "notebook",
	},
	TrackingTier.ASSISTED: {
		"name": "Assisted",
		"description": "I'll remind you of rules, prompt for events and morale, and track unit status.",
		"icon_hint": "compass",
	},
	TrackingTier.FULL_ORACLE: {
		"name": "Full Oracle",
		"description": "I'll tell you what the enemies do, draw from the AI oracle, and manage everything.",
		"icon_hint": "crystal_ball",
	},
}

@export var current_tier: int = TrackingTier.LOG_ONLY

## Set tracking tier. Can only upgrade mid-battle (never downgrade).
## Set force to true to allow setting any tier (e.g., at battle start).
func set_tier(tier: int, force: bool = false) -> bool:
	if tier < TrackingTier.LOG_ONLY or tier > TrackingTier.FULL_ORACLE:
		push_warning("BattleTierController: Invalid tier value: %d" % tier)
		return false

	if not force and tier < current_tier:
		push_warning("BattleTierController: Cannot downgrade tier mid-battle (%d -> %d)" % [current_tier, tier])
		return false

	if tier == current_tier:
		return true

	var old_tier := current_tier
	current_tier = tier
	tier_changed.emit(old_tier, current_tier)
	return true

## Get all components enabled for the current tier (cumulative).
func get_enabled_components() -> Array[StringName]:
	var components: Array[StringName] = []
	for tier_level: int in range(current_tier + 1):
		var tier_components: Array = TIER_COMPONENTS.get(tier_level, [])
		for comp: StringName in tier_components:
			if comp not in components:
				components.append(comp)
	return components

## Check if a specific component is enabled at current tier.
func is_component_enabled(component_name: StringName) -> bool:
	return component_name in get_enabled_components()

## Check if a specific feature flag is enabled at current tier.
func is_feature_enabled(feature_name: String) -> bool:
	var features: Dictionary = TIER_FEATURES.get(current_tier, {})
	return features.get(feature_name, false)

## Get display info for a specific tier.
func get_tier_info(tier: int = -1) -> Dictionary:
	if tier < 0:
		tier = current_tier
	return TIER_INFO.get(tier, {})

## Get the current tier enum value.
func get_current_tier() -> int:
	return current_tier

## Serialize for save/load.
func serialize() -> Dictionary:
	return {
		"current_tier": current_tier,
	}

## Deserialize from save data.
func deserialize(data: Dictionary) -> void:
	current_tier = data.get("current_tier", TrackingTier.LOG_ONLY)
