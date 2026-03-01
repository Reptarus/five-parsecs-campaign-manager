#!/usr/bin/env python3
"""
Five Parsecs File Analysis and Consolidation Planner
Analyzes the 514 files and creates a consolidation roadmap
"""

import os
import json
from pathlib import Path
from collections import defaultdict

def analyze_gdscript_files(src_path):
    """Analyze all GDScript files for consolidation opportunities"""
    
    file_analysis = {
        "managers": [],
        "coordinators": [],
        "enhanced_classes": [],
        "small_files": [],  # < 50 lines
        "duplicate_functionality": defaultdict(list),
        "ui_fragments": [],
        "data_classes": [],
        "test_stubs": []
    }
    
    for root, dirs, files in os.walk(src_path):
        for file in files:
            if file.endswith('.gd'):
                filepath = os.path.join(root, file)
                analyze_single_file(filepath, file_analysis)
    
    return file_analysis

def analyze_single_file(filepath, analysis):
    """Categorize individual files for consolidation"""
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        lines = content.split('\n')
        line_count = len(lines)
        
        # Check for forbidden patterns
        if 'Manager' in filepath or 'extends.*Manager' in content:
            analysis['managers'].append({
                'path': filepath,
                'lines': line_count,
                'consolidate_into': suggest_consolidation_target(filepath)
            })
        
        if 'Coordinator' in filepath:
            analysis['coordinators'].append(filepath)
            
        if 'Enhanced' in filepath or 'Advanced' in filepath:
            analysis['enhanced_classes'].append(filepath)
        
        # Small files that should be merged
        if line_count < 50:
            analysis['small_files'].append({
                'path': filepath,
                'lines': line_count
            })
        
        # Test stubs without implementation
        if 'func test_' in content and line_count < 10:
            analysis['test_stubs'].append(filepath)
            
        # UI fragments that could be merged
        if '/ui/' in filepath and line_count < 100:
            analysis['ui_fragments'].append(filepath)

def suggest_consolidation_target(filepath):
    """Suggest where to consolidate a file"""
    
    # Manager consolidation rules
    if 'CharacterManager' in filepath:
        return 'src/core/character/Character.gd'
    elif 'CampaignManager' in filepath:
        return 'src/core/campaign/Campaign.gd'
    elif 'BattleManager' in filepath:
        return 'src/core/battle/BattleSystem.gd'
    elif 'EquipmentManager' in filepath:
        return 'src/core/equipment/Equipment.gd'
    elif 'WorldManager' in filepath:
        return 'src/core/world/WorldGeneration.gd'
    else:
        return 'src/core/GameState.gd'  # Fallback

def create_consolidation_plan(analysis):
    """Create actionable consolidation plan"""
    
    plan = {
        "immediate_deletions": [],
        "merge_operations": [],
        "refactor_targets": [],
        "estimated_final_count": 0
    }
    
    # Delete test stubs and empty files
    plan['immediate_deletions'].extend(analysis['test_stubs'])
    
    # Merge small files
    for small_file in analysis['small_files']:
        if small_file['lines'] < 20:
            plan['immediate_deletions'].append(small_file['path'])
        else:
            # Find appropriate merge target
            plan['merge_operations'].append({
                'source': small_file['path'],
                'target': find_merge_target(small_file['path']),
                'lines': small_file['lines']
            })
    
    # Refactor managers
    for manager in analysis['managers']:
        plan['refactor_targets'].append(manager)
    
    # Calculate estimated final file count
    current_count = 514
    deletions = len(plan['immediate_deletions'])
    merges = len(plan['merge_operations'])
    
    plan['estimated_final_count'] = current_count - deletions - merges
    
    return plan

def find_merge_target(filepath):
    """Find the best file to merge into"""
    
    # UI consolidation
    if '/panels/' in filepath:
        return 'src/ui/screens/CampaignCreationUI.gd'
    elif '/dialogs/' in filepath:
        return 'src/ui/DialogManager.gd'
    elif '/components/' in filepath:
        return 'src/ui/UIComponents.gd'
    
    # Core consolidation
    elif '/character/' in filepath:
        return 'src/core/character/Character.gd'
    elif '/battle/' in filepath:
        return 'src/core/battle/BattleSystem.gd'
    elif '/world/' in filepath:
        return 'src/core/world/WorldGeneration.gd'
    
    # Default to appropriate core file
    else:
        return 'src/core/GameState.gd'

if __name__ == "__main__":
    src_path = r"C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\src"
    
    print("Analyzing 514 GDScript files...")
    analysis = analyze_gdscript_files(src_path)
    
    print("\nCreating consolidation plan...")
    plan = create_consolidation_plan(analysis)
    
    print("\n" + "="*60)
    print("CONSOLIDATION PLAN SUMMARY")
    print("="*60)
    print(f"Current files: 514")
    print(f"Files to delete: {len(plan['immediate_deletions'])}")
    print(f"Files to merge: {len(plan['merge_operations'])}")
    print(f"Managers to refactor: {len(plan['refactor_targets'])}")
    print(f"Estimated final count: {plan['estimated_final_count']}")
    print("="*60)
    
    # Save detailed plan
    with open('consolidation_plan.json', 'w') as f:
        json.dump(plan, f, indent=2)
    
    print("\nDetailed plan saved to consolidation_plan.json")
