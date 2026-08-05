# Changelog

## 1.1.0

- Rejected paths that resolve to the game folder root, which previously added every server file to the download table.
- Limited directory recursion to 16 levels to stop symlink loops.
- Added `sm_downloader_max_files` to cap how many files a single load can add.
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
