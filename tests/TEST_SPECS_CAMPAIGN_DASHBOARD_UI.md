# Test Specifications: CampaignDashboard UI Modernization

**Created**: 2025-11-28
**Version**: 1.0
**Target**: Campaign Dashboard HTML mockup implementation
**Framework**: GDUnit4 v6.0.1
**Testing Constraints**: UI mode only (no headless), max 13 tests per file

---

## Executive Summary

This document specifies comprehensive test coverage for the modernized CampaignDashboard UI, targeting:
- **Campaign Turn Progress Tracker** (7-step phase display)
- **Character Cards** (stats, equipment, badges, responsive layout)
- **Mission & World Cards** (data binding, dynamic updates)
- **Responsive Behavior** (mobile/tablet/desktop breakpoints)
- **Design System Compliance** (touch targets, colors, typography)

**Total Test Files**: 6 files (consolidated per Framework Bible)
**Total Test Cases**: 65 tests (P0: 28, P1: 25, P2: 12)
**Estimated Execution Time**: ~45 minutes (all tests)

---

## Test File Structure

```
tests/
├── unit/
│   ├── test_stat_badge.gd               [CREATED - 8 tests passing]
│   ├── test_character_card.gd           [NEW - 13 tests]
│   └── test_campaign_progress_tracker.gd [NEW - 11 tests]
├── integration/
│   ├── test_dashboard_data_binding.gd   [NEW - 13 tests]
│   ├── test_dashboard_responsive.gd     [NEW - 13 tests]
│   └── test_dashboard_signal_flow.gd    [NEW - 13 tests]
└── manual/
    └── MANUAL_QA_DASHBOARD_RESPONSIVE.md [NEW - checklist]
```

---

## 1. Unit Tests: CharacterCard Component

**File**: `tests/unit/test_character_card.gd`
**Priority**: P0 (Critical)
**Dependencies**: CharacterCard.gd, StatBadge.gd, Character.gd
**Test Count**: 13 tests

### Test Cases

#### Variant Display Tests (4 tests)

1. **test_compact_variant_renders_minimal_info**
   - **Setup**: Create CharacterCard with COMPACT variant
   - **Action**: Set character data (name, class)
   - **Expected**:
     - Card height = 80px
     - Portrait + name + class visible
     - Stats hidden, buttons hidden
   - **Priority**: P0

2. **test_standard_variant_renders_key_stats**
   - **Setup**: Create CharacterCard with STANDARD variant
   - **Action**: Set character with stats (REA=1, SPD=4, CBT=5, TGH=3, SAV=2)
   - **Expected**:
     - Card height = 120px
     - Portrait + name + class visible
     - 5 stat badges visible (REA, SPD, CBT, TGH, SAV)
     - Buttons hidden
   - **Priority**: P0

3. **test_expanded_variant_renders_all_elements**
   - **Setup**: Create CharacterCard with EXPANDED variant
   - **Action**: Set character with full data
   - **Expected**:
     - Card height = 160px
     - Portrait + name + class + stats visible
     - Action buttons visible (View, Edit, Remove)
   - **Priority**: P0

4. **test_variant_switch_updates_layout**
   - **Setup**: Create CharacterCard with STANDARD variant
   - **Action**: Change variant to EXPANDED, then COMPACT
   - **Expected**:
     - Card height updates correctly
     - Components show/hide based on variant
     - No memory leaks (check _character_card_pool)
   - **Priority**: P1

#### Stat Badge Integration (3 tests)

5. **test_stat_badges_display_correct_values**
   - **Setup**: Create CharacterCard with stats (REA=1, SPD=4, CBT=5, TGH=3, SAV=2)
   - **Action**: Render STANDARD variant
   - **Expected**:
     - 5 StatBadge components created
     - Each badge shows correct stat_name and stat_value
     - Values match character.combat, character.reactions, etc.
   - **Priority**: P0

