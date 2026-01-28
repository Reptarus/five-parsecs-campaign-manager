# Claude Code Prompt: Fix Five Parsecs Campaign Creation UI Flow

## 🎯 **OBJECTIVE**
Transform the broken single-page campaign creation form into a proper multi-step UI flow that routes through wireframed scenes and integrates with the production-ready CampaignCreationStateManager.

## 📁 **TARGET PROJECT**
- **Primary Path**: `C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\`
- **Console**: `"C:\Users\elija\Desktop\GoDot\Godot_v4.4-stable_mono_win64\Godot_v4.4-stable_mono_win64_console.exe"`

## 🚨 **CRITICAL ISSUES TO FIX**

### **1. Signal Connection Failures**
```
Panel CrewPanel missing or lacks set_state_manager method
Panel CaptainPanel missing or lacks set_state_manager method  
Panel CrewPanel does not have signal crew_setup_complete
Panel CrewPanel does not have signal panel_completed
Panel CaptainPanel does not have signal panel_ready
```

### **2. Wrong UI Flow**
Current: Basic single-page form with campaign name/difficulty
Expected: Multi-step flow → CrewPanel → CaptainPanel → EquipmentPanel → FinalPanel

### **3. Missing Integration**
CampaignCreationStateManager exists and is production-ready, but UI doesn't use it properly

## 🔧 **STEP-BY-STEP IMPLEMENTATION**

### **Phase 1: Analyze Current Structure (15 mins)**
```bash
# First, examine the current campaign creation files
cd "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\"

# Check current UI structure
find ./src/ui/screens/campaign -name "*.gd" -type f
find ./src/ui/screens/campaign -name "*.tscn" -type f

# Examine the state manager (should be production-ready)
cat "./src/core/campaign/creation/CampaignCreationStateManager.gd"

# Check existing panels
find ./src/ui/screens/campaign/panels -name "*.gd" -type f
```

### **Phase 2: Fix Panel Base Classes (30 mins)**

**Create Base Panel Interface:**
```gdscript
# File: src/base/ui/ICampaignCreationPanel.gd
class_name ICampaignCreationPanel
extends Control

## Base interface for campaign creation panels
signal panel_completed(panel_data: Dictionary)
signal panel_ready()
signal validation_failed(errors: Array[String])
signal crew_setup_complete(crew_data: Dictionary)  # For CrewPanel
signal crew_data_complete(data: Dictionary)        # For CrewPanel

var state_manager: CampaignCreationStateManager
var is_panel_valid: bool = false

## REQUIRED: Set the state manager reference
func set_state_manager(manager: CampaignCreationStateManager) -> void:
    state_manager = manager
    _on_state_manager_set()

## REQUIRED: Validate panel data
func validate_panel() -> ValidationResult:
    push_error("validate_panel() must be implemented in derived class")
    return ValidationResult.new()

## REQUIRED: Get panel data for state manager
func get_panel_data() -> Dictionary:
    push_error("get_panel_data() must be implemented in derived class")
    return {}

## REQUIRED: Reset panel to default state
func reset_panel() -> void:
    push_error("reset_panel() must be implemented in derived class")

## Override in derived classes
func _on_state_manager_set() -> void:
    pass
```

### **Phase 3: Implement Required Panel Methods (45 mins)**

**Fix CrewPanel:**
```gdscript
# File: src/ui/screens/campaign/panels/CrewPanel.gd
class_name CrewPanel
extends ICampaignCreationPanel

@export var crew_size_spinbox: SpinBox
@export var crew_member_container: VBoxContainer
@export var add_crew_button: Button

var crew_members: Array[Dictionary] = []

func _ready():
    if add_crew_button:
        add_crew_button.pressed.connect(_on_add_crew_member_pressed)
    
    # Connect other UI elements...
    _setup_ui_connections()

func set_state_manager(manager: CampaignCreationStateManager) -> void:
    super.set_state_manager(manager)

func _on_state_manager_set() -> void:
    # Initialize with state manager data if needed
    if state_manager:
        var existing_data = state_manager.get_crew_data()
        if not existing_data.is_empty():
            _load_crew_data(existing_data)

func validate_panel() -> ValidationResult:
    var result = ValidationResult.new()
    
    if crew_members.size() == 0:
        result.valid = false
        result.error_message = "At least one crew member is required"
        validation_failed.emit(["At least one crew member is required"])
        return result
    
    # Additional validation...
    result.valid = true
    is_panel_valid = true
    panel_ready.emit()
    return result

