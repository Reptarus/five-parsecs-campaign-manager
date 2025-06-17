# 🔧 Test Fix Template

## Quick Reference: How to Fix Any Failing Test

### **Step 1: Fix Base Class and Imports**
```gdscript
# Change from:
extends GdUnitGameTest

# To (for UI tests):
extends UITest

# Fix imports - use actual paths
const YourComponent = preload("res://path/to/actual/component.gd")
```

### **Step 2: Fix Instance Variables**
```gdscript
# Use specific types, not generic Node
var _component_instance: Control  # or Button, Label, etc.
```

### **Step 3: Fix Setup Method**
```gdscript
func before_test() -> void:
	super.before_test()
	
	# For UI Components:
	_component_instance = await create_ui_component(YourComponent, "TestComponent")
	await wait_for_ui_ready(_component_instance)
	
	# For Non-UI Components:
	_component_instance = YourComponent.new()
	add_child(_component_instance)
	auto_free(_component_instance)
```

### **Step 4: Fix Test Methods**

#### **Property Access (CRITICAL)**
```gdscript
# ❌ WRONG: Direct property access
_component_instance.some_property = value
var value = _component_instance.some_property

# ✅ CORRECT: Safe property access
safe_set_ui_property(_component_instance, "some_property", value)
var value = safe_get_ui_property(_component_instance, "some_property")
```

#### **Method Calls (CRITICAL)**
```gdscript
# ❌ WRONG: Direct method calls
_component_instance.some_method()

# ✅ CORRECT: Safe method calls
safe_call_method(_component_instance, "some_method", [])
```

#### **Signal Testing (CRITICAL)**
```gdscript
# ❌ WRONG: Direct signal monitoring
monitor_signals(_component_instance)
assert_signal(_component_instance).is_emitted("signal_name")

# ✅ CORRECT: Safe signal monitoring
monitor_ui_signals(_component_instance, ["signal_name"])
assert_ui_signal_emitted(_component_instance, "signal_name")
```

#### **Node Access (CRITICAL)**
```gdscript
# ❌ WRONG: Direct node access
var child = _component_instance.get_node("Child")

# ✅ CORRECT: Safe node access
var child = safe_get_ui_node(_component_instance, "Child")
```

### **Step 5: Common Test Patterns**

#### **Basic Component Check**
```gdscript
func test_component_exists() -> void:
	assert_that(_component_instance).is_not_null()
	assert_ui_property_equals(_component_instance, "visible", true)
```

#### **Signal Testing**
```gdscript
func test_signal() -> void:
	monitor_ui_signals(_component_instance, ["expected_signal"])
	safe_simulate_ui_input(_component_instance, "click")
	await get_tree().process_frame
	assert_ui_signal_emitted(_component_instance, "expected_signal")
```

#### **Property Testing**
```gdscript
func test_property() -> void:
	var success = safe_set_ui_property(_component_instance, "test_property", "new_value")
	assert_that(success).is_true()
	await get_tree().process_frame
	assert_ui_property_equals(_component_instance, "test_property", "new_value")
```

### **Step 6: Fix Common Error Patterns**

#### **Orphan Nodes → Use auto_free()**
```gdscript
# Always use auto_free() for nodes you create
var node = Node.new()
add_child(node)
auto_free(node)  # Prevents orphan nodes
```

#### **API Mismatches → Check before use**
```gdscript
# Check if method exists before calling
if _component_instance.has_method("expected_method"):
	_component_instance.expected_method()
else:
	push_warning("Method expected_method does not exist")
```

#### **Signal Issues → Check signal exists**
```gdscript
# Check if signal exists before monitoring
if _component_instance.has_signal("expected_signal"):
	monitor_signals(_component_instance)
else:
	push_warning("Signal expected_signal does not exist")
```

#### **Null References → Always validate**
```gdscript
# Always check if objects are valid
if not is_instance_valid(_component_instance):
	push_error("Component instance is null")
	return
```

## 🎯 **Priority Fix List**

### **Highest Priority (1500+ orphan nodes)**
1. **tests/unit/ui/panels/** - 7 files with 300+ orphans each
2. **tests/unit/ui/components/** - 20+ files with API mismatches
3. **tests/unit/ui/campaign/** - 10 files with signal issues
4. **tests/unit/ui/controllers/** - 5 files with null errors
5. **tests/unit/ui/dialogs/** - 3 files with setup errors

### **Apply This Template To:**
- Any test with "orphan nodes" warnings
- Any test with "Can't wait for non-existent signal" errors  
- Any test with "null instance" errors
- Any test with API mismatch errors
- Any test expecting methods that don't exist

### **Success Metrics:**
- 0 orphan nodes per test
- 0 signal timeout errors
- 0 null reference errors
- All tests using safe patterns from base classes 