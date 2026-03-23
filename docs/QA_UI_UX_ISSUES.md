# UI/UX Issues — Visual Audit Report

**Date**: 2026-03-23
**Method**: MCP-automated screenshots + structural `get_ui_elements` analysis
**Scope**: MainMenu, Campaign Creation (7 steps), Campaign Dashboard, Campaign Turn phases

---

## Issue Severity Guide

- **CRITICAL**: Blocks user from completing a core flow
- **HIGH**: Data flow bug visible in UI, or major theme violation
- **MEDIUM**: Visual inconsistency, usability friction
- **LOW**: Polish item, minor visual nit

---

## Issues Found

### ISSUE-001: MainMenu buttons below touch target minimum
- **Severity**: MEDIUM
- **Screen**: MainMenu
- **Description**: All 8 menu buttons are 45px height, 3px below the `TOUCH_TARGET_MIN` of 48px defined in BaseCampaignPanel.
- **Expected**: Buttons should be >= 48px for mobile accessibility.
- **Fix**: Increase `custom_minimum_size.y` to 48 in MainMenu.tscn or the button theme override.

### ISSUE-002: Campaign Creation Steps 2, 3, 6 use black background instead of COLOR_BASE
- **Severity**: HIGH
- **Screen**: CaptainPanel (Step 2), CrewPanel (Step 3), WorldInfoPanel (Step 6)
- **Description**: These panels use pure black (`#000000`) background instead of the Deep Space theme `COLOR_BASE` (`#1A1A2E`). Steps 1, 5, 7 correctly use `COLOR_BASE`. Step 4 (EquipmentPanel) also uses black.
- **Root Cause**: Steps 2, 3, 6 do not extend `FiveParsecsCampaignPanel` (BaseCampaignPanel), which sets the background color.
- **Fix**: Migrate CaptainPanel, CrewPanel, WorldInfoPanel to extend `FiveParsecsCampaignPanel` or manually set `COLOR_BASE` as the background.

### ISSUE-003: Campaign Creation Steps 2, 3, 6 lack card containers
- **Severity**: MEDIUM
- **Screen**: CaptainPanel, CrewPanel, WorldInfoPanel
- **Description**: Content displayed as plain unstyled text with no `PanelContainer` card wrappers. Contrast with Steps 1, 5, 7 which use `_create_section_card()` pattern with `COLOR_ELEVATED` backgrounds and `COLOR_BORDER` borders.
- **Fix**: Wrap content sections in PanelContainers using BaseCampaignPanel helper methods.

### ISSUE-004: Captain stats displayed as plain text
- **Severity**: MEDIUM
- **Screen**: CaptainPanel (Step 2) — after captain creation
- **Description**: Captain info shows as centered plain text: "Combat: 2  Reactions: 1  Toughness: 2". No stat badges, no visual hierarchy. Compare to Step 7 (FinalPanel) which uses `_create_stat_display()` badges beautifully.
- **Fix**: Use `_create_stats_grid()` or `_create_character_card()` from BaseCampaignPanel.

### ISSUE-005: Crew list displayed as plain text
- **Severity**: MEDIUM
- **Screen**: CrewPanel (Step 3) — after crew generation
- **Description**: Crew members shown as single lines of text ("Zephyr Mercer - Artist (Human)") with no cards, no stat preview, no visual distinction between members. Large empty space below the list.
- **Fix**: Use character cards with stat shorthand similar to the Dashboard's CREW MANIFEST section.

### ISSUE-006: Victory condition targets display floats instead of integers
- **Severity**: LOW
- **Screen**: ExpandedConfigPanel (Step 1) — Victory Conditions section
- **Description**: Target values show decimal points: "Target: 10000.0 credits", "Target: 3.0 factions", "Target: 20.0 worlds", "Target: 50.0 enemies", "Target: 5.0 missions".
- **Expected**: "Target: 10,000 credits", "Target: 3 factions", etc.
- **Fix**: Cast target values to `int()` before display, or use `"%.0f"` format string.

### ISSUE-007: Auto-Assign button clipped in Equipment Panel
- **Severity**: LOW
- **Screen**: EquipmentPanel (Step 4)
- **Description**: "Auto-Assign" button at top-right of the Available Equipment section appears to overflow its container.
- **Fix**: Check container sizing or button `custom_minimum_size`.

