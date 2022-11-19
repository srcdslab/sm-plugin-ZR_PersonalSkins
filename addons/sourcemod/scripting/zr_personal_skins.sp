#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <smlib>
#include <multicolors>
#include <zombiereloaded>

#pragma semicolon 1
#pragma newdecls required

#define CHANGE_MODE_NOT_CHANGED_YET 0
#define CHANGE_MODE_CHANGED 1
#define CHANGE_MODE_CHANGESKIN_TO_PSKIN 2
#define CHANGE_MODE_CHANGESKIN_TO_ACTUAL 3

int 
		g_iClientChangeMode[MAXPLAYERS + 1] = { CHANGE_MODE_NOT_CHANGED_YET, ... },
		g_iClientPreviousChangeMode[MAXPLAYERS + 1] = { CHANGE_MODE_NOT_CHANGED_YET, ... };

bool	g_bIsPlayerHasSkins[MAXPLAYERS + 1] = { false, ... },
		g_bClientDisabledSkin[MAXPLAYERS + 1] = { false, ... },
		g_bClientChangedSkin[MAXPLAYERS + 1] = { false, ... },
		g_bForceDisableSkin[MAXPLAYERS + 1] = { false, ... },
		g_bMotherInfect = false;

ConVar 	g_cvZombies,
		g_cvHumans,
		g_cvFileSettingsPath,
		g_cvDownListPath;

char 	g_sPlayerModelZombie[MAXPLAYERS+1][PLATFORM_MAX_PATH],
		g_sPlayerModelHuman[MAXPLAYERS+1][PLATFORM_MAX_PATH],
		g_sPlayerActualModel[MAXPLAYERS+1][PLATFORM_MAX_PATH],
		g_sDownListPath[PLATFORM_MAX_PATH],
 		g_sFileSettingsPath[PLATFORM_MAX_PATH];

KeyValues g_KV;

Cookie 	
		g_hUser,
		g_hForced;

public Plugin myinfo =
{
	name = "[ZR] Personal Skins",
	description = "Gives a personal human or zombie skin",
	author = "FrozDark, maxime1907, .Rushaway, Dolly",
	version = "1.3.0",
	url = ""
}

public void OnPluginStart()
{
	g_cvDownListPath = CreateConVar("zr_personalskins_downloadslist", "addons/sourcemod/configs/zr_personalskins_downloadslist.txt", "Config path of the download list", FCVAR_NONE, false, 0.0, false, 0.0);
	g_cvDownListPath.AddChangeHook(CvarChanges);

	g_cvFileSettingsPath = CreateConVar("zr_personalskins_skinslist", "addons/sourcemod/data/zr_personal_skins.txt", "Config path of the skin settings", FCVAR_NONE, false, 0.0, false, 0.0);
	g_cvFileSettingsPath.AddChangeHook(CvarChanges);
	
	g_cvZombies 	= CreateConVar("zr_personalskins_zombies_enable", "1", "Enable personal skin pickup for Zombies", _, true, 0.0, true, 1.0);
	g_cvHumans 		= CreateConVar("zr_personalskins_humans_enable", "1", "Enable personal skin pickup for Humans", _, true, 0.0, true, 1.0);

	RegAdminCmd("zr_pskins_reload", Command_Reload, ADMFLAG_GENERIC);
	RegAdminCmd("sm_togglepskin", Command_TogglePSkin, ADMFLAG_RCON);
	RegConsoleCmd("sm_pskin", Command_pSkin);

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_team", Event_PlayerSpawn);
	HookEvent("round_start", Event_RoundStart);

	AutoExecConfig(true, "zr_personal_skins", "zombiereloaded");
	
	g_hUser = new Cookie("zr_personalskins_user", "Disable/Enable skin", CookieAccess_Public);
	g_hForced = new Cookie("zr_personalskins_forced", "Admin force enable/disable skin", CookieAccess_Public);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		if(AreClientCookiesCached(i))
			OnClientCookiesCached(i);
	}
}

public void OnClientCookiesCached(int client)
{
	char cookieValue[6];
	g_hUser.Get(client, cookieValue, sizeof(cookieValue));
	
	if(StrEqual(cookieValue, "true", false))
		g_bClientDisabledSkin[client] = true;
	else
		g_bClientDisabledSkin[client] = false;
		
	g_hForced.Get(client, cookieValue, sizeof(cookieValue));
	
	if(StrEqual(cookieValue, "true", false))
		g_bForceDisableSkin[client] = true;
	else
		g_bForceDisableSkin[client] = false;
}

