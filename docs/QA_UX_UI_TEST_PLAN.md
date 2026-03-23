# UX/UI QA Test Plan — Systematic Coverage

**Last Updated**: 2026-03-23
**Complements**: `docs/testing/UI_UX_TEST_PLAN.md` (session-based walkthroughs, ~200 tests)
**Purpose**: Systematic design-system and accessibility coverage that session walkthroughs miss

---

## Scope

This document covers **systematic** UI testing — theme compliance, responsive layout, animation verification, empty states, accessibility, and component-level checks. It does NOT duplicate the session-based walkthroughs in `docs/testing/UI_UX_TEST_PLAN.md` (Sessions 0-7) which cover user journey flows.

---

## 1. Screen Inventory & Route Coverage

### 1a. SceneRouter Route Reachability (39 routes)

Every SceneRouter key must be reachable, have a back path, and not dead-end.

| Route Key | Category | Reachable | Back Path | Tested |
|-----------|----------|-----------|-----------|--------|
| `main_menu` | Main | Yes (default) | N/A (root) | [ ] |
| `main_game` | Main | — | — | [ ] |
| `campaign_creation` | Campaign | MainMenu → New Campaign | Cancel → MainMenu | [ ] |
| `main_campaign` | Campaign | — | — | [ ] |
| `campaign_turn` | Campaign | — | — | [ ] |
| `campaign_dashboard` | Campaign | After creation / load | MainMenu button | [ ] |
| `campaign_setup` | Campaign | — | — | [ ] |
| `campaign_turn_controller` | Campaign | Dashboard → Start Turn | End Turn → Dashboard | [ ] |
| `victory_progress` | Campaign | Dashboard → Victory | Back → Dashboard | [ ] |
| `character_creator` | Character | Creation Step 2 | Back → Step 1 | [ ] |
| `character_details` | Character | Crew list → member | Back → Crew | [ ] |
| `character_progression` | Character | — | — | [ ] |
| `advancement_manager` | Character | PostBattle / Dashboard | Back | [ ] |
| `crew_management` | Crew | Dashboard → Crew | Back → Dashboard | [ ] |
| `equipment_manager` | Equipment | Dashboard → Equipment | Back | [ ] |
| `equipment_generation` | Equipment | Creation Step 4 | Back → Step 3 | [ ] |
| `ship_manager` | Ship | Dashboard → Ship | Back | [ ] |
| `ship_inventory` | Ship | Ship Manager → Stash | Back | [ ] |
| `world_phase` | World | Turn Controller → World | Phase complete → next | [ ] |
| `mission_selection` | World | World → Choose Battle | Back → World | [ ] |
| `patron_rival_manager` | World | Dashboard → Intel | Back | [ ] |
| `world_phase_summary` | World | — | — | [ ] |
| `travel_phase` | Travel | Turn Controller → Travel | Phase complete | [ ] |
| `pre_battle` | Battle | World → Battle | Abort → Dashboard | [ ] |
| `battlefield_main` | Battle | Pre-Battle → Start | — | [ ] |
| `tactical_battle` | Battle | Pre-Battle → Start | Battle complete → Post | [ ] |
| `post_battle` | Battle | Battle complete | All 14 steps → Dashboard | [ ] |
| `post_battle_sequence` | Battle | (alias) | — | [ ] |
| `campaign_events` | Events | — | — | [ ] |
| `save_load` | Utility | Dashboard → Save/Load | Back | [ ] |
| `game_over` | Utility | Campaign end | MainMenu | [ ] |
| `logbook` | Utility | Dashboard → Journal | Back | [ ] |
| `settings` | Utility | MainMenu → Options | Close | [ ] |
| `tutorial_selection` | Tutorial | MainMenu → Tutorial | Back | [ ] |
| `new_campaign_tutorial` | Tutorial | Tutorial selection | Back | [ ] |
| `help` | Help | MainMenu → Library | Back | [ ] |
| `bug_hunt_creation` | Bug Hunt | MainMenu → Bug Hunt | Cancel | [ ] |
| `bug_hunt_dashboard` | Bug Hunt | After BH creation | MainMenu | [ ] |
| `bug_hunt_turn_controller` | Bug Hunt | BH Dashboard → Turn | End → BH Dashboard | [ ] |

### 1b. Dead End Audit

Check each screen for:
- [ ] Has visible back/close/cancel button
- [ ] Back button navigates to correct parent
- [ ] No infinite loops (A → B → A without progress)
- [ ] Error states have recovery path (not stuck)

### 1c. Orphan Scene Audit

Search for `.tscn` files NOT in SceneRouter:
```
Glob: src/ui/screens/**/*.tscn
Compare against SCENE_PATHS keys
```
Expected orphans (embedded as sub-scenes, not standalone routes): panel components, dialogs, phase sub-panels.

