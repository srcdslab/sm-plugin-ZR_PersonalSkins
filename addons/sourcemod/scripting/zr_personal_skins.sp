#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <multicolors>
#include <zombiereloaded>
#include <utilshelper>

#pragma semicolon 1
#pragma newdecls required

//#define DEBUG

bool	g_bHasPersonalSkinsZombie[MAXPLAYERS + 1] = { false, ... },
		g_bHasPersonalSkinsHuman[MAXPLAYERS + 1] = { false, ... };

ConVar 	g_cvZombies, g_cvHumans,
		g_cvFileSettingsPath, g_cvDownListPath,
		g_cvClassIdentifierZombie, g_cvClassIdentifierHuman,
		g_cvClassIdentifierZombieVIP, g_cvClassIdentifierHumanVIP,
		g_cvTeamMode;

char 	g_sPlayerModelZombie[MAXPLAYERS+1][PLATFORM_MAX_PATH],
		g_sPlayerModelHuman[MAXPLAYERS+1][PLATFORM_MAX_PATH],
		g_sDownListPath[PLATFORM_MAX_PATH],
		g_sFileSettingsPath[PLATFORM_MAX_PATH],
		g_sClassIdentifierZombie[PLATFORM_MAX_PATH], g_sClassIdentifierHuman[PLATFORM_MAX_PATH],
		g_sClassIdentifierZombieVIP[PLATFORM_MAX_PATH], g_sClassIdentifierHumanVIP[PLATFORM_MAX_PATH];

KeyValues g_KV;

public Plugin myinfo =
{
	name = "[ZR] Personal Skins",
	description = "Gives a personal human or zombie skin",
	author = "FrozDark, maxime1907, .Rushaway, Dolly, zaCade",
	version = "2.2.0",
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ZR_PersonalSkins");
	return APLRes_Success;
}

public void OnPluginStart()
{
	/* Paths Configs */
	g_cvDownListPath = CreateConVar("zr_personalskins_downloadslist", "addons/sourcemod/configs/zr_personalskins_downloadslist.txt", "Config path of the download list", FCVAR_NONE);
	g_cvFileSettingsPath = CreateConVar("zr_personalskins_skinslist", "addons/sourcemod/data/zr_personal_skins.txt", "Config path of the skin settings", FCVAR_NONE);

	/* Enable - Disable */
	g_cvZombies 	= CreateConVar("zr_personalskins_zombies_enable", "1", "Enable personal skin pickup for Zombies", _, true, 0.0, true, 1.0);
	g_cvHumans 		= CreateConVar("zr_personalskins_humans_enable", "1", "Enable personal skin pickup for Humans", _, true, 0.0, true, 1.0);

	/* Groups */
	g_cvClassIdentifierZombie 	= CreateConVar("zr_personalskins_group_zombie", "Personal-Skin-Zombie", "Class identifier name for personal skin zombie", FCVAR_PROTECTED);
	g_cvClassIdentifierHuman 	= CreateConVar("zr_personalskins_group_human", "Personal-Skin-Human", "Class identifier name for personal skin human", FCVAR_PROTECTED);
	g_cvClassIdentifierZombieVIP = CreateConVar("zr_personalskins_group_zombie_vip", "Personal-Skin-Zombie-VIP", "Class identifier name for personal skin zombie VIP", FCVAR_PROTECTED);
	g_cvClassIdentifierHumanVIP = CreateConVar("zr_personalskins_group_human_vip", "Personal-Skin-Human-VIP", "Class identifier name for personal skin human VIP", FCVAR_PROTECTED);
	g_cvTeamMode = CreateConVar("zr_personalskins_team_mode", "0", "0: validation par class identifier, 1: validation par team (T=zm, CT=human)", FCVAR_NONE, true, 0.0, true, 1.0);

	g_cvDownListPath.AddChangeHook(CvarChanges);
	g_cvFileSettingsPath.AddChangeHook(CvarChanges);
	g_cvClassIdentifierZombie.AddChangeHook(CvarChanges);
	g_cvClassIdentifierHuman.AddChangeHook(CvarChanges);
	g_cvClassIdentifierZombieVIP.AddChangeHook(CvarChanges);
	g_cvClassIdentifierHumanVIP.AddChangeHook(CvarChanges);

	/* Initialize values + Handle plugin reload */
	GetConVarString(g_cvFileSettingsPath, g_sFileSettingsPath, sizeof(g_sFileSettingsPath));
	GetConVarString(g_cvDownListPath, g_sDownListPath, sizeof(g_sDownListPath));
	GetConVarString(g_cvClassIdentifierZombie, g_sClassIdentifierZombie, sizeof(g_sClassIdentifierZombie));
	GetConVarString(g_cvClassIdentifierHuman, g_sClassIdentifierHuman, sizeof(g_sClassIdentifierHuman));
	GetConVarString(g_cvClassIdentifierZombieVIP, g_sClassIdentifierZombieVIP, sizeof(g_sClassIdentifierZombieVIP));
	GetConVarString(g_cvClassIdentifierHumanVIP, g_sClassIdentifierHumanVIP, sizeof(g_sClassIdentifierHumanVIP));

	RegAdminCmd("zr_pskins_reload", Command_Reload, ADMFLAG_ROOT);
	RegConsoleCmd("sm_pskin", Command_pSkin);

	AutoExecConfig(true, "zr_personal_skins", "zombiereloaded");
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i))
			continue;

		if (!g_bHasPersonalSkinsZombie[i] || !g_bHasPersonalSkinsHuman[i])
			continue;

		g_sPlayerModelZombie[i] = "";
		g_sPlayerModelHuman[i] = "";
	}

	delete g_KV;

	// Restore cvar to 1
	g_cvZombies.IntValue = 1;
	g_cvHumans.IntValue = 1;
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

	else if (convar == g_cvDownListPath)
	{
		strcopy(g_sDownListPath, sizeof(g_sDownListPath), newValue);
		if(!FileExists(g_sDownListPath, false))
			return;

		File_ReadDownloadList(g_sDownListPath);
	}

	else if (convar == g_cvClassIdentifierZombie)
		strcopy(g_sClassIdentifierZombie, sizeof(g_sClassIdentifierZombie), newValue);

	else if (convar == g_cvClassIdentifierHuman)
		strcopy(g_sClassIdentifierHuman, sizeof(g_sClassIdentifierHuman), newValue);

	else if (convar == g_cvClassIdentifierZombieVIP)
		strcopy(g_sClassIdentifierZombieVIP, sizeof(g_sClassIdentifierZombieVIP), newValue);

	else if (convar == g_cvClassIdentifierHumanVIP)
		strcopy(g_sClassIdentifierHumanVIP, sizeof(g_sClassIdentifierHumanVIP), newValue);
}