public void OnMapEnd()
{
	delete g_KV;
}

public void OnConfigsExecuted()
{
	g_cvFileSettingsPath.GetString(g_sFileSettingsPath, sizeof(g_sFileSettingsPath));
	g_cvDownListPath.GetString(g_sDownListPath, sizeof(g_sDownListPath));

	g_KV = new KeyValues("SkinSettings");
	
	if(!g_KV.ImportFromFile(g_sFileSettingsPath))
	{
		SetFailState("File '%s' not found!", g_sFileSettingsPath);
		delete g_KV;
		return;
	}
	
	if(!FileExists(g_sDownListPath, false))
	{
		LogError("Downloadslist '%s' not found", g_sDownListPath);
		return;
	}
	
	File_ReadDownloadList(g_sDownListPath);
}

public void CvarChanges(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvFileSettingsPath)
	{
		if(g_KV == null)
			return;
			
		strcopy(g_sFileSettingsPath, sizeof(g_sFileSettingsPath), newValue);
		ClearKV(g_KV);
		
		if (!g_KV.ImportFromFile(g_sFileSettingsPath))
			SetFailState("File '%s' not found!", g_sFileSettingsPath);
			
		return;
	}
	
	if (convar == g_cvDownListPath)
	{
		strcopy(g_sDownListPath, sizeof(g_sFileSettingsPath), newValue);
		if(!FileExists(g_sDownListPath, false))
			return;
			
		File_ReadDownloadList(g_sDownListPath);
	}
}

public Action Command_Reload(int client, int args)
{
	if(FileExists(g_sDownListPath, false))
	{
		File_ReadDownloadList(g_sDownListPath);
		CReplyToCommand(client, "{green}[ZR] {default}Successfully reloaded Personal-Skin List.");
		if (client > 0)
			LogAction(client, -1, "[ZR-PersonalSkin] %L Reloaded the Personal-Skin List.", client);
		else
			LogAction(-1, -1, "[ZR-PersonalSkin] <Console> Reloaded the Personal-Skin List.");
	}
	
	if(g_KV == null)
		return Plugin_Handled;
		
	ClearKV(g_KV);
	if(!g_KV.ImportFromFile(g_sFileSettingsPath))
	{
		SetFailState("File '%s' not found!", g_sFileSettingsPath);
		CReplyToCommand(client, "{green}[ZR] {red}File '%' not found!", g_sFileSettingsPath);
	}
	
	return Plugin_Handled;
}

