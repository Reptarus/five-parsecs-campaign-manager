# Campaign Creation Wizard - UI/UX Research Report

**Research Date**: 2025-11-23
**Focus**: Existing UI patterns, design system elements, wizard/stepper implementations, and Five Parsecs campaign creation requirements

---

## EXECUTIVE SUMMARY

The codebase has a **solid foundation for wizard-style configuration**:
- ✅ Multi-panel architecture already in place (7 sequential panels)
- ✅ Coordinator pattern for workflow orchestration
- ✅ Theme system with 6 variants (base, dark, light, sci-fi, high contrast)
- ✅ Tooltip system with intelligent positioning
- ✅ Base component classes for consistency
- ⚠️ Progress indicators not yet implemented
- ⚠️ Validation feedback patterns need standardization
- ⚠️ Help/guidance overlays missing

**Recommendation**: Build wizard UI leveraging existing patterns, adding progress tracking and contextual help.

---

## PART 1: EXISTING UI COMPONENT PATTERNS

### 1.1 Panel Architecture (Most Relevant for Wizard)

**Location**: `src/ui/screens/campaign/panels/`

The codebase already implements a **panel-based wizard pattern** with 10 specialized panels:

```
BaseCampaignPanel.gd (abstract base)
├── ConfigPanel.gd - Campaign configuration (difficulty, story track, etc)
├── CaptainPanel.gd - Captain/leader creation
├── CrewPanel.gd - Crew member selection
├── EquipmentPanel.gd - Equipment generation
├── ShipPanel.gd - Ship assignment
├── WorldInfoPanel.gd - World details
├── FinalPanel.gd - Campaign review & finalization
├── CharacterCreationDialog.gd - Character detailed creation
├── ExpandedConfigPanel.gd - Advanced configuration options
└── (others for specialized workflows)
```

**Base Class Pattern** (`BaseCampaignPanel.gd`):
- Minimal, Framework Bible-compliant design
- Essential signals: `panel_data_changed`, `panel_validation_changed`, `panel_completed`, `validation_failed`
- Panel metadata: `panel_title`, `panel_description`
- Key methods: `validate_panel()`, `get_panel_data()`, `set_panel_data()`
- Automatic UI structure creation if needed
- Coordinator integration pattern built-in

**Why This Works**:
- Each panel is self-contained and testable
- Signals provide loose coupling between panels
- Coordinator reference allows state sharing
- Validates data before transitioning
- Extensible without monolithic bloat

### 1.2 Coordinator Pattern for Workflow Orchestration

**Location**: `src/ui/screens/campaign/CampaignCreationCoordinator.gd`

The **CampaignCreationCoordinator** manages the multi-step workflow:

```gdscript
# Navigation signals
signal navigation_updated(can_go_back: bool, can_go_forward: bool, can_finish: bool)
signal phase_transition_requested(from_phase, to_phase)
signal step_changed(step: int, total_steps: int)

# State signals
signal campaign_state_updated(state_data: Dictionary)
signal equipment_state_updated(equipment_data: Dictionary)
signal crew_state_updated(crew_data: Dictionary)

# Current workflow (7 steps)
var total_steps: int = 7
var current_step: int = 0
var phase_completion_status: Dictionary  # Tracks which steps are done
```

**Key Capabilities**:
- Unified campaign state management
- Phase completion tracking
- Integrated victory conditions (no longer separate)
- Handles both back/forward and jump navigation
- Validates state before transitions

### 1.3 UI Screen Architecture

**Location**: `src/ui/screens/`

Main screens follow a **hub-and-panel pattern**:

```
CampaignCreationUI.gd (hub screen)
├── Header: Title, progress indicator placeholder
├── Navigation: Back/Next/Finish buttons
├── Panel Container: Dynamically loads current panel
└── Status Area: Validation errors, completion status
```

**Related Screens**:
- `CampaignSetupScreen.gd` - Initial quick setup (difficulty, campaign name, story track)
- `MainCampaignScene.gd` - Main game loop after creation
- `CampaignDashboard.gd` - Campaign overview with crew/patron/rival tracking

---

## PART 2: DESIGN SYSTEM ELEMENTS

### 2.1 Theme System (6 Variants)

