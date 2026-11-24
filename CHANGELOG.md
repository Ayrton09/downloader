# Changelog

## 1.2.0

- Checked the download, model precache and sound precache tables before adding a file. A full table now skips the remaining files and logs it, instead of stopping the server with `Host_Error: PrecacheModel overflow` or failing silently.
- Added `sm_downloader_reserve` (default 10) to keep a percent of each table free for the map, the game and other plugins.
- Loaded `downloads.txt` in `OnConfigsExecuted`, after other plugins' `OnMapStart` precaches and after `downloader.cfg` is executed.
- Added a model only when the download table has room for the model and all of its companions.
- Rejected server-side folders (`addons`, `bin`, `cfg`, `download`, `downloadlists`, `logs`, `save`) in `downloads.txt`.
- Never offered server-side file types: configs, databases, plugins, binaries and keys.
- Skipped hidden files, `Thumbs.db`, `desktop.ini`, `.bz2` copies, temporary files and backups found in listed folders.
- Precached `.MDL`, `.MP3` and `.WAV` files regardless of extension casing.
- Added `.ani` to the model companion files.
- Added model companions in a listed folder together with their `.mdl`.
- Accepted file names containing `..`, such as `skin..v2.vmt`. Only `.` and `..` path segments are rejected, as well as segments ending in a dot or a space.
- Supported comments after a path, starting with whitespace and `//`.
- Accepted paths of up to 255 characters on the last line of the file.
- Reported rejected lines with their line number, and the processed and skipped file counts after each load.
- Set read-only permissions and pinned action versions in the compile workflow.

## 1.1.0

- Rejected paths that resolve to the game folder root, which previously added every server file to the download table.
- Limited directory recursion to 16 levels to stop symlink loops.
- Fixed path casing resolution being skipped on case-insensitive filesystems.
- Accepted trailing slashes, duplicate slashes and `.` segments in `downloads.txt` instead of reporting them as missing paths.
- Cached resolved path segments so repeated directory lookups are done once per load.
- Made the `sound/` prefix check case-insensitive so precaching still runs on corrected casing.
- Skipped and reported lines longer than the path buffer instead of processing the remainder as a separate entry.
- Ignored a UTF-8 byte order mark at the start of `downloads.txt`.
- Added `AutoExecConfig` so ConVars persist in `cfg/sourcemod/downloader.cfg`.
- Reported in `sm_reload_downloads` that connected players keep their previous list.

## 1.0.0

- Initial public release.
- Added recursive file and directory processing.
- Added downloads table registration.
- Added model precache support.
- Added automatic model companion file registration.
- Added sound precache support for files under `sound/`.
- Added path normalization for backslashes.
- Added support for paths with spaces.
- Added disk-based path casing resolution.
- Added reload admin command and debug ConVar.
