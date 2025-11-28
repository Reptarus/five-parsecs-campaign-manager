# Wizard UI Component Reference & Visual Guide

**Quick Reference for Implementation**

---

## COMPONENT HIERARCHY DIAGRAM

```
CampaignCreationUI (root screen)
│
├── Header Container
│   ├── StepIndicator [NEW]
│   │   └── Shows "Step 3 of 7" + visual progress
│   └── Title Label
│
├── BreadcrumbNavigation [NEW]
│   └── CONFIG > CAPTAIN > CREW > SHIP > EQUIPMENT > WORLD > FINAL
│       └── Clickable links to jump between steps
│
├── Main Content Area
│   ├── HelpPanel [NEW] (left sidebar, optional)
│   │   ├── Help text for current panel
│   │   ├── Rule references
│   │   └── Examples/tips
│   │
│   └── Panel Content (dynamic)
│       └── One of 7 panels:
│           ├── ConfigPanel (difficulty, story track, victory conditions)
│           ├── CaptainPanel (name, background, motivation)
│           ├── CrewPanel (crew size, members, species)
│           ├── ShipPanel (ship type, hull, debt)
│           ├── EquipmentPanel (starting gear, credits)
│           ├── WorldInfoPanel (world generation, traits)
│           └── FinalPanel (review and create)
│
├── Validation Feedback [ENHANCED]
│   ├── FieldValidator [NEW] (inline per-field feedback)
│   │   ├── Error message display
│   │   ├── Field highlighting (invalid/valid/pending)
│   │   └── Helper text / character count
│   │
│   └── Panel-level validation (existing, improve display)
│
└── Navigation Footer
    ├── TemplateSelector [NEW, optional]
    │   └── Quick-fill buttons (Story Focus, Combat, etc)
    │
    └── Navigation Buttons
        ├── Back Button (enabled based on coordinator)
        ├── Next Button (enabled if step valid)
        └── Finish Button (enabled on final step if complete)
```

---

## EXISTING COMPONENTS (Reuse These)

### BaseCampaignPanel
**Location**: `src/ui/screens/campaign/panels/BaseCampaignPanel.gd`
**Extends**: `Control` (class_name: `FiveParsecsCampaignPanel`)

**Key Methods**:
```gdscript
func validate_panel() -> bool              # Override to validate
func get_panel_data() -> Dictionary        # Return step data
func set_panel_data(data: Dictionary) -> void  # Receive coordinator state
func get_panel_title() -> String          # Return title
func get_panel_description() -> String    # Return description
func set_panel_info(title: String, desc: String)  # Set title/desc
```

**Key Signals** (emit these):
```gdscript
signal panel_data_changed(data: Dictionary)
signal panel_validation_changed(is_valid: bool)
signal panel_completed(data: Dictionary)
signal validation_failed(errors: Array[String])
signal panel_ready()
```

**How Panels Work Today**:
1. Coordinator creates/loads panel
2. Panel sets up UI in `_ready()`
3. User interacts with form
4. Panel emits `panel_data_changed` when user modifies data
5. Panel emits `panel_validation_changed` when validity changes
6. Coordinator listens and enables/disables Next button
7. When user clicks Next, coordinator calls `get_panel_data()`
8. Coordinator stores data and transitions to next panel

**For Wizard Integration**:
- ✅ Existing panels automatically part of wizard
- Optionally add methods: `get_help_text()`, `get_examples()`, `get_rule_references()`
- Optionally emit: `help_requested()` to show contextual help

### Tooltip System
**Location**: `src/ui/components/common/Tooltip.gd`
**Already Integrated**: Many panels use this

**Quick Usage**:
```gdscript
# In your panel's _ready():
Tooltip.add_tooltip_to_control(
    campaign_name_input,
    "Name for your crew's campaign. Examples: Orion Expedition, Crimson Reaper's Quest",
    Tooltip.Position.RIGHT
)

Tooltip.add_tooltip_to_control(
    difficulty_option,
    "Higher difficulties = stronger enemies and fewer resources.\n" +
    "[b]HARDCORE & NIGHTMARE[/b]: Permadeath is mandatory (no turning back).",
    Tooltip.Position.RIGHT
)
```

