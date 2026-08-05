# Downloader

Recursive download and precache manager for SourceMod servers. Loads configured files and folders on map start, adds them to the download table, and precaches supported assets.

## Features

- Recursively processes directories listed in `configs/downloader/downloads.txt`.
- Adds files to the Source engine downloadables table.
- Precaches `.mdl` files.
- Adds existing model companion files automatically:
  - `.sw.vtx`
  - `.dx80.vtx`
  - `.dx90.vtx`
  - `.vtx`
  - `.xbox.vtx`
  - `.vvd`
  - `.phy`
- Precaches `.mp3` and `.wav` files under `sound/`.
- Accepts backslashes in `downloads.txt` and normalizes them to forward slashes internally.
- Normalizes duplicate slashes, trailing slashes, and `.` path segments.
- Accepts spaces in file and folder names.
- Resolves file and folder casing from disk when possible.
- Rejects absolute paths, parent-directory paths, paths with drive letters, and the game folder root itself.

## Requirements

- SourceMod 1.12+

Built and tested against SourceMod 1.12.0-git7246.

## Installation

Copy the `addons` folder into your game server root.

Expected installed files:

```text
addons/sourcemod/plugins/downloader.smx
addons/sourcemod/configs/downloader/downloads.txt
```

## Configuration

Edit:

```text
addons/sourcemod/configs/downloader/downloads.txt
```

Each non-empty line must be a file or directory path relative to the game folder.

File and folder casing is resolved from disk when possible. For example, `materials/vgui/entities` can resolve to `materials/VGUI/entities` if that is the real folder name on the server.

Spaces are supported directly.

Examples:

```text
sound/umbrella/gol.mp3
sound/umbrella/goal sound.mp3
models\player\custom_skin\model.mdl
models/player/custom skin/model.mdl
models/player/custom_skin
materials/models/player/custom_skin
```

List the narrowest folder that holds your custom content. Do not list `.`, `cfg`, or `addons`: every file under a listed folder is added to the download table, which would expose server configuration to clients and overflow the engine string table. Paths that resolve to the game folder root are rejected.

## Limits

Directory recursion stops after 16 nested levels, and each load stops after `sm_downloader_max_files` files. Both limits are safety nets against symlink loops and over-broad entries; normal custom content stays far below them. Reaching either one is written to the SourceMod error log.

## Commands

```text
sm_reload_downloads
```

Reloads `downloads.txt` and rebuilds the download/precache list for the current map.

Required admin flag: `ADMFLAG_CONFIG`.

Players that are already connected keep the list they received when they joined, because clients only download files during connection. Entries removed from `downloads.txt` also stay in the engine string table until the map changes. Use the command to apply additions for players connecting next; change the map to apply the list in full.

## ConVars

```text
sm_downloader_debug 0
```

Set to `1` to print each processed file to the server console.

```text
sm_downloader_max_files 8192
```

Maximum number of files added to the download table per load. Set to `0` for no limit.

Both ConVars are written to `cfg/sourcemod/downloader.cfg` on first run.

## License

Released under the GNU General Public License v3.0 or later. See [LICENSE](LICENSE).
