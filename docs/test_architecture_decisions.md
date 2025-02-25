# Test Architecture Decisions

This document outlines the standardized test architecture for the Five Parsecs Campaign Manager project.

## Test Hierarchy

The following hierarchy has been established as our canonical test structure:

```
GutTest (from addon/gut/test.gd)
└── BaseTest (from tests/fixtures/base/base_test.gd)
    └── GameTest (from tests/fixtures/base/game_test.gd)
        ├── UITest (from tests/fixtures/specialized/ui_test.gd)
        ├── BattleTest (from tests/fixtures/specialized/battle_test.gd)
        ├── CampaignTest (from tests/fixtures/specialized/campaign_test.gd)
        ├── MobileTest (from tests/fixtures/specialized/mobile_test.gd)
        └── EnemyTest (from tests/fixtures/specialized/enemy_test.gd)
```

## Naming Conventions

The following naming conventions have been standardized:

1. **Base Classes**:
   - Use descriptive names without suffixes (BaseTest, GameTest)
   - Must include class_name declarations

2. **Specialized Classes**:
   - Use domain name + Test pattern (UITest, BattleTest)
   - Must include class_name declarations

3. **Test Files**:
   - Use test_[feature].gd pattern (test_enemy.gd, test_ui_component.gd)
   - Should be named after the feature they test, not the class

## File Organization

1. **Base Classes**:
   - Located in `tests/fixtures/base/`
   - Provide core testing functionality

2. **Specialized Classes**:
   - Located in `tests/fixtures/specialized/`
   - Provide domain-specific testing functionality

3. **Test Files**:
   - Unit tests in `tests/unit/[domain]/`
   - Integration tests in `tests/integration/[domain]/`
   - Performance tests in `tests/performance/[domain]/`
   - Mobile tests in `tests/mobile/[domain]/`

## Extension Rules

Tests MUST extend from the appropriate specialized class based on the domain:

1. UI-focused tests must extend UITest
2. Battle-focused tests must extend BattleTest
3. Campaign-focused tests must extend CampaignTest
4. Mobile-specific tests must extend MobileTest
5. Enemy-focused tests must extend EnemyTest
6. Generic game tests can extend GameTest directly

## Extension Syntax

All test files MUST use class_name-based extension:

```gdscript
@tool
extends BattleTest  # Instead of "res://tests/fixtures/specialized/battle_test.gd"
```

## Implementation Timeline

These standards will be implemented according to the following timeline:

1. Documentation Updates (Completed)
2. Base Class Reorganization
3. Specialized Class Standardization
4. Test File Updates
5. Final Verification

## Migration Guidelines

When migrating existing tests to the new standard:

1. Update the extends statement to use the appropriate specialized class
2. Ensure proper super.before_each() and super.after_each() calls
3. Refactor to use type-safe methods from the specialized class
4. Update test docs to reflect the new standard

## Decision Rationale

This architecture was chosen to:

1. Provide clear specialization for different test domains
2. Ensure proper inheritance of common functionality
3. Standardize naming and organization
4. Simplify test authoring through domain-specific helpers
5. Support future extensibility 