# UX/UI QA Test Plan — Systematic Coverage

**Last Updated**: 2026-03-20
**Complements**: `docs/testing/UI_UX_TEST_PLAN.md` (session-based walkthroughs, ~200 tests)
**Purpose**: Systematic design-system and accessibility coverage that session walkthroughs miss

---

## Scope

This document covers **systematic** UI testing — theme compliance, responsive layout, animation verification, empty states, accessibility, and component-level checks. It does NOT duplicate the session-based walkthroughs in `docs/testing/UI_UX_TEST_PLAN.md` (Sessions 0-7) which cover user journey flows.

---

## 1. Screen Inventory & Route Coverage

### 1a. SceneRouter Route Reachability (38 routes)

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
| `UIColors.should_animate()` checks `ThemeManager._reduced_animation` | `UIColors.gd` | [ ] |
| All 23 TweenFX-using files call `should_animate()` before animating | Various | [ ] |
| Toggling "Reduce Animations" in settings stops all animations | SettingsDialog | [ ] |
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
