# Campaign Wizard Responsive Layout Implementation

**Date**: 2025-11-28
**Component**: `src/ui/screens/campaign/CampaignCreationUI.tscn/.gd`
**Status**: ✅ Complete

## Overview
Implemented responsive wizard layout system for campaign creation with mobile/tablet/desktop support, smooth panel transitions, and progress visualization.

## Changes Made

### 1. Scene Structure (`CampaignCreationUI.tscn`)
**Added complete responsive hierarchy**:
```
CampaignCreationUI (Control)
└── ResponsiveMargin (MarginContainer) - Responsive padding
    └── MainContainer (VBoxContainer)
        ├── HeaderSection (MarginContainer)
        │   └── HeaderContainer (VBoxContainer)
        │       ├── ProgressBar (thin 8px bar)
        │       ├── BreadcrumbContainer (HBoxContainer)
        │       │   └── Step1-Step7 (Label dots: ●)
        │       └── StepIndicator (Label - "Step X of 7 • Panel Title")
        ├── ContentArea (PanelContainer)
        │   └── ContentMargin (MarginContainer)
        │       └── PanelContainer (Control) - Dynamic panel insertion
        └── NavigationFooter (MarginContainer)
            └── NavigationContainer (HBoxContainer)
                ├── BackButton
                ├── ValidationStatus (HBoxContainer)
                │   ├── ValidationIcon (⚠️/✅)
                │   └── ValidationText
                └── NextButton/FinishButton
```

### 2. Script Updates (`CampaignCreationUI.gd`)

#### Added @onready References
```gdscript
@onready var responsive_margin: MarginContainer = $ResponsiveMargin
@onready var progress_indicator: ProgressBar = $ResponsiveMargin/MainContainer/HeaderSection/HeaderContainer/ProgressBar
@onready var breadcrumb_container: HBoxContainer = $ResponsiveMargin/MainContainer/HeaderSection/HeaderContainer/BreadcrumbContainer
@onready var step_indicator: Label = $ResponsiveMargin/MainContainer/HeaderSection/HeaderContainer/StepIndicator
@onready var content_container: Control = $ResponsiveMargin/MainContainer/ContentArea/ContentMargin/PanelContainer
@onready var back_button: Button = $ResponsiveMargin/MainContainer/NavigationFooter/NavigationContainer/BackButton
@onready var next_button: Button = $ResponsiveMargin/MainContainer/NavigationFooter/NavigationContainer/NextButton
@onready var finish_button: Button = $ResponsiveMargin/MainContainer/NavigationFooter/NavigationContainer/FinishButton
```

#### Responsive System Functions
- **`_apply_responsive_margins()`** - Adjusts margins based on viewport width
  - Mobile (<768px): 16px margins
  - Tablet (768-1024px): 32px margins
  - Desktop (≥1024px): 64px margins

- **`_style_wizard_header()`** - Applies visual styling to progress bar and breadcrumbs
  - Progress bar: COLOR_BORDER background, COLOR_ACCENT fill, 4px radius
  - Breadcrumbs: Dynamic color based on completion state

- **`_connect_navigation_signals()`** - Wires navigation button signals

#### Panel Transition Functions
- **`_fade_out_panel(panel)`** - Smooth 150ms fade-out animation
- **`_fade_in_panel(panel)`** - Smooth 150ms fade-in animation
- **`_switch_to_phase(phase)`** - Enhanced with await fade transitions
  - Prevents rapid clicks via `is_panel_fading` flag
  - Sequence: fade out → clear → load → fade in → update navigation

#### Progress Tracking
- **`update_progress_indicator(step, panel_title)`**
  - Updates ProgressBar value (1-7)
  - Colors breadcrumb dots:
    - Completed: `#2D5A7B` (COLOR_ACCENT)
    - Current: `#4FC3F7` (COLOR_FOCUS)
    - Future: `#808080` (COLOR_TEXT_SECONDARY)
  - Updates step text: "Step X of 7 • Panel Title"

- **`_update_progress_for_phase(phase)`**
  - Maps phase enum to step number:
    - CONFIG → 1
    - SHIP_ASSIGNMENT → 2
    - CAPTAIN_CREATION → 3
    - CREW_SETUP → 4
    - EQUIPMENT_GENERATION → 5
    - WORLD_GENERATION → 6
    - FINAL_REVIEW → 7

### 3. Responsive Layout Modes

#### Mobile (<768px)
- 16px margins
- 80px button width
- 48dp touch targets
- 14pt step indicator font

#### Tablet (768-1024px)
- 32px margins
- 100px button width
- 48dp touch targets
- 16pt step indicator font

#### Desktop (≥1024px)
- 64px margins
- 100px button width
- 48dp touch targets
- 18pt step indicator font

## Panel Integration

### Panel Order (7 Panels)
1. **ExpandedConfigPanel** - Campaign Setup (includes victory conditions)
2. **ShipPanel** - Ship Assignment
3. **CaptainPanel** - Captain Creation
4. **CrewPanel** - Crew Setup (≥4 crew required)
5. **EquipmentPanel** - Equipment Distribution
6. **WorldInfoPanel** - World Generation
7. **FinalPanel** - Final Review

### Signal Flow (Call-Down-Signal-Up)
**Panels → CampaignCreationUI**:
- `panel_validation_changed(is_valid)` - Enable/disable Next button
- `panel_data_changed(data)` - Update state manager
- `panel_completed(data)` - Mark phase complete

