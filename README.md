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
- Rejects absolute paths, parent-directory paths, and paths with drive letters.

## Requirements

- SourceMod 1.12+

## Compatibility

The plugin only uses APIs included with SourceMod, so it is intended for SourceMod-supported Source engine games.

It is currently packaged from a Counter-Strike: Source workspace. Game-specific behavior can still vary by engine branch, especially sound handling.

## Installation

Copy the `addons` folder into your game server root.

Expected installed files:

```text
addons/sourcemod/plugins/downloader.smx
addons/sourcemod/scripting/downloader.sp
addons/sourcemod/configs/downloader/downloads.txt
```

## Configuration

Edit:

```text
addons/sourcemod/configs/downloader/downloads.txt
```

Each non-empty line must be a file or directory path relative to the game folder.

Examples:

```text
sound/umbrella/gol.mp3
models\player\custom_skin\model.mdl
models/player/custom_skin
materials/models/player/custom_skin
```

## Commands

```text
sm_reload_downloads
```

Reloads `downloads.txt` and rebuilds the download/precache list for the current map.

Required admin flag: `ADMFLAG_CONFIG`.

## ConVars

```text
sm_downloader_debug 0
```

Set to `1` to print each processed file to the server console.
