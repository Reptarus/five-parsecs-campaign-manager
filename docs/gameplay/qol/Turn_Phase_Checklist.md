# Turn Phase Checklist System

**Priority**: P1 - High | **Effort**: 2-3 days | **Phase**: 1

## Overview
Prevent forgotten steps with phase-by-phase validation. Context-sensitive guidance ensures players don't skip critical actions like upkeep, patron checks, or story track progression.

## Key Features
- Required vs Optional action tracking
- Can't advance until required items checked
- Context-sensitive suggestions
- New player guidance mode
- Veteran toggle (disable/minimize help)

## Phase Checklist Example
```
UPKEEP PHASE ✓ 2/3 Required, 1/2 Optional
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Required Actions:
  ✓ Pay crew upkeep (-50 credits)
  ✓ Pay ship maintenance (-25 credits)
  ✗ Resolve injuries (2 crew wounded) ⚠️

Optional Actions:
  ✓ Check for story events
  ✗ Purchase equipment

[Cannot Advance - Resolve injuries first]
```

## Implementation
```gdscript
# TurnPhaseChecklist.gd
class_name TurnPhaseChecklist

func get_phase_checklist(phase: GamePhase) -> Dictionary
func mark_action_complete(action_id: String) -> void
func can_advance_phase() -> bool
func get_incomplete_required_actions() -> Array
```

##Phase Definitions
```gdscript
const PHASE_CHECKLISTS = {
    GamePhase.UPKEEP: {
        "required": ["pay_crew", "pay_ship", "resolve_injuries"],
        "optional": ["check_story", "purchase_equipment"]
    },
    GamePhase.WORLD_STEPS: {
        "required": ["patron_jobs", "enemy_encounter_check"],
        "optional": ["hire_crew", "trade_goods", "repair_ship"]
    },
    # ... etc
}
```

## UI Integration
- Expandable checklist panel in CampaignDashboard
- Per-phase display
- Progress bar showing completion
- "What's Next?" button for guidance

---
**Status**: Ready to implement
