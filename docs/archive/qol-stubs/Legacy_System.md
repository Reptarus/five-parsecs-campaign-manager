# Legacy & Retirement System

**Priority**: P3 - Low | **Effort**: 2-3 days | **Phase**: 3

## Overview
Archive completed campaigns and retired crews. Hall of Fame showcases legendary characters, import veterans as NPCs in new campaigns.

## Key Features
- Campaign archival (preserve entire campaign state)
- Crew statistics preservation
- Hall of Fame (greatest achievements)
- Import veterans as NPCs
- Cross-campaign legacy bonuses

## Hall of Fame Display
```
┌──────────────────────────────────────────────────────┐
│ 🏆 Hall of Fame                                      │
├──────────────────────────────────────────────────────┤
│ Campaign: "Iron Will"                                │
│ Turns Survived: 47                                   │
│ Story Points: 5/5 ✓ VICTORY                          │
│ Ended: 2025-11-15                                    │
│                                                       │
│ Legendary Crew:                                      │
│ • "Iron" Jack Morrison (Captain) - 47 turns         │
│ • Elena "Torch" Rodriguez - 42 turns                │
│ • Deceased: Kira "Deadeye" Chen - Heroic (15 turns) │
│                                                       │
│ Achievements:                                        │
│ ⭐ Never Lost a Battle (23 battles)                  │
│ ⭐ Millionaire Crew (1,247 credits peak)             │
│ 💀 Defeated Rival: Red Hand Gang                    │
│                                                       │
│ [View Full History] [Import as NPCs] [Share]        │
└──────────────────────────────────────────────────────┘
```

## Implementation
```gdscript
# LegacySystem.gd
func archive_campaign(campaign_id: String) -> bool
func get_hall_of_fame() -> Array[Dictionary]
func import_veteran_as_npc(character_id: String, campaign_id: String) -> Character
func calculate_legacy_bonus(archived_campaign: Dictionary) -> int
```

---
**Status**: Post-launch feature
