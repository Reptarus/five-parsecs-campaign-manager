#!/usr/bin/env python3
"""
Quick fix script to remove Unicode emojis from gdscript_linter_fixer.py
"""

import re

# Read the file
with open(r"C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\fixes\gdscript_linter_fixer.py", 'r', encoding='utf-8') as f:
    content = f.read()

# Define emoji replacements
emoji_replacements = {
    '✅': '[OK]',
    '❌': '[FAIL]',
    '📝': '[FIXING]',
    '🎯': '[TARGET]',
    '\u2705': '[COMPLETE]'  # Check mark emoji
}

# Replace all emojis
for emoji, replacement in emoji_replacements.items():
    content = content.replace(emoji, replacement)

# Write back to file
with open(r"C:\Users\elija\SynologyDrive\Godot\five-parsecs-campaign-manager\fixes\gdscript_linter_fixer.py", 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed all emoji encoding issues in gdscript_linter_fixer.py")
