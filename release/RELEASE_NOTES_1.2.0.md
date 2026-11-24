# Downloader 1.2.0

Engine limit and server file protection release for SourceMod-supported Source engine game servers.

## Install

Extract `downloader-1.2.0.zip` into the game folder.

## Included Files

```text
addons/sourcemod/plugins/downloader.smx
addons/sourcemod/scripting/downloader.sp
addons/sourcemod/configs/downloader/downloads.txt
```

## Changes

- The download, model precache and sound precache tables are checked before adding a file. A full table skips the remaining files and logs it, instead of stopping the server with `Host_Error: PrecacheModel overflow`.
- New `sm_downloader_reserve` ConVar (default 10) keeps a percent of each table free for the map, the game and other plugins.
- `downloads.txt` is loaded in `OnConfigsExecuted`, after other plugins' `OnMapStart` precaches and after `downloader.cfg` is executed.
- A model is added only when the download table has room for the model and all of its companions.
- Server-side folders (`addons`, `bin`, `cfg`, `download`, `downloadlists`, `logs`, `save`) are rejected in `downloads.txt`.
- Server-side file types (configs, databases, plugins, binaries and keys) are never offered to clients.
- Hidden files, `Thumbs.db`, `desktop.ini`, `.bz2` copies, temporary files and backups in listed folders are skipped.
- `.MDL`, `.MP3` and `.WAV` files are precached regardless of extension casing.
- `.ani` files are added as model companions.
- File names containing `..`, such as `skin..v2.vmt`, are accepted.
- Comments are supported after a path, starting with whitespace and `//`.
- Rejected lines are reported with their line number, and each load logs the processed and skipped file counts.

## Notes

- Edit `addons/sourcemod/configs/downloader/downloads.txt` to list files or folders.
- Use `sm_reload_downloads` to reload the list during a map. Players already connected keep the list they joined with.
- Use `sm_downloader_debug 1` to print every added and skipped file.
- Existing `cfg/sourcemod/downloader.cfg` files do not list the new ConVar; delete the file to regenerate it, or add `sm_downloader_reserve` by hand.
- Built against SourceMod 1.12.0-git7260.
