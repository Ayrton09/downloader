#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.2.0"
#define MAX_DIRECTORY_DEPTH 16
#define LINE_BUFFER_SIZE 1024

// Top-level folders that hold server-side files only. A downloads.txt entry
// below any of them is rejected.
static const char g_sBlockedRoots[][] =
{
    "addons",
    "bin",
    "cfg",
    "download",
    "downloadlists",
    "logs",
    "save"
};

// Server-side or sensitive file types that are never offered to clients.
static const char g_sBlockedExtensions[][] =
{
    ".bat",
    ".cfg",
    ".db",
    ".dll",
    ".dylib",
    ".exe",
    ".inc",
    ".ini",
    ".key",
    ".log",
    ".pem",
    ".sh",
    ".smx",
    ".so",
    ".sp",
    ".sq3",
    ".sql",
    ".sqlite",
    ".sqlite3",
    ".vdf"
};

// Compressed FastDL copies, temporary files and backups left next to content.
static const char g_sJunkExtensions[][] =
{
    ".bak",
    ".bz2",
    ".orig",
    ".part",
    ".tmp",
    ".ztmp"
};

// Longer suffixes first, so ".dx90.vtx" is matched before ".vtx".
static const char g_sModelCompanions[][] =
{
    ".sw.vtx",
    ".dx80.vtx",
    ".dx90.vtx",
    ".xbox.vtx",
    ".vtx",
    ".vvd",
    ".phy",
    ".ani"
};

enum SkipReason
{
    Skip_None,
    Skip_Blocked,
    Skip_Junk
};

ConVar g_cvDebug;
ConVar g_cvReserve;
StringMap g_smProcessed;
StringMap g_smResolved;

int g_iDownloadsTable = INVALID_STRING_TABLE;
int g_iModelTable = INVALID_STRING_TABLE;
int g_iSoundTable = INVALID_STRING_TABLE;

bool g_bDownloadsFullReported;
bool g_bModelsFullReported;
bool g_bSoundsFullReported;

int g_iSkippedBlocked;
int g_iSkippedJunk;
int g_iSkippedFull;

public Plugin myinfo =
{
    name = "Downloader",
    author = "Ayrton09",
    description = "Recursive download table loader with SourceMod precache support",
    version = PLUGIN_VERSION,
    url = "https://github.com/Ayrton09/downloader"
};

public void OnPluginStart()
{
    RegAdminCmd("sm_reload_downloads", Command_ReloadDownloads, ADMFLAG_CONFIG, "Reloads downloads.txt");
    g_cvDebug = CreateConVar("sm_downloader_debug", "0", "1 = Prints every processed and skipped file to the server console.", _, true, 0.0, true, 1.0);
    g_cvReserve = CreateConVar("sm_downloader_reserve", "10", "Percent of each engine table (downloads, models, sounds) kept free for the map, the game and other plugins.", _, true, 0.0, true, 50.0);
    AutoExecConfig(true, "downloader");

    g_smProcessed = new StringMap();
    g_smResolved = new StringMap();
}

// Runs after every plugin's OnMapStart, so their precaches are already counted
// when the free room in each table is measured, and after downloader.cfg.
public void OnConfigsExecuted()
{
    LoadDownloads();
}

public Action Command_ReloadDownloads(int client, int args)
{
    int total = LoadDownloads();
    ReplyToCommand(client, "[SM] Download list reloaded. Processed files: %d. Skipped: %d blocked, %d junk, %d over engine limits.",
        total, g_iSkippedBlocked, g_iSkippedJunk, g_iSkippedFull);
    ReplyToCommand(client, "[SM] Players already connected keep the previous list until the next map change.");
    return Plugin_Handled;
}

