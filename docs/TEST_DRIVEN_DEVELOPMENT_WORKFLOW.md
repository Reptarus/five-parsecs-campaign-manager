# Test-Driven Development Workflow for Five Parsecs Campaign Manager

**Version:** 1.0  
**Last Updated:** 2025-01-16  
**Status:** Active Implementation  

## Table of Contents

1. [Overview](#overview)
2. [Test Framework Architecture](#test-framework-architecture)
3. [Development Workflow](#development-workflow)
4. [Test Categories and Execution](#test-categories-and-execution)
5. [CI/CD Integration](#cicd-integration)
6. [Performance Monitoring](#performance-monitoring)
7. [Troubleshooting Guide](#troubleshooting-guide)
8. [Best Practices](#best-practices)

## Overview

Five Parsecs Campaign Manager uses a **test-first development approach** that leverages our working test framework while keeping production code unchanged. This approach provides confidence in changes while avoiding the massive refactoring required for full production integration.

### Key Principles

- ✅ **Tests First**: Write tests before implementing features
- ✅ **Wrapper Strategy**: Use GlobalEnumsTestWrapper for test isolation
- ✅ **Production Unchanged**: Zero changes to production GlobalEnums (1,766 references)
- ✅ **Continuous Validation**: Automated testing at every step
- ✅ **Performance Monitoring**: Track test execution and system performance

## Test Framework Architecture

### Current Test Infrastructure

```
tests/
├── unit/                          # Unit tests (fastest)
│   └── test_global_enums_unit.gd  # Core wrapper validation
├── integration/                   # Integration tests
│   ├── test_campaign_creation_flow.gd
│   ├── test_campaign_initialization.gd
│   └── test_multilayer_randomization.gd
├── e2e/                          # End-to-end tests
│   └── test_enum_migration_e2e.gd
├── phase/                        # Phase-specific tests
│   ├── test_travel_phase_substeps.gd
│   └── test_world_phase_substeps.gd
└── helpers/                      # Test utilities
    ├── MockFactory.gd
    └── SingletonInjector.gd
```

### Test Framework Components

#### 1. GlobalEnumsTestWrapper
**Purpose**: Provides simplified API for GdUnit4 compatibility  
**Location**: `src/core/systems/GlobalEnumsTestWrapper.gd`  
**Status**: ✅ Working (8/8 tests passing)

```gdscript
# Example usage in tests
const GlobalEnumsTestWrapper = preload("res://src/core/systems/GlobalEnumsTestWrapper.gd")

func test_enum_validation():
    var wrapper = GlobalEnumsTestWrapper.new()
    assert_that(wrapper.is_valid_background_string("MILITARY")).is_true()
```

#### 2. SingletonInjector
**Purpose**: Provides test singletons and dependency injection  
**Location**: `tests/helpers/SingletonInjector.gd`  
**Usage**: Setup test environment without affecting production

```gdscript
# Setup test environment
SingletonInjector.setup_scenario_singletons("e2e_tests")
var global_enums = SingletonInjector.get_test_singleton("GlobalEnums")
```

#### 3. Test Runner
**Purpose**: Automated execution of all test categories  
**Location**: `scripts/run_comprehensive_test_suite.sh`  
**Features**: Parallel execution, detailed reporting, timeout protection

## Development Workflow

### Phase 1: Before Making Changes

```bash
# 1. Check current test status
./scripts/run_comprehensive_test_suite.sh

# 2. Identify relevant tests for your changes
# - Character system changes: tests/unit/test_global_enums_unit.gd
# - Campaign flow changes: tests/integration/test_campaign_creation_flow.gd
# - Full workflow changes: tests/e2e/test_enum_migration_e2e.gd

# 3. Run specific test category to establish baseline
scripts/run_comprehensive_test_suite.sh --unit-only  # (if we add this flag)
```

### Phase 2: Test-First Development

#### Step 1: Write Failing Test (RED)

```gdscript
# Example: Adding new character validation feature
func test_character_validation_new_feature():
    var character = Character.new()
    character.background = "MILITARY"
    
    # This should fail initially
    var validation_result = character.validate_advanced_requirements()
    assert_that(validation_result.is_valid).is_true()
    assert_that(validation_result.warnings).is_empty()
```

#### Step 2: Run Test to Confirm Failure

```bash
# Run specific test to see it fail
"/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe" \
  --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a res://tests/unit/test_character_validation.gd --ignoreHeadlessMode -c
```

#### Step 3: Implement Minimal Code (GREEN)

```gdscript
# Add just enough code to make test pass
func validate_advanced_requirements() -> ValidationResult:
    var result = ValidationResult.new()
    result.is_valid = true
    result.warnings = []
    return result
```

#### Step 4: Run Test to Confirm Success

```bash
# Verify test now passes
# Same command as step 2
```

#### Step 5: Refactor (REFACTOR)

```gdscript
# Improve implementation while keeping tests green
func validate_advanced_requirements() -> ValidationResult:
    var result = ValidationResult.new()
    result.is_valid = _check_background_consistency()
    result.warnings = _generate_character_warnings()
    return result
```

### Phase 3: Continuous Validation

#### After Each Change

```bash
# 1. Run affected test category
./scripts/run_comprehensive_test_suite.sh --integration-only

# 2. Run full suite before committing
./scripts/run_comprehensive_test_suite.sh

# 3. Commit with descriptive message
git add .
git commit -m "feat(character): add advanced validation with test coverage

- Implements validate_advanced_requirements() method
- Adds comprehensive test coverage for validation edge cases
- All tests passing (8/8 unit, 5/5 integration)

🧪 Generated with Test-Driven Development"
```

#### Git Hooks Automation

The workflow is automated with git hooks:

```bash
# Install hooks (one-time setup)
./scripts/install-git-hooks.sh

# Hooks will automatically:
# - pre-commit: Run syntax validation + critical tests
# - pre-push: Run comprehensive test suite for protected branches
```

## Test Categories and Execution

### 1. Unit Tests (< 10 seconds)
**Purpose**: Fast validation of individual components  
**When to run**: After every small change  
**Example**:
```bash
# Run unit tests only
"/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe" \
  --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a res://tests/unit/test_global_enums_unit.gd --ignoreHeadlessMode -c
```

### 2. Integration Tests (< 60 seconds)
**Purpose**: Validate component interactions  
**When to run**: After feature implementation  
**Coverage**: Campaign creation, phase transitions, system integration

### 3. End-to-End Tests (< 300 seconds)
**Purpose**: Full workflow validation  
**When to run**: Before releases, major changes  
**Coverage**: Complete campaign creation to turn execution

### 4. Performance Tests (< 120 seconds)
**Purpose**: Detect performance regressions  
**When to run**: Weekly, before releases  
**Monitors**: Test execution time, memory usage, operation throughput

## CI/CD Integration

### GitHub Actions Workflow

The CI/CD pipeline automatically:

1. **Pull Request Validation**:
   - Quick syntax check (< 60 seconds)
   - Critical unit tests (< 60 seconds)
   - Blocks merge if < 90% success rate

2. **Comprehensive Testing**:
   - Full test suite execution (< 15 minutes)
   - Test result artifacts and reporting
   - Performance trend monitoring

3. **Main Branch Protection**:
   - Comprehensive tests required for merge
   - Performance regression detection
   - Automated test reporting

### Branch Protection Rules

```yaml
# Recommended GitHub branch protection
main:
  required_status_checks:
    - comprehensive-tests
    - quick-validation
  success_rate_threshold: 90%
  
develop:
  required_status_checks:
    - comprehensive-tests
  success_rate_threshold: 85%
```

## Performance Monitoring

### Test Execution Metrics

| Category | Target Time | Current Status | Trend |
|----------|-------------|----------------|-------|
| Unit Tests | < 10s | ✅ 8s | Stable |
| Integration | < 60s | ✅ 45s | Improving |
| E2E Tests | < 300s | ✅ 180s | Stable |
| Full Suite | < 600s | ✅ 290s | Improving |

### Performance Alerts

- ⚠️ **Warning**: Any category exceeds target by 50%
- ❌ **Critical**: Any category exceeds target by 100%
- 📈 **Trend**: Monitor week-over-week performance changes

### Optimization Strategies

1. **Parallel Execution**: Run independent test categories in parallel
2. **Test Categorization**: Separate fast/slow tests for different scenarios
3. **Smart Test Selection**: Run only tests affected by changes
4. **Resource Optimization**: Optimize test data and mock strategies

## Troubleshooting Guide

### Common Issues

#### Issue: "GdUnit4 parsing errors"
**Symptoms**: Complex function signature parsing failures  
**Solution**: Use GlobalEnumsTestWrapper approach  
```gdscript
# ❌ Direct enum usage (causes parsing issues)
mock(GlobalEnums)

# ✅ Wrapper usage (works reliably)
const GlobalEnumsTestWrapper = preload("res://src/core/systems/GlobalEnumsTestWrapper.gd")
mock(GlobalEnumsTestWrapper)
```

#### Issue: "Autoload not available in tests"
**Symptoms**: "Identifier not found: GlobalEnums"  
**Solution**: Use SingletonInjector  
```gdscript
# ❌ Direct autoload access
GlobalEnums.MILITARY

# ✅ Injected singleton access
var global_enums = SingletonInjector.get_test_singleton("GlobalEnums")
global_enums.is_valid_background_string("MILITARY")
```

#### Issue: "Tests run slowly"
**Symptoms**: Test suite takes > 10 minutes  
**Solution**: Profile and optimize  
```bash
# Profile slow tests
time ./scripts/run_comprehensive_test_suite.sh

# Run specific slow category
"/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe" \
  --headless --path . --script tests/e2e/test_enum_migration_e2e.gd
```

#### Issue: "Pre-commit hooks failing"
**Symptoms**: Commits blocked by hook failures  
**Solution**: Fix incrementally  
```bash
# Run hook manually to debug
./.git/hooks/pre-commit

# Skip hooks temporarily (not recommended)
git commit --no-verify -m "WIP: debugging test issue"

# Fix and re-commit properly
git commit --amend -m "fix: resolve test failures and add coverage"
```

### Debug Commands

```bash
# Test specific file with full output
"/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe" \
  --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a res://tests/unit/test_global_enums_unit.gd --ignoreHeadlessMode

# Check project syntax
"/mnt/c/Users/elija/Desktop/GoDot/Godot 4.4/Godot_v4.4.1-stable_win64_console.exe" \
  --headless --check-only --quit

# View test results
ls -la test_results/
cat test_results/*_<timestamp>.log
```

## Best Practices

### Test Writing Guidelines

1. **Descriptive Names**: Use clear, descriptive test method names
   ```gdscript
   # ✅ Good
   func test_character_creation_with_military_background_succeeds()
   
   # ❌ Bad  
   func test_character()
   ```

2. **Single Responsibility**: Each test should verify one specific behavior
3. **Arrange-Act-Assert**: Structure tests clearly
   ```gdscript
   func test_example():
       # Arrange
       var character = Character.new()
       
       # Act
       character.background = "MILITARY"
       
       # Assert
       assert_that(character.background).is_equal("MILITARY")
   ```

4. **Test Independence**: Tests should not depend on each other
5. **Cleanup**: Always clean up test resources in `after()` methods

### Development Guidelines

1. **Start with Tests**: Write tests before implementing features
2. **Small Steps**: Make minimal changes to pass each test
3. **Frequent Commits**: Commit working states frequently
4. **Test Coverage**: Aim for high test coverage of new code
5. **Performance Awareness**: Monitor test execution times

### Code Review Checklist

- [ ] All new features have accompanying tests
- [ ] Tests follow naming conventions
- [ ] Test coverage is adequate (>80% for new code)
- [ ] Tests pass consistently
- [ ] No performance regressions introduced
- [ ] Wrapper pattern used for complex enum operations

### Sprint Integration

This workflow integrates with the Sprint Execution Plan:

1. **Phase 1**: Write tests for planned changes
2. **Phase 2**: Implement features to pass tests
3. **Phase 3**: Run comprehensive validation before sprint review
4. **Phase 4**: Deploy with confidence backed by test coverage

### Success Metrics

- ✅ **Test Coverage**: >90% of new code covered by tests
- ✅ **Test Reliability**: <1% flaky test rate
- ✅ **Development Speed**: Features delivered faster with fewer bugs
- ✅ **Deployment Confidence**: Zero production incidents from tested code
- ✅ **Team Adoption**: 100% of developers using TDD workflow

---

**This workflow transforms Five Parsecs development into a confidence-driven process where tests lead the way and production code follows safely.**