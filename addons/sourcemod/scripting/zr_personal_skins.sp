#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <zombiereloaded>

#pragma semicolon 1
#pragma newdecls required

bool IsPlayerHasSkins[MAXPLAYERS+1];

char s_PlayerModelZombie[MAXPLAYERS+1][256];
char s_PlayerModelHuman[MAXPLAYERS+1][256];
char s_DownListPath[256];
char s_FileSettingsPath[256];

Handle hKVSettings = INVALID_HANDLE;

Handle h_FileSettingsPath = INVALID_HANDLE;
Handle h_DownListPath = INVALID_HANDLE;

public Plugin myinfo =
{
	name = "[ZR] Personal Skins",
	description = "Gives a personal human or zombie skin",
	author = "FrozDark, maxime1907",
	version = "1.1",
	url = ""
};

public void OnPluginStart()
{
	h_DownListPath = CreateConVar("zr_personalskins_downloadslist", "addons/sourcemod/configs/zr_personalskins_downloadslist.txt", "Config path of the download list", FCVAR_NONE, false, 0.0, false, 0.0);
	HookConVarChange(h_DownListPath, CvarChanges);

	h_FileSettingsPath = CreateConVar("zr_personalskins_skinslist", "addons/sourcemod/data/zr_personal_skins.txt", "Config path of the skin settings", FCVAR_NONE, false, 0.0, false, 0.0);
	HookConVarChange(h_FileSettingsPath, CvarChanges);

	RegAdminCmd("zr_pskins_reload", Command_Reload, ADMFLAG_GENERIC);

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerSpawn, EventHookMode_Post);

	AutoExecConfig(true, "zr_personal_skins", "zombiereloaded");
}

public void OnPluginEnd()
{
	UnhookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	UnhookEvent("player_team", Event_PlayerSpawn, EventHookMode_Post);
}

public void OnConfigsExecuted()
{
	GetConVarString(h_FileSettingsPath, s_FileSettingsPath, sizeof(s_FileSettingsPath));
	GetConVarString(h_DownListPath, s_DownListPath, sizeof(s_DownListPath));

	hKVSettings = CreateKeyValues("SkinSettings");
	if (!FileToKeyValues(hKVSettings, s_FileSettingsPath))
	{
		SetFailState("File '%s' not found!", s_FileSettingsPath);
	}
	if (FileExists(s_DownListPath, false))
	{
		File_ReadDownloadList(s_DownListPath);
	}
	else
	{
		LogError("Downloadslist '%s' not found", s_DownListPath);
	}
}

public void CvarChanges(Handle convar, char[] oldValue, char[] newValue)
{
	if (h_FileSettingsPath == convar)
	{
		strcopy(s_FileSettingsPath, sizeof(s_FileSettingsPath), newValue);
		ClearKV(hKVSettings);
		if (!FileToKeyValues(hKVSettings, s_FileSettingsPath))
		{
			SetFailState("File '%s' not found!", s_FileSettingsPath);
		}
	}
	else if (h_DownListPath == convar)
	{
		strcopy(s_DownListPath, sizeof(s_FileSettingsPath), newValue);
		if (FileExists(s_DownListPath, false))
		{
			File_ReadDownloadList(s_DownListPath);
		}
	}
}

public Action Command_Reload(int client, int args)
{
	if (FileExists(s_DownListPath, false))
	{
		File_ReadDownloadList(s_DownListPath);
	}
	ClearKV(hKVSettings);
	if (!FileToKeyValues(hKVSettings, s_FileSettingsPath))
	{
		SetFailState("File '%s' not found!", s_FileSettingsPath);
	}
	return Plugin_Handled;
}

public void Event_PlayerSpawn(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!client || !IsPlayerHasSkins[client] || IsFakeClient(client) || !IsPlayerAlive(client))
		return;

	CreateTimer(1.0, SetClientModel, client, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(6.0, SetClientModel, client, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(31.0, SetClientModel, client, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(61.0, SetClientModel, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action SetClientModel(Handle timer, any client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && ZR_IsClientHuman(client))
	{
		if (s_PlayerModelHuman[client][0] && IsModelFile(s_PlayerModelHuman[client]))
		{
			SetEntityModel(client, s_PlayerModelHuman[client]);
		}
	}
	if (IsClientInGame(client) && IsPlayerAlive(client) && ZR_IsClientZombie(client))
	{
		if (s_PlayerModelZombie[client][0] && IsModelFile(s_PlayerModelZombie[client]))
		{
			SetEntityModel(client, s_PlayerModelZombie[client]);
		}
	}
	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	if (!client || IsFakeClient(client))
		return;

	IsPlayerHasSkins[client] = false;

	char sSteam32ID[24];
	char sPlayerIP[16];
	char sName[64];

	GetClientIP(client, sPlayerIP, sizeof(sPlayerIP), true);
	GetClientAuthId(client, AuthId_Steam2, sSteam32ID, sizeof(sSteam32ID));
	GetClientName(client, sName, sizeof(sName));

	KvRewind(hKVSettings);

	if (KvJumpToKey(hKVSettings, sSteam32ID, false) || KvJumpToKey(hKVSettings, sPlayerIP, false) || KvJumpToKey(hKVSettings, sName, false))
	{
		IsPlayerHasSkins[client] = true;
		KvGetString(hKVSettings, "ModelZombie", s_PlayerModelZombie[client], sizeof(s_FileSettingsPath), "");
		KvGetString(hKVSettings, "ModelHuman", s_PlayerModelHuman[client], sizeof(s_FileSettingsPath), "");

		if (s_PlayerModelZombie[client][0] && IsModelFile(s_PlayerModelZombie[client]) && !IsModelPrecached(s_PlayerModelZombie[client]))
		{
			PrecacheModel(s_PlayerModelZombie[client], false);
		}

		if (s_PlayerModelHuman[client][0] && IsModelFile(s_PlayerModelHuman[client]) && !IsModelPrecached(s_PlayerModelHuman[client]))
		{
			PrecacheModel(s_PlayerModelHuman[client], false);
		}
	}
}

stock void ClearKV(Handle kvhandle)
{
	KvRewind(kvhandle);
	if (KvGotoFirstSubKey(kvhandle))
	{
		do
		{
			KvDeleteThis(kvhandle);
			KvRewind(kvhandle);
		}
		while (KvGotoFirstSubKey(kvhandle));
		KvRewind(kvhandle);
	}
}

stock bool IsModelFile(char[] model)
{
	char buf[4];
	GetExtension(model, buf, sizeof(buf));
	return !strcmp(buf, "mdl", false);
}

stock void GetExtension(char[] path, char[] buffer, int size)
{
	int extpos = FindCharInString(path, '.', true);
	if (extpos == -1)
	{
		buffer[0] = '\0';
		return;
	}
	extpos++;
	strcopy(buffer, size, path[extpos]);
}