---

## 2. Deep Space Theme Compliance Audit

**Source**: `BaseCampaignPanel.gd` constants and `UIColors.gd`

### 2a. Color Palette Verification

For each screen, verify these colors are used correctly:

| Token | Hex | Usage | Check Method |
|-------|-----|-------|--------------|
| COLOR_BASE | `#1A1A2E` | Panel backgrounds | Screenshot pixel check |
| COLOR_ELEVATED | `#252542` | Card backgrounds | Screenshot |
| COLOR_INPUT | `#1E1E36` | Form field backgrounds | Screenshot |
| COLOR_BORDER | `#3A3A5C` | Card borders | Screenshot |
| COLOR_ACCENT | `#2D5A7B` | Primary buttons, highlights | Screenshot |
| COLOR_ACCENT_HOVER | `#3A7199` | Button hover state | Interaction + screenshot |
| COLOR_FOCUS | `#4FC3F7` | Focus ring (cyan) | Tab navigation + screenshot |
| COLOR_TEXT_PRIMARY | `#E0E0E0` | Main content text | Screenshot |
| COLOR_TEXT_SECONDARY | `#808080` | Descriptions, helpers | Screenshot |
| COLOR_TEXT_DISABLED | `#404040` | Inactive elements | Screenshot |
| COLOR_SUCCESS | `#10B981` | Positive feedback | Screenshot |
| COLOR_WARNING | `#D97706` | Warnings | Screenshot |
| COLOR_DANGER | `#DC2626` | Errors, destructive actions | Screenshot |

**Priority screens for audit** (most user-facing):
- [ ] MainMenu
- [ ] CampaignCreationUI (all 7 steps)
- [ ] CampaignDashboard
- [ ] CampaignTurnController
- [ ] TacticalBattleUI
- [ ] PostBattleSequence
- [ ] TradePhasePanel
- [ ] AdvancementPhasePanel
- [ ] CharacterDetailsScreen

### 2b. Spacing Grid Compliance (8px grid)

| Constant | Value | Where Used |
|----------|-------|------------|
| SPACING_XS | 4px | Icon padding, label-to-input gap |
| SPACING_SM | 8px | Element gaps within cards |
| SPACING_MD | 16px | Inner card padding |
| SPACING_LG | 24px | Section gaps between cards |
| SPACING_XL | 32px | Panel edge padding |

Verification: Check that no spacing values fall outside the grid system (e.g., 10px, 15px, 20px are non-standard).

### 2c. Typography Scale

| Size | Value | Usage |
|------|-------|-------|
| FONT_SIZE_XS | 11 | Captions, character limits |
| FONT_SIZE_SM | 14 | Descriptions, helper text |
| FONT_SIZE_MD | 16 | Body text, input fields |
| FONT_SIZE_LG | 18 | Section headers |
| FONT_SIZE_XL | 24 | Panel titles |

Verification: No text should use sizes outside this scale (e.g., 12, 20, 22 are non-standard).

### 2d. Touch Target Validation

| Target | Min Size | Check |
|--------|----------|-------|
| All interactive elements | 48px height | `get_ui_elements` → check rect.height |
| Comfortable inputs | 56px height | LineEdit, SpinBox, OptionButton |

**Critical screens**: Campaign Creation (many inputs), Trading (buy/sell buttons), Battle (phase buttons).

---

## 3. Responsive Layout Validation

### 3a. Breakpoint Testing

| Breakpoint | Width Range | Expected Behavior |
|------------|------------|-------------------|
| MOBILE | <600px | Single column, stacked cards, larger touch targets |
| TABLET | 600-1024px | Two columns where appropriate |
| DESKTOP | 1024-1440px | Multi-column layouts, sidebars visible |
| WIDE | >1440px | Content centered with max-width, no stretching |

**Test method**: Resize game window to each breakpoint width, take screenshots, verify no clipping/overlap.

### 3b. Critical Path Screens — Portrait vs Landscape

| Screen | Portrait Check | Landscape Check |
|--------|---------------|-----------------|
| MainMenu | [ ] Buttons readable, not clipped | [ ] Layout adapts, no overlap |
| Campaign Creation | [ ] Step panels scrollable | [ ] Side-by-side possible |
| Dashboard | [ ] Cards stack vertically | [ ] Multi-column layout |
| Battle UI | [ ] Phase buttons accessible | [ ] Map + panels visible |
| Post-Battle | [ ] Step list scrollable | [ ] Details beside list |
| Trading | [ ] Items scrollable | [ ] Comparison panels side-by-side |

### 3c. Known Issue: Panels Too Wide

Per `feedback_responsive_layout.md`: Panels are too wide for landscape mode. Verify:
- [ ] Content doesn't stretch to full window width on widescreen
- [ ] Cards have maximum width constraints
- [ ] Multi-column layouts activate at appropriate breakpoints

