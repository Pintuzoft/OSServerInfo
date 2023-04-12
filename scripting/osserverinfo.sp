#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <string>

char error[255];
Handle mysql = null;

public Plugin myinfo = {
    name = "OSServerInfo",
    author = "Pintuz",
    description = "OldSwedes Server Info plugin",
    version = "0.01",
    url = "https://github.com/Pintuzoft/OSServerInfo"
};

int serverPort;
char serverName[128];
char map[64];

public void OnPluginStart() {
    databaseConnect();
    GetConVarString(FindConVar("hostname"), serverName, sizeof(serverName));
    serverPort = GetConVarInt(FindConVar("hostport"));
    HookEvent("player_disconnect", Event_PlayerDisconnect);
    HookEvent("player_connect", Event_PlayerConnect);
}
public void OnMapStart ( ) {
    GetConVarString(FindConVar("hostname"), serverName, sizeof(serverName));
    GetCurrentMap ( map, sizeof(map) );
    updateServer ( );    
}

public void Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast) {
    int player_id = GetEventInt ( event, "userid" );
    int player = GetClientOfUserId ( player_id );

    PrintToServer ( "Player %d connected", player );
    if ( playerIsReal ( player ) ) {
        PrintToServer ( "Player %d is real", player );
        CreateTimer ( 3.0, handleNewPlayer, player, TIMER_FLAG_NO_MAPCHANGE );
    } else {
        PrintToServer ( "Player %d is fake", player );
    }
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
    int player_id = GetEventInt ( event, "userid" );
    int player = GetClientOfUserId ( player_id );

    if ( playerIsReal ( player ) ) {
        char authid[64];
        GetClientAuthId(player, AuthId_Steam2, authid, sizeof(authid));
        disconnectPlayer ( authid );
    }
}

public Action handleNewPlayer ( Handle timer, int player ) {
    char name[32];
    char authid[64];
    PrintToServer ( " - 0", player );
    GetClientName ( player, name, sizeof(name) );
    PrintToServer ( " - 1", player );
    GetClientAuthId(player, AuthId_Steam2, authid, sizeof(authid));
    PrintToServer ( " - 2", player );
    connectPlayer ( name, authid );
    PrintToServer ( " - 3", player );
    return Plugin_Handled;
}

public void databaseConnect() {
    if ((mysql = SQL_Connect("serverinfo", true, error, sizeof(error))) != null) {
        PrintToServer("[OSServerInfo]: Connected to mysql database!");
    } else {
        PrintToServer("[OSServerInfo]: Failed to connect to mysql database! (error: %s)", error);
    }
}

public void updateServer (  ) {
    checkConnection ( );
    DBStatement stmt;
    if ( ( stmt = SQL_PrepareQuery ( mysql, "insert into server (port,name,map) values (?,?,?) on duplicate key update name = ?, map = ?", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( mysql, error, sizeof(error) );
        PrintToServer("[OSServerInfo]: Failed to prepare query[0x01] (error: %s)", error);
        return;
    }

    SQL_BindParamInt ( stmt, 0, serverPort );
    SQL_BindParamString ( stmt, 1, serverName, false );
    SQL_BindParamString ( stmt, 2, map, false );
    SQL_BindParamString ( stmt, 3, serverName, false );
    SQL_BindParamString ( stmt, 4, map, false );

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( mysql, error, sizeof(error));
        PrintToServer("[OSServerInfo]: Failed to query[0x02] (error: %s)", error);
    }

    if ( stmt != null ) {
        delete stmt;
    }
}

public void connectPlayer ( const char[] name, const char[] authid ) {
    checkConnection ( );
    DBStatement stmt;
    if ( ( stmt = SQL_PrepareQuery ( mysql, "insert into player (sport, steamid, name) values (?,?,?) on duplicate key update name = ?", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( mysql, error, sizeof(error) );
        PrintToServer("[OSServerInfo]: Failed to prepare query[0x03] (error: %s)", error);
        return;
    }

    SQL_BindParamInt ( stmt, 0, serverPort );
    SQL_BindParamString ( stmt, 1, authid, false );
    SQL_BindParamString ( stmt, 2, name, false );
    SQL_BindParamString ( stmt, 3, name, false );
    
    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( mysql, error, sizeof(error));
        PrintToServer("[OSServerInfo]: Failed to query[0x04] (error: %s)", error);
    }

    if ( stmt != null ) {
        delete stmt;
    }
}
 
public void disconnectPlayer ( const char[] authid ) {
    checkConnection ( );
    DBStatement stmt;
    if ( ( stmt = SQL_PrepareQuery ( mysql, "delete from player where sport = ? and steamid = ?", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( mysql, error, sizeof(error) );
        PrintToServer("[OSServerInfo]: Failed to prepare query[0x05] (error: %s)", error);
        return;
    }

    SQL_BindParamInt ( stmt, 0, serverPort );
    SQL_BindParamString ( stmt, 1, authid, false );

    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( mysql, error, sizeof(error));
        PrintToServer("[OSServerInfo]: Failed to query[0x06] (error: %s)", error);
    }

    if ( stmt != null ) {
        delete stmt;
    }
}

public void checkConnection() {
    if (mysql == null || mysql == INVALID_HANDLE) {
        databaseConnect();
    }
}

public bool playerIsReal ( int player ) {
    return ( player > 0 &&
             IsClientInGame ( player ) &&
             ! IsFakeClient ( player ) &&
             ! IsClientSourceTV ( player ) );
}
  