6. **test_stat_badge_colors_match_design_system**
   - **Setup**: Create CharacterCard with stats
   - **Action**: Render STANDARD variant
   - **Expected**:
     - Stat badges use COLOR_ACCENT (#2D5A7B) by default
     - No custom colors override (unless specified)
   - **Priority**: P2

7. **test_stat_badge_updates_when_character_data_changes**
   - **Setup**: Create CharacterCard with initial stats (CBT=3)
   - **Action**: Update character.combat to 5, call update_display()
   - **Expected**:
     - Combat stat badge updates from 3 to 5
     - No badge recreation (reuses existing badges)
   - **Priority**: P1

#### Equipment Badges (2 tests)

8. **test_equipment_badges_show_keyword_tooltips**
   - **Setup**: Create CharacterCard with equipment (Infantry Laser - keywords: "Energy", "Accurate")
   - **Action**: Render EXPANDED variant, hover over equipment badge
   - **Expected**:
     - Equipment badge displays item name
     - Tooltip shows keyword definitions on hover
     - KeywordTooltip component instantiated correctly
   - **Priority**: P1
   - **Dependencies**: KeywordTooltip.gd, EquipmentFormatter.gd

9. **test_empty_equipment_hides_badges**
   - **Setup**: Create CharacterCard with no equipment
   - **Action**: Render EXPANDED variant
   - **Expected**:
     - Equipment section hidden or shows "No Equipment"
     - No empty badge components rendered
   - **Priority**: P2

#### XP Progress Bar (2 tests)

10. **test_xp_progress_bar_accuracy**
    - **Setup**: Create CharacterCard with XP=7 (50% to next advancement)
    - **Action**: Render EXPANDED variant
    - **Expected**:
      - Progress bar shows 50% fill
      - Progress bar color = COLOR_BLUE (#3b82f6)
      - XP label shows "7 / 14 XP"
    - **Priority**: P1

11. **test_xp_progress_bar_caps_at_100_percent**
    - **Setup**: Create CharacterCard with XP=20 (over max)
    - **Action**: Render EXPANDED variant
    - **Expected**:
      - Progress bar shows 100% fill
      - No overflow or visual glitch
    - **Priority**: P2

#### Signal Tests (2 tests)

12. **test_card_tap_emits_signal**
    - **Setup**: Create CharacterCard
    - **Action**: Simulate tap/click on card body
    - **Expected**:
      - card_tapped signal emitted
      - Signal emitted once (no duplicates)
    - **Priority**: P1

13. **test_action_buttons_emit_correct_signals**
    - **Setup**: Create CharacterCard in EXPANDED variant
    - **Action**: Click "View", "Edit", "Remove" buttons
    - **Expected**:
      - view_details_pressed signal emitted on View
      - edit_pressed signal emitted on Edit
      - remove_pressed signal emitted on Remove
      - Each signal emitted only once
    - **Priority**: P1

---

## 2. Unit Tests: Campaign Progress Tracker

**File**: `tests/unit/test_campaign_progress_tracker.gd`
**Priority**: P0 (Critical)
**Dependencies**: CampaignDashboard.gd, CampaignPhaseManager.gd
**Test Count**: 11 tests

### Test Cases

#### Phase Highlighting Tests (4 tests)

1. **test_travel_phase_highlighted**
   - **Setup**: Mock campaign in TRAVEL phase
   - **Action**: Render progress tracker
   - **Expected**:
     - "Travel" step highlighted (COLOR_ACCENT background)
     - Other steps dimmed (COLOR_TEXT_SECONDARY)
     - Current step indicator visible
   - **Priority**: P0

2. **test_world_phase_highlighted**
   - **Setup**: Mock campaign in WORLD phase
   - **Action**: Render progress tracker
   - **Expected**:
     - "World" step highlighted
     - Travel step marked as complete (checkmark icon)
     - Battle/Post-Battle dimmed (not yet reached)
   - **Priority**: P0

3. **test_battle_phase_highlighted**
   - **Setup**: Mock campaign in BATTLE phase
   - **Action**: Render progress tracker
   - **Expected**:
     - "Battle" step highlighted
     - Travel/World marked complete
     - Post-Battle dimmed
   - **Priority**: P0

4. **test_post_battle_phase_highlighted**
   - **Setup**: Mock campaign in POST_BATTLE phase
   - **Action**: Render progress tracker
   - **Expected**:
     - "Post-Battle" step highlighted
     - Travel/World/Battle marked complete
   - **Priority**: P0

#### Phase Transition Tests (3 tests)

5. **test_phase_transition_updates_tracker**
   - **Setup**: Mock campaign in TRAVEL phase
   - **Action**: Trigger phase transition to WORLD
   - **Expected**:
     - Tracker updates to highlight WORLD
     - Travel marked complete
     - No visual glitches during transition
   - **Priority**: P0

6. **test_invalid_phase_transition_prevented**
   - **Setup**: Mock campaign in TRAVEL phase
   - **Action**: Attempt transition to BATTLE (skipping WORLD)
   - **Expected**:
     - Transition rejected
     - Tracker remains on TRAVEL
     - Error logged to console
   - **Priority**: P1
   - **Dependencies**: CampaignPhaseManager validation

7. **test_complete_turn_cycle_updates_tracker**
   - **Setup**: Mock campaign in TRAVEL phase
   - **Action**: Transition TRAVEL → WORLD → BATTLE → POST_BATTLE → TRAVEL
   - **Expected**:
     - Tracker updates at each transition
     - All phases marked complete in sequence
     - Turn number increments after POST_BATTLE → TRAVEL
   - **Priority**: P1

#### Action Button Tests (2 tests)

8. **test_action_button_shows_correct_label**
   - **Setup**: Mock campaign in TRAVEL phase
   - **Action**: Render progress tracker
   - **Expected**:
     - Action button label = "Start Travel"
     - Button enabled
   - **Priority**: P1

9. **test_action_button_disabled_during_transition**
   - **Setup**: Mock campaign mid-transition (transition_in_progress = true)
   - **Action**: Render progress tracker
   - **Expected**:
     - Action button disabled
     - Button label = "Transitioning..." (or similar)
   - **Priority**: P1

#### Visual Design Tests (2 tests)

10. **test_step_indicators_meet_touch_targets**
    - **Setup**: Render progress tracker on mobile viewport (360x640)
    - **Action**: Measure step indicator dimensions
    - **Expected**:
      - Each step indicator ≥ 48px height (TOUCH_TARGET_MIN)
      - Tap areas don't overlap
    - **Priority**: P2

11. **test_responsive_layout_on_mobile**
    - **Setup**: Render progress tracker on narrow viewport (360px width)
    - **Action**: Check layout
    - **Expected**:
      - Horizontal scrolling enabled if needed
      - All 7 steps visible (may require scroll)
      - No text clipping
    - **Priority**: P1

---

## 3. Integration Tests: Dashboard Data Binding

**File**: `tests/integration/test_dashboard_data_binding.gd`
**Priority**: P0 (Critical)
**Dependencies**: GameStateManager, CampaignDashboard.gd, Character.gd
**Test Count**: 13 tests

### Test Cases

#### Campaign State Binding (4 tests)

1. **test_credits_label_binds_to_game_state**
   - **Setup**: Mock campaign with 5000 credits
   - **Action**: Render CampaignDashboard
   - **Expected**:
     - Credits label displays "5,000 Credits"
     - Currency formatted with thousands separator
   - **Priority**: P0

2. **test_story_points_label_binds_to_game_state**
   - **Setup**: Mock campaign with 3 story points
   - **Action**: Render CampaignDashboard
   - **Expected**:
     - Story points label displays "3"
   - **Priority**: P0

3. **test_campaign_stats_update_dynamically**
   - **Setup**: Mock campaign with initial credits=1000
   - **Action**: Modify GameStateManager.credits to 2500
   - **Expected**:
     - Credits label updates to "2,500 Credits"
     - No manual refresh required (signal-driven)
   - **Priority**: P0

4. **test_phase_label_syncs_with_phase_manager**
   - **Setup**: Mock campaign in WORLD phase
   - **Action**: Render CampaignDashboard
   - **Expected**:
     - Phase label displays "World Phase"
     - Phase icon displayed correctly
   - **Priority**: P0

#### Character Card Data Binding (4 tests)

5. **test_crew_cards_render_from_roster**
   - **Setup**: Mock campaign with 4 crew members (diverse stats)
   - **Action**: Render CampaignDashboard
   - **Expected**:
     - 4 CharacterCard instances created
     - Each card shows correct character data (name, class, stats)
     - Cards displayed in crew_card_container
   - **Priority**: P0

6. **test_crew_stats_update_after_battle**
   - **Setup**: Mock campaign with crew member at CBT=3
   - **Action**: Simulate battle, increase CBT to 5, refresh dashboard
   - **Expected**:
     - Character card updates to show CBT=5
     - No card recreation (reuses pooled card)
   - **Priority**: P1

7. **test_empty_crew_roster_shows_placeholder**
   - **Setup**: Mock campaign with 0 crew members
   - **Action**: Render CampaignDashboard
   - **Expected**:
     - "No crew members" placeholder displayed
     - No CharacterCard instances created
   - **Priority**: P2

8. **test_leader_badge_displays_on_captain**
   - **Setup**: Mock campaign with captain (is_leader=true)
   - **Action**: Render CampaignDashboard
   - **Expected**:
     - Captain's card shows "Leader" status badge
     - Badge styled with COLOR_AMBER (#f59e0b)
   - **Priority**: P1

#### Mission & World Card Binding (3 tests)

9. **test_world_info_binds_to_current_world**
   - **Setup**: Mock campaign on world "Tau Ceti IV" (Frontier Colony)
   - **Action**: Render CampaignDashboard
   - **Expected**:
     - World info label displays "Tau Ceti IV - Frontier Colony"
     - World traits listed correctly
   - **Priority**: P1

10. **test_quest_info_binds_to_active_quest**
    - **Setup**: Mock campaign with active quest "Rescue Hostages"
    - **Action**: Render CampaignDashboard
    - **Expected**:
      - Quest info label displays quest name
      - Quest progress shown (e.g., "2/3 objectives")
    - **Priority**: P1

11. **test_no_active_quest_shows_placeholder**
    - **Setup**: Mock campaign with no active quest
    - **Action**: Render CampaignDashboard
    - **Expected**:
      - Quest info shows "No active quest"
      - Quest panel visible but empty state
    - **Priority**: P2

#### Ship & Equipment Binding (2 tests)

12. **test_ship_info_displays_ship_data**
    - **Setup**: Mock campaign with ship "Wanderer's Hope" (Hull=6, Cargo=8)
    - **Action**: Render CampaignDashboard
    - **Expected**:
      - Ship name displayed
      - Hull and Cargo stats shown via StatBadge
    - **Priority**: P1

13. **test_equipment_stash_count_displays**
    - **Setup**: Mock campaign with 7 items in stash
    - **Action**: Render CampaignDashboard
    - **Expected**:
      - Equipment panel shows "7 items in stash"
      - Count updates when items added/removed
    - **Priority**: P2

---

## 4. Integration Tests: Dashboard Responsive Behavior

**File**: `tests/integration/test_dashboard_responsive.gd`
**Priority**: P1 (High)
**Dependencies**: CampaignDashboard.gd, ResponsiveContainer (if implemented)
**Test Count**: 13 tests

### Test Cases

#### Mobile Layout (< 480px) (4 tests)

1. **test_mobile_single_column_layout**
   - **Setup**: Set viewport to 360x640 (mobile)
   - **Action**: Render CampaignDashboard
   - **Expected**:
     - All cards stack vertically (single column)
     - No horizontal overflow
     - Scrollable vertical container
   - **Priority**: P1

2. **test_mobile_bottom_navigation**
   - **Setup**: Set viewport to 360x640 (mobile)
   - **Action**: Render CampaignDashboard
   - **Expected**:
     - Navigation buttons fixed to bottom
     - Buttons span full width
     - Touch targets ≥ 48px height
   - **Priority**: P1

3. **test_mobile_crew_cards_horizontal_scroll**
   - **Setup**: Set viewport to 360x640, mock 6 crew members
   - **Action**: Render crew_card_container
   - **Expected**:
     - Crew cards display in horizontal scroll (carousel)
     - Each card maintains COMPACT variant (80px height)
     - Smooth horizontal scrolling
   - **Priority**: P1

4. **test_mobile_progress_tracker_compact**
   - **Setup**: Set viewport to 360x640
   - **Action**: Render campaign progress tracker
   - **Expected**:
     - Progress tracker uses compact layout
     - Step labels abbreviated if needed
     - Horizontal scroll enabled for 7 steps
   - **Priority**: P2

#### Tablet Layout (480-768px) (3 tests)

5. **test_tablet_two_column_layout**
   - **Setup**: Set viewport to 600x800 (tablet)
   - **Action**: Render CampaignDashboard
   - **Expected**:
     - Cards arranged in 2-column grid
     - Left column: Campaign stats, Crew
     - Right column: World info, Quests
   - **Priority**: P1

6. **test_tablet_crew_cards_grid_layout**
   - **Setup**: Set viewport to 600x800, mock 6 crew members
   - **Action**: Render crew_card_container
   - **Expected**:
     - Crew cards display in 2-column grid
     - Cards use STANDARD variant (120px height)
     - No horizontal scroll
   - **Priority**: P1

7. **test_tablet_touch_targets_comfortable**
   - **Setup**: Set viewport to 600x800
   - **Action**: Measure interactive elements
   - **Expected**:
     - All buttons ≥ 56px height (TOUCH_TARGET_COMFORT)
     - Increased spacing between elements (SPACING_LG)
   - **Priority**: P2

#### Desktop Layout (> 1024px) (3 tests)

8. **test_desktop_full_layout_with_sidebar**
   - **Setup**: Set viewport to 1920x1080 (desktop)
   - **Action**: Render CampaignDashboard
   - **Expected**:
     - Full layout with left sidebar (navigation)
     - Main content area uses 3-column grid
     - All cards visible without scrolling
   - **Priority**: P1

9. **test_desktop_crew_cards_full_grid**
   - **Setup**: Set viewport to 1920x1080, mock 6 crew members
   - **Action**: Render crew_card_container
   - **Expected**:
     - Crew cards display in 3-column grid
     - Cards use EXPANDED variant (160px height)
     - All action buttons visible
   - **Priority**: P1

10. **test_desktop_expanded_stats_visible**
    - **Setup**: Set viewport to 1920x1080
    - **Action**: Render CampaignDashboard
    - **Expected**:
      - All stat badges visible simultaneously
      - Additional info panels displayed (patrons, rivals)
      - No content hidden behind scrolling
    - **Priority**: P2

#### Viewport Resize Tests (3 tests)

11. **test_viewport_resize_triggers_layout_update**
    - **Setup**: Start with mobile viewport (360x640)
    - **Action**: Resize to desktop (1920x1080)
    - **Expected**:
      - Layout transitions from single-column to 3-column
      - Crew cards transition from COMPACT to EXPANDED
      - No visual glitches during resize
    - **Priority**: P1

12. **test_rapid_resize_no_memory_leaks**
    - **Setup**: Start with any viewport size
    - **Action**: Rapidly resize viewport 20 times (mobile ↔ desktop)
    - **Expected**:
      - No orphaned nodes or signals
      - Memory usage stable (character card pool reused)
      - No console errors
    - **Priority**: P1

13. **test_orientation_change_on_tablet**
    - **Setup**: Set viewport to 600x800 (portrait tablet)
    - **Action**: Rotate to 800x600 (landscape)
    - **Expected**:
      - Layout adapts to landscape orientation
      - Crew cards rearrange in grid
      - All content remains accessible
    - **Priority**: P2

---

## 5. Integration Tests: Dashboard Signal Flow

**File**: `tests/integration/test_dashboard_signal_flow.gd`
**Priority**: P0 (Critical)
**Dependencies**: CampaignDashboard.gd, GameStateManager, SignalBus
**Test Count**: 13 tests

### Test Cases

#### Phase Transition Signals (4 tests)

1. **test_next_phase_button_emits_transition_signal**
   - **Setup**: Mock campaign in TRAVEL phase
   - **Action**: Click "Start Travel" action button
   - **Expected**:
     - phase_transition_requested signal emitted
     - Signal payload contains next_phase = "WORLD"
     - CampaignPhaseManager receives signal
   - **Priority**: P0

2. **test_phase_transition_updates_dashboard_ui**
   - **Setup**: Mock campaign in TRAVEL phase
   - **Action**: Trigger phase transition to WORLD via CampaignPhaseManager
   - **Expected**:
     - CampaignDashboard receives phase_changed signal
     - Progress tracker updates to highlight WORLD
     - Phase label updates to "World Phase"
   - **Priority**: P0

3. **test_phase_transition_signal_cleanup_on_free**
   - **Setup**: Create CampaignDashboard, connect phase signals
   - **Action**: Free CampaignDashboard instance
   - **Expected**:
     - All signal connections disconnected
     - No orphaned signals in CampaignPhaseManager
   - **Priority**: P1

4. **test_invalid_phase_transition_rejected**
   - **Setup**: Mock campaign in TRAVEL phase
   - **Action**: Attempt manual transition to POST_BATTLE (invalid)
   - **Expected**:
     - Transition rejected by CampaignPhaseManager
     - Dashboard remains on TRAVEL phase
     - Error signal emitted (if applicable)
   - **Priority**: P1

#### Character Card Signal Flow (3 tests)

5. **test_character_card_tap_opens_details_screen**
   - **Setup**: Render CampaignDashboard with crew
   - **Action**: Tap CharacterCard instance
   - **Expected**:
     - card_tapped signal emitted by CharacterCard
     - CampaignDashboard receives signal
     - Character details screen opens (or navigation triggered)
   - **Priority**: P1

6. **test_view_details_button_navigates_correctly**
   - **Setup**: Render CampaignDashboard with crew (EXPANDED variant)
   - **Action**: Click "View" button on CharacterCard
   - **Expected**:
     - view_details_pressed signal emitted
     - Navigation to CharacterDetailsScreen with character_id
   - **Priority**: P1

7. **test_remove_character_updates_crew_roster**
   - **Setup**: Render CampaignDashboard with 4 crew members
   - **Action**: Click "Remove" button on CharacterCard
   - **Expected**:
     - remove_pressed signal emitted
     - Confirmation dialog shown (if applicable)
     - Crew roster updates, card removed from UI
   - **Priority**: P1

#### Save/Load Signals (2 tests)

8. **test_save_button_triggers_save_signal**
   - **Setup**: Render CampaignDashboard
   - **Action**: Click "Save" button
   - **Expected**:
     - save_requested signal emitted
     - GameStateManager receives signal
     - Save process initiated
   - **Priority**: P1

9. **test_load_button_triggers_load_signal**
   - **Setup**: Render CampaignDashboard
   - **Action**: Click "Load" button
   - **Expected**:
     - load_requested signal emitted
     - File dialog opened
     - Load process initiated on file selection
   - **Priority**: P2

#### Navigation Signals (2 tests)

10. **test_manage_crew_button_opens_crew_screen**
    - **Setup**: Render CampaignDashboard
    - **Action**: Click "Manage Crew" button
    - **Expected**:
      - navigate_to_crew_management signal emitted
      - Crew management screen opens
    - **Priority**: P1

11. **test_quit_button_confirms_before_exit**
    - **Setup**: Render CampaignDashboard
    - **Action**: Click "Quit" button
    - **Expected**:
      - quit_requested signal emitted
      - Confirmation dialog shown (unsaved changes check)
      - Exit only if confirmed
    - **Priority**: P2

#### Battle History Signals (2 tests)

12. **test_resume_battle_button_loads_battle_state**
    - **Setup**: Mock campaign with active battle
    - **Action**: Click "Resume Battle" button
    - **Expected**:
      - resume_battle_requested signal emitted
      - Battle state loaded from GameStateManager
      - Battle screen opens with saved state
    - **Priority**: P1

13. **test_no_active_battle_disables_resume_button**
    - **Setup**: Mock campaign with no active battle
    - **Action**: Render CampaignDashboard
    - **Expected**:
      - "Resume Battle" button disabled
      - Button tooltip shows "No active battle"
    - **Priority**: P2

---

## 6. Manual QA Checklist: Responsive Behavior

**File**: `tests/manual/MANUAL_QA_DASHBOARD_RESPONSIVE.md`
**Priority**: P1 (High)
**Format**: Human-executed checklist
**Estimated Time**: 30 minutes

### Checklist Structure

#### Pre-Flight Validation
- [ ] No GDScript errors in console
- [ ] All unit tests passing (test_character_card, test_campaign_progress_tracker)
- [ ] All integration tests passing (data binding, responsive, signal flow)
- [ ] Theme resource loads correctly

#### Mobile (360x640) Testing
- [ ] Single column layout
- [ ] Bottom navigation visible
- [ ] All touch targets ≥ 48px
- [ ] No horizontal overflow (except crew carousel)
- [ ] Crew cards horizontal scroll works smoothly
- [ ] Progress tracker scrollable horizontally
- [ ] Text readable at mobile size

#### Tablet (600x800) Testing
- [ ] Two-column layout
- [ ] Crew cards in 2-column grid
- [ ] Touch targets ≥ 56px (comfortable)
- [ ] No horizontal scrolling required
- [ ] Progress tracker fits without scrolling
- [ ] All stat badges visible

#### Desktop (1920x1080) Testing
- [ ] Full layout with sidebar
- [ ] Three-column grid for cards
- [ ] Crew cards in 3-column grid (EXPANDED variant)
- [ ] All content visible without scrolling
- [ ] Action buttons all visible
- [ ] No wasted whitespace

#### Viewport Resize Testing
- [ ] Mobile → Tablet: Layout transitions smoothly
- [ ] Tablet → Desktop: Grid expands correctly
- [ ] Desktop → Mobile: Content collapses gracefully
- [ ] No visual glitches during resize
- [ ] No orphaned nodes after resize

#### Orientation Change (Tablet)
- [ ] Portrait → Landscape: Content reflows
- [ ] Landscape → Portrait: Content stacks
- [ ] No content clipping
- [ ] Progress tracker adapts

#### Design System Compliance
- [ ] Touch targets meet minimums (48px mobile, 56px tablet)
- [ ] Color contrast ratios pass WCAG AA
- [ ] Typography sizes match design system
- [ ] Spacing consistent (8px grid)
- [ ] Borders and corners consistent (8px radius, 2px width)

---

## Priority Matrix

### P0: Critical (Must Pass for Beta) - 28 tests
- CharacterCard variant display (3 tests)
- CharacterCard stat badge integration (1 test)
- Progress tracker phase highlighting (4 tests)
- Progress tracker phase transitions (1 test)
- Dashboard data binding (7 tests)
- Dashboard signal flow (2 tests)
- Mobile layout basics (3 tests)
- Tablet layout basics (2 tests)
- Desktop layout basics (2 tests)
- Viewport resize (2 tests)
- Manual QA pre-flight (1 checklist)

### P1: High (Important for Production) - 25 tests
- CharacterCard variant switching (1 test)
- CharacterCard stat updates (1 test)
- CharacterCard equipment tooltips (1 test)
- CharacterCard XP progress (1 test)
- CharacterCard signals (2 tests)
- Progress tracker action button (2 tests)
- Progress tracker responsive (1 test)
- Dashboard data binding (5 tests)
- Dashboard responsive (4 tests)
- Dashboard signal flow (7 tests)

### P2: Medium (Polish & Edge Cases) - 12 tests
- CharacterCard stat colors (1 test)
- CharacterCard empty equipment (1 test)
- CharacterCard XP overflow (1 test)
- Progress tracker touch targets (1 test)
- Dashboard data binding (3 tests)
- Dashboard responsive (3 tests)
- Dashboard signal flow (2 tests)

---

## Test Execution Plan

### Phase 1: Unit Tests (Week 1, Days 1-2)
1. Create test_character_card.gd (13 tests) - **2 hours**
2. Create test_campaign_progress_tracker.gd (11 tests) - **2 hours**
3. Execute all unit tests via PowerShell - **30 minutes**
4. Fix any failures - **1 hour**

**Deliverable**: 24/24 unit tests passing

### Phase 2: Integration Tests (Week 1, Days 3-5)
1. Create test_dashboard_data_binding.gd (13 tests) - **3 hours**
2. Create test_dashboard_responsive.gd (13 tests) - **3 hours**
3. Create test_dashboard_signal_flow.gd (13 tests) - **3 hours**
4. Execute all integration tests - **45 minutes**
5. Fix any failures - **2 hours**

**Deliverable**: 39/39 integration tests passing

### Phase 3: Manual QA (Week 2, Day 1)
1. Execute manual responsive checklist - **30 minutes**
2. Document any visual regressions - **15 minutes**
3. Create bug tickets for failures - **15 minutes**

**Deliverable**: Manual QA checklist completed, 0 regressions

### Phase 4: Regression & Performance (Week 2, Day 2)
1. Run full test suite (63 tests) - **45 minutes**
2. Profile dashboard load time (target: <500ms) - **30 minutes**
3. Profile memory usage (target: <200MB) - **30 minutes**
4. Fix performance regressions - **2 hours**

**Deliverable**: 100% test pass rate, performance targets met

---

## Dependencies & Blockers

### Test File Dependencies
- `test_character_card.gd` depends on:
  - CharacterCard.gd (UI component)
  - StatBadge.gd (UI component)
  - Character.gd (data model)
  - KeywordTooltip.gd (optional, for equipment test)

- `test_campaign_progress_tracker.gd` depends on:
  - CampaignDashboard.gd (UI component)
  - CampaignPhaseManager.gd (state management)

- `test_dashboard_data_binding.gd` depends on:
  - GameStateManager.gd (autoload singleton)
  - CampaignDashboard.gd
  - Character.gd

- `test_dashboard_responsive.gd` depends on:
  - CampaignDashboard.gd
  - ResponsiveContainer.gd (if implemented)

- `test_dashboard_signal_flow.gd` depends on:
  - SignalBus.gd (autoload singleton)
  - CampaignDashboard.gd
  - CampaignPhaseManager.gd

### External Blockers
- **Godot 4.5.1 headless bug**: Must use UI mode for all tests
- **GDUnit4 test count limit**: Max 13 tests per file (stability)
- **ResponsiveContainer**: If not implemented, responsive tests may need mocking

---

## Success Criteria

### Test Coverage
- [ ] 100% of P0 tests passing (28/28)
- [ ] 95%+ of P1 tests passing (24/25+)
- [ ] 80%+ of P2 tests passing (10/12+)
- [ ] Manual QA checklist 100% complete
- [ ] 0 regressions from existing functionality

### Performance
- [ ] Dashboard load time < 500ms (95th percentile)
- [ ] Memory usage < 200MB peak
- [ ] Frame rate > 58 FPS sustained (95% of frames)
- [ ] No signal leaks after dashboard free

### Code Quality
- [ ] All tests follow GDUnit4 v6.0.1 patterns
- [ ] Test files ≤ 13 tests each
- [ ] Helper classes plain (no Node inheritance)
- [ ] Clear, descriptive test names
- [ ] Comprehensive assertions

---

## Maintenance Notes

### When to Update This Spec
- When CharacterCard API changes (variant enum, signals)
- When CampaignDashboard layout changes (responsive breakpoints)
- When design system constants update (colors, spacing, sizes)
- When new dashboard features added (battle history, etc.)
- When Godot version updates (verify headless bug status)

### Test File Consolidation
Current plan: 6 test files (4 unit, 2 integration, 1 manual)
If file count becomes issue per Framework Bible:
- Merge test_character_card.gd + test_campaign_progress_tracker.gd → test_dashboard_components.gd (24 tests, exceeds 13-test limit - NOT recommended)
- Alternative: Keep separate, verify Framework Bible allows test files

---

## Appendix: Test Execution Commands

### Run Single Test File
```powershell
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_character_card.gd `
  --quit-after 60
```

### Run All Dashboard Tests (Sequential)
```powershell
$dashboardTests = @(
    'tests/unit/test_character_card.gd',
    'tests/unit/test_campaign_progress_tracker.gd',
    'tests/integration/test_dashboard_data_binding.gd',
    'tests/integration/test_dashboard_responsive.gd',
    'tests/integration/test_dashboard_signal_flow.gd'
)

foreach ($testFile in $dashboardTests) {
    Write-Host "Running $testFile..." -ForegroundColor Cyan
    & 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
      --path 'c:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
      --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
      -a $testFile `
      --quit-after 60
}
```

---

**End of Test Specifications**