### Coordinator Pattern
**Location**: `src/ui/screens/campaign/CampaignCreationCoordinator.gd`
**Extends**: `Node`

**Key Signals to Hook**:
```gdscript
signal navigation_updated(can_go_back: bool, can_go_forward: bool, can_finish: bool)
signal step_changed(step: int, total_steps: int)  # ← Feed to StepIndicator
signal campaign_state_updated(state_data: Dictionary)  # ← Feed to HelpPanel/FieldValidator
```

**Key Methods to Call**:
```gdscript
coordinator.go_next()        # Advance to next step
coordinator.go_back()        # Go to previous step
coordinator.get_unified_campaign_state()  # Get current state
coordinator.set_panel(panel_instance)  # Register panel
```

### Theme System
**Location**: `src/ui/themes/base_theme.tres` (6 variants available)

**How to Use Custom Colors**:
```gdscript
# In any Control:
add_theme_color_override("font_color", Color.RED)
add_theme_font_size_override("font_size", 18)

# Or reference theme directly:
get_tree().root.get_theme().get_color("font_color", "Label")
```

---

## NEW COMPONENTS TO CREATE

### 1. StepIndicator

**Purpose**: Show progress (e.g., "Step 3 of 7: Equipment Generation")

**File**: `src/ui/components/wizard/StepIndicator.gd` + `.tscn`

**API**:
```gdscript
class_name StepIndicator
extends Control

# Update the display
func update_step(current_step: int, total_steps: int, step_name: String = "") -> void:
    # Shows: "Step 3 of 7"
    # Shows: step_name if provided
    
# Optional: Show completed steps with checkmarks
func mark_step_complete(step_index: int) -> void:

# Optional: Show which steps are valid
var completed_steps: Array[bool] = [true, true, true, false, false, false, false]
func update_completed_steps(completed: Array[bool]) -> void:

# Visual options
var show_percentage: bool = true      # Show "(42%)"
var show_step_name: bool = true       # Show step title
var animate_progress: bool = true     # Tween bar fill
```

**Visual Design** (text-based for now):
```
┌─────────────────────────────────┐
│ Step 3 of 7: Equipment (42%)     │
│ ▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
└─────────────────────────────────┘
```

Or with circles:
```
● ● ● ○ ○ ○ ○
1 2 3 4 5 6 7
  (current)
```

**Integration**:
```gdscript
# In CampaignCreationUI._ready():
step_indicator = StepIndicator.new()
add_child(step_indicator)

# In coordinator signal handler:
coordinator.step_changed.connect(func(step, total):
    step_indicator.update_step(step, total, get_step_name(step))
)

func get_step_name(step: int) -> String:
    match step:
        0: return "Configuration"
        1: return "Captain Creation"
        2: return "Crew Setup"
        3: return "Ship Assignment"
        4: return "Equipment Generation"
        5: return "World Setup"
        6: return "Final Review"
        _: return "Unknown"
```

---

### 2. BreadcrumbNavigation

**Purpose**: Show and navigate the path through wizard steps

**File**: `src/ui/components/wizard/BreadcrumbNavigation.gd` + `.tscn`

**Visual Design**:
```
Configuration > Captain > Crew > Ship > Equipment > World > Final
   (visited)                        (current)   (future)
```

**API**:
```gdscript
class_name BreadcrumbNavigation
extends Control

# Setup the breadcrumb trail
func set_steps(step_names: Array[String]) -> void:
    # step_names = ["Configuration", "Captain", "Crew", ...]

# Update which steps are completed/current
func update_state(current_step: int, completed_steps: Array[bool]) -> void:
    # Highlights current, grays out future, marks completed with ✓
    # Disables clicks on future steps

# Signal when user clicks a breadcrumb
signal step_selected(step_index: int)

# Visual options
var allow_jump_back: bool = true       # Can click to go backwards
var show_checkmarks: bool = true       # ✓ for completed
var separator: String = " > "          # Between steps
```