int LoadDownloads()
{
    g_smProcessed.Clear();
    g_smResolved.Clear();

    g_iDownloadsTable = FindStringTable("downloadables");
    g_iModelTable = FindStringTable("modelprecache");
    g_iSoundTable = FindStringTable("soundprecache");

    g_bDownloadsFullReported = false;
    g_bModelsFullReported = false;
    g_bSoundsFullReported = false;

    g_iSkippedBlocked = 0;
    g_iSkippedJunk = 0;
    g_iSkippedFull = 0;

    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/downloader/downloads.txt");

    if (!FileExists(configPath))
    {
        LogError("[Downloader] File not found: %s", configPath);
        return 0;
    }

    File file = OpenFile(configPath, "r");
    if (file == null)
    {
        LogError("[Downloader] Could not open: %s", configPath);
        return 0;
    }

    int total;
    int lineNumber;
    char line[LINE_BUFFER_SIZE];
    char resolvedPath[PLATFORM_MAX_PATH];

    while (!file.EndOfFile() && file.ReadLine(line, sizeof(line)))
    {
        lineNumber++;

        if (IsTruncatedLine(line, sizeof(line)))
        {
            LogError("[Downloader] Line %d is longer than %d characters, skipped.", lineNumber, sizeof(line) - 1);
            SkipRestOfLine(file);
            continue;
        }

        if (lineNumber == 1)
        {
            StripUTF8BOM(line, sizeof(line));
        }

        StripInlineComment(line);
        TrimString(line);

        if (IsIgnoredLine(line))
        {
            continue;
        }

        NormalizeDownloadPath(line, sizeof(line));

        if (strlen(line) >= PLATFORM_MAX_PATH)
        {
            LogError("[Downloader] Line %d: path longer than %d characters, skipped.", lineNumber, PLATFORM_MAX_PATH - 1);
            continue;
        }

        if (!IsValidRelativePath(line))
        {
            LogError("[Downloader] Line %d: invalid path: %s", lineNumber, line);
            continue;
        }

        if (IsBlockedRoot(line))
        {
            LogError("[Downloader] Line %d: server-side folder, not offered to clients: %s", lineNumber, line);
            continue;
        }

        if (!ResolvePathCasing(line, resolvedPath, sizeof(resolvedPath)))
        {
            LogError("[Downloader] Line %d: path does not exist: %s", lineNumber, line);
            continue;
        }

        if (!StrEqual(line, resolvedPath))
        {
            LogMessage("[Downloader] Corrected path casing: %s -> %s", line, resolvedPath);
        }

        if (DirExists(resolvedPath))
        {
            total += ProcessDirectory(resolvedPath, 1);
        }
        else if (FileExists(resolvedPath))
        {
            total += ValidateAndProcessFile(resolvedPath, lineNumber);
        }
        else
        {
            LogError("[Downloader] Line %d: resolved path is not a file or directory: %s", lineNumber, resolvedPath);
        }
    }

    delete file;

    LogMessage("[Downloader] Processed files: %d. Skipped: %d blocked, %d junk, %d over engine limits.",
        total, g_iSkippedBlocked, g_iSkippedJunk, g_iSkippedFull);

    if ((g_iSkippedBlocked > 0 || g_iSkippedJunk > 0) && !g_cvDebug.BoolValue)
    {
        LogMessage("[Downloader] Set sm_downloader_debug 1 to list every skipped file.");
    }

    return total;
}

int ProcessDirectory(const char[] dir, int depth)
{
    if (depth > MAX_DIRECTORY_DEPTH)
    {
        LogError("[Downloader] Maximum depth of %d directories reached, not descending into: %s", MAX_DIRECTORY_DEPTH, dir);
        return 0;
    }

    DirectoryListing listing = OpenDirectory(dir);
    if (listing == null)
    {
        LogError("[Downloader] Could not open directory: %s", dir);
        return 0;
    }

    int total;
    FileType type;
    char entry[PLATFORM_MAX_PATH];
    char fullPath[PLATFORM_MAX_PATH];

    while (listing.GetNext(entry, sizeof(entry), type))
    {
        if (StrEqual(entry, ".") || StrEqual(entry, ".."))
        {
            continue;
        }

        Format(fullPath, sizeof(fullPath), "%s/%s", dir, entry);

        if (type == FileType_Directory)
        {
            total += ProcessDirectory(fullPath, depth + 1);
        }
        else if (type == FileType_File)
        {
            total += ValidateAndProcessFile(fullPath, 0);
        }
    }

    delete listing;
    return total;
}

