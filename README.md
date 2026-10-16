# Nautilus thumbnail optimizer for Fedora

Nautilus can become sluggish or unresponsive in directories containing thousands of videos. Two common causes are:

- `gst-video-thumbnailer` hanging indefinitely on an otherwise readable video
- GNOME's default 512 MiB thumbnail cache repeatedly evicting and rebuilding previews

This installer redirects GNOME video-thumbnail requests to `ffmpegthumbnailer`, raises the global thumbnail-cache limit to 2 GiB, and retains thumbnails for ten years by default.

## Supported system

- Fedora Workstation with GNOME and Nautilus
- A regular desktop user with `sudo` access when `ffmpegthumbnailer` is not installed

The script intentionally refuses to run as root because GNOME settings and thumbnailer overrides belong to the desktop user.

## Install

```bash
git clone https://github.com/mjdelro/nautilus-thumbnail-optimizer.git
cd nautilus-thumbnail-optimizer
./install.sh
```

If needed, the installer uses `sudo dnf install -y ffmpegthumbnailer`. It then stops Nautilus so the new thumbnailer configuration is loaded the next time Files opens.

## Options

```text
--cache-size MIB   Global GNOME thumbnail cache limit (default: 2048)
--cache-age DAYS   Thumbnail retention period (default: 3650)
--no-restart       Do not stop a running Nautilus process
--no-install       Fail instead of installing a missing package
```

Example with a 4 GiB cache and one-year retention:

```bash
./install.sh --cache-size 4096 --cache-age 365
```

## What changes

The installer creates:

```text
~/.local/share/thumbnailers/gst-video-thumbnailer.thumbnailer
```

That user-level entry takes precedence over Fedora's GStreamer thumbnailer and invokes:

```text
/usr/bin/ffmpegthumbnailer -i %i -o %o -s %s -f
```

It also changes these global settings for the current GNOME user:

```text
org.gnome.desktop.thumbnail-cache maximum-size 2048
org.gnome.desktop.thumbnail-cache maximum-age 3650
```

The size limit covers the user's entire GNOME thumbnail cache, not a single directory. Existing override files are timestamped and backed up before replacement.

## Uninstall

```bash
./uninstall.sh
```

The uninstaller removes only an override marked as belonging to this project and resets GNOME's cache settings to Fedora defaults. It does not delete cached thumbnails or automatic backup files.

## Verify the active thumbnailer

Run the installer, reopen Files, and check that no GStreamer video thumbnailer remains:

```bash
pgrep -af gst-video-thumbnailer
```

No output is expected. `ffmpegthumbnailer` processes are normally brief and may disappear before they can be observed.

## Scope

This reduces hangs and cache churn. A single icon-view directory containing several thousand 512 px thumbnails can still consume substantial memory. Splitting very large collections into subdirectories or using list view remains worthwhile.