**Integration**:
```gdscript
# In CampaignCreationUI._ready():
breadcrumb = BreadcrumbNavigation.new()
add_child(breadcrumb)
breadcrumb.set_steps(get_step_names())
breadcrumb.step_selected.connect(_on_breadcrumb_selected)

# Listen to coordinator:
coordinator.step_changed.connect(func(step, total):
    breadcrumb.update_state(step, phase_completion_status.values())
)

func _on_breadcrumb_selected(step_index: int) -> void:
    if step_index < current_step:
        coordinator.go_to_step(step_index)  # Jump back
    # Cannot jump forward (unsaved progress)
```

---

### 3. HelpPanel

**Purpose**: Show contextual help, examples, and rule references

**File**: `src/ui/components/wizard/HelpPanel.gd` + `.tscn`

**API**:
```gdscript
class_name HelpPanel
extends Control

# Show help for a panel
func show_help_for_panel(panel: FiveParsecsCampaignPanel) -> void:
    # Try to get help from panel itself
    var help_text = ""
    var rule_refs = []
    var examples = []
    
    if panel.has_method("get_help_text"):
        help_text = panel.get_help_text()
    if panel.has_method("get_rule_references"):
        rule_refs = panel.get_rule_references()
    if panel.has_method("get_examples"):
        examples = panel.get_examples()
    
    # Display in this panel

# Manual set help
func set_help(title: String, content: String, rules: Array[String] = [], examples: Array[Dictionary] = []) -> void:

# Hide help
func clear_help() -> void:

# Visual options
var show_examples: bool = true
var show_rule_links: bool = true
var collapsible: bool = true           # Can collapse/expand
var width_percent: float = 0.25        # 25% of screen width
```

**Visual Structure**:
```
╔════════════════════════════════╗
║ Configuration & Difficulty      ║
╠════════════════════════════════╣
║                                ║
║ The difficulty level affects... ║
║                                ║
║ [Learn More...]                ║
║                                ║
║ ┌──────────────────────────┐   ║
║ │ Rule References:         │   ║
║ │ • Core Rules p.42        │   ║
║ │ • Appendix III (Jobs)    │   ║
║ └──────────────────────────┘   ║
║                                ║
║ ┌──────────────────────────┐   ║
║ │ Examples:                │   ║
║ │ • Casual Campaign        │   ║
║ │ • Hardcore Mercenaries   │   ║
║ └──────────────────────────┘   ║
║                                ║
╚════════════════════════════════╝
```

**Integration**:
```gdscript
# In CampaignCreationUI._ready():
help_panel = HelpPanel.new()
add_child(help_panel)

# When panel changes:
func _on_panel_changed(panel: FiveParsecsCampaignPanel) -> void:
    help_panel.show_help_for_panel(panel)

# In each panel, add help methods:
# (Example in ConfigPanel)
func get_help_text() -> String:
    return """
    [b]Difficulty[/b]
    Determines enemy strength and available resources.
    
    [b]Story Track[/b]
    Optional narrative system that provides connected campaign events.
    See Core Rulebook Appendix V for details.
    """

func get_rule_references() -> Array[String]:
    return [
        "Core Rulebook, p.42 (Difficulty)",
        "Appendix V: The Story Track",
        "Appendix III: Red and Black Zone Jobs"
    ]

func get_examples() -> Array[Dictionary]:
    return [
        {"name": "Casual Story Campaign", "difficulty": "STORY", "story_track": true},
        {"name": "Hardcore Mercenaries", "difficulty": "HARDCORE", "story_track": false}
    ]
```

---

### 4. FieldValidator

**Purpose**: Inline validation feedback for form fields

**File**: `src/ui/components/wizard/FieldValidator.gd` + `.tscn`

