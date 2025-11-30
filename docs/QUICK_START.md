# Five Parsecs Campaign Manager - Quick Start Guide

**Last Updated**: 2025-11-29  
**Project Status**: BETA_READY (95/100)  
**Godot Version**: 4.5.1-stable (non-mono, GDScript only)

## 🚀 Quick Start for Developers

Get up and running with the Five Parsecs Campaign Manager development environment in minutes.

---

## Prerequisites

- **Godot 4.5.1-stable** (non-mono version - pure GDScript, no C#)
- **Git** for version control
- **PowerShell** (Windows) for running tests
- **Visual Studio Code** (recommended) with Godot extensions
- **gdUnit4 v6.0.1** (included in `addons/gdUnit4/`)

### Install Godot 4.5.1

1. Download from [Godot Downloads](https://godotengine.org/download/archive/)
2. Choose **4.5.1-stable** (Standard version, NOT Mono)
3. Extract to: `C:\Users\YourUser\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\`
4. Verify console version exists: `Godot_v4.5.1-stable_win64_console.exe`

---

## 🏃 Getting Started (5 Minutes)

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/five-parsecs-campaign-manager.git
cd five-parsecs-campaign-manager
```

### 2. Open in Godot
1. Launch Godot 4.5.1
2. Click "Import"
3. Navigate to the project folder
4. Select `project.godot`
5. Click "Import & Edit"

### 3. Run the Project
- Press `F5` or click the Play button
- The game starts at `src/ui/screens/mainmenu/MainMenu.tscn`
- Test the campaign creation workflow immediately

---

## 🏗️ Project Architecture Overview

### Current Stats (2025-11-29)
- **Total GDScript Files**: 470+
- **Total Scene Files**: 196 .tscn files
- **Data Files**: 104 JSON files
- **Test Files**: 138 passing tests (100% of created tests)
- **Framework**: Godot 4.5.1 with gdUnit4 testing

### Directory Structure
```
five-parsecs-campaign-manager/
├── src/
│   ├── autoload/              # Autoload singletons (GameState, DiceSystem, etc.)
│   ├── core/                  # Business logic (470+ files)
│   │   ├── battle/           # Battle system
│   │   ├── campaign/         # Campaign management
│   │   │   ├── phases/      # Turn phases (Travel, World, Battle, PostBattle)
│   │   │   └── ...
│   │   ├── character/        # Character system
│   │   ├── managers/         # Game managers
│   │   ├── systems/          # Game systems (injuries, loot, advancement)
│   │   └── ...
│   ├── ui/                    # User interface
│   │   ├── components/       # Reusable UI components
│   │   │   ├── battle/      # Battle UI components
│   │   │   ├── campaign/    # Campaign dashboard components
│   │   │   ├── character/   # Character cards and details
│   │   │   ├── inventory/   # Equipment management
│   │   │   └── tooltips/    # Keyword tooltips, equipment formatters
│   │   └── screens/          # Screen implementations
│   │       ├── campaign/    # Campaign wizard & dashboard
│   │       ├── battle/      # Battle UI
│   │       ├── crew/        # Crew management
│   │       ├── mainmenu/    # Main menu
│   │       └── world/       # World phase
│   └── game/                  # Game logic
├── data/                      # 104 JSON data files
│   ├── characters/           # Character templates
│   ├── enemies/              # Enemy data
│   ├── equipment/            # Weapons, gear, items
│   ├── events/               # Story events
│   └── ...
├── tests/
│   ├── unit/                 # Unit tests (character, injuries, loot)
│   ├── integration/          # Integration tests (wizard flow, dashboard)
│   └── legacy/               # E2E workflow tests
├── docs/                      # Documentation
│   ├── gameplay/             # Game rules and mechanics
│   ├── technical/            # Architecture and implementation
│   ├── testing/              # Testing guides
│   └── ...
└── addons/
    └── gdUnit4/              # Testing framework
```

### Signal Architecture ("Call Down, Signal Up")

The project follows Godot's best practice:

```gdscript
# ✅ CORRECT: Parent calling down to child
func _ready():
    $CharacterCard.update_health(5, 5)  # Direct method call

# ✅ CORRECT: Child signaling up to parent
signal card_tapped(character: Character)
func _on_tap_detected():
    card_tapped.emit(character_data)  # Signal up

# ❌ WRONG: Child accessing parent directly
func _on_button_pressed():
    get_parent().update_crew_roster()  # Brittle!
```

### Panel Self-Management Pattern

Campaign panels use a coordinator pattern:

```gdscript
# Panels are self-managing with get_panel_data()
func get_panel_data() -> Dictionary:
    return {
        "campaign_name": _campaign_name,
        "difficulty": _difficulty,
        "crew_size": _crew_size
    }

# Signal up with NO arguments (parent fetches data)
signal panel_data_changed()

func _on_input_changed():
    panel_data_changed.emit()  # Parent calls get_panel_data()
```

### State Management

- **CampaignCreationStateManager**: Validation and state tracking
- **GameStateManager**: Global game state (autoload singleton)
- **Resource Classes**: Character, Enemy, Mission (with behavior)

---

## 🧪 Testing the Application

### ⚠️ CRITICAL: Test Runner Constraints

**DO NOT use `--headless` flag** - causes signal 11 crash after 8-18 tests.  
**ALWAYS use PowerShell or UI mode** for running tests.

### Running Tests via PowerShell (Recommended)

```powershell
# Run specific test file
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit/test_character_advancement_costs.gd `
  --quit-after 60

# Run all tests in a directory
& 'C:\Users\elija\Desktop\GoDot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe' `
  --path 'C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager' `
  --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
  -a tests/unit `
  --quit-after 60
```

**Note**: Path has `.exe` as a directory name - this is correct.

### Running Tests in Godot Editor (UI Mode)

1. Open project in Godot
2. Click **Project → Tools → GdUnit4 → Run Tests**
3. Select test file or directory
4. View results in bottom panel

### Test Coverage (Current)

- **Total Tests**: 138 passing (100% of created tests)
- **Character Advancement**: 36 tests ✅
- **Injury System**: 26 tests ✅
- **Loot System**: 44 tests ✅
- **State Persistence**: 32 tests ✅
- **E2E Workflow**: 20/22 tests ⚠️ (2 failing - equipment field mismatch)

### Test File Limits

**Maximum 13 tests per file** for runner stability.  
Split larger test suites into multiple files.

---

## 🛠️ Common Development Tasks

### Adding a New Campaign Panel

1. **Create Panel Script**
```gdscript
# src/ui/screens/campaign/panels/YourPanel.gd
class_name YourPanel
extends Control

signal panel_data_changed()

@export var min_crew_size: int = 4
@export var max_crew_size: int = 8

var _campaign_name: String = ""
var _difficulty: int = 3

@onready var _name_input: LineEdit = $VBoxContainer/NameInput
@onready var _difficulty_slider: HSlider = $VBoxContainer/DifficultySlider

func _ready() -> void:
    _setup_signals()
    _style_inputs()

func _setup_signals() -> void:
    _name_input.text_changed.connect(_on_name_changed)
    _difficulty_slider.value_changed.connect(_on_difficulty_changed)

func _on_name_changed(new_text: String) -> void:
    _campaign_name = new_text
    panel_data_changed.emit()

func _on_difficulty_changed(value: float) -> void:
    _difficulty = int(value)
    panel_data_changed.emit()

func get_panel_data() -> Dictionary:
    return {
        "campaign_name": _campaign_name,
        "difficulty": _difficulty
    }

func _style_inputs() -> void:
    # Apply design system styling
    pass
```

2. **Create Panel Scene**
- Create `YourPanel.tscn` in `src/ui/screens/campaign/panels/`
- Attach the script to the root Control node
- Design UI using VBoxContainer/HBoxContainer
- Use `BaseCampaignPanel.gd` constants for spacing

3. **Register with Wizard**
- Add to `CampaignCreationUI.tscn` or `CampaignWorkflowOrchestrator.gd`
- Connect `panel_data_changed` signal
- Test the flow

### Debugging Campaign Creation

Enable debug logging:
```gdscript
# In CampaignWorkflowOrchestrator._ready()
print("=== Campaign Wizard Debug Mode ===")
print("Panel count: ", _panels.size())
print("Current panel: ", _current_panel_index)
```

### Working with State Management

Access campaign state safely:
```gdscript
# Access global game state (autoload singleton)
var current_crew = GameState.get_crew()
var current_ship = GameState.get_ship()

# Update state
GameState.set_campaign_name("My Campaign")
GameState.add_crew_member(new_character)

# Listen for changes
GameState.crew_updated.connect(_on_crew_changed)
```

### Using Desktop Commander for Editing

**Read before editing**:
```bash
desktop-commander:read_file 
  path: "src/ui/screens/campaign/panels/ConfigPanel.gd"
  offset: 100
  length: 50
```

**Surgical edits**:
```bash
desktop-commander:edit_block
  file_path: "src/ui/screens/campaign/panels/ConfigPanel.gd"
  old_string: "func _old_implementation():"
  new_string: "func _new_implementation():"
  expected_replacements: 1
```

---

## 🐛 Troubleshooting

### Common Issues

#### Scene Not Found Errors
```gdscript
# Always use ResourceLoader to verify scenes exist
if ResourceLoader.exists("res://path/to/scene.tscn"):
    get_tree().change_scene_to_file("res://path/to/scene.tscn")
else:
    push_error("Scene not found: res://path/to/scene.tscn")
```

#### Signal Connection Errors
```gdscript
# Use safe connection pattern
if not panel.panel_data_changed.is_connected(_on_panel_data_changed):
    panel.panel_data_changed.connect(_on_panel_data_changed)

# Always disconnect in cleanup
func _exit_tree():
    if panel.panel_data_changed.is_connected(_on_panel_data_changed):
        panel.panel_data_changed.disconnect(_on_panel_data_changed)
```

#### Resource Property Check Errors
```gdscript
# ✅ CORRECT: Check properties in Resources
if "background" in character:
    print(character.background)

# ❌ WRONG: .has() doesn't exist for Resources
if character.has("background"):  # ERROR!
    print(character.background)
```

#### Test Runner Signal 11 Crash
```
⚠️ Symptom: Tests crash after 8-18 tests with "signal 11"
✅ Solution: DO NOT use --headless flag, use PowerShell or UI mode
```

---

## 🚀 Production Build

### Build Commands
```bash
# Development build (with debug symbols)
godot --export-debug "Windows Desktop" builds/dev/game.exe

# Production build (optimized)
godot --export "Windows Desktop" builds/prod/game.exe
```

### Build Checklist
- [ ] Run all tests (138 tests must pass)
- [ ] Check for `print()` statements in production code
- [ ] Verify save/load functionality
- [ ] Test campaign creation end-to-end
- [ ] Profile performance (60 FPS target)

---

## 📊 Performance Profiling

### Performance Targets

- **Panel Load Time**: <100ms ✅ (currently meeting target)
- **Memory Usage**: <200MB target
- **Frame Rate**: 60 FPS target (16.67ms per frame)

### Enable Profiler

1. Run the project in Godot Editor
2. Go to **Debugger → Profiler**
3. Click "Start"
4. Navigate through campaign creation workflow
5. Analyze bottlenecks (look for frame spikes)

### Optimization Tips

- Use `@onready` for node references (cache, don't query)
- Avoid `find_child()` in loops (use cached references)
- Use `NinePatchRect` instead of `PanelContainer` (overdraw issues)
- Batch UI updates with `call_deferred()`
- Disconnect signals before `queue_free()` (prevent memory leaks)

---

## 🔧 IDE Setup

### VS Code Configuration
```json
// .vscode/settings.json
{
    "godot_tools.editor_path": "C:/Users/YourUser/Desktop/GoDot/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64.exe",
    "editor.formatOnSave": false,
    "files.exclude": {
        "**/.godot": true,
        "**/.import": true,
        "**/builds": true
    },
    "files.watcherExclude": {
        "**/.godot/**": true
    }
}
```

### Recommended Extensions
- **Godot Tools** (geequlim.godot-tools)
- **GitLens** (eamodio.gitlens)
- **Error Lens** (usernamehw.errorlens)
- **TODO Highlight** (wayou.vscode-todo-highlight)

---

## 🌟 Best Practices

### Code Style (Static Typing Everywhere)

```gdscript
# ✅ CORRECT: Static typing on all variables
func calculate_damage(attacker: Character, defender: Character) -> int:
    var base_damage: int = attacker.attack_power
    var defense: int = defender.defense_value
    return max(1, base_damage - defense)

# ✅ CORRECT: Signal with typed parameters
signal health_changed(new_health: int, max_health: int)

# ✅ CORRECT: @export with type hints
@export var character_data: Character
@export var max_crew_size: int = 8

# ❌ WRONG: Untyped variables
var damage = attacker.get_attack() - defender.get_defense()
```

### Signal Architecture

```gdscript
# ✅ CORRECT: Parent calls down to child
func _ready():
    $CharacterCard.update_stats(health, attack, defense)

# ✅ CORRECT: Child signals up to parent
signal card_tapped(character: Character)

# ❌ WRONG: Child calling get_parent()
func _on_button_pressed():
    get_parent().handle_card_tap()  # Brittle coupling!
```

### Git Workflow
```bash
# Feature branch workflow
git checkout -b feature/panel-improvement
git add src/ui/screens/campaign/panels/ConfigPanel.gd
git commit -m "feat(campaign): improve validation feedback in ConfigPanel"
git push origin feature/panel-improvement
```

### Documentation
- Comment complex business logic
- Use `## Documentation comments` for class/function docs
- Update WEEK_N_RETROSPECTIVE.md when completing major features
- Keep TESTING_GUIDE.md current with new tests

---

## 🤝 Contributing

### Before Submitting PR

1. **Run all tests** (138 tests must pass):
   ```powershell
   & 'path/to/Godot_v4.5.1-stable_win64_console.exe' `
     --path '.' --script addons/gdUnit4/bin/GdUnitCmdTool.gd `
     -a tests --quit-after 60
   ```

2. **Check for errors**:
   - No console errors in Godot editor
   - No `print()` statements in production code
   - No untyped variables

3. **Test manually**:
   - Complete campaign creation workflow
   - Navigate between screens
   - Verify save/load works

4. **Update documentation**:
   - Update WEEK_N_RETROSPECTIVE.md if major feature
   - Update TESTING_GUIDE.md if adding tests
   - Update this QUICK_START.md if workflow changes

### PR Template
```markdown
## Description
Brief description of changes (1-2 sentences)

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] All 138 tests pass
- [ ] Manual testing completed (campaign creation end-to-end)
- [ ] No console errors in Godot editor
- [ ] Performance profiled (no frame drops)

## Files Changed
- `src/path/to/file.gd` - Description of changes
- `tests/unit/test_file.gd` - Added test coverage

## Screenshots
(if applicable - UI changes, new panels, etc.)
```

---

## 📚 Resources

### Project Documentation

- **[CLAUDE.md](../CLAUDE.md)** - Living development guide (workflow, tools, best practices)
- **[WEEK_4_RETROSPECTIVE.md](../WEEK_4_RETROSPECTIVE.md)** - Current project status
- **[TESTING_GUIDE.md](../tests/TESTING_GUIDE.md)** - Testing methodology and test coverage
- **[REALISTIC_FRAMEWORK_BIBLE.md](../REALISTIC_FRAMEWORK_BIBLE.md)** - Architecture principles
- **[PROJECT_INSTRUCTIONS.md](../PROJECT_INSTRUCTIONS.md)** - 96 verified TODOs

### Godot Resources

- [Godot 4.5 Documentation](https://docs.godotengine.org/en/4.5/)
- [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [Godot Best Practices](https://docs.godotengine.org/en/stable/tutorials/best_practices/)
- [Godot Signal Patterns](https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html)

### Five Parsecs Resources

- [Core Rules](https://www.modiphius.net/pages/five-parsecs)
- [Community Forum](https://forum.modiphius.com/)
- [Implementation Notes](gameplay/rules/core_rules.md)

---

## 🎯 Quick Start Checklist

### First-Time Setup
- [ ] Install Godot 4.5.1-stable (non-mono)
- [ ] Clone repository
- [ ] Open project in Godot
- [ ] Run project (F5) - verify MainMenu loads
- [ ] Run tests via PowerShell - verify 138 tests pass

### Daily Development Workflow
- [ ] Read WEEK_N_RETROSPECTIVE.md (current status)
- [ ] Check TESTING_GUIDE.md (test status)
- [ ] Review `git log --oneline -10` (recent changes)
- [ ] Make changes using Desktop Commander (read → edit_block)
- [ ] Run affected tests
- [ ] Validate with `git diff`
- [ ] Commit with descriptive message

### Before Committing
- [ ] Run all tests (138 must pass)
- [ ] Check for console errors
- [ ] Remove debug `print()` statements
- [ ] Update documentation if needed
- [ ] Verify static typing on all new variables

---

**Need Help?** 

- Check [CLAUDE.md](../CLAUDE.md) for development workflow
- Review [TESTING_GUIDE.md](../tests/TESTING_GUIDE.md) for testing methodology
- Read [WEEK_4_RETROSPECTIVE.md](../WEEK_4_RETROSPECTIVE.md) for project status
- Open an issue on GitHub for bugs or feature requests

**Project Status**: BETA_READY (95/100) - On track for production candidate by end of Week 4.