// lineNumber is the downloads.txt line that lists the file, or 0 when the
// file was found while walking a listed directory.
int ValidateAndProcessFile(const char[] path, int lineNumber)
{
    if (g_smProcessed.ContainsKey(path))
    {
        return 0;
    }

    SkipReason reason = GetSkipReason(path);
    if (reason != Skip_None)
    {
        ReportSkipped(path, reason, lineNumber);
        return 0;
    }

    // Companions of a model in the same folder are added together with the
    // .mdl, so the model and its files are either all added or all skipped.
    if (lineNumber == 0 && IsCompanionOfExistingModel(path))
    {
        return 0;
    }

    if (!FileExists(path))
    {
        LogError("[Downloader] File not found: %s", path);
        return 0;
    }

    if (HasExtension(path, ".mdl"))
    {
        return ProcessModel(path);
    }

    if (HasExtension(path, ".mp3") || HasExtension(path, ".wav"))
    {
        return ProcessSound(path);
    }

    return AddDownload(path) ? 1 : 0;
}

int ProcessModel(const char[] path)
{
    if (NeedsTableSlot(g_iModelTable, path) && GetTableRoom(g_iModelTable) < 1)
    {
        ReportTableFull("modelprecache", g_iModelTable, g_bModelsFullReported, path);
        return 0;
    }

    int needed = NeedsTableSlot(g_iDownloadsTable, path) ? 1 : 0;
    needed += CountPendingCompanions(path);

    if (needed > GetTableRoom(g_iDownloadsTable))
    {
        ReportTableFull("downloadables", g_iDownloadsTable, g_bDownloadsFullReported, path);
        return 0;
    }

    if (!AddDownload(path))
    {
        return 0;
    }

    PrecacheModel(path, true);
    return 1 + AddModelCompanionFiles(path);
}

int ProcessSound(const char[] path)
{
    char soundPath[PLATFORM_MAX_PATH];
    if (!GetSoundPath(path, soundPath, sizeof(soundPath)))
    {
        return AddDownload(path) ? 1 : 0;
    }

    if (NeedsTableSlot(g_iSoundTable, soundPath) && GetTableRoom(g_iSoundTable) < 1)
    {
        ReportTableFull("soundprecache", g_iSoundTable, g_bSoundsFullReported, path);
        return 0;
    }

    if (!AddDownload(path))
    {
        return 0;
    }

    PrecacheSound(soundPath, true);
    return 1;
}

bool AddDownload(const char[] path)
{
    if (g_smProcessed.ContainsKey(path))
    {
        return false;
    }

    if (NeedsTableSlot(g_iDownloadsTable, path) && GetTableRoom(g_iDownloadsTable) < 1)
    {
        ReportTableFull("downloadables", g_iDownloadsTable, g_bDownloadsFullReported, path);
        return false;
    }

    g_smProcessed.SetValue(path, true);

    if (g_cvDebug.BoolValue)
    {
        PrintToServer("[Downloader] Adding download: %s", path);
    }

    AddFileToDownloadsTable(path);
    return true;
}

int AddModelCompanionFiles(const char[] modelPath)
{
    int total;
    char path[PLATFORM_MAX_PATH];

    for (int i = 0; i < sizeof(g_sModelCompanions); i++)
    {
        if (BuildCompanionPath(modelPath, g_sModelCompanions[i], path, sizeof(path))
            && FileExists(path)
            && AddDownload(path))
        {
            total++;
        }
    }

    return total;
}