**Location**: `src/ui/themes/`

Godot Theme resources with consistent styling:

```
base_theme.tres (foundation)
├── dark_theme.tres (dark mode)
├── light_theme.tres (light mode)
├── sci_fi_theme.tres (game aesthetic)
├── high_contrast_theme.tres (accessibility)
└── (others as needed)
```

**Current Theme Coverage**:
```gdscript
Button/colors/font_color = Color(0.875, 0.875, 0.875, 1)
Button/colors/font_focus_color = Color(0.95, 0.95, 0.95, 1)
Button/font_sizes/font_size = 16

Label/colors/font_color = Color(0.875, 0.875, 0.875, 1)
Label/font_sizes/font_size = 16
Label/constants/line_spacing = 3

RichTextLabel/colors/default_color = Color(0.875, 0.875, 0.875, 1)
RichTextLabel/font_sizes/normal_font_size = 16
```

**What's Missing for Wizard UI**:
- Progress bar styling (ProgressBar colors, fonts)
- Stepper indicator styles (step numbers, connectors)
- Validation state colors (error red, success green, warning orange)
- Info panel backgrounds
- Disabled state distinctions
- Hover/focus states for interactive elements

### 2.2 Color Scheme (Inferred from Theme)

**Primary Palette** (from base_theme.tres):
- Text: `#DEDEDE` (light gray)
- Focus: `#F2F2F2` (very light)
- Background: Dark (implied by light text)
- Accent: Blue (selection in RichTextLabel: `#0000FF80`)

**Recommendation for Wizard**:
- Use existing palette as foundation
- Add semantic colors:
  - Success: Green `#00AA00`
  - Error: Red `#DD0000`
  - Warning: Orange `#FFAA00`
  - Info: Cyan `#00DDDD`

### 2.3 Responsive Design Foundation

**Location**: `src/ui/components/base/ResponsiveContainer.gd` and `CampaignResponsiveLayout.gd`

- Built-in support for multiple screen sizes
- Breakpoints defined in `CampaignCreationUI.gd`:
  ```gdscript
  layout_breakpoints: Dictionary = {
      "mobile": 768,
      "tablet": 1024,
      "desktop": 1025
  }
  ```
- Used by campaign creation screens already

---

## PART 3: TOOLTIP & HELP SYSTEM

### 3.1 Universal Tooltip System

**Location**: `src/ui/components/common/Tooltip.gd`

**Features** (Production-ready):
```gdscript
# Positioning options
enum Position {
    AUTO,      # Smart positioning based on available space
    TOP, BOTTOM, LEFT, RIGHT,
    TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT
}

# Show/hide with delays
show_tooltip(text: String, target: Control, position: Position = AUTO)
show_immediately(text: String, target: Control, position: Position = AUTO)
hide_tooltip()
set_delays(show_delay_time: float, hide_delay_time: float)

# Sizing
max_width: float = 300.0
margin: float = 10.0

# Visual features
- Animated fade in/out (0.2s / 0.15s)
- Smart positioning to avoid screen edges
- Directional arrow pointing to target
- BBCode support for formatted text
```

**Signal-based Integration**:
```gdscript
signal tooltip_shown(text: String)
signal tooltip_hidden()
```

**Static Helper Methods**:
```gdscript
Tooltip.create_tooltip_for_control(control, text, position)
Tooltip.add_tooltip_to_control(control, text, position)
```

**Wizard Application**:
- Attach tooltips to all input fields
- Explain configuration options on hover
- Show rule references (e.g., "Difficulty: See Core Rulebook p.42")
- Validate field input with error tooltips

### 3.2 Keyword Tooltip System

**Location**: `src/ui/components/qol/KeywordTooltip.gd`

Similar to Tooltip but specialized for game terms/keywords (not fully explored in this research, but exists).

### 3.3 QoL Components Available

**Location**: `src/ui/components/qol/`

- `PhaseChecklistPanel.gd` - Checklist tracking (relevant for completion)
- `JournalPanel.gd` - Information display
- `ComparisonPanel.gd` - Side-by-side comparison
- `NPCTrackerPanel.gd` - Relationship tracking

---

## PART 4: DIALOG & POPUP PATTERNS

