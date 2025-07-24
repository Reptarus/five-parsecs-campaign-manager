# Claude Hooks Integration Guide
## Five Parsecs Campaign Manager

### 🎯 **OVERVIEW**

This document provides comprehensive guidance for using the integrated Claude Hooks system in the Five Parsecs Campaign Manager project. The hooks system provides automated quality assurance, testing, and validation workflows that execute whenever you use Claude to modify project files.

---

## 📦 **INSTALLATION & SETUP**

### **Prerequisites**
- Python 3.8+ installed and accessible via `python` command
- Godot 4.4 console executable properly configured
- Five Parsecs Campaign Manager project structure in place

### **Quick Setup**
```bash
# Navigate to your project root
cd "C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager"

# Test hook dependencies
python automation/hooks_manager.py validate

# List available hooks
python automation/hooks_manager.py list

# Test all hooks
python automation/hooks_manager.py test-all
```

### **Configuration Files**
- **Main Config**: `.claude/hooks.json` - Complete hook configuration
- **Automation Scripts**: `automation/` directory - All hook execution scripts
- **Logs**: `.claude/hooks.log` - Hook execution logs and debugging info

---

## 🔧 **AVAILABLE HOOKS**

### **1. GDScript Quality Enforcer** ⚡
**Type**: `PreToolUse` | **Trigger**: Before file modifications  
**Purpose**: Automatically fix GDScript linting errors and enforce coding standards

**What it does**:
- Fixes type annotation issues automatically  
- Resolves unsafe property/method access warnings
- Corrects shadowing identifier conflicts
- Enforces Five Parsecs coding standards

**Example Fixes**:
```gdscript
# Before (hook fixes this automatically)
var character_name = get_character_name()  # Missing type

# After (hook applies this fix)
var character_name: String = get_character_name()
```

### **2. Comprehensive Test Suite** 🧪
**Type**: `PostToolUse` | **Trigger**: After code modifications  
**Purpose**: Run relevant tests based on modified files

**What it does**:
- Intelligently selects tests based on changed files
- Executes GDUnit4 test suite with targeted testing
- Provides immediate feedback on code changes
- Prevents regressions in production-ready systems

**Test Mapping Examples**:
- `src/core/campaign/` → Runs campaign and integration tests
- `CampaignCreationStateManager.gd` → Runs campaign + state tests
- `src/ui/screens/` → Runs UI component tests

### **3. Godot Project Validator** 🎬
**Type**: `PostToolUse` | **Trigger**: After scene/resource modifications  
**Purpose**: Validate project integrity and dependencies

**What it does**:
- Validates scene dependencies and references
- Checks resource integrity and loading paths
- Verifies project configuration compliance
- Ensures critical Five Parsecs scenes are properly structured

### **4. Five Parsecs Rule Compliance** 🎲
**Type**: `PostToolUse` | **Trigger**: After game system modifications  
**Purpose**: Validate digital implementation against tabletop rules

**What it does**:
- Validates character creation mechanics (2d6/3 rounded up)
- Checks campaign turn structure compliance
- Verifies combat mechanics accuracy
- Ensures dice system follows Five Parsecs standards

**Rule Validation Examples**:
```gdscript
// Validates this follows Core Rules p.13
func generate_attribute() -> int:
    var roll = DiceSystem.roll_dice(2, 6)
    return int(ceil(float(roll) / 3.0))  ✅ Compliant

// Flags this as non-compliant
func generate_attribute() -> int:
    return randi() % 6 + 1  ❌ Wrong dice method
```

### **5. Campaign State Guardian** 🛡️
**Type**: `PreToolUse` | **Trigger**: Before state management modifications  
**Purpose**: Protect enterprise-grade state management integrity

**What it does**:
- Validates signal architecture and connections
- Ensures state validation logic compliance
- Checks UI-state binding consistency
- Prevents breaking production-ready state managers

### **6. Performance Monitor** ⚡
**Type**: `PostToolUse` | **Trigger**: After any code modifications  
**Purpose**: Monitor performance impact and 60 FPS target

**What it does**:
- Analyzes code complexity and optimization opportunities
- Detects memory allocation hotspots
- Identifies rendering performance issues
- Validates 60 FPS target compatibility

---

## 🚀 **HOOK MANAGEMENT**

### **Activate/Deactivate Hooks**
```bash
# Activate specific hook
python automation/hooks_manager.py activate gdscript_quality_enforcer

# Deactivate hook
python automation/hooks_manager.py deactivate performance_monitor

# List all hooks with status
python automation/hooks_manager.py list
```

### **Test Individual Hooks**
```bash
# Test specific hook
python automation/hooks_manager.py test five_parsecs_rule_compliance

# Test with specific file
python automation/hooks_manager.py test state_guardian --file src/ui/screens/campaign/CampaignCreationUI.gd

# Test all enabled hooks
python automation/hooks_manager.py test-all --format detailed
```

### **System Status & Diagnostics**
```bash
# Check system status
python automation/hooks_manager.py status

# Validate dependencies
python automation/hooks_manager.py validate

# Generate JSON status report
python automation/hooks_manager.py status --format json
```

---

## 📊 **PERFORMANCE IMPACT**

### **Hook Execution Times** (Typical)
- **GDScript Quality Enforcer**: 5-15 seconds
- **Test Suite (Targeted)**: 30-90 seconds
- **Project Validator**: 10-30 seconds  
- **Rule Compliance**: 5-20 seconds
- **State Guardian**: 8-25 seconds
- **Performance Monitor**: 10-40 seconds

