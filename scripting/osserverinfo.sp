#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <string>

char g_Error[255];
Database g_MySQL = null;

int g_ServerPort;
char g_ServerName[128];
char g_Map[64];
char g_Host[64];

ConVar g_CvarHost;

public Plugin myinfo = {
    name = "OSServerInfo",
    author = "Pintuz",
    description = "OldSwedes Server Info plugin (OSBase schema)",
    version = "0.02",
    url = "https://github.com/Pintuzoft/OSServerInfo"
};

public void OnPluginStart() {
    g_CvarHost = CreateConVar("osserverinfo_host", "csgo.oldswedes.se", "Public hostname for serverinfo");
    
    GetConVarString(FindConVar("hostname"), g_ServerName, sizeof(g_ServerName));
    g_ServerPort = GetConVarInt(FindConVar("hostport"));
    GetConVarString(g_CvarHost, g_Host, sizeof(g_Host));

    DatabaseConnect();
}

public void OnMapStart() {
    GetConVarString(FindConVar("hostname"), g_ServerName, sizeof(g_ServerName));
    g_ServerPort = GetConVarInt(FindConVar("hostport"));
    GetConVarString(g_CvarHost, g_Host, sizeof(g_Host));
    GetCurrentMap(g_Map, sizeof(g_Map));

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