#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

char g_Error[255];
Database g_MySQL = null;

int g_ServerPort;
char g_ServerName[128];
char g_Map[64];
char g_Host[64];

public Plugin myinfo = {
    name = "OSServerInfo",
    author = "Pintuz",
    description = "OldSwedes Server Info plugin (OSBase schema)",
    version = "0.03",
    url = "https://github.com/Pintuzoft/OSServerInfo"
};

public void OnPluginStart() {
    GetConVarString(FindConVar("hostname"), g_ServerName, sizeof(g_ServerName));
    g_ServerPort = GetConVarInt(FindConVar("hostport"));
    g_Host[0] = '\0';

    LoadConfig();
    DatabaseConnect();
}

public void OnMapStart() {
    char currentHostname[128];
    int currentHostPort;

    GetConVarString(FindConVar("hostname"), currentHostname, sizeof(currentHostname));
    currentHostPort = GetConVarInt(FindConVar("hostport"));
    GetCurrentMap(g_Map, sizeof(g_Map));

    if (g_ServerName[0] == '\0') {
        strcopy(g_ServerName, sizeof(g_ServerName), currentHostname);
    }

    if (g_ServerPort <= 0) {
        g_ServerPort = currentHostPort;
    }

    SaveServerInfo();
    ClearUsers();
    AddPlayers();
}

public void OnClientPutInServer(int client) {
    char name[128];

    if (!PlayerIsReal(client)) {
        return;
    }

    GetClientName(client, name, sizeof(name));
    ConnectPlayer(name);
}

public void OnClientDisconnect(int client) {
    char name[128];

    if (!PlayerIsReal(client)) {
        return;
    }

    GetClientName(client, name, sizeof(name));
    DisconnectPlayer(name);
}

public void LoadConfig() {
    char path[PLATFORM_MAX_PATH];

    BuildPath(Path_SM, path, sizeof(path), "configs/osserverinfo.cfg");

    if (!FileExists(path)) {
        PrintToServer("[OSServerInfo]: Config file not found: %s", path);
        PrintToServer("[OSServerInfo]: Falling back to hostname/hostport where possible.");
        return;
    }

    File file = OpenFile(path, "r");

    if (file == null) {
        PrintToServer("[OSServerInfo]: Failed to open config file: %s", path);
        return;
    }

    char line[256];
    while (!file.EndOfFile() && file.ReadLine(line, sizeof(line))) {
        TrimString(line);

        if (line[0] == '\0') {
            continue;
        }

        if (StrContains(line, "//") == 0) {
            continue;
        }

        char key[64];
        char value[192];
        key[0] = '\0';
        value[0] = '\0';

        int firstSpace = FindCharInString(line, ' ');
        if (firstSpace == -1) {
            continue;
        }

        strcopy(key, sizeof(key), line);
        key[firstSpace] = '\0';
        TrimString(key);

        int valueStart = firstSpace + 1;
        while (line[valueStart] == ' ' || line[valueStart] == '\t') {
            valueStart++;
        }

        strcopy(value, sizeof(value), line[valueStart]);
        TrimString(value);
        StripQuotes(value);

        if (StrEqual(key, "name", false)) {
            strcopy(g_ServerName, sizeof(g_ServerName), value);
        } else if (StrEqual(key, "host", false)) {
            strcopy(g_Host, sizeof(g_Host), value);
        } else if (StrEqual(key, "port", false)) {
            g_ServerPort = StringToInt(value);
        } else {
            PrintToServer("[OSServerInfo]: Unknown config key: %s", key);
        }
    }

    delete file;

    if (g_ServerName[0] == '\0') {
        GetConVarString(FindConVar("hostname"), g_ServerName, sizeof(g_ServerName));
    }

    if (g_ServerPort <= 0) {
        g_ServerPort = GetConVarInt(FindConVar("hostport"));
    }

    if (g_Host[0] == '\0') {
        PrintToServer("[OSServerInfo]: WARNING - host is empty in configs/osserverinfo.cfg");
    }

    PrintToServer("[OSServerInfo]: Config loaded. host=%s port=%d name=%s", g_Host, g_ServerPort, g_ServerName);
}

public void DatabaseConnect() {
    if ((g_MySQL = SQL_Connect("osbase", true, g_Error, sizeof(g_Error))) != null) {
        PrintToServer("[OSServerInfo]: Connected to mysql database!");
    } else {
        PrintToServer("[OSServerInfo]: Failed to connect to mysql database! (error: %s)", g_Error);
    }
}

public void CheckConnection() {
    if (g_MySQL == null) {
        DatabaseConnect();
    }
}