### ISSUE-008: Ship Traits section has no empty-state message
- **Severity**: LOW
- **Screen**: ShipPanel (Step 5)
- **Description**: "SHIP TRAITS" card is displayed but completely empty — no "No traits" message.
- **Fix**: Add "No special traits" placeholder text when traits array is empty.

### ISSUE-009: World Phase Market Prices section empty with no feedback
- **Severity**: LOW
- **Screen**: WorldInfoPanel (Step 6)
- **Description**: "Market Prices:" section header shown with nothing below it. Should either populate data or show "No market data available".
- **Fix**: Add empty-state message or hide section when no data.

### ISSUE-010: Inconsistent button styling across creation steps
- **Severity**: MEDIUM
- **Screen**: All Campaign Creation steps
- **Description**: Action buttons (Create Captain, Randomize, Generate Equipment, etc.) use a faint border-only style with minimal visual weight. Navigation buttons (Back, Next, Start Campaign) use the accent-colored filled style. The action buttons are the primary affordance on each step but look secondary.
- **Fix**: Apply accent fill styling to primary action buttons on each step.

### ISSUE-011: Dashboard shows "Unknown / Unknown" for crew origin/class
- **Severity**: HIGH
- **Screen**: CampaignDashboard — CREW MANIFEST
- **Description**: All 4 crew members show "Unknown / Unknown" beneath their names where origin and class should display. The data was correctly set during creation (e.g., "Precursor Working Class" for captain).
- **Root Cause**: Dashboard crew card rendering reads from different dict keys than what creation stores. Likely a key mismatch (e.g., `origin` vs `species`, `character_class` vs `class`).
- **Fix**: Audit the data keys used by CampaignDashboard crew rendering vs. what CampaignCreationCoordinator stores.

### ISSUE-012: Dashboard Equipment section empty
- **Severity**: HIGH
- **Screen**: CampaignDashboard — EQUIPMENT section
- **Description**: Equipment section shows header only, no items listed despite 4 items being generated and assigned in Step 4.
- **Root Cause**: Equipment data may not be flowing from creation coordinator to `campaign.equipment_data["equipment"]`, or the Dashboard reads from a different key.
- **Fix**: Trace equipment data flow from EquipmentPanel → CampaignCreationCoordinator → FiveParsecsCampaignCore → CampaignDashboard.

### ISSUE-013: Dashboard shows wrong difficulty
- **Severity**: MEDIUM
- **Screen**: CampaignDashboard — status bar
- **Description**: Status bar shows "Difficulty: Hard" but "Standard" was selected in Campaign Creation Step 1.
- **Root Cause**: Possible enum ordinal mapping issue. "Standard" in the UI dropdown may map to a different `DifficultyLevel` value than what the Dashboard reads.
- **Fix**: Verify the difficulty value stored in `campaign.difficulty` matches what the ExpandedConfigPanel selected.

### ISSUE-014: Companion Level dialog blocks navigation
- **Severity**: MEDIUM
- **Screen**: CampaignTurnController — World Phase
- **Description**: The "Choose Your Companion Level" dialog appears on campaign start but has no dismiss/close button. It overlays the Upkeep Phase content without a semi-transparent backdrop. The "Back to Dashboard" button doesn't work while the dialog is open.
- **Fix**: Add a backdrop overlay, and either auto-dismiss after selection or add a close button.

### ISSUE-015: Dashboard "Credits: 0" on new campaign
- **Severity**: MEDIUM
- **Screen**: CampaignDashboard — header
- **Description**: A brand new campaign shows 0 credits. Core Rules specify starting credits based on crew size and background.
- **Root Cause**: Starting credits may not be calculated during creation, or the calculation result isn't stored in `campaign.credits`.
- **Fix**: Verify starting credits calculation in CampaignCreationCoordinator.

### ISSUE-016: No max-width constraint on desktop layouts
- **Severity**: LOW
- **Screen**: Campaign Creation Steps 1, 5 (card panels), all full-width elements
- **Description**: All form elements and cards stretch to nearly full screen width (1792px on 1920 display). On widescreen monitors, this creates uncomfortably wide form fields and reading lines.
- **Expected**: Content should have a max-width (~1200px) and be centered on wide displays.
- **Fix**: Add `custom_maximum_size.x` or a CenterContainer with max-width to the main content area.

