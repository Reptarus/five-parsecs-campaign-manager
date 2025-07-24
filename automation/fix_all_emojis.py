#!/usr/bin/env python3
"""
Comprehensive fix script to remove Unicode emojis from all automation scripts
"""

import os

# Define emoji replacements
emoji_replacements = {
    '🧪': '[TEST]',
    '✅': '[OK]',
    '❌': '[FAIL]',
    '📦': '[INSTALL]',
    'ℹ️': '[INFO]',
    '🧹': '[CLEANUP]',
    '📋': '[LIST]',
    '📊': '[STATUS]',
    '🔧': '[CONFIG]',
    '🔍': '[VALIDATE]',
    '💥': '[CRASH]',
    '⏭️': '[SKIP]',
    '⚙️': '[SETTINGS]',
    '🔌': '[DEACTIVATED]',
    '📝': '[FIXING]',
    '🎯': '[TARGET]',
    '\u2705': '[COMPLETE]',
    '\u26a1': '[PERFORMANCE]',
    '⚡': '[PERFORMANCE]',
    '🚀': '[STARTING]',
    '🎉': '[SUCCESS]',
    '🛡️': '[GUARDIAN]',
    '🎲': '[DICE]',
    '🎬': '[SCENE]',
    '🏗️': '[BUILDING]',
    '📁': '[FOLDER]',
    '🎮': '[GAME]',
    '💡': '[TIP]',
    '🔗': '[LINK]',
    '📈': '[METRICS]',
    '🔥': '[HOT]',
    '⭐': '[STAR]',
    '🚨': '[CRITICAL]',
    '🧠': '[MEMORY]',
    '🎨': '[RENDERING]',
    '📐': '[COMPLEXITY]',
    '🛠️': '[TOOLS]'
}

# Files to fix
files_to_fix = [
    r"C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\automation\performance_monitor.py",
    r"C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\automation\state_guardian.py",
    r"C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\automation\rule_validator.py",
    r"C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\automation\godot_validator.py",
    r"C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\automation\test_runner.py"
]

# Fix each file
for file_path in files_to_fix:
    if os.path.exists(file_path):
        print(f"Fixing emojis in: {os.path.basename(file_path)}")
        
        try:
            # Read the file
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Replace all emojis
            for emoji, replacement in emoji_replacements.items():
                content = content.replace(emoji, replacement)
            
            # Write back to file
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
                
            print(f"  FIXED: {os.path.basename(file_path)}")
            
        except Exception as e:
            print(f"  ERROR fixing {os.path.basename(file_path)}: {e}")
    else:
        print(f"  NOT FOUND: {file_path}")

print("Emoji encoding fix complete for all automation scripts!")
