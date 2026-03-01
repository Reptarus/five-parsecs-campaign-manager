# NPC Persistence System

**Priority**: P0 - Critical | **Effort**: 4-5 days | **Phase**: 1

## Overview
Track Patrons, Rivals, and visited Locations across the entire campaign. Remember NPCs at each location, facility availability, and relationship progression.

## Key Features
- **Patron Job History**: Track jobs offered, accepted, completed, failed
- **Rival Encounter Tracking**: Remember every confrontation, escalation
- **Location Memory**: NPCs met, facilities visited, reputation changes
- **Relationship Progression**: Favor tracking, faction standing
- **Galaxy Map Integration**: Visual representation of visited systems

## Data Structure
```gdscript
# Patron tracking
{
    "patron_id": "marcus_vex",
    "name": "Marcus Vex",
    "location": "Trade Station Alpha",
    "relationship": 3,  # -5 (hostile) to +5 (allied)
    "jobs_offered": 7,
    "jobs_completed": 5,
    "jobs_failed": 1,
    "favors_owed": 1,
    "last_contact_turn": 15,
    "history": [
        {"turn": 5, "event": "job_offered", "job_type": "patrol"},
        {"turn": 6, "event": "job_completed", "payment": 400}
    ]
}

# Location tracking
{
    "location_id": "station_alpha",
    "name": "Trade Station Alpha",
    "visits": 5,
    "first_visit_turn": 1,
    "last_visit_turn": 15,
    "reputation": 2,  # Local standing
    "npcs_met": ["marcus_vex", "dr_silva", "quartermaster_jones"],
    "facilities": {
        "market": true,
        "hospital": true,
        "shipyard": false
    },
    "rumors": ["rival_activity", "new_patron_available"]
}
```

## Implementation
**Files**: `src/qol/NPCPersistence.gd`, `src/ui/components/qol/NPCTrackerPanel.gd`

**Core Methods**:
```gdscript
func track_patron_interaction(patron_id, event_type, data)
func track_rival_encounter(rival_id, battle_result)
func visit_location(location_id)
func get_patron_relationship(patron_id) -> int
func get_location_history(location_id) -> Dictionary
```

## Integration Points
- `PatronJobGenerator.gd` - Auto-track job offers
- `RivalManager.gd` - Auto-track encounters  
- `TravelPhaseUI.gd` - Auto-track location visits

## UI Components
- NPC relationship panel (patrons/rivals)
- Location history browser
- Galaxy map with visit markers
- Reputation tracker

---
**Status**: Ready to implement after Campaign Journal
