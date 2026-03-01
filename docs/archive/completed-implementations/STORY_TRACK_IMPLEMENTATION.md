# Story Track Implementation Guide

## Overview

The Story Track system provides a curated vertical slice of the Five Parsecs Campaign Manager, serving dual purposes:
1. **Development Validation**: End-to-end test of the complete campaign loop
2. **User Onboarding**: Guided tutorial teaching game mechanics progressively

## Architecture

### Core Components

| Component | File | Purpose |
|-----------|------|---------|
| StoryTrackSystem | `src/core/story/StoryTrackSystem.gd` | Manages story state, events, evidence, clock |
| StoryMissionLoader | `src/core/story/StoryMissionLoader.gd` | Loads/validates JSON mission files |
| TutorialCoordinator | `src/core/tutorial/TutorialCoordinator.gd` | Orchestrates tutorial components |
| TutorialOverlay | `src/ui/components/tutorial/TutorialOverlay.gd` | Mobile-responsive tutorial UI |
| StoryTextFormatter | `src/ui/components/story/StoryTextFormatter.gd` | Keyword integration for story text |

### Story Mission JSON Files

Located in `data/story_track_missions/`:

| Mission | File | Event ID | Difficulty |
|---------|------|----------|------------|
| 1 | `mission_01_discovery.json` | discovery_signal | 1 |
| 2 | `mission_02_contact.json` | first_contact | 2 |
| 3 | `mission_03_conspiracy.json` | conspiracy_revealed | 3 |
| 4 | `mission_04_personal.json` | personal_connection | 3 |
| 5 | `mission_05_hunt.json` | hunt_begins | 4 |
| 6 | `mission_06_confrontation.json` | final_confrontation | 5 |

### Phase Integration

```
Campaign Creation (Guided Mode)
        ↓
   WorldPhase ←────── Story Mission Injection (priority job offer)
        ↓
   BattlePhase ←───── Curated Content (fixed enemies/terrain)
        ↓
  PostBattlePhase ←── Evidence Tracking + Story Progression
        ↓
    (repeat until 6 missions complete)
        ↓
  Story Track Complete → Sandbox Mode Unlocks
```

## Mission JSON Schema

```json
{
  "mission_id": "story_mission_01",
  "story_event_id": "discovery_signal",
  "title": "Mysterious Signal",
  "mission_number": 1,
  "narrative": {
    "intro": "Story introduction text...",
    "briefing": "Mission briefing...",
    "completion_success": "Victory narrative...",
    "completion_failure": "Defeat narrative..."
  },
  "battlefield": {
    "size": {"x": 15, "y": 15},
    "theme": "industrial_ruins",
    "terrain_features": [
      {"type": "full_cover", "position": {"x": 5, "y": 5}, "description": "Rusted container"}
    ],
    "deployment_zones": {
      "crew": {"x_min": 0, "x_max": 3, "y_min": 6, "y_max": 9},
      "enemy": {"x_min": 12, "x_max": 15, "y_min": 0, "y_max": 15}
    }
  },
  "enemies": {
    "category": "gangers",
    "fixed_count": 5,
    "composition": [
      {"type": "ganger_grunt", "count": 4, "stats": {...}},
      {"type": "ganger_leader", "count": 1, "stats": {...}}
    ],
    "ai_behavior": "aggressive"
  },
  "objectives": {
    "primary": {"type": "investigate", "description": "..."},
    "secondary": {"type": "hold_field", "rounds": 1}
  },
  "rewards": {
    "credits_base": 3,
    "evidence_base": 1,
    "loot_opportunities": 2
  },
  "tutorial_hints": ["BattleJournal", "ObjectiveDisplay"],
  "difficulty_rating": 1
}
```

## Evidence System

### Calculation Rules
- **Victory**: 2 evidence pieces
- **Defeat**: 1 evidence piece
- **Held Field Bonus**: +1 evidence piece

### Story Clock
- Starts at 6 ticks
- Advances by 1 each campaign turn
- Additional pressure mechanics for dramatic tension

## Tutorial Integration

### Responsive Layouts
- **Mobile (<600px)**: Bottom sheet (60% height)
- **Tablet (600-900px)**: Side panel (30% width)
- **Desktop (>900px)**: Contextual popover

### Touch Targets
- Minimum: 48dp
- Comfortable: 56dp
- All interactive elements comply with accessibility guidelines

### Swipe Gestures
- Bottom sheet: Swipe down to dismiss
- Side panel: Swipe right to dismiss
- Velocity threshold: 500px/s
- Distance threshold: 100px

## Keyword System Integration

Story text automatically links game terms to the KeywordDB. Terms are rendered as clickable BBCode links that show tooltips with definitions.

### Usage
```gdscript
var formatted_text = StoryTextFormatter.format_story_text(raw_text)
rich_text_label.bbcode_text = formatted_text
```

## Testing

### Unit Tests
- `tests/unit/test_story_mission_loader.gd` (13 tests)
- `tests/unit/test_story_track_integration.gd` (13 tests)

### E2E Integration Tests
- `tests/integration/test_story_track_e2e.gd` (13 tests)

### Test Coverage
- Mission loading and validation
- Phase integration (World/Battle/Post-Battle)
- Evidence calculation
- Story progression
- Save/load persistence
- Difficulty progression
- Sandbox mode unlock

## Phase Handler Code Locations

### WorldPhase.gd
- Story mission injection: `_load_story_mission_offer()` (~line 1020)
- Priority job offer logic: `_generate_job_offers()` (~line 956)

### BattlePhase.gd
- Story track detection: `_determine_deployment_conditions()` (~line 199)
- Curated setup: `_setup_story_battle()` (~line 156)
- Enemy generation: `_generate_story_enemies()` (~line 234)

### PostBattlePhase.gd
- Story outcome processing: `_process_story_mission_outcome()` (~line 82)
- Completion handling: `_complete_story_track()` (~line 162)

## Signals

### StoryTrackSystem
- `story_event_triggered(event_id: String)`
- `tutorial_requested(event_id: String, tools: Array, context: String)`
- `evidence_collected(total: int)`
- `story_clock_advanced(remaining: int)`
- `story_track_completed(completion_data: Dictionary)`

### PostBattlePhase
- `story_track_updated(progress: Dictionary)`
- `story_track_completed(completion_data: Dictionary)`

## Future Enhancements

1. **Balance Testing**: Manual playthrough of all 6 missions
2. **Performance Profiling**: Mobile device optimization
3. **Narrative Polish**: Additional dialogue and flavor text
4. **Analytics**: Tutorial completion tracking