public Action Command_pSkin(int client, int args)
{
	if(!client)
		return Plugin_Handled;
		
	if(!g_bIsPlayerHasSkins[client])
	{
		CReplyToCommand(client, "{green}[ZR] {default}You don't have a personal skin to use this command.");
		return Plugin_Handled;
	}
	
	if(g_bForceDisableSkin[client])
	{
		CReplyToCommand(client, "{green}[ZR] {red}You Personal Skin is temporary disabled by an Administrator.");
		return Plugin_Handled;
	}
	
	g_bClientDisabledSkin[client] = (g_bClientDisabledSkin[client]) ? false : true;
	CReplyToCommand(client, "{green}[ZR] {default}Successfully %s {default}Personal-Skin.", (g_bClientDisabledSkin[client]) ? "{red}disabled" : "{green}enabled");
	CReplyToCommand(client, "{green}[ZR] {default}Type {olive}!pskin {default}again if you want to %s it.", (g_bClientDisabledSkin[client]) ? "enable" : "disable");
	
	char cookieValue[6];
	FormatEx(cookieValue, sizeof(cookieValue), "%s", (g_bClientDisabledSkin[client]) ? "true" : "false");
	g_hUser.Set(client, cookieValue);
	
	if(!g_bMotherInfect)
	{
		if(!g_bClientChangedSkin[client])
		{
			int newMode;
			
			if(g_bClientDisabledSkin[client])
			{
				if(ZR_IsClientHuman(client) && g_sPlayerActualModel[client][0])
				{
					newMode = CHANGE_MODE_CHANGESKIN_TO_ACTUAL;
					SetEntityModel(client, g_sPlayerActualModel[client]);
				}
			}
			else
			{
				if(ZR_IsClientHuman(client) && g_sPlayerModelHuman[client][0])
				{
					newMode = CHANGE_MODE_CHANGESKIN_TO_PSKIN;
					SetEntityModel(client, g_sPlayerModelHuman[client]);
				}
			}
			
			g_iClientPreviousChangeMode[client] = CHANGE_MODE_CHANGED;
			g_iClientChangeMode[client] = newMode;
			g_bClientChangedSkin[client] = true;
		}
		else
		{
			int modeEx = g_iClientChangeMode[client];
			int newMode;
		
			if(!g_bClientDisabledSkin[client])
				newMode = CHANGE_MODE_CHANGESKIN_TO_PSKIN;
			else
				newMode = CHANGE_MODE_CHANGESKIN_TO_ACTUAL;
		
			g_iClientPreviousChangeMode[client] = modeEx;
			g_iClientChangeMode[client] = newMode;
			CReplyToCommand(client, "{green}[ZR] {default}Your changes will be applied on next round!");
		}
		
		return Plugin_Handled;
	}
	else
	{
		int mode = g_iClientChangeMode[client];
		int newMode;
		
		if(!g_bClientDisabledSkin[client])
			newMode = CHANGE_MODE_CHANGESKIN_TO_PSKIN;
		else
			newMode = CHANGE_MODE_CHANGESKIN_TO_ACTUAL;
		
		g_iClientPreviousChangeMode[client] = mode;
		g_iClientChangeMode[client] = newMode;
		CReplyToCommand(client, "{green}[ZR] {default}Your changes will be applied on next round!");
		return Plugin_Handled;
	}
}

public Action Command_TogglePSkin(int client, int args)
{
	if(args < 2)
	{
		CReplyToCommand(client, "{green}[ZR] {default}Usage: sm_togglepskin <player> <1|0>");
		return Plugin_Handled;
	}
	
	char arg1[65], arg2[7];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	int target = FindTarget(client, arg1, true, false);
	if(target < 1)
	{
		CReplyToCommand(client, "{green}[ZR] {default}Invalid target.");
		return Plugin_Handled;
	}
	
	if(!g_bIsPlayerHasSkins[target])
	{
		CReplyToCommand(client, "{green}[ZR] {default}The specified target doesn't have a personal skin!");
		return Plugin_Handled;
	}
	
	int num;
	if(!StringToIntEx(arg2, num))
	{
		CReplyToCommand(client, "{green}[ZR] {default}Invalid toggle value.");
		return Plugin_Handled;
	}
	
	bool bValue;
	if(num <= 0)
		bValue = true;
	else
		bValue = false;
		
	if(g_bForceDisableSkin[target] == bValue)
	{
		CReplyToCommand(client, "{green}[ZR] {default}The specified target's personal skin is already %s.", (bValue) ? "{red}disabled" : "{green}enabled");
		return Plugin_Handled;
	}
	
	g_bForceDisableSkin[target] = bValue;
	g_hForced.Set(client, "true");
	CReplyToCommand(client, "{green}[ZR] {red}Successfully %s {default}Personal Skin on {olive}%N.", (bValue) ? "{red}disabled" : "{green}enabled", target);
	LogAction(client, target, "[ZR-PersonalSkin] \"%L\" Force-%s \"%L\"'s personal skin", client, (bValue) ? "Disabled" : "Enabled", target);
	return Plugin_Handled;
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect)
{
	if(motherInfect)
		g_bMotherInfect = true;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bMotherInfect = false;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;
			
		if(!g_bIsPlayerHasSkins[i])
			continue;
			
		g_iClientPreviousChangeMode[i] = CHANGE_MODE_CHANGED;
		g_bClientChangedSkin[i] = false;
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (client < 1 || client > MaxClients || IsFakeClient(client) || !g_bIsPlayerHasSkins[client])
		return;

	if(g_bForceDisableSkin[client])
		return;
		
	CreateTimer(0.5, PlayerSpawn_Timer, userid);
}

