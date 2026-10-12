#!/usr/bin/env bash

set -euo pipefail

CACHE_SIZE_MIB=2048
CACHE_AGE_DAYS=3650
RESTART_NAUTILUS=1
INSTALL_PACKAGE=1

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Options:
  --cache-size MIB   Global GNOME thumbnail cache limit (default: 2048)
  --cache-age DAYS   Thumbnail retention period (default: 3650)
  --no-restart       Do not stop a running Nautilus process
  --no-install       Fail instead of installing a missing ffmpegthumbnailer package
  -h, --help         Show this help
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_positive_integer() {
    local label=$1 value=$2
    [[ "$value" =~ ^[1-9][0-9]*$ ]] || die "$label must be a positive integer"
}

while (($#)); do
    case "$1" in
        --cache-size)
            (($# >= 2)) || die '--cache-size requires a value'
            CACHE_SIZE_MIB=$2
            shift 2
            ;;
        --cache-age)
            (($# >= 2)) || die '--cache-age requires a value'
            CACHE_AGE_DAYS=$2
            shift 2
            ;;
        --no-restart)
            RESTART_NAUTILUS=0
            shift
            ;;
        --no-install)
            INSTALL_PACKAGE=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

require_positive_integer 'cache size' "$CACHE_SIZE_MIB"
require_positive_integer 'cache age' "$CACHE_AGE_DAYS"

((EUID != 0)) || die 'run this as your desktop user, not as root'

if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == fedora ]] || die 'this installer supports Fedora only'
else
    die 'cannot identify the operating system'
fi

command -v gsettings >/dev/null 2>&1 || die 'gsettings is missing; install a Fedora Workstation GNOME session'

if ! command -v ffmpegthumbnailer >/dev/null 2>&1; then
    ((INSTALL_PACKAGE)) || die 'ffmpegthumbnailer is not installed'
    command -v sudo >/dev/null 2>&1 || die 'sudo is required to install ffmpegthumbnailer'
    sudo dnf install -y ffmpegthumbnailer
fi

schema=org.gnome.desktop.thumbnail-cache
gsettings list-schemas | grep -Fx "$schema" >/dev/null || die "GNOME schema is unavailable: $schema"

system_gst=/usr/share/thumbnailers/gst-video-thumbnailer.thumbnailer
system_ffmpeg=/usr/share/thumbnailers/ffmpegthumbnailer.thumbnailer
mime_types=''
for thumbnailer_file in "$system_gst" "$system_ffmpeg"; do
    if [[ -r "$thumbnailer_file" ]]; then
        mime_types=$(sed -n 's/^MimeType=//p' "$thumbnailer_file" | head -n 1)
        [[ -n "$mime_types" ]] && break
    fi
done
[[ -n "$mime_types" ]] || die 'could not discover installed video MIME types'

data_home=${XDG_DATA_HOME:-$HOME/.local/share}
override_dir=$data_home/thumbnailers
override_file=$override_dir/gst-video-thumbnailer.thumbnailer
mkdir -p "$override_dir"

if [[ -e "$override_file" ]]; then
    backup_file="${override_file}.bak.$(date +%Y%m%d-%H%M%S)"
    cp --preserve=mode,timestamps "$override_file" "$backup_file"
    printf 'Backed up existing override to %s\n' "$backup_file"
fi

temporary_file=$(mktemp "$override_dir/.gst-video-thumbnailer.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT
{
    printf '%s\n' '# Installed by nautilus-thumbnail-optimizer'
    printf '%s\n' '[Thumbnailer Entry]'
    printf '%s\n' 'TryExec=/usr/bin/ffmpegthumbnailer'
    printf '%s\n' 'Exec=/usr/bin/ffmpegthumbnailer -i %i -o %o -s %s -f'
    printf 'MimeType=%s\n' "$mime_types"
} >"$temporary_file"
chmod 0644 "$temporary_file"
mv -f "$temporary_file" "$override_file"
trap - EXIT

gsettings set "$schema" maximum-size "$CACHE_SIZE_MIB"
gsettings set "$schema" maximum-age "$CACHE_AGE_DAYS"

if ((RESTART_NAUTILUS)); then
    pkill -u "$UID" -f '^/usr/bin/gst-video-thumbnailer( |$)' 2>/dev/null || true
    nautilus -q 2>/dev/null || true
fi

printf '\nInstalled Nautilus thumbnail optimization.\n'
printf 'Video thumbnailer: /usr/bin/ffmpegthumbnailer\n'
printf 'Global cache limit: %s MiB\n' "$CACHE_SIZE_MIB"
printf 'Global cache retention: %s days\n' "$CACHE_AGE_DAYS"
if ((RESTART_NAUTILUS)); then
    printf 'Nautilus was stopped; reopen Files to start a fresh process.\n'
else
    printf 'Restart Nautilus later for the thumbnailer override to take effect.\n'
fi