func get_panel_data() -> Dictionary:
    return {
        "crew_members": crew_members,
        "crew_size": crew_members.size(),
        "crew_setup_timestamp": Time.get_unix_time_from_system()
    }

func reset_panel() -> void:
    crew_members.clear()
    _update_crew_display()
    is_panel_valid = false

func _on_add_crew_member_pressed() -> void:
    # Implementation for adding crew members
    _add_new_crew_member()
    
    # Emit completion signals
    crew_setup_complete.emit(get_panel_data())
    crew_data_complete.emit(get_panel_data())
    
    # Validate after changes
    validate_panel()
    
    if is_panel_valid:
        panel_completed.emit(get_panel_data())
```

**Fix CaptainPanel:**
```gdscript
# File: src/ui/screens/campaign/panels/CaptainPanel.gd
class_name CaptainPanel
extends ICampaignCreationPanel

@export var captain_name_input: LineEdit
@export var background_option: OptionButton
@export var motivation_option: OptionButton

func _ready():
    _setup_ui_connections()

func set_state_manager(manager: CampaignCreationStateManager) -> void:
    super.set_state_manager(manager)

func _on_state_manager_set() -> void:
    # Load existing captain data if available
    if state_manager:
        var existing_data = state_manager.get_captain_data()
        if not existing_data.is_empty():
            _load_captain_data(existing_data)

func validate_panel() -> ValidationResult:
    var result = ValidationResult.new()
    var errors: Array[String] = []
    
    if captain_name_input.text.strip_edges().length() < 2:
        errors.append("Captain name must be at least 2 characters")
    
    if background_option.selected == -1:
        errors.append("Please select a background")
    
    if errors.size() > 0:
        result.valid = false
        result.error_message = errors[0]
        validation_failed.emit(errors)
        return result
    
    result.valid = true
    is_panel_valid = true
    panel_ready.emit()
    return result

func get_panel_data() -> Dictionary:
    return {
        "captain_name": captain_name_input.text.strip_edges(),
        "background": background_option.selected,
        "motivation": motivation_option.selected,
        "creation_timestamp": Time.get_unix_time_from_system()
    }

func reset_panel() -> void:
    captain_name_input.text = ""
    background_option.selected = -1
    motivation_option.selected = -1
    is_panel_valid = false
```

### **Phase 4: Fix CampaignCreationUI Signal Integration (30 mins)**

```gdscript
# File: src/ui/screens/campaign/CampaignCreationUI.gd
class_name CampaignCreationUI
extends Control

@export var panel_container: Control
@export var navigation_container: HBoxContainer
@export var back_button: Button
@export var next_button: Button
@export var progress_bar: ProgressBar

var state_manager: CampaignCreationStateManager
var current_panel_index: int = 0
var panels: Array[ICampaignCreationPanel] = []

enum CampaignCreationStep {
    CREW_SETUP,
    CAPTAIN_SETUP, 
    EQUIPMENT_SETUP,
    FINAL_REVIEW
}

func _ready():
    _initialize_state_manager()
    _load_panels()
    _connect_panel_signals()
    _setup_navigation()
    _show_current_panel()

func _initialize_state_manager():
    state_manager = CampaignCreationStateManager.new()
    
    # Connect state manager signals
    state_manager.validation_completed.connect(_on_state_validation_completed)
    state_manager.step_completed.connect(_on_step_completed)

func _load_panels():
    # Load all panel scenes and add to panels array
    var crew_panel = load("res://src/ui/screens/campaign/panels/CrewPanel.tscn").instantiate()
    var captain_panel = load("res://src/ui/screens/campaign/panels/CaptainPanel.tscn").instantiate()
    var equipment_panel = load("res://src/ui/screens/campaign/panels/EquipmentPanel.tscn").instantiate()  
    var final_panel = load("res://src/ui/screens/campaign/panels/FinalPanel.tscn").instantiate()
    
    panels = [crew_panel, captain_panel, equipment_panel, final_panel]
    
    # Add panels to container and set state manager
    for panel in panels:
        panel_container.add_child(panel)
        panel.set_state_manager(state_manager)
        panel.visible = false

func _connect_panel_signals():
    for panel in panels:
        # Connect required signals
        panel.panel_completed.connect(_on_panel_completed)
        panel.panel_ready.connect(_on_panel_ready)
        panel.validation_failed.connect(_on_panel_validation_failed)
        
        # Connect crew-specific signals if it's CrewPanel
        if panel is CrewPanel:
            panel.crew_setup_complete.connect(_on_crew_setup_complete)
            panel.crew_data_complete.connect(_on_crew_data_complete)