---

## 4. TweenFX Animation Verification

### 4a. Pivot-Offset Requirements

These 13 animations require `pivot_offset = size / 2` BEFORE the animation call:

| Animation | Files Using It | pivot_offset Set? | Tested |
|-----------|---------------|-------------------|--------|
| `press` | Various buttons | [ ] | [ ] |
| `pop_in` | Cards, panels | [ ] | [ ] |
| `pulsate` | Status indicators | [ ] | [ ] |
| `punch_in` | Emphasis effects | [ ] | [ ] |
| `breathe` | Idle animations | [ ] | [ ] |
| `tada` | Victory/achievement | [ ] | [ ] |
| `critical_hit` | Battle events | [ ] | [ ] |
| `upgrade` | Level-up effects | [ ] | [ ] |
| `attract` | Call-to-action | [ ] | [ ] |
| `headshake` | Error/denial | [ ] | [ ] |

**Safe animations (no pivot_offset needed)**: `fade_in`, `fade_out`, `blink`, `spotlight`, `alarm`, `shake`, `flash`, `flicker`, `ghost`

### 4b. Looping Animation Cleanup

These 4 animations loop forever and MUST be stopped in cleanup/hide code:

| Animation | Files Using It | stop() Called? | Where? | Tested |
|-----------|---------------|---------------|--------|--------|
| `alarm` | — | [ ] | — | [ ] |
| `breathe` | — | [ ] | — | [ ] |
| `attract` | — | [ ] | — | [ ] |
| `glow_pulse` | — | [ ] | — | [ ] |

**Verification**: Navigate away from any screen using looping animations. Check that animation tween is killed (no orphaned tweens).

### 4c. Reduced Animation (Accessibility)

| Check | File | Tested |
|-------|------|--------|
| `ThemeManager.is_reduced_animation_enabled()` returns `_reduced_animation` flag | `ThemeManager.gd` | [ ] |
| TweenFX-using files check reduced animation before animating | Various | [ ] |
| Toggling "Reduce Animations" in settings fires `reduced_animation_changed` signal | SettingsDialog | [ ] |
| `ThemeManager.set_reduced_animation(true)` stops all animations via `_apply_animation_settings()` | ThemeManager.gd | [ ] |
| No animation plays when reduced animation is ON | All screens | [ ] |

---

## 5. Empty State Handling

Every screen must gracefully handle "nothing to show" scenarios.

| Scenario | Screen(s) | Expected | Tested |
|----------|-----------|----------|--------|
| No crew members | CrewManagement, CrewPanel | "No crew members" message | [ ] |
| No equipment | EquipmentManager, ShipStash | "No equipment" empty state | [ ] |
| No missions/jobs | WorldPhase JobOffers | "No opportunities available" | [ ] |
| No patrons | PatronRivalManager | "No patrons" section | [ ] |
| No rivals | PatronRivalManager | "No rivals" section | [ ] |
| No save files | SaveLoadUI | "No saves found" message | [ ] |
| No DLC owned | DLCManagementDialog | All packs show "Not Owned" | [ ] |
| First launch | MainMenu | "Continue" disabled, "Load" shows empty | [ ] |
| No victory conditions set | EndPhasePanel | Graceful "No victory condition" display | [ ] |
| 0 credits | UpkeepPhaseComponent | Insufficient funds warning | [ ] |
| No loot found | Post-Battle Battlefield Finds | "Nothing found" message | [ ] |
| Empty ship stash | Mission Prep Equipment | "No equipment in stash" | [ ] |
| 0 story points | StoryPointSpendingDialog | All options disabled | [ ] |
| No injuries | Post-Battle Injuries | "All crew unharmed" | [ ] |
| No training available | Post-Battle Training | "No training opportunities" | [ ] |

---

## 6. Accessibility Audit

### 6a. Contrast Ratios

