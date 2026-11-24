# Downloader

[![Release](https://img.shields.io/github/v/release/Ayrton09/downloader?label=release&color=blue)](https://github.com/Ayrton09/downloader/releases/latest)
[![Compile](https://github.com/Ayrton09/downloader/actions/workflows/compile.yml/badge.svg)](https://github.com/Ayrton09/downloader/actions/workflows/compile.yml)
[![Downloads](https://img.shields.io/github/downloads/Ayrton09/downloader/total?color=brightgreen)](https://github.com/Ayrton09/downloader/releases)
![SourceMod](https://img.shields.io/badge/SourceMod-1.12%2B-orange)
![Game](https://img.shields.io/badge/game-Source%20engine-orange)
[![License](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

Recursive download and precache manager for SourceMod servers. List files and folders in one text file, and on every map start the plugin adds them to the download table and precaches models and sounds.

**[Download the latest release](https://github.com/Ayrton09/downloader/releases/latest)** · [Installation](#installation) · [Configuration](#configuration) · [Commands](#commands) · [Limits](#engine-limits)

---

## Features

- Recursively processes folders listed in `configs/downloader/downloads.txt`.
- Adds files to the engine download table.
- Precaches `.mdl` models and `.mp3` / `.wav` sounds under `sound/`, with any extension casing.
- Adds model companion files together with each model: `.sw.vtx`, `.dx80.vtx`, `.dx90.vtx`, `.xbox.vtx`, `.vtx`, `.vvd`, `.phy` and `.ani`.
- Never overflows the engine tables: it keeps a configurable share of the download, model and sound tables free, and when its share is used up the remaining files are skipped and the error log says so, instead of the server stopping with `Host_Error`.
- Keeps server files private: server-side folders and file types are rejected, so a broad entry cannot hand out databases or configs.
- Skips leftovers in content folders: hidden files, `Thumbs.db`, `desktop.ini`, `.bz2` FastDL copies, temporary files and backups.
- Resolves file and folder casing from disk, accepts backslashes, spaces, duplicate slashes and `.` segments.
- Reports every rejected line with its line number.

## Requirements

- SourceMod 1.12 or newer.
- Any Source engine game supported by SourceMod.

## Installation

1. Download `downloader-X.Y.Z.zip` from the [latest release](https://github.com/Ayrton09/downloader/releases/latest).
2. Extract it into the game folder (for Counter-Strike: Source, `cstrike/`).
3. List your content in `addons/sourcemod/configs/downloader/downloads.txt`.
4. Restart the server or change the map.

Installed files:

```text
addons/sourcemod/plugins/downloader.smx
addons/sourcemod/scripting/downloader.sp
addons/sourcemod/configs/downloader/downloads.txt
```

The plugin only registers files in the engine download table. Clients fetch them from `sv_downloadurl` when a FastDL host is configured, or from the game server itself while `sv_allowdownload` is enabled. Upload the same files (or their `.bz2` copies) to your FastDL host.

## Configuration

Each line of `downloads.txt` is a file or folder path relative to the game folder.

```text
// Comments start with //, # or ;
sound/umbrella/gol.mp3
sound/umbrella/goal sound.mp3   // a " //" after a path is a comment
models\player\custom_skin\model.mdl
models/player/custom_skin
materials/models/player/custom_skin
```

- **Folders** are processed recursively, up to 16 nested levels.
- **Models** listed on their own line bring their companion files with them. Inside a folder, companions are added together with their `.mdl`.
- **Casing** is resolved from disk: `materials/vgui/entities` becomes `materials/VGUI/entities` if that is the real folder name.
- **List the narrowest folder** that holds your custom content. Every file below a listed folder takes a slot in the engine download table.

### What is rejected

| Rejected | Examples | Why |
| --- | --- | --- |
| Absolute paths, drive letters, `.` and `..` segments | `/home/srcds`, `C:\srcds`, `../x` | Paths must stay inside the game folder. |
| The game folder root | `.`, `./` | Would offer every server file. |
| Server-side folders | `addons`, `bin`, `cfg`, `download`, `downloadlists`, `logs`, `save` | Hold server files only. |
| Server-side file types | `.cfg`, `.ini`, `.vdf`, `.log`, `.sq3`, `.sqlite`, `.db`, `.sql`, `.smx`, `.sp`, `.inc`, `.dll`, `.so`, `.exe`, `.key`, `.pem` | Configs, databases, plugins, binaries and keys. |
| Leftovers | hidden files, `Thumbs.db`, `desktop.ini`, `.bz2`, `.ztmp`, `.tmp`, `.bak`, `.orig`, `.part` | Not game content. |

A rejected line is written to the SourceMod error log. Files skipped inside a folder are counted in the load summary; set `sm_downloader_debug 1` to list them.

## Commands

| Command | Access | Description |
| --- | --- | --- |
| `sm_reload_downloads` | `ADMFLAG_CONFIG` | Reloads `downloads.txt` and prints how many files were processed and skipped. |

Clients only download while connecting, so players already on the server keep the list they joined with, and removed entries stay in the engine tables until the map changes. A reload applies additions for players connecting next; change the map to apply the list in full.

## ConVars

| ConVar | Default | Description |
| --- | --- | --- |
| `sm_downloader_debug` | `0` | `1` prints every added and skipped file to the server console. |
| `sm_downloader_reserve` | `10` | Percent of each engine table (downloads, models, sounds) kept free for the map, the game and other plugins. Range `0` to `50`. |

ConVars are written to `cfg/sourcemod/downloader.cfg` on first run.

## Engine limits

The plugin has no file limit of its own. The engine tables are the limit; in Counter-Strike: Source they hold 8192 downloads, 4096 precached models and 16384 precached sounds, shared with the map and every other plugin.

The list is loaded in `OnConfigsExecuted`, after every plugin's `OnMapStart`, so their downloads and precaches are already counted. A share of each table is still kept free with `sm_downloader_reserve` (10% by default: 819 downloads, 409 models and 1638 sounds in Counter-Strike: Source), because the game and other plugins keep precaching after the load, and a full precache table stops the server.

Before adding a file, the plugin checks that the table it needs has room outside that reserve. A model is added only when the download table has room for the model and all of its companions, and the model precache table has a free slot. When a table reaches its limit, the first skipped file is written to the error log and the rest are counted in the load summary.

## Building

```text
spcomp -i <sourcemod>/addons/sourcemod/scripting/include addons/sourcemod/scripting/downloader.sp
```

Every push is compiled by GitHub Actions against the latest SourceMod 1.12 build with warnings treated as errors. Release builds are compiled with SourceMod 1.12.0-git7260.

## License

Released under the GNU General Public License v3.0 or later. See [LICENSE](LICENSE).
