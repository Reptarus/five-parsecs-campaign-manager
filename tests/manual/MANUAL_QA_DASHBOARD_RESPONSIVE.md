# Manual QA Checklist - CampaignDashboard Responsive Behavior

**Test Date**: _______________
**Tester**: _______________
**Build**: Campaign Dashboard UI Modernization
**Test Duration**: ~30 minutes

---

## Pre-Flight Validation

- [ ] **GDScript errors**: No errors in Godot output console
- [ ] **Unit tests**: test_character_card.gd passing (13/13)
- [ ] **Unit tests**: test_campaign_progress_tracker.gd passing (11/11)
- [ ] **Unit tests**: test_stat_badge.gd passing (8/8 existing)
- [ ] **Integration tests**: test_dashboard_data_binding.gd passing (13/13)
- [ ] **Integration tests**: test_dashboard_responsive.gd passing (13/13)
- [ ] **Integration tests**: test_dashboard_signal_flow.gd passing (13/13)
- [ ] **Theme resource**: res://assets/themes/deep_space_theme.tres loads correctly

---

## 📱 Mobile Testing (360x640 Portrait)

### Test Setup
1. Launch Godot project in windowed mode
2. Resize window to 360x640 pixels (or use mobile emulator)
3. Navigate to CampaignDashboard scene
4. Load test campaign with 6 crew members

### Layout Tests

#### Single Column Layout
- [ ] All content cards stack **vertically** (single column)
- [ ] No horizontal overflow (content fits within 360px width)
- [ ] Vertical scrolling enabled for full content
- [ ] Campaign Progress Tracker visible at top
- [ ] Bottom navigation visible (fixed position)

#### Bottom Navigation Bar
- [ ] Navigation buttons **fixed to bottom** of viewport
- [ ] Buttons span **full width** of screen (360px)
- [ ] Button height ≥ **48px** (TOUCH_TARGET_MIN)
- [ ] Buttons remain visible when scrolling content
- [ ] Button labels readable (not truncated)

#### Crew Cards (Horizontal Carousel)
- [ ] Crew cards displayed in **horizontal scroll** container
- [ ] Each card uses **COMPACT variant** (80px height)
- [ ] Smooth horizontal scrolling (no stuttering)
- [ ] Cards maintain aspect ratio (no distortion)
- [ ] 6 crew cards visible via scroll (not all at once)
- [ ] First card visible without scrolling
- [ ] Last card reachable via scroll

#### Campaign Progress Tracker
- [ ] Progress tracker displayed **horizontally** (7 steps)
- [ ] Tracker width ≤ 360px OR horizontal scroll enabled
- [ ] Current step highlighted correctly (e.g., "Travel")
- [ ] Step labels **readable** (may be abbreviated: "Travel" → "TRV")
- [ ] Step indicators ≥ **48px tap area** (touch-friendly)
- [ ] Smooth horizontal scrolling if needed

### Touch Target Tests

#### Measure Interactive Elements
- [ ] "Next Phase" button height ≥ **48px**
- [ ] "Manage Crew" button height ≥ **48px**
- [ ] "Save" button height ≥ **48px**
- [ ] Character card tap area ≥ **80px** (full card)
- [ ] Progress tracker step tap areas ≥ **48px**
- [ ] All buttons have **visible tap feedback** (press state)

#### Touch Interaction
- [ ] Single tap on CharacterCard navigates to details
- [ ] Tap on "Next Phase" triggers phase transition
- [ ] Tap on navigation buttons opens correct screen
- [ ] No accidental double-taps required
- [ ] Tap targets don't overlap (no mis-taps)

### Typography & Readability

#### Font Sizes
- [ ] Campaign name: **XL (24px)** - readable without zoom
- [ ] Section headers: **LG (18px)** - readable
- [ ] Body text: **MD (16px)** - comfortable reading
- [ ] Stat badge labels: **XS (11px)** - readable but small
- [ ] Button labels: **MD (16px)** - clear