int CountPendingCompanions(const char[] modelPath)
{
    int count;
    char path[PLATFORM_MAX_PATH];

    for (int i = 0; i < sizeof(g_sModelCompanions); i++)
    {
        if (BuildCompanionPath(modelPath, g_sModelCompanions[i], path, sizeof(path))
            && !g_smProcessed.ContainsKey(path)
            && FileExists(path)
            && NeedsTableSlot(g_iDownloadsTable, path))
        {
            count++;
        }
    }

    return count;
}

bool BuildCompanionPath(const char[] modelPath, const char[] suffix, char[] path, int maxlen)
{
    int dot = FindCharInString(modelPath, '.', true);
    if (dot == -1)
    {
        return false;
    }

    strcopy(path, maxlen, modelPath);
    path[dot] = '\0';
    StrCat(path, maxlen, suffix);
    return true;
}

bool IsCompanionOfExistingModel(const char[] path)
{
    char modelPath[PLATFORM_MAX_PATH];

    for (int i = 0; i < sizeof(g_sModelCompanions); i++)
    {
        int baseLength = strlen(path) - strlen(g_sModelCompanions[i]);
        if (baseLength <= 0 || !StrEqual(path[baseLength], g_sModelCompanions[i], false))
        {
            continue;
        }

        strcopy(modelPath, sizeof(modelPath), path);
        modelPath[baseLength] = '\0';
        StrCat(modelPath, sizeof(modelPath), ".mdl");

        if (FileExists(modelPath))
        {
            return true;
        }

        modelPath[baseLength] = '\0';
        StrCat(modelPath, sizeof(modelPath), ".MDL");
        return FileExists(modelPath);
    }

    return false;
}

bool GetSoundPath(const char[] path, char[] soundPath, int maxlen)
{
    if (!StartsWith(path, "sound/", false))
    {
        LogError("[Downloader] Sound not precached; it must be under sound/: %s", path);
        return false;
    }

    strcopy(soundPath, maxlen, path[6]);

    if (soundPath[0] == '\0')
    {
        LogError("[Downloader] Empty sound path: %s", path);
        return false;
    }

    return true;
}

bool NeedsTableSlot(int table, const char[] value)
{
    return table != INVALID_STRING_TABLE && FindStringIndex(table, value) == INVALID_STRING_INDEX;
}

int GetTableRoom(int table)
{
    if (table == INVALID_STRING_TABLE)
    {
        return cellmax;
    }

    int room = GetStringTableMaxStrings(table) - GetTableReserve(table) - GetStringTableNumStrings(table);
    return room > 0 ? room : 0;
}

int GetTableReserve(int table)
{
    return GetStringTableMaxStrings(table) * g_cvReserve.IntValue / 100;
}

void ReportTableFull(const char[] name, int table, bool &reported, const char[] path)
{
    g_iSkippedFull++;

    if (reported)
    {
        return;
    }

    reported = true;
    LogError("[Downloader] Engine table \"%s\" reached its limit (%d of %d entries used, %d kept free by sm_downloader_reserve). %s and every further file that needs it were skipped. Narrow downloads.txt.",
        name, GetStringTableNumStrings(table), GetStringTableMaxStrings(table), GetTableReserve(table), path);
}

SkipReason GetSkipReason(const char[] path)
{
    int slash = FindCharInString(path, '/', true);
    int nameStart = slash + 1;

    if (path[nameStart] == '.')
    {
        return Skip_Junk;
    }

    if (StrEqual(path[nameStart], "Thumbs.db", false) || StrEqual(path[nameStart], "desktop.ini", false))
    {
        return Skip_Junk;
    }

    for (int i = 0; i < sizeof(g_sJunkExtensions); i++)
    {
        if (HasExtension(path, g_sJunkExtensions[i]))
        {
            return Skip_Junk;
        }
    }

    for (int i = 0; i < sizeof(g_sBlockedExtensions); i++)
    {
        if (HasExtension(path, g_sBlockedExtensions[i]))
        {
            return Skip_Blocked;
        }
    }

    return Skip_None;
}