### ISSUE-017: Dashboard fuel shows dash
- **Severity**: LOW
- **Screen**: CampaignDashboard — SHIP section
- **Description**: Ship fuel displays "—" instead of a numeric value.
- **Fix**: Ensure fuel value is initialized during ship generation.

---

## Screens Audited

| Screen | Audited | Screenshot |
|--------|---------|------------|
| MainMenu | Yes | screenshot_1774298734_877.png |
| CC Step 1: Configuration | Yes | screenshot_1774299116_012.png |
| CC Step 2: Captain Creation (empty) | Yes | screenshot_1774299142_23.png |
| CC Step 2: Captain Creation (filled) | Yes | screenshot_1774299160_97.png |
| CC Step 3: Crew Setup (empty) | Yes | screenshot_1774299178_435.png |
| CC Step 3: Crew Setup (filled) | Yes | screenshot_1774299224_726.png |
| CC Step 4: Equipment Generation | Yes | screenshot_1774299238_183.png |
| CC Step 5: Ship Assignment | Yes | screenshot_1774299257_722.png |
| CC Step 6: World Generation | Yes | screenshot_1774299276_401.png |
| CC Step 7: Final Review | Yes | screenshot_1774299294_045.png |
| Campaign Turn Controller | Yes | screenshot_1774299328_638.png |
| Campaign Dashboard | Yes | screenshot_1774299392_414.png |
| Campaign Turn: Story Phase | Pending |  |
| Campaign Turn: Travel Phase | Pending |  |
| Campaign Turn: Upkeep Phase | Partial (behind dialog) |  |
| Campaign Turn: Mission Phase | Pending |  |
| Campaign Turn: Post-Mission Phase | Pending |  |
| Campaign Turn: Advancement Phase | Pending |  |
| Campaign Turn: Trading Phase | Pending |  |
| Campaign Turn: Character Phase | Pending |  |
| Campaign Turn: Retirement Phase | Pending |  |
| Battle UI (TacticalBattleUI) | Pending |  |
| Bug Hunt Creation | Pending |  |
| Bug Hunt Dashboard | Pending |  |
| Settings/Options | Pending |  |
| Library/Help | Pending |  |
| Save/Load | Pending |  |

---

## Summary Statistics

- **Total issues**: 17
- **CRITICAL**: 0
- **HIGH**: 5 (ISSUE-002, 011, 012, 018, 019)
- **MEDIUM**: 12
- **LOW**: 10
- **Touch target failures**: 1 (MainMenu buttons)
- **Theme compliance**: 8/21 screens fully compliant
- **Data flow bugs**: 5 (crew origin, equipment, difficulty, mission data, credits)

---

## Campaign Turn Phase Issues (ISSUE-018 onward)

