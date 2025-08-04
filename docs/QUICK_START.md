# Five Parsecs Campaign Manager - Quick Start Guide

## 🚀 Quick Start for Developers

Get up and running with the Five Parsecs Campaign Manager development environment in minutes.

## Prerequisites

- **Godot 4.4+** (Mono version for C# support)
- **Git** for version control
- **Python 3.8+** for build scripts
- **Visual Studio Code** (recommended) with Godot extensions

## 🏃 Getting Started (5 Minutes)

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/five-parsecs-campaign-manager.git
cd five-parsecs-campaign-manager
```

### 2. Open in Godot
1. Launch Godot 4.4+
2. Click "Import" 
3. Navigate to the project folder
4. Select `project.godot`
5. Click "Import & Edit"

### 3. Run the Project
- Press `F5` or click the Play button
- The game starts at `MainMenu.tscn`
- Test the campaign creation flow immediately

## 🏗️ Project Architecture Overview

### Coordinator Pattern
The project uses a Coordinator Pattern for UI orchestration:
- **Panels**: Self-managing UI components with business logic
- **Coordinator**: Lightweight orchestration without UI knowledge
- **State Manager**: Centralized state with validation

### Directory Structure
```
src/
├── ui/screens/        # All UI components
│   ├── mainmenu/     # Entry point
│   └── campaign/     # Campaign creation
├── core/             # Business logic
│   ├── systems/      # Game systems
│   └── validation/   # Security layer
└── test/             # Test suites
```

## 🧪 Testing the Application

### Running Tests
```bash
# Run all tests
godot --script res://src/test/run_all_tests.gd

# Run specific test suite
godot --script res://src/test/integration/test_campaign_creation_flow.gd
```

### Test Coverage
- **Critical Paths**: 100% coverage required
- **UI Components**: Integration tests for workflows
- **Game Systems**: Unit tests for logic

## 🛠️ Common Development Tasks

### Adding a New Campaign Panel

1. **Create Panel Script**
```gdscript
# src/ui/screens/campaign/panels/YourPanel.gd
extends Panel

signal panel_completed(data: Dictionary)

var state_manager: CampaignCreationStateManager
var local_data: Dictionary = {}

func initialize(state: CampaignCreationStateManager) -> void:
    state_manager = state
    _setup_ui()

func get_panel_data() -> Dictionary:
    return {
        "is_complete": _validate_data(),
        "data": local_data
    }

func _validate_data() -> bool:
    # Your validation logic
    return true
```

2. **Create Panel Scene**
- Create `YourPanel.tscn` in the same directory
- Attach the script to the root node
- Design your UI

3. **Register with Coordinator**
- Add to `CampaignCreationUI.tscn`
- Update phase enumeration
- Test the flow

### Debugging Campaign Creation

Enable debug mode for detailed logging:
```gdscript
# In CampaignCreationUI._ready()
CampaignAnalytics.enable_debug_mode()
coordinator.enable_verbose_logging()
```

### Working with State Management

Access campaign state safely:
```gdscript
# Read state
var crew_data = state_manager.get_phase_data(Phase.CREW_SETUP)

# Update state
state_manager.set_phase_data(Phase.CONFIG, {
    "campaign_name": "My Campaign",
    "difficulty": 3
})

# Listen for changes
state_manager.state_updated.connect(_on_state_changed)
```

## 🐛 Troubleshooting

### Common Issues

#### Scene Not Found Errors
```gdscript
# Always use FileAccess to verify scenes exist
if FileAccess.file_exists("res://path/to/scene.tscn"):
    get_tree().change_scene_to_file("res://path/to/scene.tscn")
```

#### Signal Connection Errors
```gdscript
# Use safe connection pattern
if not panel.panel_completed.is_connected(_on_panel_completed):
    panel.panel_completed.connect(_on_panel_completed)
```

#### State Persistence Issues
```gdscript
# Force state save
state_manager.persist_current_state()
SaveManager.force_save()
```

## 🚀 Production Build

### Quick Build Commands
```bash
# Development build (with debug)
godot --export-debug "Windows Desktop" builds/dev/game.exe

# Production build (optimized)
godot --export "Windows Desktop" builds/prod/game.exe

# Run tests before building
./scripts/pre-build-tests.sh
```

### Build Checklist
- [ ] Run all tests
- [ ] Check for console.log/print statements
- [ ] Verify analytics endpoints
- [ ] Test save/load functionality
- [ ] Profile performance

## 📊 Performance Profiling

### Enable Profiler
1. Run the project
2. Go to Debugger → Profiler
3. Click "Start"
4. Navigate through campaign creation
5. Analyze bottlenecks

### Key Metrics to Monitor
- **Panel Load Time**: Should be <100ms
- **Memory Usage**: Should stay under 50MB
- **Frame Time**: Maintain 60 FPS (16.67ms)

## 🔧 IDE Setup

### VS Code Configuration
```json
// .vscode/settings.json
{
    "godot_tools.editor_path": "/path/to/godot",
    "editor.formatOnSave": true,
    "files.exclude": {
        "**/.godot": true,
        "**/*.tmp": true
    }
}
```

### Recommended Extensions
- Godot Tools
- GitLens
- Error Lens
- TODO Highlight

## 🌟 Best Practices

### Code Style
```gdscript
# Use type hints everywhere
func calculate_damage(attacker: Character, defender: Character) -> int:
    var base_damage: int = attacker.get_attack_power()
    var defense: int = defender.get_defense_value()
    return max(1, base_damage - defense)

# Prefer signals over direct coupling
signal health_changed(new_health: int)

# Use resource types for data
export var character_data: CharacterResource
```

### Git Workflow
```bash
# Feature branch workflow
git checkout -b feature/panel-improvement
git add -A
git commit -m "feat(panels): improve validation feedback"
git push origin feature/panel-improvement
```

### Documentation
- Comment complex logic
- Update API docs when changing interfaces
- Add examples for new features
- Keep README current

## 🤝 Contributing

### Before Submitting PR
1. Run all tests: `godot --script res://src/test/run_all_tests.gd`
2. Check linting: No errors in Godot editor
3. Update documentation if needed
4. Test the complete workflow manually

### PR Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] All tests pass
- [ ] Manual testing completed
- [ ] No console errors

## Screenshots
(if applicable)
```

## 📚 Resources

### Project Documentation
- [Architecture Guide](docs/technical/ARCHITECTURE.md)
- [API Reference](docs/developer/API_REFERENCE.md)
- [Testing Guide](docs/testing/integration_guide.md)

### Godot Resources
- [Official Documentation](https://docs.godotengine.org/)
- [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [Best Practices](https://docs.godotengine.org/en/stable/tutorials/best_practices/)

### Five Parsecs Resources
- [Core Rules](https://www.modiphius.net/pages/five-parsecs)
- [Community Forum](https://forum.modiphius.com/)
- [Implementation Notes](docs/gameplay/rules_implementation.md)

---

**Need Help?** Check the [FAQ](docs/support/FAQ.md) or open an issue on GitHub.