**API**:
```gdscript
class_name FieldValidator
extends Control

# Validate a field
func validate_field(field_name: String, value: Variant, rules: Dictionary) -> ValidationResult:
    # rules = {"required": true, "min_length": 3, "max_length": 50, "pattern": "regex"}
    # Returns: {valid: bool, errors: Array[String]}

# Real-time monitoring
func monitor_field(field: Control, validation_rules: Dictionary) -> void:
    # Auto-validate on input changed

# Update display
func show_error(field: Control, error_message: String) -> void:
    # Highlight field in red
    # Show error below field
    
func show_success(field: Control) -> void:
    # Show green checkmark
    
func clear_feedback(field: Control) -> void:
    # Reset to neutral

# Visual indicators
var error_color: Color = Color.RED
var success_color: Color = Color.GREEN
var pending_color: Color = Color.YELLOW
var error_message_position: String = "below"  # "below", "tooltip", "panel"
```

**Validation Rules Format**:
```gdscript
{
    "required": true,                          # Must not be empty
    "min_length": 3,                          # Minimum characters
    "max_length": 50,                         # Maximum characters
    "pattern": "^[A-Za-z0-9\\s]+$",          # Regex pattern
    "allowed_values": ["STANDARD", "STORY"],  # Whitelist
    "custom_validator": callable              # Function(value) -> bool
}
```

**Visual Example**:
```
Campaign Name: [___________________]
               ^ Must be 3-50 characters

    (user types "Ca")
    
Campaign Name: [_Ca________________] ⚠️
               Campaign name too short (need 1 more character)
               
    (user types "Campaign")
    
Campaign Name: [_Campaign__________] ✓
```

**Integration**:
```gdscript
# In a panel _ready():
var validator = FieldValidator.new()
add_child(validator)

# Monitor field as user types
validator.monitor_field(campaign_name_input, {
    "required": true,
    "min_length": 3,
    "max_length": 50,
    "pattern": "^[A-Za-z0-9\\s]+$"
})

# Hook validation into panel completion
validator.field_valid.connect(func(field_name):
    _check_all_fields_valid()
)
```

---

### 5. TemplateSelector (Optional)

**Purpose**: Quick-fill wizard with preset configurations

**File**: `src/ui/components/wizard/TemplateSelector.gd` + `.tscn`

**API**:
```gdscript
class_name TemplateSelector
extends Control

# Define available templates
var templates: Dictionary = {
    "story_focused": {
        "name": "Story-Focused Campaign",
        "description": "Narrative-driven experience with moderate difficulty",
        "icon": preload("res://assets/icons/book.png"),
        "config": {
            "difficulty": "STORY",
            "story_track": true,
            "crew_size": 3,
            "permadeath": false
        }
    },
    "hardcore": {
        "name": "Hardcore Combat",
        "description": "Intense difficulty with permadeath enabled",
        "icon": preload("res://assets/icons/skull.png"),
        "config": {
            "difficulty": "HARDCORE",
            "story_track": false,
            "crew_size": 5,
            "permadeath": true
        }
    },
    "balanced": {
        "name": "Balanced Campaign",
        "description": "Mix of story and combat challenges",
        "icon": preload("res://assets/icons/scales.png"),
        "config": {
            "difficulty": "STANDARD",
            "story_track": true,
            "crew_size": 4,
            "permadeath": false
        }
    }
}

# Signal when user selects template
signal template_selected(template_key: String, config: Dictionary)

# Display templates
func show_templates() -> void:
    # Show cards for each template
    
# Get selected template
func get_selected_template() -> Dictionary:
```

**Visual Design**:
```
┌─────────────────────────────────────────────────┐
│ Start with a template:                          │
│                                                 │
│  [Story Focus]  [Balanced]  [Hardcore]  [Custom]│
│   (narrative)              (hard mode) (manual) │
│                                                 │
│  Quick Start       Or Customize Manually       │
│  [Quick Select]    [Next Step by Step]         │
└─────────────────────────────────────────────────┘
```

---

## INTEGRATION CHECKLIST

### Step 1: Import Components
```gdscript
# In CampaignCreationUI.gd
const StepIndicator = preload("res://src/ui/components/wizard/StepIndicator.gd")
const BreadcrumbNavigation = preload("res://src/ui/components/wizard/BreadcrumbNavigation.gd")
const HelpPanel = preload("res://src/ui/components/wizard/HelpPanel.gd")
const FieldValidator = preload("res://src/ui/components/wizard/FieldValidator.gd")
const TemplateSelector = preload("res://src/ui/components/wizard/TemplateSelector.gd")
```