### 4.1 Quick Start Dialog

**Location**: `src/ui/components/dialogs/QuickStartDialog.gd`

Simple multi-option dialog with:
- Template selection
- Crew size dropdown
- Import option
- Dialog types: INFO, WARNING, ERROR, CONFIRMATION, INPUT

**Pattern for Wizard**:
- Modular confirmation dialogs at validation points
- Preset/template selection for quick start
- Context-sensitive help

### 4.2 Setup Dialogs

**Location**: `src/ui/screens/campaign/`

- `CampaignSetupDialog.gd` - Configuration dialog
- `CampaignLoadDialog.gd` - Load existing campaigns
- Various character creation dialogs

---

## PART 5: VALIDATION & ERROR HANDLING

### 5.1 Error Display Component

**Location**: `src/ui/components/ErrorDisplay.gd/tscn`

Dedicated error message display (exists but implementation not fully explored).

### 5.2 Validation Patterns in Panels

From `FinalPanel.gd` and `EquipmentPanel.gd`:

```gdscript
# Each panel implements validation
func validate_panel() -> bool:
    """Return true if panel data is valid"""
    return all_required_fields_present()

# Emit validation state
signal panel_validation_changed(is_valid: bool)
signal validation_failed(errors: Array[String])

# Track last validation errors
var last_validation_errors: Array[String] = []
```

**Current Gap**: 
- No inline field validation UI
- No real-time feedback during form filling
- No clear error message display strategy within panels

---

## PART 6: NAVIGATION & FLOW CONTROL

### 6.1 Navigation Buttons (Existing Pattern)

From `CampaignCreationUI.gd`:

```gdscript
# Navigation buttons managed by UI
var back_button: Button
var next_button: Button
var finish_button: Button

# Coordinator controls state
signal navigation_updated(can_go_back: bool, can_go_forward: bool, can_finish: bool)
```

**Current Issues**:
- No visual step indicator (which step am I on?)
- No progress bar
- No breadcrumb navigation
- Back button logic not fully explored

### 6.2 Phase Transition System

```gdscript
signal phase_transition_requested(from_phase, to_phase)
signal step_changed(step: int, total_steps: int)
```

Built-in but not yet fully leveraged.

---

## PART 7: FIVE PARSECS CAMPAIGN CREATION REQUIREMENTS

Based on `docs/gameplay/rules/core_rules.md` and codebase implementation:

### 7.1 Core Campaign Creation Steps (Current Implementation)

**7 Required Steps**:

1. **CONFIG Panel** - Campaign Setup
   - Campaign name (required)
   - Difficulty level (STORY, STANDARD, CHALLENGING, HARDCORE, NIGHTMARE)
   - Permadeath toggle (disabled for STORY, forced for HARDCORE/NIGHTMARE)
   - Story track toggle (optional storytelling mode)
   - Victory conditions (integrated here, not separate)

2. **CAPTAIN Panel** - Leader Creation
   - Name (required)
   - Background (rolled or selected)
   - Motivation (rolled or selected)

3. **CREW Panel** - Initial Crew Members
   - Crew size (1-6)
   - Generate or manually select members
   - Species selection
   - Assign roles/equipment

4. **SHIP Panel** - Vessel Assignment
   - Ship type selection
   - Name/customization
   - Hull points tracking
   - Starting debt

5. **EQUIPMENT Panel** - Starting Gear
   - Generate standard equipment package
   - Starting credits
   - Manual override option
   - Reroll capability

6. **WORLD Panel** - Initial World
   - World generation
   - Danger level (1-6)
   - Tech level (1-6)
   - Government type
   - Traits and special features

7. **FINAL Panel** - Review & Create
   - Summary of all selections
   - Validation check
   - Create campaign button

### 7.2 Rules-Based Configuration Options

From Five Parsecs lore:

**Difficulty Levels** (hardcoded pattern):
```
Story      → Casual, reduced difficulty, learning mode
Standard   → Core rules as written, classic experience
Challenging → Increased enemy strength, tougher encounters
Hardcore   → Maximum difficulty, elite enemies, permadeath mandatory
Nightmare  → Ultra-hard custom mode, permadeath mandatory
```

