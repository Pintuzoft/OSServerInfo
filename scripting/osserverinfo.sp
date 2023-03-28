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

char serverName[128]; 
int round;
char map[64];

char playerNames[MAXPLAYERS+1][64];
char playerSteamID[MAXPLAYERS+1][64];
int playerKills[MAXPLAYERS+1];
int playerDeaths[MAXPLAYERS+1];
int playerAssists[MAXPLAYERS+1];
int playerTeam[MAXPLAYERS+1];
int playerConnectTime[MAXPLAYERS+1];
bool playerChanged[MAXPLAYERS+1];
bool removePlayer[MAXPLAYERS+1];

public void OnPluginStart() {
    databaseConnect();
    CreateTimer(5.0, SetServerName);

    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_disconnect", Event_PlayerDisconnect);
    HookEvent("player_connect", Event_PlayerConnect);
}
public void OnMapStart ( ) {
    round = 0;
    GetCurrentMap(map, sizeof(map));
}


public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    if ( ! isWarmup ( ) ) {
        round++;
    }

}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    if ( ! isWarmup ( ) ) {
        updatePlayers ( );
    }
    resetPlayers ( );
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    int killer = event.GetInt("attacker");
    int victim = event.GetInt("userid");

    if (killer == victim) {
        return;
    }

    if (killer > 0 && killer <= MAXPLAYERS) {
        playerKills[killer]++;
        playerChanged[killer] = true;
    }

    if (victim > 0 && victim <= MAXPLAYERS) {
        playerDeaths[victim]++;
        playerChanged[victim] = true;
    }

    int assist = event.GetInt("assister");

    if (assist > 0 && assist <= MAXPLAYERS) {
        playerAssists[assist]++;
        playerChanged[assist] = true;
    }

}

public void Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast) {
    CreateTimer(5.0, Timer_ConnectPlayer, event.GetInt("userid"));
}

public Action Timer_ConnectPlayer ( Handle timer, int userid ) {
    int index = GetClientOfUserId(userid);
    if (index > 0 && index <= MAXPLAYERS) {
        GetClientName ( index, playerNames[index], 64 );
        GetClientName ( index, playerSteamID[index], 64 );
        playerKills[index] = GetClientFrags(index);
        playerDeaths[index] = GetClientDeaths(index);
        playerAssists[index] = CS_GetClientAssists(index);
        playerTeam[index] = GetClientTeam(index);
        playerConnectTime[index] = GetTime()-5;
        playerChanged[index] = true;
    }
    return Plugin_Handled;
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
    int userid = event.GetInt("userid");
    int index = GetClientOfUserId(userid);
    if (index > 0 && index <= MAXPLAYERS) {
        removePlayer[index] = true;
    }
}

public void databaseConnect() {
    if ((mysql = SQL_Connect("serverinfo", true, error, sizeof(error))) != null) {
        PrintToServer("[OSServerInfo]: Connected to mysql database!");
    } else {
        PrintToServer("[OSServerInfo]: Failed to connect to mysql database! (error: %s)", error);
    }
}

public void updatePlayers ( ) {
    Handle stmt = null;
    checkConnection();

    for ( int i = 1; i <= MAXPLAYERS; i++  ) {
        if ( removePlayer[i] ) {
            if ( ( stmt = SQL_PrepareQuery ( mysql, "delete from players where steamid = ?", error, sizeof(error) ) ) == null ) {
                SQL_GetError ( mysql, error, sizeof(error) );
                PrintToServer("[OSServerInfo]: Failed to query[0x01] (error: %s)", error);
                return;
            }
            SQL_BindParamString(stmt, 1, playerSteamID[i], false);
            SQL_Execute(stmt);
            CloseHandle(stmt);

        } else if ( playerChanged[i] ) {
            if ( ( stmt = SQL_PrepareQuery ( mysql, "insert into players (steamid, name, kills, deaths, assists, team, connecttime) values (?, ?, ?, ?, ?, ?, ?, ?, ?) on duplicate key update name = ?, kills = ?, deaths = ?, assists = ?, team = ?, connecttime = ?", error, sizeof(error) ) ) == null ) {
                SQL_GetError ( mysql, error, sizeof(error) );
                PrintToServer("[OSGameAnalyzer]: Failed to query[0x01] (error: %s)", error);
                return;
            }
            SQL_BindParamString(stmt, 1, playerSteamID[i], false);
            SQL_BindParamString(stmt, 2, playerNames[i], false);
            SQL_BindParamInt(stmt, 3, playerKills[i]);
            SQL_BindParamInt(stmt, 4, playerDeaths[i]);
            SQL_BindParamInt(stmt, 5, playerAssists[i]);
            SQL_BindParamInt(stmt, 6, playerTeam[i]);
            SQL_BindParamInt(stmt, 7, playerConnectTime[i]);
            SQL_BindParamString(stmt, 8, playerNames[i], false);
            SQL_BindParamInt(stmt, 9, playerKills[i]);
            SQL_BindParamInt(stmt, 10, playerDeaths[i]);
            SQL_BindParamInt(stmt, 11, playerAssists[i]);
            SQL_BindParamInt(stmt, 12, playerTeam[i]);
            SQL_BindParamInt(stmt, 13, playerConnectTime[i]);
            SQL_Execute(stmt);
            CloseHandle(stmt);
        }
    }
}

public void resetPlayers() {
    for (int i = 1; i <= MAXPLAYERS; i++) {
        playerChanged[i] = false;
    }
}

public void checkConnection() {
    if (mysql == null || mysql == INVALID_HANDLE) {
        databaseConnect();
    }
}

public bool isWarmup() {
    if (GameRules_GetProp("m_bWarmupPeriod") == 1) {
        return true;
    }
    return false;
}

public Action SetServerName ( Handle timer ) {
    GetConVarString(FindConVar("hostname"), serverName, sizeof(serverName));
    PrintToServer("Server name: %s", serverName);
    return Plugin_Stop; // Stop the timer
}