### Step 2: Instantiate in _ready()
```gdscript
func _ready() -> void:
    # Create components
    step_indicator = StepIndicator.new()
    breadcrumb = BreadcrumbNavigation.new()
    help_panel = HelpPanel.new()
    template_selector = TemplateSelector.new()
    
    # Add to scene
    header_container.add_child(step_indicator)
    add_child(breadcrumb)
    add_child(help_panel)
    
    # Configure
    breadcrumb.set_steps(STEP_NAMES)
    template_selector.show_templates()
```

### Step 3: Connect Signals
```gdscript
# Coordinator → Wizard Components
coordinator.step_changed.connect(_on_step_changed)
coordinator.navigation_updated.connect(_on_navigation_updated)

# Breadcrumb → Coordinator
breadcrumb.step_selected.connect(func(step): coordinator.go_to_step(step))

# Template → Coordinator
template_selector.template_selected.connect(func(key, config): 
    coordinator.apply_template(config)
)

# Panel → Help Panel
current_panel.panel_ready.connect(func(): help_panel.show_help_for_panel(current_panel))
```

### Step 4: Add Help Methods to Each Panel
```gdscript
# In ConfigPanel.gd, CaptainPanel.gd, etc:

func get_help_text() -> String:
    return """[b]Step Name[/b]
    Description of what this step does.
    Explain key options and consequences."""

func get_rule_references() -> Array[String]:
    return ["Core Rulebook p.XX", "Appendix X: Title"]

func get_examples() -> Array[Dictionary]:
    return [
        {"label": "Example 1", "details": "..."},
        {"label": "Example 2", "details": "..."}
    ]
```

### Step 5: Update Theme (optional)
Add to `base_theme.tres`:
```gdscript
# Progress/Stepper colors
ProgressBar/colors/fill = Color(0.1, 0.6, 1.0, 1)

# Step indicator
StepIndicator/colors/completed = Color(0.0, 1.0, 0.0, 1)
StepIndicator/colors/current = Color(0.1, 0.6, 1.0, 1)
StepIndicator/colors/future = Color(0.3, 0.3, 0.3, 1)

# Help panel
HelpPanel/colors/background = Color(0.15, 0.15, 0.2, 0.9)
HelpPanel/colors/border = Color(0.1, 0.6, 1.0, 0.5)

# Validation states
Label/colors/error = Color(1.0, 0.0, 0.0, 1.0)
Label/colors/success = Color(0.0, 1.0, 0.0, 1.0)
Label/colors/warning = Color(1.0, 0.8, 0.0, 1.0)
```

---

## TESTING CHECKLIST

- [ ] StepIndicator updates correctly when step changes
- [ ] BreadcrumbNavigation allows jumping back to completed steps
- [ ] BreadcrumbNavigation prevents jumping to incomplete future steps
- [ ] HelpPanel shows correct help for each step
- [ ] FieldValidator catches invalid inputs
- [ ] FieldValidator allows valid inputs
- [ ] FieldValidator shows/hides feedback correctly
- [ ] TemplateSelector applies presets to all fields
- [ ] All tooltips display with correct positioning
- [ ] Theme colors apply correctly across components
- [ ] Components respond to mobile/tablet/desktop breakpoints
- [ ] No memory leaks from signals/connections

---

## PERFORMANCE NOTES

- All components use lightweight controls
- Signals are preferred over direct calls (loose coupling)
- Tooltips use timers for show delays (no polling)
- Help panel lazy-loads content (no rendering until visible)
- Theme inheritance minimizes memory usage
- No heavy tweens or animations on every update

---

## NEXT STEPS

1. **Create Component Files**: Copy templates above into new .gd files
2. **Add Scene Files**: Create .tscn layouts for visual components
3. **Integrate**: Hook into CampaignCreationUI.gd
4. **Test**: Run full wizard workflow end-to-end
5. **Polish**: Adjust colors, spacing, animations as needed
6. **Document**: Add method documentation with ### comments