**Game Mechanics to Explain in UI**:
- Permadeath consequences (permanent crew loss)
- Story track integration (narrative arc options)
- World danger levels (affect encounter generation)
- Tech levels (equipment availability)
- Crew advancement (XP, injuries, promotions)

**Optional Features**:
- House rules selection
- Custom difficulty modifiers
- Campaign objectives/victory conditions
- Play style preferences (turn-based vs real-time, etc.)

### 7.3 What Needs Explanation (Guidance Needed)

From reading the rulebook intro, players new to Five Parsecs need to understand:

1. **Campaign vs Battle**: Not just tactical skirmish battles, but long-term crew management
2. **Crew Advancement**: Characters carry over, gain experience, can die permanently
3. **Story Context**: Each battle builds on previous ones (rumors → quests → rivalries)
4. **Economic Management**: Equipment purchases, crew upkeep, loot distribution
5. **Open-Ended Success**: No fixed "winning" condition beyond player goals

**Wizard Should Provide**:
- Context help explaining each concept
- Examples for each configuration option
- Preset templates for different play styles (Combat-focused, Story-focused, Economic-focused)
- Links to rule references for each major section

---

## PART 8: MISSING PIECES FOR COMPLETE WIZARD UX

### 8.1 Progress Indication (Critical Gap)

**Missing Components**:
- ❌ Visual progress bar showing 1/7, 2/7, etc.
- ❌ Step indicators (circles or numbered steps)
- ❌ Breadcrumb navigation (CONFIG → CAPTAIN → CREW...)
- ❌ Current step highlighting
- ❌ Completion checkmarks for finished steps

**What We Need to Add**:
```gdscript
# Proposed ProgressIndicator component
class ProgressIndicator extends Control:
    var total_steps: int = 7
    var current_step: int = 0
    
    func show_step(step: int, title: String, completed_steps: Array)
        # Render progress bar with step numbers
        # Show current step title
        # Highlight completed steps with checkmarks
```

**Recommended Implementation**:
- Create `src/ui/components/wizard/StepIndicator.gd` (visual step tracker)
- Create `src/ui/components/wizard/ProgressBar.gd` (fill indicator)
- Create `src/ui/components/wizard/Breadcrumb.gd` (navigation trail)

### 8.2 Validation & Error Feedback (Partial Gap)

**Exists but Needs UI**:
- ✅ Validation logic in each panel
- ✅ Error array collection
- ❌ Real-time field validation feedback
- ❌ Error message display strategy
- ❌ Field highlighting for errors
- ❌ Success state indicators

**What We Need**:
```gdscript
# Proposed FieldValidator component
class FieldValidator extends Control:
    signal field_valid(field_name: String)
    signal field_invalid(field_name: String, error_message: String)
    
    # Shows inline error messages
    # Highlights invalid fields
    # Shows validation state (pending, valid, invalid)
```

### 8.3 Contextual Help System (Critical Gap)

**Missing**:
- ❌ Help panels for each step
- ❌ Expandable help sections
- ❌ Info icons with explanations
- ❌ Rule references
- ❌ Example values/templates

**What We Need**:
```gdscript
# Proposed HelpPanel component
class HelpPanel extends Control:
    var help_text: String
    var rule_references: Array[String]  # Links to rule sections
    var examples: Array[Dictionary]      # Example configurations
    var tips: Array[String]              # Pro tips
    
    func show_help_for_step(step: int) -> void
        # Display contextual help
        # Show examples
        # Link to rules
```

### 8.4 Template/Preset System (Nice-to-Have Gap)

**Exists partially**:
- ✅ QuickStartDialog has templates concept
- ❌ Wizard presets not implemented
- ❌ Quick-fill options not available

**What We Could Add**:
```gdscript
# Preset configurations
var presets: Dictionary = {
    "Quick Start": {
        "difficulty": STANDARD,
        "story_track": true,
        "crew_size": 4,
        "skip_customization": true
    },
    "Story Focus": {
        "difficulty": STORY,
        "story_track": true,
        "crew_size": 3,
        # ... more options
    },
    "Combat Focused": {
        "difficulty": CHALLENGING,
        "story_track": false,
        "crew_size": 5,
        # ... optimized for battles
    }
}
```

