# Core Scripts Reference

## Overview
This document provides a reference for core scripts in the Five Parsecs Campaign Manager, including their locations, purposes, and key features.

## State Management

### GameState
- **Location**: `src/core/state/GameState.gd`
- **Purpose**: Manages global game state and campaign data
- **Key Features**:
  - Campaign state management
  - Game settings persistence
  - Resource tracking
  - State validation integration
  - Auto-save functionality
  - Error recovery support

### ValidationManager
- **Location**: `src/core/systems/ValidationManager.gd`
- **Purpose**: Handles comprehensive state validation
- **Key Features**:
  - Validation schemas for all game states
  - Cache management for validation results
  - Warning system with severity levels
  - Context-aware validation
  - Integration with error logging
  - Performance optimization

### ErrorLogger
- **Location**: `src/core/systems/ErrorLogger.gd`
- **Purpose**: Manages error logging and tracking
- **Key Features**:
  - Error severity levels
  - Category-based logging
  - File-based logging
  - Error tracking and resolution
  - Log rotation
  - Summary generation

## Phase Management

### CampaignPhaseManager
- **Location**: `src/core/managers/CampaignPhaseManager.gd`
- **Purpose**: Controls campaign phase transitions
- **Key Features**:
  - Phase state validation
  - Error recovery for phases
  - State rollback capability
  - Phase history management
  - Integration with validation
  - Auto-save triggers

### EventManager
- **Location**: `src/core/managers/EventManager.gd`
- **Purpose**: Manages story and campaign events
- **Key Features**:
  - Event generation
  - Event validation
  - State persistence
  - Error recovery
  - Integration with phases
  - Event history tracking

### DeploymentManager
- **Location**: `src/core/managers/DeploymentManager.gd`
- **Purpose**: Handles battle deployment
- **Key Features**:
  - Deployment zone generation
  - Terrain layout creation
  - State validation
  - Error recovery
  - Integration with battle setup
  - Performance optimization

## UI Components

### ErrorDisplay
- **Location**: `src/ui/ErrorDisplay.gd`
- **Purpose**: Displays validation errors and logs
- **Key Features**:
  - Error filtering by category
  - Severity-based display
  - Error resolution tracking
  - Log export functionality
  - Real-time updates
  - User feedback

### SaveLoadUI
- **Location**: `src/ui/SaveLoadUI.gd`
- **Purpose**: Manages save/load operations
- **Key Features**:
  - Save state validation
  - Error recovery interface
  - Auto-save configuration
  - Backup management
  - Version compatibility
  - Progress tracking

## Performance Monitoring

### PerformanceMonitor
- **Location**: `src/core/systems/PerformanceMonitor.gd`
- **Purpose**: Tracks system performance
- **Key Features**:
  - Phase transition timing
  - Resource usage tracking
  - Validation performance
  - UI responsiveness
  - Memory management
  - Performance reporting

## Testing Framework

### TestRunner
- **Location**: `src/testing/TestRunner.gd`
- **Purpose**: Manages test execution
- **Key Features**:
  - Unit test execution
  - Integration testing
  - State validation tests
  - Performance benchmarks
  - Error scenario testing
  - Test reporting

### StateValidationTests
- **Location**: `src/testing/StateValidationTests.gd`
- **Purpose**: Tests state validation
- **Key Features**:
  - Validation coverage tests
  - Error recovery testing
  - Edge case validation
  - Performance testing
  - Integration verification
  - Test case generation

## Integration Points
- All managers integrate with ValidationManager
- ErrorLogger used across all systems
- PerformanceMonitor tracks all operations
- TestRunner verifies all components
- UI components provide user feedback
- State persistence throughout

## Development Guidelines
1. Use ValidationManager for all state changes
2. Log errors through ErrorLogger
3. Monitor performance with PerformanceMonitor
4. Include tests for new features
5. Maintain error recovery capability
6. Document all validation schemas 