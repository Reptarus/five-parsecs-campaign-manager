#!/usr/bin/env python3
"""
Quick fix script to remove Unicode emojis from hooks_manager.py
"""

import re

# Read the file
with open(r"C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\automation\hooks_manager.py", 'r', encoding='utf-8') as f:
    content = f.read()

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
    '🔌': '[DEACTIVATED]'
}

# Replace all emojis
for emoji, replacement in emoji_replacements.items():
    content = content.replace(emoji, replacement)

# Write back to file
with open(r"C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\automation\hooks_manager.py", 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed all emoji encoding issues in hooks_manager.py")