| Check | Target | Known Issue | Tested |
|-------|--------|-------------|--------|
| Primary text (#E0E0E0) on base (#1A1A2E) | ≥7:1 (AAA) | — | [ ] |
| Secondary text (#808080) on base (#1A1A2E) | ≥4.5:1 (AA) | — | [ ] |
| Accent text on accent bg | ≥4.5:1 (AA) | **BUG-034**: VC card text on blue bg | [ ] |
| Status colors on elevated bg (#252542) | ≥4.5:1 (AA) | — | [ ] |
| Disabled text (#404040) on base | Clearly disabled | Not readable by design | [ ] |

### 6b. Focus Management

| Check | Tested |
|-------|--------|
| Tab key navigates between interactive elements | [ ] |
| Focus indicator visible (AccessibilityManager) | [ ] |
| Focus order matches visual order | [ ] |
| No focus traps (can tab out of any element) | [ ] |
| Focus returns to trigger element after dialog close | [ ] |

### 6c. Reduced Animation

| Check | Tested |
|-------|--------|
| Settings has "Reduce Animations" toggle | [ ] |
| Toggle persists across sessions | [ ] |
| All TweenFX animations respect the toggle | [ ] |
| UI remains fully functional with animations disabled | [ ] |

### 6d. Text Scaling

| Check | Tested |
|-------|--------|
| Text is readable at minimum supported resolution | [ ] |
| No text truncation on critical information | [ ] |
| Stat abbreviations clear (C:2 R:1 T:3 S:5 Sv:2 L:1) | [ ] |

---

## 7. Component-Level Testing

### 7a. BaseCampaignPanel Helper Methods

Test each helper method produces correct visual output:

| Method | Expected Output | Tested |
|--------|-----------------|--------|
| `_create_section_card(title, content, desc)` | Titled card with border, correct padding | [ ] |
| `_create_labeled_input(label, input)` | Label above input, correct spacing | [ ] |
| `_create_stat_display(name, value)` | Stat badge with name + value | [ ] |
| `_create_stats_grid(stats, columns)` | Grid of stat badges, correct columns | [ ] |
| `_create_character_card(name, sub, stats)` | Character card with name, subtitle, stats | [ ] |
| `_style_line_edit(edit)` | Themed input field (COLOR_INPUT bg) | [ ] |
| `_style_option_button(btn)` | Themed dropdown | [ ] |

### 7b. Key Components

| Component | Key Checks | Test File | Tested |
|-----------|-----------|-----------|--------|
| CharacterCard | Stats display, status badge, equipment list | `test_character_card.gd` | [ ] |
| StatBadge | Value + label formatting | `test_stat_badge.gd` | [ ] |
| EquipmentComparisonPanel | Side-by-side diff, stat deltas highlighted | — | [ ] |
| CheatSheetPanel | 8 DLC-gated sections accordion | — | [ ] |
| DLCManagementDialog | Pack toggle, flag display | — | [ ] |
| ValidationPanel | Error/warning message display | `test_validation_panel.gd` | [ ] |
| BattlefieldMapView | 4×4 grid, terrain shapes drawn | — | [ ] |
| DiceDashboard | Quick dice, roll history | — | [ ] |

### 7c. BBCode Color Usage

Verify RichTextLabel BBCode colors match theme:

| BBCode | Expected Color | Usage | Tested |
|--------|---------------|-------|--------|
| `[color=#10B981]` | Success green | Positive outcomes | [ ] |
| `[color=#D97706]` | Warning orange | Cautions, pending | [ ] |
| `[color=#DC2626]` | Danger red | Errors, casualties | [ ] |

---

## 8. Rules-Faithful Display & Flow Verification

This section verifies that the UI **accurately displays** game data values AND that **UI workflows match** the Core Rules book's prescribed sequences. A system can have the correct data in JSON but still show wrong values in the UI due to formatting bugs, stale caches, or wrong field bindings.

### 8a. Display Accuracy — Values Shown Match Underlying Data

For each screen, verify that displayed values match the canonical data source (JSON file or GDScript constant). Use `run_script` to read the underlying value, then `take_screenshot` to compare what's displayed.

| Screen | What to Check | Data Source | Method | Tested |
|--------|--------------|-------------|--------|--------|
| CharacterCard (Crew Panel) | Stat values (C/R/T/S/Sv/L) | `Character.combat`, `.reactions`, etc. | run_script + screenshot | [ ] |
| CharacterCard (Crew Panel) | Species name | `Character.species` | run_script + screenshot | [ ] |
| CharacterCard (Crew Panel) | Equipment names | `Character.equipment[]` | run_script + screenshot | [ ] |
| EquipmentPanel (Creation) | Weapon Range/Shots/Damage | `weapons.json` / `equipment_database.json` | run_script + screenshot | [ ] |
| EquipmentPanel (Creation) | Armor save values | `armor.json` | run_script + screenshot | [ ] |
| TradePhasePanel | Item prices | `equipment_database.json` costs | run_script + screenshot | [ ] |
| TradePhasePanel | Sell values | `EquipmentManager.get_sell_value()` | run_script + screenshot | [ ] |
| UpkeepPhasePanel (turn panel) | Upkeep cost displayed | `FiveParsecsConstants.ECONOMY.base_upkeep` | run_script + screenshot | [ ] |
| UpkeepPhaseComponent (world step) | Crew upkeep breakdown | `UpkeepPhaseComponent.current_upkeep_data` | run_script + screenshot | [ ] |
| UpkeepPhasePanel / Component | Ship maintenance cost | Book value p.80 | run_script + screenshot | [ ] |
| AdvancementPhasePanel | XP cost per stat | `CharacterAdvancementConstants` | run_script + screenshot | [ ] |
| AdvancementPhasePanel | Current XP value | `Character.experience` | run_script + screenshot | [ ] |
| PostBattleSequence | Injury result text | `InjurySystemConstants` | run_script + screenshot | [ ] |
| PostBattleSequence | Loot item stats | `weapons.json` / `gear_database.json` | run_script + screenshot | [ ] |
| PostBattleSequence | Credits awarded | `PaymentProcessor` result | run_script + screenshot | [ ] |
| TacticalBattleUI | Enemy count | `EnemyGenerator` result | run_script + screenshot | [ ] |
| TacticalBattleUI | Enemy names/stats | `enemy_types.json` | run_script + screenshot | [ ] |
| CampaignDashboard | Credits display | `GameStateManager.credits` | run_script + screenshot | [ ] |
| CampaignDashboard | Turn counter | `progress_data.turn_number` | run_script + screenshot | [ ] |
| CampaignDashboard | Crew count | `crew_data.members.size()` | run_script + screenshot | [ ] |
| ShipPanel (Creation) | Hull points range | `ships.json` | run_script + screenshot | [ ] |

### 8b. Rulebook-Faithful UI Flow — Sequence Matches Core Rules

Verify the UI presents game phases, steps, and options in the order prescribed by the Core Rules book.

| Flow | Core Rules Reference | What to Verify | Tested |
|------|---------------------|---------------|--------|
| Campaign Creation | pp.15-37 | 7-step wizard matches book's creation sequence: Config → Captain → Crew → Equipment → Ship → World → Review | [ ] |
| Campaign Turn | pp.70-102 | 9 phases in correct order: Story → Travel → Upkeep → Mission → Post-Mission → Advancement → Trading → Character → Retirement | [ ] |
| Post-Battle Sequence | pp.96-102 | All 14 steps present and in correct order per book | [ ] |
| Character Creation | pp.24-37 | Species → Background (D100) → Motivation (D66) → Class (D66) → Starting Equipment sequence | [ ] |
| Crew Task Options | pp.82-83 | All 8 task types available: Find Patron, Train, Trade, Recruit, Explore, Track, Repair, Decoy | [ ] |
| Battle Setup | pp.87-90 | Correct sequence: Mission → Enemy Generation → Deployment → Initiative → Combat | [ ] |
| Injury Resolution | pp.122-124 | D100 roll → Injury type → Recovery time → Treatment options presented correctly | [ ] |
| Advancement | pp.128-132 | XP spend → Stat increase options → Training paths all present | [ ] |
| Loot Resolution | pp.66-72 | Battlefield finds → Main loot → Subtable resolution shown correctly | [ ] |
| Victory Check | p.134 | All victory condition types checkable, progress displayed accurately | [ ] |

### 8c. D100/D66 Roll Display Verification

When the UI shows a dice roll result (D100, D66, D6), verify:

| Check | Screens | Tested |
|-------|---------|--------|
| D100 roll range label matches book's table entry | Character creation (Background, Strange Characters), Post-battle events, Explore task, Loot tables | [ ] |
| D66 roll result maps to correct table entry | Character creation (Motivation, Class) | [ ] |
| D6 roll result text matches book | Crew tasks (Trade, Recruit, Track), Initiative, Rival following | [ ] |
| Roll result affects game state correctly | All dice-driven screens — value written to data matches displayed result | [ ] |

### 8d. MCP Display Accuracy Automation

```gdscript
extends RefCounted
func execute(scene_tree: SceneTree) -> Variant:
    # Compare displayed credits vs underlying data
    var gsm = scene_tree.root.get_node_or_null("/root/GameStateManager")
    if not gsm:
        return {"error": "GameStateManager not loaded"}
    var underlying_credits = gsm.credits
    # Find credits label in current scene
    var scene = scene_tree.current_scene
    var labels = _find_labels_containing(scene, "Credits")
    var mismatches = []
    for label_info in labels:
        if str(underlying_credits) not in label_info["text"]:
            mismatches.append({
                "label": label_info["name"],
                "displayed": label_info["text"],
                "underlying": underlying_credits
            })
    return {"credits_value": underlying_credits, "labels_found": labels.size(), "mismatches": mismatches}

func _find_labels_containing(node: Node, keyword: String) -> Array:
    var results = []
    if node is Label and keyword.to_lower() in String(node.name).to_lower():
        results.append({"name": str(node.name), "text": node.text})
    if node is RichTextLabel and keyword.to_lower() in String(node.name).to_lower():
        results.append({"name": str(node.name), "text": node.get_parsed_text()})
    for child in node.get_children():
        results.append_array(_find_labels_containing(child, keyword))
    return results
```

---

## 9. Layout & UX Improvement Audit

This section identifies **concrete layout issues and UX improvements** — not just pass/fail checks, but suggestions for tightening layouts, fixing inconsistencies, and improving the player experience. Review each screen during QA sessions and log findings.

### 9a. Margin Consistency Audit

Root-level margins vary across screens with no unified standard. During QA, screenshot each screen and note the outer margin.

| Screen | Current Margin | Expected | File | Issue |
|--------|---------------|----------|------|-------|
| CampaignDashboard | 24/16 (L-R / T-B) | 24/16 | `CampaignDashboard.tscn` | Reference standard |
| CampaignCreationUI | 20 all | 24/16 | `CampaignCreationUI.tscn` | Doesn't match dashboard |
| WorldPhaseController | 32 all | 24 all | `WorldPhaseController.tscn` | Largest margin in codebase — too spacious |
| TacticalBattleUI | None | 20 all | `TacticalBattleUI.tscn` | No root MarginContainer |
| BattleTransitionUI | Hardcoded offsets | 20 all | `BattleTransitionUI.tscn` | Uses offset calcs, not containers |
| TravelPhaseUI | None (CenterContainer) | 20 all | `TravelPhaseUI.tscn` | Relies on centering only |
| TradePhasePanel | 16 all | 16 or 24/16 | `TradePhasePanel.tscn` | Smallest campaign margin |
| PreBattle | 20 all | 20 all | `PreBattle.tscn` | OK for battle context |
| CaptainPanel / CrewPanel | 20 all | 24/16 | `CaptainPanel.tscn` | No root MarginContainer |

**Recommendation**: Standardize to 24/16 (L-R/T-B) for campaign screens, 20 all for battle screens.

### 9b. Container Separation (Spacing Between Elements)

VBoxContainer/HBoxContainer `separation` values vary widely (4px–24px). Audit each screen's internal spacing.

| Screen | Container | Current | Recommended | Issue |
|--------|-----------|---------|-------------|-------|
| TacticalBattleUI | ContentArea HBox | 4px | 12px | Cramped — below SPACING_XS |
| TacticalBattleUI | CenterPanel VBox | 4px | 8px | Cramped |
| TacticalBattleUI | BottomBar Content | 4px | 8px | Tight above EndTurnButton |
| CampaignDashboard | CrewVBox | 8px | 12px | Inconsistent (Center/Right use 12px) |
| WorldPhaseController | Main VBox | 24px | 20px | Largest in codebase |
| CampaignCreationUI | StepPanels VBox | 20px | 16px | Slightly large for step content |

**Design system reference** (from Deep Space theme):
- SPACING_XS (4px): icon padding only
- SPACING_SM (8px): element gaps within cards
- SPACING_MD (16px): inner card padding
- SPACING_LG (24px): section gaps between cards

### 9c. Button Height Standardization

Touch target minimum is 48px (TOUCH_TARGET_MIN). Some buttons are below this.

| Screen | Button | Current Height | Issue | Fix |
|--------|--------|---------------|-------|-----|
| TacticalBattleUI | ReturnButton | 44px | Below 48px minimum | → 48px |
| TacticalBattleUI | AutoResolveButton | 44px | Below 48px minimum | → 48px |
| CaptainPanel | Control buttons | 50px | Non-standard | → 48px (secondary) or 56px (primary) |
| CrewPanel | Control buttons | 50px | Non-standard | → 48px or 56px |
| WorldPhaseController | BackToDashboard | 48px | Inconsistent (Back/Next are 56px) | → 56px |
| WorldPhaseController | ProceedToBattle | 48px | Inconsistent (Back/Next are 56px) | → 56px |

**Standard**: Primary actions (Next, Confirm, Proceed) = 56px. Secondary actions (Back, Cancel, Return) = 48px.

### 9d. Fixed-Width Panels (Responsive Blockers)

Several screens use hardcoded pixel widths that prevent responsive scaling.

| Screen | Component | Fixed Width | Issue | Suggestion |
|--------|-----------|------------|-------|------------|
| TacticalBattleUI | LeftPanel | 220px | Won't adapt to screen size | Use size_flags + min_size |
| TacticalBattleUI | RightPanel | 280px | Won't adapt to screen size | Use size_flags + min_size |
| TacticalBattleUI | OverlayContent | 500px | Breaks on <640px screens | Wrap in ResponsiveContainer |
| TravelPhaseUI | PanelContainer | 600x400px | Most rigid constraint | Replace with responsive layout |
| BattleTransitionUI | TransitionPanel | 600x300px | Hardcoded offsets | Replace with ResponsiveContainer |

**Reference pattern**: `PostBattleSequence.tscn` already uses ResponsiveContainer — use as template for retrofitting.

### 9e. Per-Screen UX Review Checklist

During QA sessions, evaluate each screen for these subjective UX qualities. Record suggestions, not just pass/fail.

| Screen | Check | Question to Ask | Notes |
|--------|-------|----------------|-------|
| CampaignDashboard | Information density | Can the player find key info (credits, crew, turn) within 2 seconds? | |
| CampaignDashboard | Card layout | Do dashboard cards have consistent sizing? Any feel squished or oversized? | |
| CampaignDashboard | Action discoverability | Are primary actions (Start Turn, Save) immediately visible without scrolling? | |
| CampaignCreationUI | Step progression | Is it clear which step you're on and how many remain? | |
| CampaignCreationUI | Form density | Are there too many inputs visible at once? Should any be collapsed/grouped? | |
| TacticalBattleUI | Panel balance | Does the 3-panel layout feel balanced or does one side dominate? | |
| TacticalBattleUI | Combat log readability | Is the battle log easy to scan? Font size? Line spacing? | |
| PostBattleSequence | Step list length | Are all 14 steps visible or does the list feel overwhelming? | |
| PostBattleSequence | Progress indication | Is it clear which step you're on and which are completed? | |
| TradePhasePanel | Comparison clarity | When buying/selling, can you easily compare item stats? | |
| TradePhasePanel | Price visibility | Are costs clearly visible before purchase confirmation? | |
| AdvancementPhasePanel | XP clarity | Is it obvious how much XP each character has and what it costs to advance? | |
| WorldPhaseController | Step navigation | Is it clear what order steps should be completed in? | |
| WorldPhaseController | White space | Is there too much empty space? (Currently 32px margins + 24px separation) | |
| TravelPhaseUI | Event readability | Are travel event descriptions easy to read? Text size appropriate? | |
| PreBattle | Crew selection | Is it easy to select/deselect crew members for battle? | |
| PreBattle | Mission briefing | Is the mission objective clearly communicated? | |
| CharacterDetailsScreen | Stat layout | Are character stats easy to scan? Stat abbreviations clear? | |
| MainMenu | Button hierarchy | Is the primary action (Continue/New Campaign) visually prominent? | |

### 9f. Widescreen Behavior Audit

On widescreen (>1440px), check whether content stretches uncomfortably or is properly constrained.

| Screen | Behavior at 1920px | Issue | Suggestion |
|--------|-------------------|-------|------------|
| CampaignDashboard | 3 columns stretch full width | Cards may become too wide | Add max-width constraint (~1200px) |
| CampaignCreationUI | Step panels stretch full width | Form inputs become very wide | Add max-width on input containers |
| TradePhasePanel | Item list stretches full width | Empty space in item rows | Add max-width on grid |
| PostBattleSequence | Already has ResponsiveContainer | OK | Reference implementation |

---

## How to Run

### Quick Audit (~15 min)
1. Launch game → MainMenu screenshot
2. Navigate through CC Steps 1-7 → screenshot each
3. Load saved campaign → Dashboard screenshot
4. Enter battle → TacticalBattleUI screenshot
5. Compare all screenshots against color palette table (§2a)
6. Check touch targets on critical buttons (§2d)

### Full Audit (~45 min)
1. Quick Audit (above)
2. Resize window to each breakpoint (§3a) — 4 screenshots per critical screen
3. Navigate to every SceneRouter route (§1a) — verify reachability + back
4. Toggle "Reduce Animations" — verify no animations play (§4c)
5. Check all empty state scenarios (§5)
6. Tab through Campaign Creation for focus order (§6b)
7. Verify contrast on all status messages (§6a)

### MCP Automation

Use `get_ui_elements` + `take_screenshot` for visual checks. Use `run_script` for:

```gdscript
# Check touch target heights
var root = get_tree().current_scene
var small_targets = []
for child in root.get_children():
    if child is BaseButton and child.size.y < 48:
        small_targets.append(child.name + ": " + str(child.size.y) + "px")
return "Small targets: " + str(small_targets.size()) + "\n" + "\n".join(small_targets)
```

```gdscript
# Check for non-standard font sizes
var root = get_tree().current_scene
var standard = [11, 14, 16, 18, 24]
var non_standard = []
for child in root.get_children():
    if child is Label and child.get("theme_override_font_sizes/font_size") != null:
        var size = child.get("theme_override_font_sizes/font_size")
        if size not in standard:
            non_standard.append(child.name + ": " + str(size))
return "Non-standard: " + str(non_standard.size()) + "\n" + "\n".join(non_standard)
```

---

## 8. Output Accuracy Verification — JSON Data Flow to UI

**Added**: 2026-03-23 (Generator Wiring Fix Sprint)
**Unit Tests**: `tests/unit/test_generator_wiring.gd` (25 tests)

Verifies that values displayed in the UI originate from canonical JSON data files, not fabricated hardcoded constants. This section guards against the "load but never use" anti-pattern where generators load JSON but ignore it.

### 8a. Economy Display Accuracy

All credit amounts shown in UI must use Core Rules single-digit economy (1-12 credits per transaction, not hundreds).

| Screen | Value Displayed | Expected Range | Source | Check |
|--------|----------------|----------------|--------|-------|
| Mission briefing | Mission reward | 2-12 cr | `patron_generation.json` danger_pay + D6 base | [ ] |
| Post-battle summary | Loot credits | 1-3 cr per roll | D100 loot table | [ ] |
| Patron job offer | Base + danger pay | 3-15 cr total | `patron_generation.json` | [ ] |
| Campaign creation | Starting credits | 1 cr × crew size | `FiveParsecsConstants.starting_credits_per_crew` | [ ] |
| Equipment generation | Bonus credits | 0 (items only) | `StartingEquipmentGenerator` returns 0 | [ ] |
| Upkeep phase | Upkeep cost | 1-3 cr | `FiveParsecsConstants.ECONOMY` | [ ] |
| Salvage trade | Salvage conversion | 2-18 cr | `SalvageJobGenerator.SALVAGE_CONVERSION` | [ ] |

**Red flag**: Any credit value > 50 in normal gameplay is likely a fabricated constant regression.

### 8b. Character Stat Display Accuracy

Stats shown in character panels must be within model range (1-6).

| Screen | Value | Expected Range | Source | Check |
|--------|-------|----------------|--------|-------|
| Character creator | Generated stats | 1-6 each | `SimpleCharacterCreator._roll_stat()` = ceil(2D6/3) | [ ] |
| Character details | Current stats | 1-6 each (0-6 with penalties) | `Character.combat/reactions/etc` | [ ] |
| Crew panel | Stat summary | 1-6 each | Same | [ ] |
| Advancement | Stat costs | 5-10 XP | `campaign_rules.json` or `FiveParsecsConstants` | [ ] |

**Red flag**: Any stat > 6 is likely a raw 2D6 regression.

### 8c. Patron Type Display Accuracy

Patron types shown in UI must match Core Rules p.83 (6 types).

| UI Element | Expected Values | Source | Check |
|------------|----------------|--------|-------|
| Patron type label | Corporation, Local Government, Sector Government, Wealthy Individual, Private Organization, Secretive Group | `patron_generation.json` | [ ] |
| Patron job type | Maps from FactionType enum via `_get_patron_type_string()` | `PatronJobGenerator` | [ ] |
| Danger pay modifier | +1 for Corporation | `patron_generation.json` | [ ] |
| Time frame modifier | +1 for Secretive Group | `patron_generation.json` | [ ] |

**Red flag**: Types like "MILITARY", "CRIMINAL", "TRADER", "SCIENTIST" are fabricated (pre-fix) keys.

### 8d. Compendium Mission Data Accuracy (DLC-gated)

When DLC is enabled, mission data shown in tactical UI must come from JSON, not const arrays alone.

| Mission Type | JSON Source | Key Data Points | Check |
|-------------|------------|-----------------|-------|
| Street Fight | `StealthAndStreet.json` → `street_fights` | Suspect markers, identification rules, police response | [ ] |
| Salvage Job | `SalvageJobs.json` | Tension track, contact resolution, POI table | [ ] |
| Stealth Mission | `StealthAndStreet.json` → `stealth` | Objectives (D100), spotting modifiers, detection rules | [ ] |

### 8e. MCP Verification Scripts

```gdscript
# Check mission reward range in running game
var gen = load("res://src/game/campaign/FiveParsecsMissionGenerator.gd").new()
var rewards = []
for i in range(20):
    rewards.append(gen.calculate_mission_reward(3, 0))
var max_r = rewards.max()
var min_r = rewards.min()
return "Reward range: %d-%d (expect 2-12, FAIL if >20)" % [min_r, max_r]
```

```gdscript
# Check character stat generation range
var creator = load("res://src/core/character/Generation/SimpleCharacterCreator.gd").new()
var stats = []
for i in range(100):
    stats.append(creator._roll_stat())
var max_s = stats.max()
var min_s = stats.min()
creator.free()
return "Stat range: %d-%d (expect 1-6, FAIL if >6)" % [min_s, max_s]
```

```gdscript
# Check patron type mapping completeness
var gen_class = load("res://src/core/patrons/PatronJobGenerator.gd")
var gen = gen_class.new()
var keys = gen.patron_type_modifiers.keys()
gen.free()
var expected = ["Corporation", "Local Government", "Sector Government", "Wealthy Individual", "Private Organization", "Secretive Group"]
var missing = []
for e in expected:
    if e not in keys:
        missing.append(e)
return "Patron types: %d/6 present. Missing: %s" % [6 - missing.size(), str(missing)]
```
