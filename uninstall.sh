#!/usr/bin/env bash

set -euo pipefail

RESTART_NAUTILUS=1

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [--no-restart]

Removes this project's thumbnailer override and restores GNOME's default
thumbnail cache settings. Existing thumbnail images are left intact.
EOF
}

while (($#)); do
    case "$1" in
        --no-restart) RESTART_NAUTILUS=0 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Error: unknown option: %s\n' "$1" >&2; exit 1 ;;
    esac
    shift
done

((EUID != 0)) || { printf 'Error: run this as your desktop user, not as root\n' >&2; exit 1; }

data_home=${XDG_DATA_HOME:-$HOME/.local/share}
override_file=$data_home/thumbnailers/gst-video-thumbnailer.thumbnailer

if [[ -f "$override_file" ]] && head -n 1 "$override_file" | grep -Fxq '# Installed by nautilus-thumbnail-optimizer'; then
    rm -f "$override_file"
    printf 'Removed %s\n' "$override_file"
elif [[ -e "$override_file" ]]; then
    printf 'Left unrecognized override untouched: %s\n' "$override_file"
fi

schema=org.gnome.desktop.thumbnail-cache
if command -v gsettings >/dev/null 2>&1 && gsettings list-schemas | grep -Fx "$schema" >/dev/null; then
    gsettings reset "$schema" maximum-size
    gsettings reset "$schema" maximum-age
fi

if ((RESTART_NAUTILUS)); then
    nautilus -q 2>/dev/null || true
    printf 'Nautilus was stopped; reopen Files to start a fresh process.\n'
fi

printf 'Uninstall complete. Existing thumbnail cache files were preserved.\n'
