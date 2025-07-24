# 🤖 Gemini CLI Task Specifications - Production Readiness Sprint

## 📊 **TASK 1: COMPREHENSIVE ERROR AUDIT ANALYSIS**
**Priority**: IMMEDIATE | **Expected Completion**: 30-45 minutes

### **Task Description:**
Analyze all error calls in the Five Parsecs Campaign Manager codebase to create a comprehensive classification and prioritization system for production error handling implementation.

### **Detailed Requirements:**

#### **1.1 Error Pattern Discovery**
```bash
# Search patterns to analyze:
find /src -name "*.gd" -exec grep -l "push_error\|push_warning\|printerr\|assert" {} \;
```

**Analyze these specific error patterns:**
- `push_error("...")` - Critical system errors
- `push_warning("...")` - Non-critical warnings  
- `printerr(...)` - Error output to stderr
- `assert(condition, "message")` - Development assertions

#### **1.2 Severity Classification System**
**CRITICAL** (Immediate attention required):
- Keywords: "critical", "fatal", "corrupt", "crash", "data loss"
- Impact: System instability, data corruption, user data loss
- Example: `push_error("Critical: Campaign data corrupted")`

**HIGH** (Significant impact):  
- Keywords: "fail", "crash", "exception", "invalid state"
- Impact: Feature failure, significant user experience degradation
- Example: `push_error("Mission generation failed")`

**MEDIUM** (Moderate impact):
- Keywords: "warning", "timeout", "invalid", "missing"
- Impact: Reduced functionality, performance issues
- Example: `push_warning("Invalid character data, using default")`

**LOW** (Minor impact):
- Keywords: "info", "debug", "notice"
- Impact: Cosmetic issues, minor inconveniences
- Example: `push_warning("Animation not found, skipping")`

#### **1.3 System Classification**
**UI System**: Files in `/ui/` directories
**Core System**: Files in `/core/` directories  
**Game System**: Files in `/game/` directories
**Data System**: Files containing "data", "manager", "save"
**Battle System**: Files containing "battle", "combat", "enemy"

#### **1.4 Required Output Files**

##### **ERROR_AUDIT_REPORT.md**
```markdown
# Five Parsecs Campaign Manager - Error Audit Report

## Executive Summary
- Total Error Calls: [NUMBER]
- Files Analyzed: [NUMBER]  
- Critical Issues: [NUMBER]
- Immediate Action Required: [NUMBER]

## Severity Breakdown
| Severity | Count | Percentage | Systems Affected |
|----------|-------|------------|------------------|
| CRITICAL | X     | Y%         | [List]           |
| HIGH     | X     | Y%         | [List]           |
| MEDIUM   | X     | Y%         | [List]           |
| LOW      | X     | Y%         | [List]           |

## System Breakdown
| System | Total Errors | Critical | High | Medium | Low |
|--------|--------------|----------|------|--------|-----|
| UI     | X           | X        | X    | X      | X   |
| Core   | X           | X        | X    | X      | X   |
| [etc]  | X           | X        | X    | X      | X   |

## Top 20 Critical Error Paths
1. [File:Line] - [Error Message] - [Severity] - [Recommended Action]
2. [Continue for top 20...]

## Recommended Recovery Strategies
### For CRITICAL errors:
- Emergency save and graceful shutdown
- Data backup before operations
- User notification of data risk

### For HIGH errors:  
- Component restart capabilities
- Fallback to basic functionality
- User notification of feature unavailability

### For MEDIUM errors:
- Automatic retry with backoff
- Graceful degradation
- Background error logging

### For LOW errors:
- Silent error logging
- Continue normal operation
- Optional user notification
```

##### **CRITICAL_ERROR_PRIORITIES.json**
```json
{
  "immediate_action_required": [
    {
      "file": "path/to/file.gd",
      "line": 123,
      "error_message": "Critical error text",
      "severity": "CRITICAL",
      "system": "Core",
      "impact": "Data corruption possible",
      "recommended_recovery": "EMERGENCY_SAVE",
      "priority_score": 100
    }
  ],
  "high_priority": [...],
  "system_totals": {
    "ui_system": {"total": 45, "critical": 2, "high": 8},
    "core_system": {"total": 67, "critical": 5, "high": 12}
  },
  "recovery_strategy_distribution": {
    "RETRY": 234,
    "FALLBACK": 156, 
    "EMERGENCY_SAVE": 12,
    "GRACEFUL_DEGRADE": 89
  }
}
```

---

## 🧠 **TASK 2: MEMORY LEAK PATTERN ANALYSIS**
**Priority**: HIGH | **Expected Completion**: 45-60 minutes

### **Task Description:**
Systematically analyze all 419 GDScript files for memory leak patterns and anti-patterns that could cause memory exhaustion in production.

### **Memory Leak Patterns to Detect:**

#### **2.1 Node Management Issues**
```gdscript
# BAD PATTERNS:
remove_child(node)  # Missing queue_free()
node.get_parent().remove_child(node)  # Missing queue_free()

# GOOD PATTERNS:  
remove_child(node)
node.queue_free()
```

#### **2.2 Resource Management Issues**
```gdscript
# BAD PATTERNS:
var file = FileAccess.open(path, FileAccess.READ)
# Missing file.close()

var http = HTTPRequest.new()
# Missing cleanup on destruction
```

