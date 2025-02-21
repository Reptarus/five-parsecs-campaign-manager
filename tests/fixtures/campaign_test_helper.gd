@tool
extends GameTest
class_name CampaignTestHelper

# Constants for campaign testing
const DEFAULT_TIMEOUT := 1.0
const CAMPAIGN_SETUP_TIMEOUT := 2.0

# Constants for test campaign states
const TEST_CAMPAIGN_STATES := {
	"SETUP": {
		"phase": GameEnums.FiveParcsecsCampaignPhase.SETUP,
		"resources": {
			"credits": 100,
			"reputation": 0
		}
	},
	"STORY": {
		"phase": GameEnums.FiveParcsecsCampaignPhase.STORY,
		"resources": {
			"credits": 150,
			"reputation": 5
		}
	},
	"BATTLE": {
		"phase": GameEnums.FiveParcsecsCampaignPhase.BATTLE_SETUP,
		"resources": {
			"credits": 200,
			"reputation": 10
		}
	}
}

# Helper functions for campaign testing
func verify_campaign_phase_transition(campaign: Resource, from_phase: int, to_phase: int) -> void:
	assert_eq(_call_resource_method_int(campaign, "get_phase"), from_phase, "Campaign should start in correct phase")
	
	# Watch for phase change signals
	watch_signals(campaign)
	
	# Attempt phase transition
	_call_resource_method(campaign, "transition_to_phase", [to_phase])
	
	# Verify the phase changed
	assert_eq(_call_resource_method_int(campaign, "get_phase"), to_phase, "Campaign should transition to new phase")
	verify_signal_emitted(campaign, "phase_changed")

func verify_invalid_phase_transition(campaign: Resource, from_phase: int, to_phase: int) -> void:
	assert_eq(_call_resource_method_int(campaign, "get_phase"), from_phase, "Campaign should start in correct phase")
	
	# Watch for phase change signals
	watch_signals(campaign)
	
	# Attempt invalid phase transition
	_call_resource_method(campaign, "transition_to_phase", [to_phase])
	
	# Verify phase did not change
	assert_eq(_call_resource_method_int(campaign, "get_phase"), from_phase, "Campaign phase should not change")
	verify_signal_not_emitted(campaign, "phase_changed")

func verify_missing_signals(emitter: Object, expected_signals: Array) -> void:
	for signal_name in expected_signals:
		if not emitter.has_signal(signal_name):
			assert_false(true, "Missing required signal: %s" % signal_name)
		else:
			verify_signal_not_emitted(emitter, signal_name)