void ReportSkipped(const char[] path, SkipReason reason, int lineNumber)
{
    if (reason == Skip_Blocked)
    {
        g_iSkippedBlocked++;
    }
    else
    {
        g_iSkippedJunk++;
    }

    if (lineNumber > 0)
    {
        LogError("[Downloader] Line %d: %s, not offered to clients: %s",
            lineNumber, reason == Skip_Blocked ? "server-side file type" : "not a client file", path);
    }
    else if (g_cvDebug.BoolValue)
    {
        PrintToServer("[Downloader] Skipping %s file: %s", reason == Skip_Blocked ? "blocked" : "junk", path);
    }
}

bool IsBlockedRoot(const char[] path)
{
    char root[PLATFORM_MAX_PATH];
    strcopy(root, sizeof(root), path);

    int slash = FindCharInString(root, '/');
    if (slash != -1)
    {
        root[slash] = '\0';
    }

    for (int i = 0; i < sizeof(g_sBlockedRoots); i++)
    {
        if (StrEqual(root, g_sBlockedRoots[i], false))
        {
            return true;
        }
    }

    return false;
}

bool IsIgnoredLine(const char[] line)
{
    return line[0] == '\0'
        || line[0] == '#'
        || line[0] == ';'
        || (line[0] == '/' && line[1] == '/');
}

// "path // note" keeps "path". A "//" with no whitespace before it is part of
// the path and is normalized to a single slash later.
void StripInlineComment(char[] line)
{
    if (line[0] == '\0')
    {
        return;
    }

    for (int i = 1; line[i] != '\0'; i++)
    {
        if (line[i] == '/' && line[i + 1] == '/' && (line[i - 1] == ' ' || line[i - 1] == '\t'))
        {
            line[i] = '\0';
            return;
        }
    }
}

bool IsValidRelativePath(const char[] path)
{
    return path[0] != '\0'
        && path[0] != '/'
        && path[0] != '\\'
        && FindCharInString(path, ':') == -1
        && !HasInvalidSegment(path);
}

// Rejects "." and ".." segments and segments ending in a dot or a space,
// which Windows would silently resolve to a different name.
bool HasInvalidSegment(const char[] path)
{
    int start;
    int i;

    for (i = 0; path[i] != '\0'; i++)
    {
        if (path[i] != '/')
        {
            continue;
        }

        if (IsInvalidSegment(path, start, i))
        {
            return true;
        }

        start = i + 1;
    }

    return IsInvalidSegment(path, start, i);
}

bool IsInvalidSegment(const char[] path, int start, int end)
{
    if (end <= start)
    {
        return true;
    }

    char last = path[end - 1];
    return last == '.' || last == ' ';
}

void NormalizeDownloadPath(char[] path, int maxlen)
{
    ReplaceString(path, maxlen, "\\", "/", false);

    while (ReplaceString(path, maxlen, "//", "/", false) > 0)
    {
    }

    while (ReplaceString(path, maxlen, "/./", "/", false) > 0)
    {
    }

    if (path[0] == '.' && path[1] == '/')
    {
        strcopy(path, maxlen, path[2]);
    }

    int length = strlen(path);
    while (length > 1)
    {
        if (path[length - 1] == '/')
        {
            path[--length] = '\0';
            continue;
        }

        if (path[length - 1] == '.' && path[length - 2] == '/')
        {
            length -= 2;
            path[length] = '\0';
            continue;
        }

        break;
    }
}

bool IsTruncatedLine(const char[] line, int maxlen)
{
    return strlen(line) == maxlen - 1 && StrContains(line, "\n") == -1;
}

void SkipRestOfLine(File file)
{
    char chunk[LINE_BUFFER_SIZE];

    while (!file.EndOfFile() && file.ReadLine(chunk, sizeof(chunk)))
    {
        if (StrContains(chunk, "\n") != -1)
        {
            return;
        }
    }
}

