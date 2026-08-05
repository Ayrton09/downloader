# Downloader 1.1.0

Hardening release for SourceMod-supported Source engine game servers.

## Install

Extract `downloader-1.1.0.zip` into the game server root.

## Included Files

```text
addons/sourcemod/plugins/downloader.smx
addons/sourcemod/scripting/downloader.sp
addons/sourcemod/configs/downloader/downloads.txt
```

## Changes

- Paths that resolve to the game folder root are rejected.
- Directory recursion is limited to 16 levels, as a safety net against symlink loops. There is no limit on how many files a load can add.
- Path casing is resolved on case-insensitive filesystems as well.
- Trailing slashes, duplicate slashes and `.` segments are normalized instead of reported as missing paths.
- The `sound/` prefix check is case-insensitive.
- Overlong lines and a UTF-8 byte order mark in `downloads.txt` are handled.
- ConVars persist in `cfg/sourcemod/downloader.cfg`.

## Notes

- Edit `addons/sourcemod/configs/downloader/downloads.txt` to list files or directories.
- Use `sm_reload_downloads` to reload the list during a map. Players already connected keep the list they joined with.
- Use `sm_downloader_debug 1` to print each processed file.
- Built against SourceMod 1.12.0-git7246.