#### **2.3 Signal Connection Issues**
```gdscript
# BAD PATTERNS:
signal.connect(callable)  # Never disconnected
# In _exit_tree or cleanup, missing disconnect

# CIRCULAR REFERENCES:
var parent_ref = get_parent()
var child_ref = get_child(0)  # Potential circular reference
```

### **Required Output:**

##### **MEMORY_LEAK_AUDIT.md**
```markdown
# Five Parsecs Campaign Manager - Memory Leak Analysis

## Executive Summary  
- Files Analyzed: 419
- Memory Leak Risks Identified: [NUMBER]
- High-Risk Files: [NUMBER]
- Estimated Memory Savings: [MB]

## Pattern Analysis
| Pattern Type | Occurrences | Risk Level | Est. Memory Impact |
|--------------|-------------|------------|-------------------|
| Missing queue_free() | X | HIGH | Y MB |
| Unclosed FileAccess | X | MEDIUM | Y MB |
| Disconnected signals | X | LOW | Y MB |

## Top 20 High-Risk Files
1. [File] - [Pattern] - [Est. Impact] - [Fix Complexity]

## Automated Fix Recommendations
[Specific code changes for each pattern]

## Implementation Priority
1. IMMEDIATE: Files with potential data loss
2. HIGH: Files with >10MB estimated impact  
3. MEDIUM: Files with UI memory leaks
4. LOW: Files with minor leaks
```

---

## 🚀 **TASK 3: PERFORMANCE BOTTLENECK ANALYSIS**  
**Priority**: MEDIUM | **Expected Completion**: 45-60 minutes

### **Task Description:**
Analyze all scene files and scripts for performance anti-patterns that could impact the target of 30% load time improvement and 25% memory reduction.

### **Performance Anti-Patterns to Detect:**

#### **3.1 Heavy Initialization**
```gdscript
# BAD PATTERNS in _ready():
func _ready():
    for i in range(10000):  # Heavy loops
        process_something()
    load_all_resources()  # Synchronous loading
```

#### **3.2 Process Function Issues**  
```gdscript
# BAD PATTERNS:
func _process(delta):
    expensive_operation()  # Every frame
    find_node("Something")  # Repeated searches
```

#### **3.3 Resource Loading Issues**
```gdscript
# BAD PATTERNS:
var texture = load("res://large_texture.png")  # Synchronous load
preload("res://everything.tscn")  # Unnecessary preloads
```

### **Required Output:**

##### **PERFORMANCE_OPTIMIZATION_PLAN.md**
```markdown
# Five Parsecs Campaign Manager - Performance Optimization Plan

## Current Performance Baseline
- Campaign Controller Load: 361ms
- WorldPhase UI Load: 2ms  
- Peak Memory: 111.4MB

## Optimization Targets
- Load Time: 361ms → 250ms (30% improvement)
- Memory Usage: 111.4MB → 85MB (25% reduction)
- FPS: Maintain 60 FPS under load

## Top 15 Performance Bottlenecks
1. [File] - [Issue] - [Impact] - [Fix Effort] - [Est. Improvement]

## Implementation Plan
### Phase 1 (High Impact, Low Effort):
- [Specific optimizations]
### Phase 2 (High Impact, Medium Effort):  
- [Specific optimizations]
### Phase 3 (Medium Impact, Low Effort):
- [Specific optimizations]

## Automated Optimization Opportunities
[Specific code patterns that can be automatically optimized]
```

---

## 🔄 **GEMINI CLI EXECUTION COMMANDS**

### **Command 1: Error Audit**
```bash
gemini "Analyze the Five Parsecs Campaign Manager codebase located at '/mnt/c/Users/elijah/SynologyDrive/Godot/five-parsecs-campaign-manager/src' for comprehensive error audit analysis. Follow the specifications in GEMINI_TASK_SPECIFICATIONS.md for Task 1. Create ERROR_AUDIT_REPORT.md and CRITICAL_ERROR_PRIORITIES.json with the exact format and analysis specified."
```

### **Command 2: Memory Leak Analysis** 
```bash
gemini "Perform comprehensive memory leak pattern analysis on Five Parsecs Campaign Manager codebase at '/mnt/c/Users/elijah/SynologyDrive/Godot/five-parsecs-campaign-manager/src'. Analyze all 419 .gd files following Task 2 specifications. Create MEMORY_LEAK_AUDIT.md and memory_leak_fixes.json."
```

### **Command 3: Performance Analysis**
```bash  
gemini "Conduct performance bottleneck analysis for Five Parsecs Campaign Manager at '/mnt/c/Users/elijah/SynologyDrive/Godot/five-parsecs-campaign-manager/src'. Follow Task 3 specifications to create PERFORMANCE_OPTIMIZATION_PLAN.md and performance_fixes.json."
```

---

## ⏰ **PARALLEL EXECUTION TIMELINE**

**T+0 minutes**: Initiate Gemini CLI Task 1 (Error Audit)
**T+0 minutes**: Claude begins ProductionErrorHandler integration planning
**T+45 minutes**: Gemini completes Task 1, begins Task 2 (Memory Analysis)  
**T+45 minutes**: Claude reviews Error Audit results, begins implementation
**T+90 minutes**: Gemini completes Task 2, begins Task 3 (Performance)
**T+135 minutes**: All Gemini analysis complete, Claude implements optimizations

**Expected Token Savings**: 8,000-12,000 tokens (60-70% reduction)
**Expected Quality Improvement**: Higher through specialized task assignment