#### Text Wrapping
- [ ] Long campaign names wrap correctly (no truncation)
- [ ] Character names wrap if needed (e.g., "Eliana 'Shadowfox' Martinez")
- [ ] No horizontal text overflow
- [ ] No text clipping (fully visible)

### Visual Design

#### Spacing (8px Grid)
- [ ] Card padding: **16px** (SPACING_MD)
- [ ] Section gaps: **24px** (SPACING_LG)
- [ ] Element gaps within cards: **8px** (SPACING_SM)
- [ ] Bottom navigation padding: **16px top/bottom**

#### Colors & Contrast
- [ ] Text readable against backgrounds (WCAG AA compliance)
- [ ] Accent color (#3b82f6) visible on dark backgrounds
- [ ] Status badges legible (Leader, Ready, Injured)
- [ ] Stat badges contrast ratio sufficient

---

## 📱 Mobile Testing (640x360 Landscape)

### Test Setup
1. Rotate device/window to **640x360 landscape**
2. Reload CampaignDashboard

### Layout Adaptation
- [ ] Content reflows to **landscape layout**
- [ ] Crew cards may display in **2-column grid** (if space)
- [ ] Progress tracker fits **horizontally** without scroll
- [ ] Bottom navigation still visible
- [ ] All content accessible without excessive scrolling

---

## 📱 Tablet Testing (600x800 Portrait)

### Test Setup
1. Resize window to 600x800 pixels (tablet portrait)
2. Reload CampaignDashboard

### Layout Tests

#### Two-Column Grid
- [ ] Content arranged in **2-column layout**
- [ ] Left column: Campaign stats, Crew roster
- [ ] Right column: World info, Quest info
- [ ] Columns balanced (equal width)
- [ ] No horizontal overflow

#### Crew Cards (Grid Layout)
- [ ] Crew cards displayed in **2-column grid**
- [ ] Each card uses **STANDARD variant** (120px height)
- [ ] Grid spacing consistent (**SPACING_MD = 16px**)
- [ ] 6 crew cards visible in 3 rows × 2 columns
- [ ] No horizontal scrolling required
- [ ] Vertical scrolling for full roster

#### Campaign Progress Tracker
- [ ] Progress tracker fits **full width** (600px)
- [ ] All 7 steps visible **without scrolling**
- [ ] Step indicators larger (**56px height** - TOUCH_TARGET_COMFORT)
- [ ] Step labels fully spelled out ("Travel", "World", etc.)

### Touch Target Tests (Comfortable Size)
- [ ] All buttons ≥ **56px height** (TOUCH_TARGET_COMFORT)
- [ ] Increased spacing between buttons (**SPACING_LG = 24px**)
- [ ] Character cards ≥ **120px tap area** (full STANDARD card)
- [ ] Progress tracker steps ≥ **56px tap area**

### Visual Polish
- [ ] Typography scales appropriately (may use larger sizes)
- [ ] Stat badges maintain **80x64px minimum**
- [ ] No wasted whitespace (columns balanced)
- [ ] Smooth scrolling for long content

---

## 📱 Tablet Testing (800x600 Landscape)

### Test Setup
1. Rotate window to **800x600 landscape**
2. Reload CampaignDashboard

### Layout Adaptation
- [ ] Content reflows to **landscape layout**
- [ ] Crew cards may display in **3-column grid** (more horizontal space)
- [ ] Progress tracker uses full width (800px)
- [ ] All content fits with minimal vertical scrolling

---

## 💻 Desktop Testing (1920x1080)

### Test Setup
1. Maximize window to **1920x1080** (or full desktop resolution)
2. Reload CampaignDashboard

### Layout Tests

#### Full Layout with Sidebar
- [ ] **Left sidebar** visible (navigation, quick actions)
- [ ] **Main content area** uses 3-column grid
- [ ] **Right panel** may show additional info (patrons, rivals)
- [ ] All cards visible **without scrolling** (above fold)
- [ ] Sidebar width: ~250px (balanced, not too wide)

#### Crew Cards (Full Grid)
- [ ] Crew cards displayed in **3-column grid** (2 rows × 3 columns for 6 crew)
- [ ] Each card uses **EXPANDED variant** (160px height)
- [ ] Action buttons visible on all cards (View, Edit, Remove)
- [ ] Equipment badges visible (with keyword tooltips)
- [ ] XP progress bars visible
- [ ] Status badges visible (Leader, Ready, Injured)

#### Campaign Progress Tracker
- [ ] Progress tracker spans **full content width** (~1400px)
- [ ] All 7 steps visible with **generous spacing**
- [ ] Step labels fully spelled out (no abbreviations)
- [ ] Step icons/indicators clearly visible
- [ ] No scrolling required

### Expanded Information Panels

#### Patron List
- [ ] Patron list visible in right panel
- [ ] Individual patron cards with details
- [ ] Patron job offers visible
- [ ] Interactive (click to view patron details)

#### Rival List
- [ ] Rival list visible in right panel
- [ ] Individual rival cards with details
- [ ] Threat level indicators visible
- [ ] Interactive (click to view rival details)

#### Battle History
- [ ] Battle history panel visible
- [ ] List of past battles (scrollable if >5)
- [ ] "Resume Battle" button visible (if active battle)
- [ ] Battle outcomes displayed (Victory, Defeat, Draw)

### Visual Design

#### Typography
- [ ] Campaign name: **XL (24px)** - prominent focal point
- [ ] Section headers: **LG (18px)** - clear hierarchy
- [ ] Body text: **MD (16px)** - comfortable reading distance
- [ ] No text scaling needed (native desktop sizes)

#### Spacing & Layout
- [ ] Panel edge padding: **32px** (SPACING_XL)
- [ ] Section gaps: **24px** (SPACING_LG)
- [ ] Card gaps in grid: **16px** (SPACING_MD)
- [ ] No cramped content (ample whitespace)

#### Colors & Contrast
- [ ] All colors visible on large display
- [ ] Accent colors pop against dark backgrounds
- [ ] Stat badges clearly legible from desk distance (~60cm)

---

## 🔄 Viewport Resize Testing

### Mobile → Tablet Transition (360x640 → 600x800)

#### Test Steps
1. Start at **360x640** (mobile portrait)
2. Gradually resize to **600x800** (tablet portrait)
3. Observe layout transitions

#### Expected Behavior
- [ ] Layout transitions **smoothly** (no sudden jumps)
- [ ] Crew cards transition from **horizontal scroll → 2-column grid**
- [ ] Crew card variant transitions from **COMPACT → STANDARD**
- [ ] Progress tracker expands to full width
- [ ] Touch targets increase from **48px → 56px**
- [ ] No visual glitches during resize (no flickering)
- [ ] No orphaned elements (all components reflow)

### Tablet → Desktop Transition (600x800 → 1920x1080)

#### Test Steps
1. Start at **600x800** (tablet portrait)
2. Gradually resize to **1920x1080** (desktop)
3. Observe layout transitions

#### Expected Behavior
- [ ] Layout transitions **smoothly**
- [ ] Crew cards transition from **2-column → 3-column grid**
- [ ] Crew card variant transitions from **STANDARD → EXPANDED**
- [ ] Left sidebar appears (navigation)
- [ ] Right panel appears (patrons, rivals)
- [ ] All content expands to fill available space
- [ ] No visual glitches during resize

### Desktop → Mobile Transition (1920x1080 → 360x640)

#### Test Steps
1. Start at **1920x1080** (desktop)
2. Gradually resize to **360x640** (mobile portrait)
3. Observe layout transitions

#### Expected Behavior
- [ ] Layout transitions **smoothly** (graceful degradation)
- [ ] Crew cards transition from **3-column → horizontal scroll**
- [ ] Crew card variant transitions from **EXPANDED → COMPACT**
- [ ] Left sidebar collapses (hidden or hamburger menu)
- [ ] Right panel collapses (hidden or tabs)
- [ ] Bottom navigation appears (fixed position)
- [ ] No content clipping (all accessible via scroll)
- [ ] No visual glitches during resize

### Rapid Resize Test (Stress Test)

#### Test Steps
1. Start at any viewport size
2. **Rapidly resize** window 20 times (random sizes)
3. Final size: 1920x1080

#### Expected Behavior
- [ ] No console errors (memory leaks, orphaned signals)
- [ ] Layout adapts correctly after rapid resizes
- [ ] Memory usage **stable** (character card pool reused)
- [ ] No visual artifacts remaining (no ghost elements)
- [ ] Final layout matches expected desktop layout

---

## 📐 Design System Compliance

### Touch Targets (Critical for Mobile)

#### Minimum Sizes
- [ ] **Mobile** (360x640): All interactive elements ≥ **48px** (TOUCH_TARGET_MIN)
- [ ] **Tablet** (600x800): All interactive elements ≥ **56px** (TOUCH_TARGET_COMFORT)
- [ ] **Desktop** (1920x1080): Buttons may use desktop sizes (40px acceptable)

#### Spacing Between Targets
- [ ] Minimum **8px gap** between adjacent tap targets (SPACING_SM)
- [ ] Preferred **16px gap** for comfortable tapping (SPACING_MD)
- [ ] No overlapping tap areas

### Color Contrast (WCAG AA)

#### Text Contrast Ratios
- [ ] Primary text (COLOR_TEXT_PRIMARY #f3f4f6) on dark background ≥ **4.5:1**
- [ ] Secondary text (COLOR_TEXT_SECONDARY #9ca3af) on dark background ≥ **3.0:1**
- [ ] Accent text (COLOR_BLUE #3b82f6) on dark background ≥ **3.0:1**
- [ ] Stat badge values on badge backgrounds ≥ **4.5:1**

#### Interactive Element Contrast
- [ ] Button backgrounds (COLOR_BLUE #3b82f6) on dark ≥ **3.0:1**
- [ ] Button text on button background ≥ **4.5:1**
- [ ] Status badges (Leader, Ready, Injured) ≥ **3.0:1**

### Typography Scale

#### Font Sizes Match Design System
- [ ] XL (24px): Campaign name, major headings
- [ ] LG (18px): Section headers
- [ ] MD (16px): Body text, buttons, inputs
- [ ] SM (14px): Descriptions, helper text
- [ ] XS (11px): Captions, stat badge labels

#### Font Weights
- [ ] Bold: Campaign name, section headers
- [ ] Regular: Body text, stat values
- [ ] Light: Descriptions (if applicable)

### Spacing System (8px Grid)

#### Verify Spacing Constants
- [ ] SPACING_XS (4px): Icon padding, label-to-input gap
- [ ] SPACING_SM (8px): Element gaps within cards
- [ ] SPACING_MD (16px): Inner card padding
- [ ] SPACING_LG (24px): Section gaps between cards
- [ ] SPACING_XL (32px): Panel edge padding

#### Measure Actual Spacing
- [ ] Card padding: **16px** (4 sides)
- [ ] Section gaps: **24px** (vertical)
- [ ] Button gaps: **8px** (horizontal in button group)
- [ ] Panel edge padding: **32px** (4 sides)

### Borders & Corners

#### Border Widths
- [ ] Card borders: **2px** (visible but not dominant)
- [ ] Stat badge borders: **1px** (subtle)
- [ ] ValidationPanel borders: **2px** (critical states)

#### Corner Radii
- [ ] Cards: **8px** (rounded corners)
- [ ] Stat badges: **8px** (consistent with cards)
- [ ] Buttons: **8px** (consistent theme)
- [ ] ValidationPanel: **8px** (consistent)

### Color Palette Usage

#### Background Colors
- [ ] COLOR_PRIMARY (#0a0d14): Panel backgrounds
- [ ] COLOR_SECONDARY (#111827): Card backgrounds
- [ ] COLOR_TERTIARY (#1f2937): Input backgrounds

#### Accent Colors
- [ ] COLOR_BLUE (#3b82f6): Primary accent, links, progress
- [ ] COLOR_EMERALD (#10b981): Success states, positive stats
- [ ] COLOR_AMBER (#f59e0b): Warning states, debt badges
- [ ] COLOR_RED (#ef4444): Error states, danger actions

#### Text Colors
- [ ] COLOR_TEXT_PRIMARY (#f3f4f6): Main content
- [ ] COLOR_TEXT_SECONDARY (#9ca3af): Descriptions, labels
- [ ] COLOR_TEXT_MUTED (#6b7280): Disabled, inactive

---

## ⚡ Performance Testing

### Load Time
- [ ] CampaignDashboard loads in **< 500ms** (cold start)
- [ ] No visible lag when switching from other screens
- [ ] Smooth transition animation (if applicable)

### Rendering Performance
- [ ] No frame drops when displaying all components (≥58 FPS)
- [ ] Crew roster with 6 characters renders smoothly
- [ ] Stat badges render without flicker
- [ ] Progress tracker updates instantly on phase change

### Memory Usage
- [ ] Memory usage **< 200MB peak** (measured via Godot profiler)
- [ ] No memory leaks when switching panels repeatedly (10 times)
- [ ] Resources cleanup properly when leaving dashboard
- [ ] Character card pool reused (no recreation on resize)

### Scrolling Performance
- [ ] Smooth 60 FPS scrolling (vertical content)
- [ ] Smooth 60 FPS scrolling (horizontal crew carousel)
- [ ] No stuttering when scrolling rapidly
- [ ] No frame drops when reaching end of scroll

---

## 🐛 Regression Testing

### Critical Data Flow
- [ ] No null parameter errors in console
- [ ] No type mismatch errors in console
- [ ] Campaign data displays correctly (credits, story points, phase)
- [ ] Character data displays correctly (names, stats, equipment)

### Signal Flow
- [ ] Panel transitions work correctly (no disconnection errors)
- [ ] Data propagates from GameStateManager to UI
- [ ] No orphaned signal warnings in console
- [ ] Signal cleanup on dashboard free (no leaks)

### Save/Load
- [ ] Campaign save completes without errors
- [ ] Save file contains all dashboard data
- [ ] Loaded campaign displays correctly in dashboard
- [ ] Save/load roundtrip preserves all data

---

## Edge Case Testing

### Boundary Conditions
- [ ] **Minimum crew (1 member)**: Crew carousel displays correctly
- [ ] **Maximum crew (8 members)**: All cards visible via scroll
- [ ] **0 credits**: Credits label displays "0 Credits" (not blank)
- [ ] **Very long campaign name (50+ characters)**: Name wraps correctly
- [ ] **Special characters in name (★, ♠, emoji)**: Displays without errors

### Empty States
- [ ] **No active quest**: Quest panel shows "No active quest" placeholder
- [ ] **No patrons**: Patron list shows empty state
- [ ] **No rivals**: Rival list shows empty state
- [ ] **No battle history**: Battle history shows empty state

### Extreme Values
- [ ] **Credits = 999,999**: Displays with thousands separators
- [ ] **Story points = 20**: Displays correctly (no overflow)
- [ ] **Phase = POST_BATTLE**: Progress tracker highlights correctly

---

## Sign-Off

### Testing Summary
- **Tests Passed**: ______ / ______
- **Tests Failed**: ______
- **Blockers Found**: ______
- **Regressions Found**: ______

### Tester Notes
```
[Add any observations, issues, or recommendations here]




```

### Issues Found (List Below)
```
1. [Issue description - severity - steps to reproduce]
2.
3.
```

### Production Readiness Assessment
- [ ] **APPROVED** - Ready for commit and production
- [ ] **APPROVED WITH NOTES** - Minor issues, safe to proceed
- [ ] **BLOCKED** - Critical issues must be fixed before commit

### Screenshots (Attach)
- [ ] Mobile (360x640) - Full dashboard
- [ ] Tablet (600x800) - Full dashboard
- [ ] Desktop (1920x1080) - Full dashboard
- [ ] Resize transition (GIF or video)

**Tester Signature**: _______________
**Date**: _______________