public Action Command_Reload(int client, int args)
{
	if(FileExists(g_sDownListPath, false))
	{
		File_ReadDownloadList(g_sDownListPath);
	
		CReplyToCommand(client, "{green}[ZR] {default}Successfully reloaded Personal-Skin List.");
		LogAction(-1, -1, "[ZR-PersonalSkin] %L Reloaded the Personal-Skin List.", client);
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
	if (!client)
		return Plugin_Handled;

	if (!g_bHasPersonalSkinsZombie[client] && !g_bHasPersonalSkinsHuman[client])
		CReplyToCommand(client, "{green}[ZR] {default}You don't have personal-skin");
	else
		ZR_MenuClass(client);

	return Plugin_Handled;
}

// We use this instead of PostAdminCheck, bcs ZombieReloaded check class on post.
// Need to give the groups used as filter in playerclass before ZR check if user can access to it.
public void OnClientPostAdminFilter(int client)
{
	if (g_KV == null || !client || IsClientSourceTV(client) || IsFakeClient(client))
		return;

	ResetClient(client);

	char sSteamID[24], sIP[16], sName[64];

	if(!GetClientIP(client, sIP, sizeof(sIP), true) || !GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID)) || !GetClientName(client, sName, sizeof(sName)))
		return;

	g_KV.Rewind();
	if(!g_KV.JumpToKey(sSteamID) && g_KV.JumpToKey(sIP) && g_KV.JumpToKey(sName))
		return;

	g_KV.GetString("ModelZombie", g_sPlayerModelZombie[client], PLATFORM_MAX_PATH);
	g_KV.GetString("ModelHuman", g_sPlayerModelHuman[client], PLATFORM_MAX_PATH);

	if(strlen(g_sPlayerModelZombie[client][0]) != 0)
	{
		if (!IsModelFile(g_sPlayerModelZombie[client]))
		{
			LogError("%L Personal Skins (Zombie) is not a model file. (.mdl)", client);
			return;
		}

		if (!IsModelPrecached(g_sPlayerModelZombie[client]))
			PrecacheModel(g_sPlayerModelZombie[client], false);

		g_bHasPersonalSkinsZombie[client] = true;
	}

	if (strlen(g_sPlayerModelHuman[client][0]) != 0)
	{
		if (!IsModelFile(g_sPlayerModelHuman[client]))
		{
			LogError("%L Personal Skins (Human) is not a model file. (.mdl)", client);
			return;
		}

		if(!IsModelPrecached(g_sPlayerModelHuman[client]))
			PrecacheModel(g_sPlayerModelHuman[client], false);
	
		g_bHasPersonalSkinsHuman[client] = true;
	}

	// No personal-skin found for this player - Stop here
	if (!g_bHasPersonalSkinsHuman[client] && !g_bHasPersonalSkinsZombie[client])
		return;

	GrantCustom5Flag(client);
}

public void OnRebuildAdminCache(AdminCachePart part)
{
	if (part != AdminCache_Admins)
		return;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		if (IsFakeClient(client))
			continue;
		if (IsClientSourceTV(client))
			continue;
		if (!g_bHasPersonalSkinsZombie[client] && !g_bHasPersonalSkinsHuman[client])
			continue;

		GrantCustom5Flag(client);
	}
}

