# Master Consolidation Plan

## Overview

This document outlines the master plan for consolidating duplicate files and refactoring the codebase to align with our project's architecture goals. The plan addresses duplicates between the `src/core` and `src/game` directories, with a focus on maintaining backward compatibility while improving code organization.

## Goals

1. Eliminate duplicate files between `src/core` and `src/game` directories
2. Establish clear inheritance hierarchies
3. Separate UI components from core logic
4. Improve code organization and maintainability
5. Ensure backward compatibility with existing save data
6. Maintain or improve test coverage

## Identified Areas for Consolidation

1. **World System** - Files related to planets, locations, and world management
2. **Campaign System** - Files related to campaign management, battle phases, and crew
3. **Combat System** - Files related to combat mechanics and battle management
4. **Character System** - Files related to character creation and management
5. **Item System** - Files related to items, equipment, and inventory
6. **Mission System** - Files related to mission generation and management

## Consolidation Approach

### Phase 1: Analysis and Planning (Completed)
1. Identify duplicate files and their relationships
2. Determine the canonical version of each file
3. Create detailed consolidation plans for each system
4. Establish testing strategies

### Phase 2: World System Consolidation (In Progress)
1. Follow the plan in `world_files_consolidation.md`
2. Estimated timeline: 6-8 days

### Phase 3: Campaign System Consolidation
1. Follow the plan in `campaign_files_consolidation.md`
2. Estimated timeline: 10-14 days

### Phase 4: Combat System Consolidation
1. Create a detailed plan for combat system consolidation
2. Implement the plan
3. Estimated timeline: 8-10 days

### Phase 5: Character System Consolidation
1. Create a detailed plan for character system consolidation
2. Implement the plan
3. Estimated timeline: 6-8 days

### Phase 6: Item System Consolidation
1. Create a detailed plan for item system consolidation
2. Implement the plan
3. Estimated timeline: 4-6 days

### Phase 7: Mission System Consolidation
1. Create a detailed plan for mission system consolidation
2. Implement the plan
3. Estimated timeline: 6-8 days

### Phase 8: Final Integration and Testing
1. Ensure all systems work together correctly
2. Verify backward compatibility
3. Update documentation
4. Estimated timeline: 5-7 days

## Architecture Principles

### 1. Clear Separation of Concerns
- UI components should be separate from core logic
- Data models should be separate from controllers
- Game-specific logic should extend base classes

### 2. Consistent Inheritance Hierarchy
- Base classes in `src/base` directory
- Game-specific implementations in `src/game` directory
- UI components in `src/ui` directory

### 3. Proper Use of Composition
- Use composition over inheritance where appropriate
- Implement interfaces for common functionality
- Use dependency injection for better testability

### 4. Backward Compatibility
- Maintain compatibility with existing save data
- Provide migration utilities for data format changes
- Add deprecation warnings for transitional code

## Testing Strategy

### 1. Unit Testing
- Maintain or improve test coverage
- Create tests for each consolidated class
- Verify that all functionality is preserved

### 2. Integration Testing
- Test the interaction between systems
- Verify that all systems work together correctly
- Test with various game scenarios

### 3. Backward Compatibility Testing
- Test with existing save data
- Verify that migration utilities work correctly
- Test with various data formats

## Timeline

- **Phase 1**: Completed
- **Phase 2**: Weeks 1-2
- **Phase 3**: Weeks 3-5
- **Phase 4**: Weeks 6-7
- **Phase 5**: Weeks 8-9
- **Phase 6**: Weeks 10-11
- **Phase 7**: Weeks 12-13
- **Phase 8**: Weeks 14-15

Total estimated time: 15 weeks

## Risk Management

### 1. Scope Creep
- Stick to the consolidation plan
- Avoid adding new features during consolidation
- Focus on maintaining existing functionality

### 2. Backward Compatibility
- Thoroughly test with existing save data
- Implement migration utilities early
- Add deprecation warnings for transitional code

### 3. Testing Coverage
- Maintain or improve test coverage
- Create tests for each consolidated class
- Verify that all functionality is preserved

### 4. Timeline Slippage
- Monitor progress regularly
- Adjust timeline as needed
- Consider breaking down phases into smaller tasks

## Conclusion

This master consolidation plan provides a roadmap for eliminating duplicate files and improving code organization. By following this plan, we will create a more maintainable codebase that aligns with our project's architecture goals while ensuring backward compatibility with existing save data. 