### 8.5 Data Persistence During Wizard (Gap)

**Current Pattern**:
- ✅ Coordinator maintains state
- ✅ Each panel saves its data
- ❌ No explicit save-to-draft functionality
- ❌ No recovery from accidental exit
- ❌ No progress restoration

**What We Could Add**:
- Auto-save draft between steps
- Warn on unsaved changes if exiting
- Restore previous draft on wizard restart
- Session recovery after crash

---

## PART 9: RECOMMENDED WIZARD COMPONENT ARCHITECTURE

### 9.1 Component Hierarchy (Proposed)

```
src/ui/components/wizard/ (NEW)
├── WizardBase.gd (abstract base for wizard flows)
├── StepIndicator.gd (shows current step, progress)
├── BreadcrumbNavigation.gd (navigation trail)
├── StepValidator.gd (validates step completion)
├── HelpPanel.gd (contextual help display)
├── FieldValidator.gd (inline field validation)
├── TemplateSelector.gd (preset selection)
└── WizardNavigation.gd (controls back/next/finish)

src/ui/screens/campaign/ (MODIFICATIONS)
└── CampaignCreationUI.gd (integrate wizard components)
```

### 9.2 Integration Points

**Coordinator Integration** (already exists):
```gdscript
coordinator.step_changed.connect(_on_step_changed)
coordinator.navigation_updated.connect(_on_navigation_updated)
coordinator.campaign_state_updated.connect(_on_state_updated)
```

**Panel Integration** (already exists):
```gdscript
current_panel.panel_validation_changed.connect(_on_panel_validation_changed)
current_panel.panel_completed.connect(_on_panel_completed)
```

**Wizard Component Integration** (needed):
```gdscript
step_indicator.update(current_step, total_steps, completed_steps)
breadcrumb.update_trail(step_names)
help_panel.show_help_for(current_panel_class)
field_validator.validate_field(field_name, field_value)
```

---

## PART 10: EXISTING PATTERNS TO LEVERAGE

### 10.1 Panel System (Core Strength)

**Reuse Pattern**:
- Each wizard step = one panel
- Already has validation, data handling, signals
- Already integrates with coordinator
- Extensible without modification

**Example**: Adding help to ConfigPanel:
```gdscript
# In ConfigPanel.gd
var help_content: String = """
[b]Campaign Difficulty[/b]
Affects enemy strength and your crew's challenge level.

[b]Story Track[/b]
Optional narrative arc system for connected campaigns.
See Appendix V, page 153 of core rulebook.
"""

func get_help_text() -> String:
    return help_content
```

### 10.2 Coordinator Signals (Already Well-Designed)

No changes needed, but fully leverage:
- `step_changed(step, total_steps)` → feeds StepIndicator
- `navigation_updated(can_back, can_forward, can_finish)` → feeds button states
- `campaign_state_updated(state)` → feeds help/validation

### 10.3 Tooltip System (Ready to Use)

```gdscript
# Add tooltips to wizard fields
Tooltip.add_tooltip_to_control(
    difficulty_option,
    "Higher difficulties increase enemy strength.\nHARDCORE and NIGHTMARE force permadeath.",
    Tooltip.Position.RIGHT
)
```

### 10.4 Theme System (Ready to Use)

- Wizard components will inherit from existing themes
- Add progress bar/stepper styling to base_theme.tres if needed

---

## PART 11: IMPLEMENTATION PRIORITY ROADMAP

### Phase 1: Critical (Must Have)

1. **StepIndicator Component**
   - Show progress (e.g., "Step 3 of 7")
   - Highlight current step
   - Time: 2-3 hours
   - Dependencies: None

2. **BreadcrumbNavigation Component**
   - Show path: CONFIG → CAPTAIN → CREW...
   - Allow jumping to previous steps
   - Time: 2-3 hours
   - Dependencies: None

3. **Enhanced Validation Display**
   - Show errors in panels with highlighting
   - Real-time feedback as user types
   - Time: 3-4 hours
   - Dependencies: ErrorDisplay component refactor

### Phase 2: Important (Should Have)