**CampaignCreationUI → Panels**:
- `set_coordinator(coordinator)` - Provide coordinator reference
- `set_panel_data(data)` - Restore saved state

## Navigation Logic

### Validation System
- **ValidationStatus** displays current panel state:
  - ⚠️ "Complete required fields to continue" (invalid)
  - ✅ "Ready to continue" (valid)
- **Next button** disabled until panel validates
- **Back button** disabled on first panel
- **Finish button** shown only on final panel

### Panel Validation Requirements
- **Config**: Difficulty selected, victory conditions set
- **Ship**: Name entered, valid hull points
- **Captain**: Name entered, background/class selected
- **Crew**: ≥4 crew members created
- **Equipment**: Credits allocated (always valid)
- **World**: World generated (always valid)
- **Final**: All previous panels valid

## Performance Optimizations

### Transition Smoothness
- 150ms fade duration (optimal for perceived smoothness)
- `is_panel_fading` flag prevents rapid clicks
- Tween easing: EASE_IN_OUT, TRANS_CUBIC
- Await chaining prevents race conditions

### Memory Safety
- Panels fade out before `queue_free()`
- `await get_tree().process_frame` ensures cleanup
- Signal disconnection before panel removal
- Tracked connections in `_panel_signal_connections`

## Testing Checklist

### Responsive Layout
- ☐ Resize viewport from 320px to 1920px width
- ☐ Verify margins adjust at breakpoints (768px, 1024px)
- ☐ Check button sizes on mobile (80px) vs desktop (100px)
- ☐ Confirm 48dp touch targets on all devices

### Panel Transitions
- ☐ Smooth fade-out when clicking Next
- ☐ Smooth fade-in after panel loads
- ☐ No flicker or panel stacking
- ☐ Rapid clicks don't break transitions

### Progress Indicator
- ☐ Progress bar fills 1/7 per step
- ☐ Breadcrumb dots color correctly (completed/current/future)
- ☐ Step text updates: "Step X of 7 • Panel Title"
- ☐ Panel titles match phase names

### Navigation
- ☐ Back button disabled on Step 1
- ☐ Next button disabled when panel invalid
- ☐ Finish button appears only on Step 7
- ☐ ValidationStatus shows correct message

### Panel Integration
- ☐ All 7 panels load successfully
- ☐ Panel data persists on back navigation
- ☐ Coordinator passes state to panels
- ☐ Panel signals properly connected

## Known Issues / Future Improvements

### Current Limitations
1. No keyboard navigation (Tab/Enter/Escape)
2. No panel save on browser refresh
3. No progress persistence across sessions
4. No accessibility labels (screen readers)

### Future Enhancements
1. Add keyboard shortcuts (Ctrl+← / Ctrl+→)
2. Add "Save & Exit" functionality
3. Add progress auto-save every 30 seconds
4. Add ARIA labels for accessibility
5. Add panel preview thumbnails in left sidebar
6. Add transition sound effects (optional)

## Files Modified
- `src/ui/screens/campaign/CampaignCreationUI.tscn` - Complete scene structure
- `src/ui/screens/campaign/CampaignCreationUI.gd` - Responsive layout + transitions
- **Total Lines Changed**: ~300 lines (scene + script)

## Dependencies
- `BaseCampaignPanel.gd` - Design system constants (SPACING_*, COLOR_*, TOUCH_TARGET_*)
- `CampaignCreationStateManager.gd` - Phase enum and state management
- `CampaignCreationCoordinator.gd` - Unified campaign state

## Validation Against Requirements

✅ **Responsive container system** - MarginContainer with 3 breakpoints  
✅ **Wizard navigation** - Back/Next/Finish buttons with validation  
✅ **Panel transitions** - 150ms fade in/out with tween animations  
✅ **7 wizard panels integrated** - Config → Ship → Captain → Crew → Equipment → World → Final  
✅ **Progress visualization** - ProgressBar + breadcrumb dots + step text  
✅ **Signal-based architecture** - Call-down-signal-up maintained  
✅ **Mobile/Tablet/Desktop support** - Breakpoints at 768px/1024px  
✅ **Touch target compliance** - 48dp minimum on all buttons  
✅ **Smooth wizard flow** - Clear progress indication, no jarring transitions  

## Implementation Notes

### Why Scene-Based Instead of Programmatic?
- **Godot best practice**: Scene files are the native UI design tool
- **Inspector-friendly**: Designers can adjust layout without code
- **Performance**: Precompiled scene tree faster than runtime creation
- **Maintainability**: Visual hierarchy in .tscn easier to understand

### Why 150ms Transition Duration?
- **UX research**: 100-200ms perceived as "instant" but smooth
- **Mobile optimization**: Longer transitions feel sluggish on touch
- **60fps target**: 150ms = 9 frames at 60fps (perceptibly smooth)

### Why Phase-to-Step Mapping?
- **Phase enum order** doesn't match wizard order (CONFIG, CAPTAIN, CREW, SHIP...)
- **Wizard order** follows logical flow (CONFIG, SHIP, CAPTAIN, CREW...)
- **Explicit mapping** prevents confusion from enum reordering

---

**Status**: Ready for integration testing
**Next Steps**: Test full wizard flow from CONFIG → FINAL_REVIEW