public void SaveServerInfo() {
    if (g_Host[0] == '\0') {
        PrintToServer("[OSServerInfo]: Cannot save serverinfo, host is empty.");
        return;
    }

    CheckConnection();

    DBStatement stmt = SQL_PrepareQuery(
        g_MySQL,
        "INSERT INTO serverinfo_server (port, host, name, map, timestamp) "
        ... "VALUES (?, ?, ?, ?, UNIX_TIMESTAMP()) "
        ... "ON DUPLICATE KEY UPDATE name = ?, map = ?, timestamp = UNIX_TIMESTAMP()",
        g_Error,
        sizeof(g_Error)
    );

    if (stmt == null) {
        SQL_GetError(g_MySQL, g_Error, sizeof(g_Error));
        PrintToServer("[OSServerInfo]: Failed to prepare query[0x01] (error: %s)", g_Error);
        return;
    }

    SQL_BindParamInt(stmt, 0, g_ServerPort);
    SQL_BindParamString(stmt, 1, g_Host, false);
    SQL_BindParamString(stmt, 2, g_ServerName, false);
    SQL_BindParamString(stmt, 3, g_Map, false);
    SQL_BindParamString(stmt, 4, g_ServerName, false);
    SQL_BindParamString(stmt, 5, g_Map, false);

    if (!SQL_Execute(stmt)) {
        SQL_GetError(g_MySQL, g_Error, sizeof(g_Error));
        PrintToServer("[OSServerInfo]: Failed to query[0x02] (error: %s)", g_Error);
    }

    delete stmt;
}

public void ConnectPlayer(const char[] name) {
    if (g_Host[0] == '\0') {
        return;
    }

    CheckConnection();

    DBStatement stmt = SQL_PrepareQuery(
        g_MySQL,
        "INSERT INTO serverinfo_user (host, port, name, team, kills, assists, deaths) "
        ... "VALUES (?, ?, ?, 0, 0, 0, 0) "
        ... "ON DUPLICATE KEY UPDATE name = ?",
        g_Error,
        sizeof(g_Error)
    );

    if (stmt == null) {
        SQL_GetError(g_MySQL, g_Error, sizeof(g_Error));
        PrintToServer("[OSServerInfo]: Failed to prepare query[0x03] (error: %s)", g_Error);
        return;
    }

    SQL_BindParamString(stmt, 0, g_Host, false);
    SQL_BindParamInt(stmt, 1, g_ServerPort);
    SQL_BindParamString(stmt, 2, name, false);
    SQL_BindParamString(stmt, 3, name, false);

    if (!SQL_Execute(stmt)) {
        SQL_GetError(g_MySQL, g_Error, sizeof(g_Error));
        PrintToServer("[OSServerInfo]: Failed to query[0x04] (error: %s)", g_Error);
    }

    delete stmt;
}

public void DisconnectPlayer(const char[] name) {
    if (g_Host[0] == '\0') {
        return;
    }

    CheckConnection();

    DBStatement stmt = SQL_PrepareQuery(
        g_MySQL,
        "DELETE FROM serverinfo_user WHERE host = ? AND port = ? AND name = ?",
        g_Error,
        sizeof(g_Error)
    );

    if (stmt == null) {
        SQL_GetError(g_MySQL, g_Error, sizeof(g_Error));
        PrintToServer("[OSServerInfo]: Failed to prepare query[0x05] (error: %s)", g_Error);
        return;
    }

    SQL_BindParamString(stmt, 0, g_Host, false);
    SQL_BindParamInt(stmt, 1, g_ServerPort);
    SQL_BindParamString(stmt, 2, name, false);

    if (!SQL_Execute(stmt)) {
        SQL_GetError(g_MySQL, g_Error, sizeof(g_Error));
        PrintToServer("[OSServerInfo]: Failed to query[0x06] (error: %s)", g_Error);
    }

    delete stmt;
}

public void ClearUsers() {
    if (g_Host[0] == '\0') {
        return;
    }

    CheckConnection();

    DBStatement stmt = SQL_PrepareQuery(
        g_MySQL,
        "DELETE FROM serverinfo_user WHERE host = ? AND port = ?",
        g_Error,
        sizeof(g_Error)
    );

    if (stmt == null) {
        SQL_GetError(g_MySQL, g_Error, sizeof(g_Error));
        PrintToServer("[OSServerInfo]: Failed to prepare query[0x07] (error: %s)", g_Error);
        return;
    }

    SQL_BindParamString(stmt, 0, g_Host, false);
    SQL_BindParamInt(stmt, 1, g_ServerPort);

    if (!SQL_Execute(stmt)) {
        SQL_GetError(g_MySQL, g_Error, sizeof(g_Error));
        PrintToServer("[OSServerInfo]: Failed to query[0x08] (error: %s)", g_Error);
    }

    delete stmt;
}

public void AddPlayers() {
    for (int player = 1; player <= MaxClients; player++) {
        if (PlayerIsReal(player)) {
            char name[128];
            GetClientName(player, name, sizeof(name));
            ConnectPlayer(name);
        }
    }
}

public bool PlayerIsReal(int player) {
    return (
        player > 0 &&
        player <= MaxClients &&
        IsClientInGame(player) &&
        !IsFakeClient(player) &&
        !IsClientSourceTV(player)
    );
}