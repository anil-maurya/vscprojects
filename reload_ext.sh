
WATCH_DIR="/home/anil/.local/share/gnome-shell/extensions/vscprojects@anil.io"

ls $WATCH_DIR/* | entr -r dbus-run-session -- gnome-shell --nested --wayland
