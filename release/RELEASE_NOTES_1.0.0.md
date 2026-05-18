# Downloader 1.0.0

Initial release for SourceMod-supported Source engine game servers.

## Install

Extract `downloader-1.0.0.zip` into the game server root.

## Included Files

```text
addons/sourcemod/plugins/downloader.smx
addons/sourcemod/scripting/downloader.sp
addons/sourcemod/configs/downloader/downloads.txt
```

## Notes

- Edit `addons/sourcemod/configs/downloader/downloads.txt` to list files or directories.
- Use `sm_reload_downloads` to reload the list during a map.
- Use `sm_downloader_debug 1` to print each processed file.