### ISSUE-018: Travel Phase — completely off-theme
- **Severity**: HIGH
- **Screen**: TravelPhaseUI
- **Description**: Uses a mid-gray background (~#4A4A4A), not COLOR_BASE. Small centered 600x400 dialog-style box instead of full-width panel. "Back" and "Next" buttons are tiny dark squares, barely visible. Tab bar "Upkeep | Travel" has no visual styling.
- **Fix**: Rebuild TravelPhaseUI to use full-width PanelContainer layout with COLOR_BASE background, following WorldPhaseController's component pattern.

### ISSUE-019: Pre-Battle UI — gray background, empty panels
- **Severity**: HIGH
- **Screen**: PreBattleUI
- **Description**: Same gray background as TravelPhaseUI. Three-column layout (Mission Info, Battlefield Preview, Select Crew) but all sections empty with no data populated. "Back" and "Confirm Deployment" buttons are small and unstyled at bottom-right. No empty-state messages.
- **Fix**: Apply COLOR_BASE background. Add empty-state messages. Style buttons with accent fills.

### ISSUE-020: Story Phase — no skip/advance when no events
- **Severity**: MEDIUM
- **Screen**: StoryPhasePanel
- **Description**: Empty ItemList with no events generated (EventManager not found). "Resolve Event" button disabled. No way to skip or advance to next phase. User would be stuck.
- **Fix**: Add "No story events this turn — Continue" skip button or auto-advance when EventManager is unavailable.

### ISSUE-021: Story Phase — empty state not communicated
- **Severity**: LOW
- **Screen**: StoryPhasePanel
- **Description**: Empty ItemList shown as dark rectangle with no "No events this turn" message.
- **Fix**: Add empty-state placeholder text.

### ISSUE-022: Advancement Phase — crew not loaded
- **Severity**: MEDIUM
- **Screen**: AdvancementPhasePanel
- **Description**: Crew Members list is empty — panel doesn't receive crew data. Available Advancements also empty. "Select a crew member" prompt shown but no members exist to select.
- **Fix**: Ensure crew data flows into AdvancementPhasePanel when it becomes visible.

### ISSUE-023: Trade Phase — no items populated
- **Severity**: MEDIUM
- **Screen**: TradePhasePanel
- **Description**: "Available Items" and "Inventory" lists both empty. No market items generated. "Credits: 0" shows despite starting credits.
- **Fix**: Populate Available Items from world economy data. Load inventory from campaign equipment_data.

### ISSUE-024: Character Events Phase — empty, no crew
- **Severity**: MEDIUM
- **Screen**: CharacterPhasePanel
- **Description**: Shows "Personal events for each crew member this turn:" followed by completely empty space. No crew members listed, no events generated.
- **Fix**: Load crew members and generate character events or show "No events this turn."

### ISSUE-025: End Phase — no turn summary
- **Severity**: MEDIUM
- **Screen**: EndPhasePanel (Campaign Cycle Summary)
- **Description**: Title says "Campaign Cycle Summary" but shows NO summary data. No battles recap, no credits earned/spent, no crew changes, no loot gained, no victory progress. Just Save + Continue buttons.
- **Fix**: Add turn summary section: credits delta, battles won/lost, crew status changes, loot gained, victory progress bar.

### ISSUE-026: Step indicators show wrong checkmarks
- **Severity**: LOW
- **Screen**: WorldPhaseController — step indicator bar
- **Description**: Step 5 shows a checkmark even when only step 1 has been completed. The checkmark appears to be hardcoded or not properly tracking completion state.
- **Fix**: Reset step indicator state on phase entry. Track actual completion.

### ISSUE-027: Progress bar stuck at 8%
- **Severity**: LOW
- **Screen**: Campaign Turn header bar
- **Description**: The turn progress bar in the header shows "8%" throughout all phase navigation. Doesn't update as phases complete.
- **Fix**: Update PhaseProgressBar value as phases complete.

### ISSUE-028: Phase header shows "Phase: World Step" for all phases
- **Severity**: LOW
- **Screen**: Campaign Turn header bar
- **Description**: Header always shows "Phase: World Step" even when viewing Advancement, Trade, Character, or End phases. Should reflect current phase.
- **Fix**: Update CurrentPhaseLabel when phase changes.

### ISSUE-029: Disabled buttons have insufficient visual contrast
- **Severity**: MEDIUM
- **Screen**: All turn phase panels
- **Description**: Disabled buttons (Decline Job, Accept Job, Buy, Sell, Apply Advancement, Next Step) are slightly dimmed but barely distinguishable from enabled state. Uses opacity reduction only, no color change or strikethrough.
- **Fix**: Apply COLOR_TEXT_DISABLED (#404040) to disabled button text. Consider adding a "disabled" visual state with reduced opacity AND desaturated color.

### ISSUE-030: WorldPhaseController components use card layout, other phases don't
- **Severity**: MEDIUM
- **Screen**: All campaign turn phases
- **Description**: WorldPhaseController components (Upkeep, CrewTasks, JobOffers, MissionPrep, etc.) use proper card containers with headers, help buttons, and COLOR_ELEVATED backgrounds. But Story, Advancement, Trade, Character, and End phases use flat layouts with HR separators only. Inconsistent visual language.
- **Fix**: Migrate remaining phase panels to use WorldPhaseComponent pattern with card containers.

---

## Comprehensive Theme Compliance Matrix

| Screen | Background | Cards | Accent Colors | Help (?) | Empty States | Rating |
|--------|-----------|-------|--------------|----------|-------------|--------|
| MainMenu | Art ✓ | N/A | ✓ | N/A | N/A | ⭐⭐⭐⭐ |
| CC Step 1 (Config) | COLOR_BASE ✓ | PanelContainers ✓ | Cyan ✓ | N/A | N/A | ⭐⭐⭐⭐ |
| CC Step 2 (Captain) | Black ✗ | None ✗ | Minimal | ✗ | ✓ msg | ⭐ |
| CC Step 3 (Crew) | Black ✗ | None ✗ | Minimal | ✗ | ✗ | ⭐ |
| CC Step 4 (Equipment) | Black ✗ | Split ✓ | Cyan ✓ | ✗ | ✓ | ⭐⭐⭐ |
| CC Step 5 (Ship) | COLOR_BASE ✓ | PanelContainers ✓ | Cyan ✓ | ✗ | ✗ Ship Traits | ⭐⭐⭐⭐ |
| CC Step 6 (World) | Black ✗ | HR only ✗ | Partial | ✗ | Partial | ⭐⭐ |
| CC Step 7 (Review) | COLOR_BASE ✓ | Cards+badges ✓ | Full ✓ | N/A | N/A | ⭐⭐⭐⭐⭐ |
| Dashboard | COLOR_BASE ✓ | 3-col cards ✓ | Full ✓ | N/A | ✗ Equip | ⭐⭐⭐⭐ |
| Turn: Story | COLOR_BASE ✓ | Flat ✗ | Minimal | ✗ | ✗ | ⭐ |
| Turn: Travel | GRAY ✗✗ | Dialog box ✗ | Minimal | ✗ | N/A | ⭐ |
| Turn: Upkeep | COLOR_BASE ✓ | Card ✓ | Green/Orange ✓ | ✓ | N/A | ⭐⭐⭐⭐⭐ |
| Turn: Crew Tasks | COLOR_BASE ✓ | Card ✓ | ✓ | ✓ | N/A | ⭐⭐⭐⭐ |
| Turn: Job Offers | COLOR_BASE ✓ | Card ✓ | ✓ | ✓ | ✓ | ⭐⭐⭐⭐ |
| Turn: Mission Prep | COLOR_BASE ✓ | Card ✓ | Green/Red ✓ | ✓ | N/A | ⭐⭐⭐⭐ |
| Turn: Pre-Battle | GRAY ✗✗ | Dark rects ✗ | Minimal | ✗ | ✗ | ⭐ |
| Turn: Advancement | COLOR_BASE ✓ | Flat ✗ | Blue CTA ✓ | ✗ | ✗ | ⭐⭐ |
| Turn: Trade | COLOR_BASE ✓ | Flat ✗ | Blue CTA ✓ | ✗ | ✗ | ⭐⭐ |
| Turn: Character | COLOR_BASE ✓ | Flat ✗ | Blue CTA ✓ | ✗ | ✗ | ⭐⭐ |
| Turn: End Phase | COLOR_BASE ✓ | Flat ✗ | Orange warn ✓ | ✗ | N/A | ⭐⭐ |

## Quality Tiers

### Tier 1 — Exemplary (⭐⭐⭐⭐-⭐⭐⭐⭐⭐): Use as reference
- CC Step 7 (Final Review), Turn: Upkeep, Turn: Crew Tasks, Turn: Job Offers, Turn: Mission Prep, Dashboard

### Tier 2 — Acceptable (⭐⭐-⭐⭐⭐): Need cards + empty states
- CC Step 4 (Equipment), CC Step 6 (World), Advancement, Trade, Character, End Phase

### Tier 3 — Needs Full Rework (⭐): Wrong background, no structure
- CC Step 2 (Captain), CC Step 3 (Crew), Story Phase, Travel Phase, Pre-Battle UI

## Priority Fix Recommendations

1. **Quick Win**: Fix MainMenu button height 45→48px (1 line change)
2. **High Impact**: Apply COLOR_BASE background to all Tier 3 panels (fixes 5 screens)
3. **Medium Effort**: Wrap Tier 2 + 3 panel content in PanelContainers with card styling
4. **Architecture**: Migrate CaptainPanel, CrewPanel, TravelPhaseUI, PreBattleUI to extend FiveParsecsCampaignPanel
5. **Data Flow**: Fix crew origin/class, equipment, difficulty, and mission data propagation (5 bugs)
6. **Empty States**: Add placeholder messages to all empty lists (12+ locations)
7. **Turn Summary**: Build End Phase summary with credits delta, battle recap, victory progress
