#!/bin/bash
set -e
echo "Restoring Blockraft player.gd and main_menu.gd..."
curl -fsSL "https://raw.githubusercontent.com/bdssmdkacem-dot/Blockraft/1e1604f3eecfdb1cbf197efc2ca2d4445bf519f6/scripts/player.gd" -o scripts/player.gd
curl -fsSL "https://raw.githubusercontent.com/bdssmdkacem-dot/Blockraft/1e1604f3eecfdb1cbf197efc2ca2d4445bf519f6/scripts/main_menu.gd" -o scripts/main_menu.gd
wc -c scripts/player.gd scripts/main_menu.gd
echo "OK - commit and push:"
echo "  git add scripts/player.gd scripts/main_menu.gd"
echo "  git commit -m \"Restore player and main menu\""
echo "  git push origin main"
