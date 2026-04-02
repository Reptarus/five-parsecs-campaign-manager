# Equipment Panel UX/UI Redesign Plan - Step 4 of 7

## Problem Summary
The current Equipment Panel (EquipmentPanel.gd, ~2115 lines) has major UX gaps: no weapon stats displayed, no Savvy substitution mechanic, opaque generation process, clunky dropdown-only assignment, hidden credit breakdown, and a misleading Generate button.

## Part 1: Three-Zone Layout Architecture

ZONE A (top ~100px): Generation Summary Bar with provenance tags, savvy prompt, credits breakdown, reroll buttons.
ZONE B (middle): HSplitContainer - Equipment Pool left 60% / Crew Loadouts right 40%.
ZONE C (bottom ~40px): Status footer with assignment count and validation.

## Part 2: Equipment Card Redesign with Stats

Collapsed card shows: [TypeBadge] Name | Rng:24 Sht:1 Dmg:+0 | [Assign To v]
Expanded card adds: full stats block, traits, description, source line, click-to-assign crew buttons.
Stats come from equipment_database.json via new _lookup_equipment_stats() helper.

## Part 3: Savvy Substitution (Core Rules p.28)

For each crew member with savvy > 0, allow swapping one Military Weapon for a High-Tech Weapon.
Show prompt in Zone A. Track in metadata.

## Part 4: Roll Provenance

Tag items with source/source_table/roll_number. Show as pill badges in Zone A and source line in cards.

## Part 5: Credits Breakdown

Track each credit contribution. Show expandable breakdown in Zone A.

## Part 6: Click-to-Assign

Primary: expand card, click crew member button. Secondary: dropdown retained inside expanded view. Stretch: drag-and-drop.

## Part 7: Auto-Generation

Auto-generate on step entry. Demote Generate button to Regenerate All.

## Part 8: Split Reroll

Two options: Reroll Shared Pool (8 items only) vs Reroll Everything (full reset).

## Implementation Phases

Phase 1: Stats Display + Source Metadata (highest impact)
Phase 2: Credits Breakdown
Phase 3: Savvy Substitution
Phase 4: Click-to-Assign
Phase 5: Generation Flow Cleanup
Phase 6: Drag-and-Drop (stretch)

## Critical Files

1. src/ui/screens/campaign/panels/EquipmentPanel.gd
2. src/ui/screens/campaign/panels/EquipmentPanel.tscn
3. src/core/character/Equipment/StartingEquipmentGenerator.gd
4. data/equipment_database.json (read only)
5. data/character_creation_tables/equipment_tables.json
