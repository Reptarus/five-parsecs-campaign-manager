# Five Parsecs Campaign Manager Documentation Summary

This document provides an overview of all project documentation, organized by category and relevance.

## Active Documentation

### Project Structure and Standards
- [`updated_project_rules.md`](updated_project_rules.md) - Current project standards and organization
- [`architecture.md`](architecture.md) - Architectural overview and design decisions
- [`documentation_consolidation_report.md`](documentation_consolidation_report.md) - Report on documentation consolidation efforts

### Implementation Plans and Status
- [`current_project_status.md`](current_project_status.md) - Current project status and forward path (March 2024)
- [`action_plan.md`](action_plan.md) - Current implementation plan
- [`application_purpose.md`](application_purpose.md) - Application goals and purpose

### System Integration
- [`world_system_integration_plan.md`](world_system_integration_plan.md) - Plan for world system integration
- [`phase_implementation.md`](phase_implementation.md) - Implementation of game phases
- [`world_gen_migration.md`](world_gen_migration.md) - Migration plan for world generation systems

### Consolidation Plans
- [`consolidation_plan/master_consolidation_plan.md`](consolidation_plan/master_consolidation_plan.md) - Master plan for consolidation
- [`consolidation_plan/campaign_files_consolidation.md`](consolidation_plan/campaign_files_consolidation.md) - Plan for campaign file consolidation
- [`consolidation_plan/world_files_consolidation.md`](consolidation_plan/world_files_consolidation.md) - Plan for world file consolidation

### Reference Documentation
- [`core_rules.md`](core_rules.md) - Essential reference for game mechanics
- [`compendium.md`](compendium.md) - Important game data reference
- [`core_scripts_reference.md`](core_scripts_reference.md) - Reference for key scripts

### Script Management
- [`class_name_conflicts_fix.md`](class_name_conflicts_fix.md) - Instructions for fixing class name conflicts and script reference management
- [`class_name_registry.md`](class_name_registry.md) - Registry of class names

### Testing Framework Documentation
- [`gut_plugin_fixes.md`](gut_plugin_fixes.md) - Fixes for GUT plugin compatibility with Godot 4.4
- [`test_architecture_decisions.md`](test_architecture_decisions.md) - **UPDATED** Comprehensive test architecture documentation including organization and patterns
- [`test_callable_patterns.md`](test_callable_patterns.md) - Patterns for working with callables in tests
- [`test_file_extends_fix.md`](test_file_extends_fix.md) - **UPDATED** Complete guide for migrating test files and fixing common issues
- [`test_safety_patterns.md`](test_safety_patterns.md) - Patterns for safe testing and resource handling
- [`test_coverage_report.md`](test_coverage_report.md) - Test coverage summary

## Documentation Standards

All documentation should follow these standards:

1. Use Markdown format with proper headers, lists, and code blocks
2. Include a brief description at the top
3. Organize content with clear section headers
4. Use relative links to reference other documentation files
5. Keep documentation up-to-date with code changes
6. Include last-updated date at the top of each document

## Testing Documentation Map

The following documentation covers our testing framework:

1. **Core Testing Architecture**: [`test_architecture_decisions.md`](test_architecture_decisions.md)
   - Hierarchical structure of test classes
   - Directory organization
   - Base class selection guide
   - Test method organization
   - Common design patterns

2. **Test Migration Guide**: [`test_file_extends_fix.md`](test_file_extends_fix.md)
   - Converting class name references to file paths
   - Best practices for resource handling
   - Fixing common anti-patterns
   - Automated tools for test migration
   - Common errors and solutions

3. **Callable Patterns**: [`test_callable_patterns.md`](test_callable_patterns.md)
   - Working with callables in tests
   - Safe script creation
   - Avoiding serialization errors
   - Type-safe callable checking

4. **Safety Patterns**: [`test_safety_patterns.md`](test_safety_patterns.md)
   - Resource path safety
   - Resource tracking
   - Safe serialization
   - Safe deserialization
   - Dictionary and method safety

5. **GUT Plugin Fixes**: [`gut_plugin_fixes.md`](gut_plugin_fixes.md)
   - Godot 4.4 compatibility issues
   - inst_to_dict handling
   - Dictionary access method changes
   - Method call patterns

6. **Coverage Status**: [`test_coverage_report.md`](test_coverage_report.md)
   - Current test coverage metrics
   - Priority areas for improvement
   - Test stability status

## Documentation Consolidation (Updated March 2024)
- ✅ Created this summary document as a central index
- ✅ Archived completed/obsolete documentation
- ✅ Renamed files to follow consistent naming conventions
- ✅ Updated references to archived documents
- ✅ Standardized documentation format
- ✅ Consolidated testing documentation into fewer, more comprehensive files
- ✅ Removed redundant documentation after consolidation 