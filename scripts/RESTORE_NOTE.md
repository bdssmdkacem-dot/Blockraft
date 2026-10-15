# Restore complete files

Run locally:
```bash
# From repo root after git pull
# Files are prepared in the conversation artifacts.
#
# OR recover from commit before wipe:
git fetch origin
git show 1e1604f3:scripts/player.gd > scripts/player.gd
git show 1e1604f3:scripts/main_menu.gd > scripts/main_menu.gd
# Then apply SFX improvements from player_compact if needed
git add scripts/player.gd scripts/main_menu.gd
git commit -m "Restore player and main menu"
git push
```