stock void GrantCustom5Flag(int client)
{
	int flags = GetUserFlagBits(client);
	if (!(flags & ADMFLAG_CUSTOM5))
	{
		flags |= ADMFLAG_CUSTOM5;
		SetUserFlagBits(client, flags);
		LogMessage("Granted custom5 flag to %L", client);
	}
}

public void ZR_OnClassAttributesApplied(int &client, int &classindex)
{
	#if defined DEBUG
	LogMessage("ZR_OnClassAttributesApplied: %d | %d", client, classindex);
	#endif

	if(IsValidClient(client) && IsPlayerAlive(client) && (g_bHasPersonalSkinsZombie[client] || g_bHasPersonalSkinsHuman[client]))
	{
		// Small workaround to prevent #10 - https://github.com/srcdslab/sm-plugin-ZR_PersonalSkins/issues/10
		int iActiveClass = -1;

		if (client && IsPlayerAlive(client))
			iActiveClass = ZR_GetActiveClass(client);
		else
			return;

		int iPersonalHumanClass = ZR_GetClassByIdentifier(g_sClassIdentifierHuman);
		int iPersonalZombieClass = ZR_GetClassByIdentifier(g_sClassIdentifierZombie);
		int iPersonalHumanClassVIP = ZR_GetClassByIdentifier(g_sClassIdentifierHumanVIP);
		int iPersonalZombieClassVIP = ZR_GetClassByIdentifier(g_sClassIdentifierZombieVIP);

		#if defined DEBUG
		LogMessage("%N has active class %d", client, iActiveClass);
		LogMessage("Personal human: %d", iPersonalHumanClass);
		LogMessage("Personal zombie: %d", iPersonalZombieClass);
		LogMessage("Personal human VIP: %d", iPersonalHumanClassVIP);
		LogMessage("Personal zombie VIP: %d", iPersonalZombieClassVIP);
		#endif

		char modelpath[PLATFORM_MAX_PATH];
		switch (g_cvTeamMode.IntValue)
		{
			case 0:
			{
				// If user is not using a Personal-Skin, stop here.
				if (ZR_IsValidClassIndex(iActiveClass) && (!(iActiveClass == iPersonalHumanClass || iActiveClass == iPersonalZombieClass || iActiveClass == iPersonalHumanClassVIP || iActiveClass == iPersonalZombieClassVIP)))
					return;

				if (ZR_IsClientZombie(client) && ZR_IsValidClassIndex(iActiveClass) && (iActiveClass == iPersonalZombieClass || iActiveClass == iPersonalZombieClassVIP))
					Format(modelpath, sizeof(modelpath), g_sPlayerModelZombie[client][0]);
				else if (ZR_IsClientHuman(client) && ZR_IsValidClassIndex(iActiveClass) && (iActiveClass == iPersonalHumanClass || iActiveClass == iPersonalHumanClassVIP))
					Format(modelpath, sizeof(modelpath), g_sPlayerModelHuman[client][0]);
			}
			case 1:
			{
				int team = GetClientTeam(client);
				if (team == 2 && g_bHasPersonalSkinsZombie[client])
					Format(modelpath, sizeof(modelpath), g_sPlayerModelZombie[client][0]);
				else if (team == 3 && g_bHasPersonalSkinsHuman[client])
					Format(modelpath, sizeof(modelpath), g_sPlayerModelHuman[client][0]);
			}
			default:
			{
				return;
			}
		}

		// Player has a Personal-Skin but no model related to the current team or model_path wasn't set.
		if (strlen(modelpath) == 0)
			return;

		#if defined DEBUG
		LogMessage("%L new model path stored: %s", client, modelpath);
		#endif
	
		if (!IsModelFile(modelpath))
		{
			PrintToChat(client, "[SM] A configuration error was caught on your model, can't apply it.");
			LogError("Model extension is not an .mdl (%s)", modelpath);
			return;
		}

		// Should never happen, but to be safe attempt hotfix on the fly
		if (!IsModelPrecached(modelpath))
		{
			PrecacheModel(modelpath);
			#if defined DEBUG
			LogMessage("Model not precached, attempting an hotfix by Precaching the model on the fly.. (%s)", modelpath);
			#endif

			if (!IsModelPrecached(modelpath))
			{
				PrintToChat(client, "[SM] A technical error was caught on your model, can't apply it.");
				LogError("Model not precached, not applying model.. \"%s\"", modelpath);
				return;
			}

			#if defined DEBUG
			LogMessage("Hotfix: Model has been preached.. Yay! (%s)", modelpath);
			#endif
		}

		SetEntityModel(client, modelpath);
	}
}

public void OnClientDisconnect(int client)
{
	ResetClient(client);
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

stock void ResetClient(int client)
{
	g_bHasPersonalSkinsZombie[client] = false;
	g_bHasPersonalSkinsHuman[client] = false;
	g_sPlayerModelZombie[client] = "";
	g_sPlayerModelHuman[client] = "";
}