4. **HelpPanel Component**
   - Show contextual help for current step
   - Include rule references
   - Expandable/collapsible
   - Time: 4-6 hours
   - Dependencies: Phase 1 complete

5. **Field Validators**
   - Inline validation feedback
   - "Name is required" style messages
   - Character count feedback
   - Time: 2-3 hours
   - Dependencies: Phase 1 complete

6. **Template/Preset System**
   - Quick-fill for common configurations
   - "Recommended" presets
   - Time: 3-4 hours
   - Dependencies: None

### Phase 3: Nice-to-Have (Could Have)

7. **Auto-Save Draft**
   - Save progress between steps
   - Recovery on restart
   - Time: 3-4 hours
   - Dependencies: Persistence refactor

8. **Advanced Help**
   - Video tutorials per step
   - Rule book links
   - FAQ for common issues
   - Time: 4-6 hours
   - Dependencies: Phase 2 complete

---

## PART 12: DESIGN PATTERNS TO FOLLOW

### 12.1 Godot Best Practices (From Codebase)

1. **Extend from base classes**
   - New wizard components → extend `Control`
   - Use composition with coordinator/state_manager
   
2. **Signal-based communication**
   ```gdscript
   signal step_completed(step_data: Dictionary)
   signal validation_changed(is_valid: bool)
   signal help_requested(topic: String)
   ```

3. **Minimal inheritance**
   - Avoid deep hierarchies
   - Prefer composition over inheritance

4. **Theme integration**
   - Use `add_theme_*_override()` for custom styling
   - Fallback to defaults if theme missing

### 12.2 Five Parsecs Specific Patterns

1. **Rule references in UI**
   ```gdscript
   # Format: "Rulebook p.XXX" or "Appendix X: Title"
   var rule_reference: String = "Core Rulebook, Appendix V (The Story Track), p.153"
   ```

2. **Contextual examples**
   ```gdscript
   var examples: Array[Dictionary] = [
       {"label": "Mercenary Crew", "difficulty": STANDARD, "story_track": false},
       {"label": "Story Campaign", "difficulty": STORY, "story_track": true},
   ]
   ```

3. **Difficulty tier descriptions**
   - Tie help to difficulty mechanics
   - Explain permadeath implications
   - Show typical challenge examples

---

## PART 13: FILES TO CREATE/MODIFY

### New Files (Recommended)

```
src/ui/components/wizard/
├── WizardBase.gd (NEW - abstract base)
├── StepIndicator.gd (NEW - progress display)
├── StepIndicator.tscn (NEW - visual layout)
├── BreadcrumbNavigation.gd (NEW - navigation trail)
├── BreadcrumbNavigation.tscn (NEW - visual layout)
├── HelpPanel.gd (NEW - contextual help)
├── HelpPanel.tscn (NEW - visual layout)
├── FieldValidator.gd (NEW - field validation)
├── TemplateSelector.gd (NEW - preset selection)
└── TemplateSelector.tscn (NEW - visual layout)

docs/ui/
└── WIZARD_DESIGN_GUIDE.md (NEW - design documentation)
```

### Files to Modify (Minimal)

```
src/ui/screens/campaign/CampaignCreationUI.gd
- Add StepIndicator instance
- Add BreadcrumbNavigation instance
- Connect coordinator signals
- Import wizard components

src/ui/themes/base_theme.tres
- Add ProgressBar styling
- Add custom step indicator colors
- Add validation state colors

src/ui/screens/campaign/panels/BaseCampaignPanel.gd
- Add get_help_text() method
- Add get_examples() method
- Add get_rule_references() method
```

---

## PART 14: KEY INSIGHTS & RECOMMENDATIONS

### What Works Well

1. **Panel-Based Architecture**: Already implements wizard pattern perfectly
2. **Coordinator Pattern**: Excellent for multi-step workflows
3. **Signal System**: Loose coupling enables modular components
4. **Theme Support**: Consistent styling across application
5. **Tooltip System**: Reusable for field help

### What Needs Work

1. **Visual Progress Feedback**: No step indicators or progress bars
2. **Error Handling UX**: Validation exists but feedback UI missing
3. **Contextual Help**: No help system integrated into wizard
4. **Field-Level Validation**: No inline validation feedback
5. **Preset/Template UX**: Concept exists, not fully integrated