void StripUTF8BOM(char[] line, int maxlen)
{
    if ((line[0] & 0xFF) == 0xEF && (line[1] & 0xFF) == 0xBB && (line[2] & 0xFF) == 0xBF)
    {
        strcopy(line, maxlen, line[3]);
    }
}

bool ResolvePathCasing(const char[] path, char[] resolvedPath, int maxlen)
{
    char remaining[PLATFORM_MAX_PATH];
    char segment[PLATFORM_MAX_PATH];
    char current[PLATFORM_MAX_PATH];
    char parent[PLATFORM_MAX_PATH];

    strcopy(remaining, sizeof(remaining), path);
    parent[0] = '\0';

    int split;
    while ((split = SplitString(remaining, "/", segment, sizeof(segment))) != -1)
    {
        if (segment[0] == '\0' || !ResolvePathSegment(parent, segment, current, sizeof(current)))
        {
            return false;
        }

        strcopy(parent, sizeof(parent), current);
        strcopy(remaining, sizeof(remaining), remaining[split]);
    }

    if (remaining[0] == '\0' || !ResolvePathSegment(parent, remaining, current, sizeof(current)))
    {
        return false;
    }

    strcopy(resolvedPath, maxlen, current);
    return true;
}

bool ResolvePathSegment(const char[] parent, const char[] segment, char[] resolvedPath, int maxlen)
{
    char exactPath[PLATFORM_MAX_PATH];
    BuildChildPath(parent, segment, exactPath, sizeof(exactPath));

    if (g_smResolved.GetString(exactPath, resolvedPath, maxlen))
    {
        return resolvedPath[0] != '\0';
    }

    char match[PLATFORM_MAX_PATH];
    if (!FindDirectoryEntry(parent, segment, match, sizeof(match)))
    {
        if (!FileExists(exactPath) && !DirExists(exactPath))
        {
            g_smResolved.SetString(exactPath, "");
            return false;
        }

        strcopy(match, sizeof(match), segment);
    }

    BuildChildPath(parent, match, resolvedPath, maxlen);
    g_smResolved.SetString(exactPath, resolvedPath);
    return true;
}

bool FindDirectoryEntry(const char[] parent, const char[] segment, char[] match, int maxlen)
{
    char openPath[PLATFORM_MAX_PATH];
    if (parent[0] == '\0')
    {
        strcopy(openPath, sizeof(openPath), ".");
    }
    else
    {
        strcopy(openPath, sizeof(openPath), parent);
    }

    DirectoryListing listing = OpenDirectory(openPath);
    if (listing == null)
    {
        return false;
    }

    bool found;
    FileType type;
    char entry[PLATFORM_MAX_PATH];

    while (listing.GetNext(entry, sizeof(entry), type))
    {
        if (StrEqual(entry, ".") || StrEqual(entry, ".."))
        {
            continue;
        }

        if (StrEqual(entry, segment))
        {
            strcopy(match, maxlen, entry);
            found = true;
            break;
        }

        if (!found && StrEqual(entry, segment, false))
        {
            strcopy(match, maxlen, entry);
            found = true;
        }
    }

    delete listing;
    return found;
}

void BuildChildPath(const char[] parent, const char[] child, char[] path, int maxlen)
{
    if (parent[0] == '\0')
    {
        strcopy(path, maxlen, child);
        return;
    }

    Format(path, maxlen, "%s/%s", parent, child);
}

bool HasExtension(const char[] path, const char[] extension)
{
    int dot = FindCharInString(path, '.', true);
    if (dot == -1)
    {
        return false;
    }

    return StrEqual(path[dot], extension, false);
}

bool StartsWith(const char[] text, const char[] prefix, bool caseSensitive = true)
{
    int length = strlen(prefix);
    return strncmp(text, prefix, length, caseSensitive) == 0;
}