public Action PlayerSpawn_Timer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(client < 1)
		return Plugin_Stop;

	RequestFrame(GetClientModel_Frame, client);
	
	int previousMode = g_iClientPreviousChangeMode[client];
	int currentMode = g_iClientChangeMode[client];
	
	if(previousMode == CHANGE_MODE_CHANGED && currentMode == CHANGE_MODE_CHANGESKIN_TO_PSKIN || (previousMode == CHANGE_MODE_NOT_CHANGED_YET && currentMode == CHANGE_MODE_NOT_CHANGED_YET) && !g_bClientDisabledSkin[client])
		CreateTimer(1.0, SetClientModelTimer, userid);

	else if(previousMode == CHANGE_MODE_CHANGED && currentMode == CHANGE_MODE_CHANGESKIN_TO_ACTUAL && g_bClientDisabledSkin[client])
		return Plugin_Stop;
	
	else
		return Plugin_Stop;
		
	if(g_bClientDisabledSkin[client])
		return Plugin_Stop;
		
	return Plugin_Continue;
}

void GetClientModel_Frame(int client)
{
	GetEntPropString(client, Prop_Data, "m_ModelName", g_sPlayerActualModel[client], PLATFORM_MAX_PATH);
}
public Action SetClientModelTimer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || !g_bIsPlayerHasSkins[client])
		return Plugin_Stop;
	
	if(g_cvHumans.BoolValue && ZR_IsClientHuman(client))
	{	
		if(g_sPlayerModelHuman[client][0] && IsModelFile(g_sPlayerModelHuman[client]))
		{
			SetEntityModel(client, g_sPlayerModelHuman[client]);
			return Plugin_Continue;
		}
	}
	
	if(g_cvZombies.BoolValue && ZR_IsClientZombie(client))
	{
		if(g_sPlayerModelZombie[client][0] && IsModelFile(g_sPlayerModelZombie[client]))
		{
			SetEntityModel(client, g_sPlayerModelZombie[client]);
			return Plugin_Continue;
		}
	}

	return Plugin_Continue;
}

public void OnClientPutInServer(int client)
{
	if (!client || IsClientSourceTV(client) || IsFakeClient(client))
		return;

	g_bIsPlayerHasSkins[client] = false;

	char SteamID[24];
	char IP[16];
	char name[64];

	if(!GetClientIP(client, IP, sizeof(IP), true)
	|| !GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID))
	|| !GetClientName(client, name, sizeof(name)))
	{
		return;
	}
	
	if(g_KV == null)
		return;
		
	g_KV.Rewind();
	if(!g_KV.JumpToKey(SteamID) || g_KV.JumpToKey(IP) || g_KV.JumpToKey(name))
		return;
		
	g_bIsPlayerHasSkins[client] = true;
	g_KV.GetString("ModelZombie", g_sPlayerModelZombie[client], PLATFORM_MAX_PATH);
	g_KV.GetString("ModelHuman", g_sPlayerModelHuman[client], PLATFORM_MAX_PATH);
	
	if(g_sPlayerModelZombie[client][0] && IsModelFile(g_sPlayerModelZombie[client]) && !IsModelPrecached(g_sPlayerModelZombie[client]))
		PrecacheModel(g_sPlayerModelZombie[client], false);

	if (g_sPlayerModelHuman[client][0] && IsModelFile(g_sPlayerModelHuman[client]) && !IsModelPrecached(g_sPlayerModelHuman[client]))
		PrecacheModel(g_sPlayerModelHuman[client], false);
}

public void OnClientDisconnect(int client)
{
	g_bClientDisabledSkin[client] = false;
	g_bIsPlayerHasSkins[client] = false;
	g_sPlayerActualModel[client][0] = '\0';
	
	g_iClientPreviousChangeMode[client] = CHANGE_MODE_NOT_CHANGED_YET;
	g_iClientChangeMode[client] = CHANGE_MODE_NOT_CHANGED_YET;
	g_bClientChangedSkin[client] = false;
	g_bForceDisableSkin[client] = false;
}

stock void ClearKV(KeyValues kvHandle)
{
	if(kvHandle == null)
		return;
		
	kvHandle.Rewind();
	
	if(!kvHandle.GotoFirstSubKey())
		return;
		
	do 
	{
		kvHandle.DeleteThis();
		kvHandle.Rewind();
	}
	
	while(kvHandle.GotoNextKey());
	kvHandle.Rewind();
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