### Strategic Recommendations

1. **Quick Win**: Add StepIndicator component (3 hours, high impact)
2. **Follow-Up**: Add BreadcrumbNavigation (2 hours, medium impact)
3. **Foundation**: Create HelpPanel system (6 hours, long-term value)
4. **Polish**: Enhance validation feedback UI (4 hours, usability improvement)
5. **Optional**: Template system (4 hours, onboarding improvement)

### Design Consistency Principle

All new wizard components should:
- ✅ Extend from `Control` or `BaseCampaignPanel`
- ✅ Use signals for communication (no direct panel calls)
- ✅ Support theme overrides for consistency
- ✅ Follow Five Parsecs lore/terminology
- ✅ Include rule references where relevant
- ✅ Have responsive layout support (mobile/tablet/desktop)

---

## APPENDIX A: FIVE PARSECS CAMPAIGN CREATION CHECKLIST

From rulebook and codebase analysis:

**Character Creation (Captain)**
- [ ] Name (text input, required)
- [ ] Background (rollable/selectable dropdown)
- [ ] Motivation (rollable/selectable dropdown)
- [ ] Starting XP (usually 0 or bonus)
- [ ] Starting equipment (from crew equipment pool)

**Crew Setup**
- [ ] Number of crew members (1-6)
- [ ] Generate crew OR manually assign characters
- [ ] Species selection per character (Human, K'Erin, Swift, Engineer, Precursor, Soulless, etc.)
- [ ] Assign starting equipment to each member

**Ship Assignment**
- [ ] Select ship type (from game tables)
- [ ] Name the ship
- [ ] Record hull points (varies by type)
- [ ] Record starting debt (if any)

**Equipment Generation**
- [ ] Generate starting equipment package
- [ ] Assign to crew members
- [ ] Track credits remaining
- [ ] Option to reroll or customize

**World Setup**
- [ ] Generate first world
- [ ] Record danger level (1-6)
- [ ] Record tech level (1-6)
- [ ] Determine government type
- [ ] Note special traits/features
- [ ] Record available locations

**Campaign Configuration**
- [ ] Campaign name (text input, required)
- [ ] Difficulty level (5 options)
- [ ] Permadeath enabled (rules-based: forced on HARDCORE/NIGHTMARE, disabled on STORY)
- [ ] Story track (optional narrative system)
- [ ] Victory conditions (optional, player-defined)
- [ ] House rules (if any)

**Final Review**
- [ ] Review all selections
- [ ] Validate no missing data
- [ ] Create campaign and start playing

---

## APPENDIX B: THEME STYLING ADDITIONS NEEDED

For the wizard UI to feel complete, add to `base_theme.tres`:

```gdscript
# Progress Indicators
ProgressBar/colors/font_color = Color(0.875, 0.875, 0.875, 1)
ProgressBar/colors/fill = Color(0.1, 0.6, 1.0, 1)  # Blue
ProgressBar/styles/background = null
ProgressBar/styles/fill = null

# Step Indicators (custom control)
StepIndicator/colors/completed_step = Color(0.0, 1.0, 0.0, 1)  # Green
StepIndicator/colors/current_step = Color(0.1, 0.6, 1.0, 1)  # Blue
StepIndicator/colors/future_step = Color(0.4, 0.4, 0.4, 1)  # Gray
StepIndicator/font_sizes/step_number = 14

# Validation States
LineEdit/colors/font_color = Color(0.875, 0.875, 0.875, 1)
LineEdit/colors/caret_color = Color(0.95, 0.95, 0.95, 1)
# Would add: error state, success state, warning state

# Info/Help Panels
PanelContainer/styles/help_panel = null
PanelContainer/colors/help_background = Color(0.2, 0.2, 0.3, 0.8)
```

---

## CONCLUSION

The codebase has **excellent foundations** for a professional wizard-style configuration UI. By adding progress indicators, validation feedback, and contextual help, you'll have a complete, user-friendly campaign creation experience that honors the Five Parsecs ruleset while guiding new players through the process.

**Start with Phase 1 (StepIndicator + BreadcrumbNavigation)** for immediate visual improvement, then add HelpPanel system for long-term educational value.

