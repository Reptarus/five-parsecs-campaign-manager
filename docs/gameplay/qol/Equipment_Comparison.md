# Equipment Comparison Tool

**Priority**: P2 - Medium | **Effort**: 2-3 days | **Phase**: 2

## Overview
Side-by-side weapon and armor comparison with stat highlighting, cost/benefit analysis, and character-specific recommendations.

## Key Features
- Compare up to 3 items simultaneously
- Highlight better/worse stats (green/red)
- Cost/benefit calculator
- Character-specific recommendations
- "Best for [Character Type]" suggestions

## Comparison UI
```
┌──────────────────────────────────────────────────────┐
│ Equipment Comparison                      [×]        │
├──────────────────────────────────────────────────────┤
│           Laser Rifle  Plasma Rifle  Auto Cannon    │
│ Cost         8 cr         18 cr        14 cr        │
│ Range        24"          18"          12"          │
│ Shots        1            1            3 ✓          │
│ Damage       +0           +1 ✓         +0           │
│ Traits       -            AP(1) ✓      Heavy        │
│                                                      │
│ Best For: Plasma Rifle (high-skill shooters)        │
│ Budget Pick: Laser Rifle                            │
│                                                      │
│ [Add to Wishlist] [Buy] [Close]                     │
└──────────────────────────────────────────────────────┘
```

## Implementation
```gdscript
# EquipmentComparisonTool.gd
func compare_weapons(weapons: Array[GameWeapon]) -> Dictionary
func compare_armor(armor_pieces: Array[GameArmor]) -> Dictionary
func get_recommendation(items: Array, character: Character) -> String
func calculate_cost_benefit(item: Variant, current_item: Variant) -> float
```

---
**Status**: Post-beta feature