### **Optimization Settings**
The hooks system includes intelligent optimizations:
- **Targeted Testing**: Only runs relevant tests, not entire suite
- **File Size Limits**: Skips very large files to prevent timeouts
- **Exclude Patterns**: Ignores generated files and addons
- **Timeout Management**: Prevents hanging on problematic files

---

## 🔧 **CUSTOMIZATION**

### **Modifying Hook Behavior**
Edit `.claude/hooks.json` to customize:

```json
{
  "hooks": [
    {
      "name": "gdscript_quality_enforcer",
      "enabled": true,
      "timeout": 30,
      "conditions": {
        "fileSize": "< 100KB",
        "excludePaths": ["addons/", "tests/fixtures/"]
      }
    }
  ]
}
```

### **Adding Custom Hooks**
```json
{
  "name": "custom_validation",
  "type": "PostToolUse", 
  "patterns": [
    {"tool": "write_file", "filePattern": "src/custom/**/*.gd"}
  ],
  "command": "python",
  "args": ["automation/custom_validator.py", "--file", "${filePath}"],
  "timeout": 60
}
```

### **Environment Variables**
Configure paths in the global settings:
```json
{
  "globalSettings": {
    "environment": {
      "GODOT_PATH": "C:/Path/To/Godot/Console.exe",
      "PROJECT_ROOT": "C:/Path/To/Project",
      "PYTHON_PATH": "python"
    }
  }
}
```

---

## 🛠️ **TROUBLESHOOTING**

### **Common Issues**

#### **"Hook timed out"**
```bash
# Increase timeout in hooks.json
"timeout": 120  # Increase from default 60 seconds

# Or skip large files
"conditions": {
  "fileSize": "< 50KB"
}
```

#### **"Command not found" errors**
```bash
# Validate dependencies
python automation/hooks_manager.py validate

# Check specific paths
echo $GODOT_PATH
python --version
```

#### **"Test failures" in hook execution**
```bash
# Run tests manually to debug
python automation/test_runner.py --mode targeted --changed-file src/core/campaign/SomeFile.gd

# Check test output
python automation/hooks_manager.py test comprehensive_test_suite --format detailed
```

#### **"Permission denied" errors**
```bash
# Make scripts executable (Unix/Mac)
chmod +x automation/*.py

# On Windows, run as administrator if needed
```

### **Debugging Hook Execution**
```bash
# Enable verbose logging
# Edit .claude/hooks.json:
"logging": {
  "level": "debug",
  "file": ".claude/hooks.log"
}

# View logs
tail -f .claude/hooks.log

# Or on Windows
Get-Content .claude/hooks.log -Wait
```

### **Disabling Problematic Hooks**
```bash
# Temporarily disable hook
python automation/hooks_manager.py deactivate problematic_hook_name

# Re-enable after fixing
python automation/hooks_manager.py activate problematic_hook_name
```

---

## 💡 **BEST PRACTICES**

### **Development Workflow**
1. **Start with validation**: Run `hooks_manager.py validate` before beginning work
2. **Test incrementally**: Use `test-all` periodically to catch issues early
3. **Monitor performance**: Check hook execution times and adjust timeouts
4. **Review hook output**: Pay attention to warnings and recommendations

### **Hook Configuration**
- **Enable gradually**: Start with 2-3 hooks, add more as you adapt workflow
- **Customize timeouts**: Adjust based on your system performance
- **Use exclude patterns**: Skip files that don't need validation (logs, generated files)
- **Monitor logs**: Check `.claude/hooks.log` for patterns and issues

### **Integration with Development**
- **Pre-commit testing**: Run `test-all` before major commits
- **Performance monitoring**: Use performance monitor for optimization sessions
- **State protection**: Always keep state guardian enabled for UI/state files
- **Rule compliance**: Keep rule validator enabled for game system files

---

## 📈 **MEASURING SUCCESS**

### **Quality Metrics**
Track these improvements after hook integration:
- **Reduced linting errors**: Should approach zero over time
- **Test coverage maintenance**: Hooks prevent test regressions
- **Performance consistency**: 60 FPS target validation
- **Rule compliance**: Ensures Five Parsecs accuracy

### **Development Velocity**
- **Faster code reviews**: Automated quality checks reduce manual review time
- **Earlier issue detection**: Hooks catch problems before they compound
- **Consistent standards**: Automated enforcement reduces style discussions
- **Confident refactoring**: Comprehensive testing enables safe changes

---

## 🎯 **NEXT STEPS**

### **Phase 1: Basic Integration** (Complete)
- ✅ Hooks system installed and configured
- ✅ All automation scripts created and tested
- ✅ Basic hook testing and validation working

### **Phase 2: Workflow Optimization** (Next)
- Configure optimal timeout values for your system
- Customize exclude patterns for your workflow
- Add project-specific validation rules
- Integrate with your preferred development tools

### **Phase 3: Advanced Automation** (Future)
- Add custom hooks for specific Five Parsecs requirements
- Integrate with CI/CD pipeline for automated testing
- Add performance benchmarking and regression detection
- Create hook-based release validation workflow

---

**🎉 Your Claude Hooks system is now ready to supercharge your Five Parsecs development workflow!**

For issues or questions, check the troubleshooting section or run:
```bash
python automation/hooks_manager.py status --format detailed
```