#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define MAX_DIRECTORY_DEPTH 16

ConVar g_cvDebug;
StringMap g_smProcessed;
StringMap g_smResolved;

public Plugin myinfo =
{
    name = "Downloader",
    author = "Ayrton09",
    description = "Recursive download table loader with SourceMod precache support",
    version = "1.1.0",
    url = "https://github.com/Ayrton09/downloader"
};

public void OnPluginStart()
{
    RegAdminCmd("sm_reload_downloads", Command_ReloadDownloads, ADMFLAG_CONFIG);
    g_cvDebug = CreateConVar("sm_downloader_debug", "0", "1 = Prints every processed file to the server console.", _, true, 0.0, true, 1.0);
    AutoExecConfig(true, "downloader");

    g_smProcessed = new StringMap();
    g_smResolved = new StringMap();
}

public void OnMapStart()
{
    LoadDownloads();
}

public Action Command_ReloadDownloads(int client, int args)
{
    int total = LoadDownloads();
    ReplyToCommand(client, "[SM] Download list reloaded. Processed files: %d.", total);
    ReplyToCommand(client, "[SM] Players already connected keep the previous list until the next map change.");
    return Plugin_Handled;
}

int LoadDownloads()
{
    g_smProcessed.Clear();
    g_smResolved.Clear();

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
    char line[PLATFORM_MAX_PATH];
    char resolvedPath[PLATFORM_MAX_PATH];

    while (!file.EndOfFile() && file.ReadLine(line, sizeof(line)))
    {
        if (IsTruncatedLine(line, sizeof(line)))
        {
            LogError("[Downloader] Line longer than %d characters, skipped.", sizeof(line) - 1);
            SkipRestOfLine(file);
            continue;
        }

        StripUTF8BOM(line, sizeof(line));
        TrimString(line);

        if (IsIgnoredLine(line))
        {
            continue;
        }

        NormalizeDownloadPath(line, sizeof(line));

        if (!IsValidRelativePath(line))
        {
            LogError("[Downloader] Invalid path in downloads.txt: %s", line);
            continue;
        }

        if (!ResolvePathCasing(line, resolvedPath, sizeof(resolvedPath)))
        {
            LogError("[Downloader] Path does not exist: %s", line);
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
            total += ValidateAndProcessFile(resolvedPath);
        }
        else
        {
            LogError("[Downloader] Resolved path is not a file or directory: %s", resolvedPath);
        }
    }

    delete file;
    LogMessage("[Downloader] Processed files: %d", total);
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
            total += ValidateAndProcessFile(fullPath);
        }
    }

    delete listing;
    return total;
}

int ValidateAndProcessFile(const char[] path)
{
    if (!FileExists(path))
    {
        LogError("[Downloader] File not found: %s", path);
        return 0;
    }

    int total = AddDownload(path);
    if (total == 0)
    {
        return 0;
    }

    if (HasExtension(path, ".mdl"))
    {
        PrecacheModel(path, true);
        total += AddModelCompanionFiles(path);
    }
    else if (HasExtension(path, ".mp3") || HasExtension(path, ".wav"))
    {
        PrecacheSoundFile(path);
    }

    return total;
}

int AddDownload(const char[] path)
{
    if (g_smProcessed.ContainsKey(path))
    {
        return 0;
    }

    g_smProcessed.SetValue(path, true);

    if (g_cvDebug.BoolValue)
    {
        PrintToServer("[Downloader] Adding download: %s", path);
    }

    AddFileToDownloadsTable(path);
    return 1;
}

int AddDownloadIfExists(const char[] path)
{
    if (!FileExists(path))
    {
        return 0;
    }

    return AddDownload(path);
}

int AddModelCompanionFiles(const char[] modelPath)
{
    static const char extensions[][] =
    {
        ".sw.vtx",
        ".dx80.vtx",
        ".dx90.vtx",
        ".vtx",
        ".xbox.vtx",
        ".vvd",
        ".phy"
    };

    int dot = FindCharInString(modelPath, '.', true);
    if (dot == -1)
    {
        return 0;
    }

    int total;
    char base[PLATFORM_MAX_PATH];
    char path[PLATFORM_MAX_PATH];

    strcopy(base, sizeof(base), modelPath);
    base[dot] = '\0';

    for (int i = 0; i < sizeof(extensions); i++)
    {
        Format(path, sizeof(path), "%s%s", base, extensions[i]);
        total += AddDownloadIfExists(path);
    }

    return total;
}

void PrecacheSoundFile(const char[] path)
{
    if (!StartsWith(path, "sound/", false))
    {
        LogError("[Downloader] Sound not precached; it must be under sound/: %s", path);
        return;
    }

    char soundPath[PLATFORM_MAX_PATH];
    strcopy(soundPath, sizeof(soundPath), path[6]);

    if (soundPath[0] == '\0')
    {
        LogError("[Downloader] Empty sound path: %s", path);
        return;
    }

    PrecacheSound(soundPath, true);
}

bool IsIgnoredLine(const char[] line)
{
    return line[0] == '\0'
        || line[0] == '#'
        || line[0] == ';'
        || (line[0] == '/' && line[1] == '/');
}

bool IsValidRelativePath(const char[] path)
{
    return path[0] != '\0'
        && path[0] != '/'
        && path[0] != '\\'
        && FindCharInString(path, ':') == -1
        && StrContains(path, "..", false) == -1
        && !HasDotSegment(path);
}

bool HasDotSegment(const char[] path)
{
    int start;
    int i;

    for (i = 0; path[i] != '\0'; i++)
    {
        if (path[i] != '/')
        {
            continue;
        }

        if (i - start == 1 && path[start] == '.')
        {
            return true;
        }

        start = i + 1;
    }

    return i - start == 1 && path[start] == '.';
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
    char chunk[PLATFORM_MAX_PATH];

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

    return StrEqual(path[dot], extension);
}

bool StartsWith(const char[] text, const char[] prefix, bool caseSensitive = true)
{
    int length = strlen(prefix);
    return strncmp(text, prefix, length, caseSensitive) == 0;
}
