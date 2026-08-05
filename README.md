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

The plugin only registers files in the engine download table. Clients fetch them from `sv_downloadurl` when a FastDL host is configured, or from the game server itself while `sv_allowdownload` is enabled.

## Configuration

Edit:

```text
addons/sourcemod/configs/downloader/downloads.txt
```

Each line is a file or directory path relative to the game folder. Blank lines are skipped, and lines starting with `#`, `;` or `//` are treated as comments.

File and folder casing is resolved from disk when possible. For example, `materials/vgui/entities` can resolve to `materials/VGUI/entities` if that is the real folder name on the server.

Examples:

```text
sound/umbrella/gol.mp3
sound/umbrella/goal sound.mp3
models\player\custom_skin\model.mdl
models/player/custom skin/model.mdl
models/player/custom_skin
materials/models/player/custom_skin
```

List the narrowest folder that holds your custom content. Every file below a listed folder is offered to clients and takes a slot in the engine string table, so an entry like `cfg` or `addons` adds thousands of files that no client needs. Paths that resolve to the game folder root are rejected outright.

## Commands

```text
sm_reload_downloads
```

Reloads `downloads.txt` and rebuilds the download/precache list for the current map.

Required admin flag: `ADMFLAG_CONFIG`.

Clients only download during connection, so players already on the server keep the list they joined with, and removed entries stay in the engine string table until the map changes. The command applies additions for players connecting next; change the map to apply the list in full.

## ConVars

```text
sm_downloader_debug 0
```

Set to `1` to print each processed file to the server console.

The ConVar is written to `cfg/sourcemod/downloader.cfg` on first run.

## Limits

There is no limit on how many files a load can add. Directory recursion stops after 16 nested levels, which is a safety net against symlink loops rather than a cap on content; real content trees are only a few levels deep. Reaching it is written to the SourceMod error log.

## License

Released under the GNU General Public License v3.0 or later. See [LICENSE](LICENSE).
