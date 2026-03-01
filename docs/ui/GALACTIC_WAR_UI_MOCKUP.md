# Galactic War Progress Panel - UI Mockup & Specifications

**Component**: GalacticWarProgressPanel  
**File**: `src/ui/components/campaign/GalacticWarProgressPanel.gd`  
**Date**: 2025-11-27  
**Designer**: UI Design System v1.0

## Mobile Layout (360×640px - Portrait)

```
┌─────────────────────────────────────────────────────────┐
│ ┌─ GalacticWarProgressPanel ─────────────────────────┐ │
│ │                                                     │ │
│ │  Galactic War Status                          [?]  │ │ ← Header (18pt, #E0E0E0)
│ │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │ │    Help button (48×48dp)
│ │                                                     │ │
│ │  ┌─ War Track Card ──────────────────────────────┐ │ │
│ │  │                                               │ │ │
│ │  │  Unity Expansion                      [8/20]  │ │ │ ← Track name (16pt)
│ │  │                                               │ │ │    Progress value (16pt #808080)
│ │  │  ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░   │ │ │ ← Progress bar
│ │  │  ◄──────────────────────────────────────────► │ │ │    Height: 8px
│ │  │  0        5        10       15       20        │ │ │    Filled: #2D5A7B
│ │  │           ▲        ▲        ▲        ▲         │ │ │    Empty: #1E1E36
│ │  │      Threshold markers                        │ │ │    Markers at 5,10,15,20
│ │  │                                               │ │ │
│ │  │  Next: Trade Route Occupation (10)           │ │ │ ← Next threshold (14pt #808080)
│ │  │                                               │ │ │
│ │  │  ┌─ Active Effects ────────────────────────┐ │ │ │
│ │  │  │ ⚠️ Border Skirmishes                    │ │ │ │ ← Warning badge
│ │  │  │                                         │ │ │ │    BG: rgba(215,119,6,0.2)
│ │  │  │ Unity patrols increase in border       │ │ │ │    Border: #D97706 1px
│ │  │  │ systems                                 │ │ │ │    Text: 11pt #E0E0E0
│ │  │  │                                         │ │ │ │    Padding: 8px
│ │  │  │ • Travel costs +20%                     │ │ │ │    Radius: 4px
│ │  │  │ • Encounter rate +15%                   │ │ │ │
│ │  │  └─────────────────────────────────────────┘ │ │ │
│ │  │                                               │ │ │
│ │  └───────────────────────────────────────────────┘ │ │
│ │                                                     │ │
│ │  ┌─ War Track Card ──────────────────────────────┐ │ │
│ │  │                                               │ │ │
│ │  │  Corporate Territorial War            [12/20] │ │ │
│ │  │                                               │ │ │
│ │  │  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░   │ │ │
│ │  │  ◄──────────────────────────────────────────► │ │ │
│ │  │  0        5        10       15       20        │ │ │
│ │  │           ▲        ▲        ▲        ▲         │ │ │
│ │  │                                               │ │ │
│ │  │  Next: Trade Embargo (15)                    │ │ │
│ │  │                                               │ │ │
│ │  │  ┌─ Active Effects ────────────────────────┐ │ │ │
│ │  │  │ ⚠️ Proxy Conflicts                      │ │ │ │
│ │  │  │                                         │ │ │ │
│ │  │  │ Corporations hire mercenaries for raids│ │ │ │
│ │  │  │                                         │ │ │ │
│ │  │  │ • Mercenary missions common            │ │ │ │
│ │  │  │ • Patron jobs +50% pay                 │ │ │ │
│ │  │  │ • Rival generation +20%                │ │ │ │
│ │  │  └─────────────────────────────────────────┘ │ │ │
│ │  │                                               │ │ │
│ │  └───────────────────────────────────────────────┘ │ │
│ │                                                     │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Design System Compliance

### Spacing (8px Grid)
- Panel Padding: 16px (SPACING_MD)
- Track Card Spacing: 24px (SPACING_LG) between cards
- Inner Card Padding: 16px (SPACING_MD)
- Element Gap: 8px (SPACING_SM) within cards
- Effect Badge Padding: 8px (SPACING_SM)

### Touch Targets
- Help Button: 48×48dp (TOUCH_TARGET_MIN) ✅
- Track Header: 48dp height ✅
- All interactive elements: ≥48dp ✅

### Typography Scale
- Panel Title: 18pt (FONT_SIZE_LG)
- Track Name: 16pt (FONT_SIZE_MD)
- Progress Value: 16pt (FONT_SIZE_MD)
- Next Threshold: 14pt (FONT_SIZE_SM)
- Effect Name: 14pt (FONT_SIZE_SM)
- Effect Details: 11pt (FONT_SIZE_XS)

### Color Palette
```
Panel Background: #252542 (COLOR_ELEVATED)
Card Background: #1A1A2E (COLOR_BASE)
Progress Bar Filled: #2D5A7B (track color)
Progress Bar Empty: #1E1E36 (COLOR_INPUT)
Text Primary: #E0E0E0
Text Secondary: #808080
Warning Badge BG: rgba(215, 119, 6, 0.2)
Warning Border: #D97706
```

## File References

### Created Files
1. `data/loot/battlefield_finds.json` (75 lines)
2. `data/campaign_tables/unique_individuals.json` (312 lines)
3. `data/galactic_war/war_progress_tracks.json` (314 lines)
4. `src/core/campaign/GalacticWarManager.gd` (400 lines)
5. `src/ui/components/campaign/GalacticWarProgressPanel.gd` (366 lines)
6. `docs/features/GALACTIC_WAR_SYSTEM.md` (353 lines)
7. `docs/ui/GALACTIC_WAR_UI_MOCKUP.md` (this file)

### Modified Files (Touch Target Fixes)
1. `src/ui/screens/campaign/TradingScreen.gd` (4 buttons: 36→48, 32→48, 32→48, 44→48)
2. `src/ui/screens/battle/PreBattleEquipmentUI.gd` (1 button: 40→48)

**Total Touch Target Violations Fixed**: 5