func _show_current_panel():
    # Hide all panels
    for panel in panels:
        panel.visible = false
    
    # Show current panel
    if current_panel_index < panels.size():
        panels[current_panel_index].visible = true
        panels[current_panel_index].validate_panel()
    
    _update_navigation_state()
    _update_progress()

func _update_navigation_state():
    back_button.disabled = current_panel_index == 0
    
    # Check if current panel is valid for next button
    var current_panel = panels[current_panel_index]
    var validation = current_panel.validate_panel()
    next_button.disabled = not validation.valid
    
    # Update button text for final step
    if current_panel_index == panels.size() - 1:
        next_button.text = "Create Campaign"
    else:
        next_button.text = "Next"

func _on_next_button_pressed():
    var current_panel = panels[current_panel_index]
    var validation = current_panel.validate_panel()
    
    if not validation.valid:
        _show_validation_errors(validation.error_message)
        return
    
    # Save current panel data to state manager
    var panel_data = current_panel.get_panel_data()
    
    match current_panel_index:
        CampaignCreationStep.CREW_SETUP:
            state_manager.set_crew_data(panel_data)
        CampaignCreationStep.CAPTAIN_SETUP:
            state_manager.set_captain_data(panel_data)
        CampaignCreationStep.EQUIPMENT_SETUP:
            state_manager.set_equipment_data(panel_data)
        CampaignCreationStep.FINAL_REVIEW:
            _create_campaign()
            return
    
    # Move to next panel
    current_panel_index += 1
    _show_current_panel()

func _create_campaign():
    var campaign_data = state_manager.compile_campaign_data()
    var validation = state_manager.validate_all_data()
    
    if not validation.valid:
        _show_validation_errors(validation.error_message)
        return
    
    # Create the actual campaign
    var campaign = FiveParsecsCampaign.new()
    campaign.initialize_from_data(campaign_data)
    
    # Save campaign and navigate to main game
    var save_result = campaign.save_to_file()
    if save_result.success:
        # Navigate to main game screen
        SceneManager.change_scene("res://src/ui/screens/main/MainGameScreen.tscn")
    else:
        _show_error("Failed to save campaign: " + save_result.error_message)

# Signal handlers
func _on_panel_completed(panel_data: Dictionary):
    print("Panel completed with data: ", panel_data)

func _on_panel_ready():
    _update_navigation_state()

func _on_panel_validation_failed(errors: Array[String]):
    _show_validation_errors(errors[0] if errors.size() > 0 else "Validation failed")

func _on_crew_setup_complete(crew_data: Dictionary):
    print("Crew setup completed: ", crew_data)

func _on_crew_data_complete(data: Dictionary):
    print("Crew data complete: ", data)
```

### **Phase 5: Test and Validate (20 mins)**

```bash
# Run the project and test the flow
cd "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\"

# Open in Godot
& "C:\Users\elija\Desktop\GoDot\Godot_v4.4-stable_mono_win64\Godot_v4.4-stable_mono_win64_console.exe" --path .

# Test each panel transition
# 1. CrewPanel → should emit crew_setup_complete, panel_completed
# 2. CaptainPanel → should emit panel_ready, panel_completed  
# 3. EquipmentPanel → should emit panel_ready, panel_completed
# 4. FinalPanel → should create campaign and navigate
```

## 🎯 **SUCCESS CRITERIA**

### **Fixed Issues:**
✅ No more "missing signal" errors in console  
✅ Multi-step UI flow instead of single form  
✅ Proper CrewPanel → CaptainPanel → EquipmentPanel → FinalPanel routing  
✅ CampaignCreationStateManager fully integrated  
✅ All panels have required `set_state_manager` method  
✅ Navigation buttons work with validation  

### **Working Features:**
✅ Campaign creation progresses through wireframed scenes  
✅ Back/Next navigation with proper validation  
✅ Progress indication for user feedback  
✅ Error handling and validation messages  
✅ Final campaign creation and file saving  
✅ Smooth scene transitions to main game  

## ⚡ **EXECUTION TIME: ~2 hours**
- Phase 1 (Analysis): 15 mins
- Phase 2 (Base Classes): 30 mins  
- Phase 3 (Panel Implementation): 45 mins
- Phase 4 (UI Integration): 30 mins
- Phase 5 (Testing): 20 mins

This will transform the broken single-page form into a production-ready multi-step campaign creation flow that properly integrates with the existing CampaignCreationStateManager.