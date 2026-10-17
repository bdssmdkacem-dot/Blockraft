#!/bin/bash
set -e
cd "$(dirname "$0")"
echo "Restoring scripts/player.gd from last known good commit..."
curl -fsSL "https://raw.githubusercontent.com/bdssmdkacem-dot/Blockraft/1e1604f3eecfdb1cbf197efc2ca2d4445bf519f6/scripts/player.gd" -o scripts/player.gd
BYTES=$(wc -c < scripts/player.gd | tr -d ' ')
echo "player.gd size: $BYTES bytes (expected ~23420)"
if [ "$BYTES" -lt 20000 ]; then
  echo "ERROR: file too small - restore failed"
  exit 1
fi
echo "OK. Commit and push:"
echo "  git add scripts/player.gd"
echo "  git commit -m \"Restore player.gd - fix blue void\""
echo "  git push origin main"
