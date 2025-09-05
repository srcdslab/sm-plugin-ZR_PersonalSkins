#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <multicolors>
#include <zombiereloaded>
#include <utilshelper>

#define MAX_PERSONAL_CLASSES 	5

//#define DEBUG

/* CVARS */
ConVar g_cvZombies; 
ConVar g_cvHumans;
ConVar g_cvFileSettingsPath;
ConVar g_cvDownListPath;

enum struct PlayerData
{
	bool hasZombie;
	bool hasHuman;
	
	char modelZombie[PLATFORM_MAX_PATH];
	char modelHuman[PLATFORM_MAX_PATH];
	
	int endZombie;
	int endHuman;
	
	void Reset()
	{
		this.hasZombie = false; 
		this.hasHuman = false;
		this.modelZombie[0] = '\0';
		this.modelHuman[0] = '\0';
		this.endZombie = 0;
		this.endHuman = 0;
	}
}

PlayerData g_PlayerData[MAXPLAYERS + 1];

/* Strings */
char g_sFileSettingsPath[PLATFORM_MAX_PATH];

/* Keyvalues */
KeyValues g_hKV;

/* Personal Classes Indexes */
int g_iPersonalClasses[MAX_PERSONAL_CLASSES] =  {-1, ...};

public Plugin myinfo =
{
	name = "[ZR] Personal Skins",
	description = "Gives a personal human or zombie skin",
	author = "FrozDark, maxime1907, .Rushaway, Dolly, zaCade",
	version = "3.2.1",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ZR_PersonalSkins");
	return APLRes_Success;
}

public void OnPluginStart()
{
	/* Paths Configs */
	g_cvDownListPath 		= CreateConVar("zr_personalskins_downloadslist", "addons/sourcemod/configs/zr_personalskins_downloadslist.txt", "Config path of the download list", FCVAR_NONE);
	g_cvFileSettingsPath 	= CreateConVar("zr_personalskins_skinslist", "addons/sourcemod/data/zr_personal_skins.txt", "Config path of the skin settings", FCVAR_NONE);

	/* Enable - Disable */
	g_cvZombies = CreateConVar("zr_personalskins_zombies_enable", "1", "Enable personal skin pickup for Zombies", _, true, 0.0, true, 1.0);
	g_cvHumans 	= CreateConVar("zr_personalskins_humans_enable", "1", "Enable personal skin pickup for Humans", _, true, 0.0, true, 1.0);

	g_cvFileSettingsPath.AddChangeHook(OnConVarChange);
	
	/* Initialize values + Handle plugin reload */
	g_cvFileSettingsPath.GetString(g_sFileSettingsPath, sizeof(g_sFileSettingsPath));
	
	RegAdminCmd("zr_pskins_reload", Command_Reload, ADMFLAG_ROOT);
	RegConsoleCmd("sm_pskin", Command_pSkin);
	
	AutoExecConfig(true, "zr_personal_skins", "zombiereloaded");
}

/* Map End */
public void OnMapEnd()
{
	// Restore cvar to 1, this is helpful when a specified team (or both) personal skin is/are disabled during a map, somehow cvars stay with the same value
	g_cvZombies.IntValue = 1;
	g_cvHumans.IntValue = 1;
}

/* Client Disconnect */
public void OnClientDisconnect(int client)
{
	g_PlayerData[client].Reset();
}

/* Read the data file */
public void ZR_OnClassLoaded()
{
	#if defined DEBUG
	LogMessage("[ZR-Personal Skins] ZR_OnClassLoaded called");
	#endif
	
	for (int i = 0; i < MAX_PERSONAL_CLASSES; i++)
	{
		g_iPersonalClasses[i] = -1;
	}
	
	delete g_hKV;
	g_hKV = new KeyValues("SkinSettings");
	
	if(!g_hKV.ImportFromFile(g_sFileSettingsPath))
	{
		SetFailState("[ZR-Personal Skins] File '%s' not found!", g_sFileSettingsPath);
		delete g_hKV;
		return;
	}
	
	if (!g_hKV.JumpToKey("Classes"))
	{
		SetFailState("[ZR-Personal Skins] Could not find 'Classes' section in config file.");
		delete g_hKV;
		return;
	}
	
	if (!g_hKV.GotoFirstSubKey())
	{
		SetFailState("[ZR-Personal Skins] Could not find any class config");
		delete g_hKV;
		return;
	}
	
	int count = 0;
	do 
	{
		// force this option if config didnt have it
		g_hKV.SetString("personal", "yes");
		
		int index = ZR_RegClassIndex(g_hKV);
		if (index == -1)
			continue;
		
		g_iPersonalClasses[count] = index;
		
		#if defined DEBUG
		PrintToServer("[ZR-Personal Skins] Registered personal class %d at index %d", index, count);
		#endif
		
		count++;
		
		if (count >= MAX_PERSONAL_CLASSES)
			break;
	} while (g_hKV.GotoNextKey());
}

/* Read Downloadlist file */
public void OnConfigsExecuted()
{
	char downloadPath[PLATFORM_MAX_PATH];
	g_cvDownListPath.GetString(downloadPath, sizeof(downloadPath));
	
	if(!FileExists(downloadPath, false))
	{
		LogError("[ZR-Personal Skins] Downloadslist '%s' not found", downloadPath);
		return;
	}
	
	File_ReadDownloadList(downloadPath);
}

/* Update settings path when it is changed */
public void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ZR_OnClassLoaded();
}

/* Commands */
public Action Command_Reload(int client, int args)
{
	if(g_hKV == null) 
		return Plugin_Handled;

	ZR_OnClassLoaded();
	
	CReplyToCommand(client, "{green}[ZR] {default}Successfully reloaded Personal-Skin List.");
	LogAction(-1, -1, "[ZR-PersonalSkin] %L Reloaded the Personal-Skin List.", client);
	return Plugin_Handled;
}

public Action Command_pSkin(int client, int args)
{
	if (!client)
		return Plugin_Handled;

	if (!g_PlayerData[client].hasZombie && !g_PlayerData[client].hasHuman) 
		CReplyToCommand(client, "{green}[ZR] {default}You don't have personal-skin");
	else 
		ZR_MenuClass(client);
	
	return Plugin_Handled;
}

// We use this instead of PostAdminCheck, bcs ZombieReloaded check class on post.
// Need to give the groups used as filter in playerclass before ZR check if user can access to it.
public void OnClientPostAdminFilter(int client)
{
	if (g_hKV == null || IsFakeClient(client))
		return;
	
	char steamID[24], ip[16];

	if(!GetClientIP(client, ip, sizeof(ip), true) || !GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID)))
		return;

	#if defined DEBUG
	PrintToServer("[ZR-Personal Skins] Player %N - SteamID: %s, IP: %s", client, steamID, ip);
	#endif

	g_hKV.Rewind();
	if(!g_hKV.JumpToKey(steamID) && !g_hKV.JumpToKey(ip))
	{
		#if defined DEBUG
		PrintToServer("[ZR-Personal Skins] No config found for %N - SteamID: %s, IP: %s", client, steamID, ip);
		#endif
		return;
	}
	
	#if defined DEBUG
	PrintToServer("[ZR-Personal Skins] Found config for %N - SteamID: %s, IP: %s", client, steamID, ip);
	#endif

	/* Get Zombie Personal Skin Info */
	int zmSkinEndTime;
	if(ValidatePersonalSkin(client, "ModelZombie", "end_zombie", g_PlayerData[client].modelZombie, sizeof(PlayerData::modelZombie), zmSkinEndTime))
	{
		g_PlayerData[client].hasZombie = true;
		if(zmSkinEndTime > 0) 
			g_PlayerData[client].endZombie = zmSkinEndTime;
	}
	else 
	{
		#if defined DEBUG
		PrintToServer("[ZR-Personal Skins] Could not Validate Zombie skin for %N, skin has probably ended", client);
		#endif
	}
	
	int humanEndTime;
	if(ValidatePersonalSkin(client, "ModelHuman", "end_human", g_PlayerData[client].modelHuman, sizeof(PlayerData::modelHuman), humanEndTime))
	{
		g_PlayerData[client].hasHuman = true;
		if(humanEndTime > 0)
			g_PlayerData[client].endHuman = humanEndTime;
	} 
	else
	{
		#if defined DEBUG
		PrintToServer("[ZR-Personal Skins] Could not Validate Human skin for %N, skin has probably ended", client);
		#endif
	}
	
	#if defined DEBUG
	PrintToServer("[ZR-Personal Skins] Player %N - hasHuman: %d, hasZombie: %d", client, g_PlayerData[client].hasHuman, g_PlayerData[client].hasZombie);
	#endif
	
	if (g_PlayerData[client].hasHuman || g_PlayerData[client].hasZombie)
	{
		for (int i = 0; i < MAX_PERSONAL_CLASSES; i++)
		{
			if (g_iPersonalClasses[i] == -1)
				continue;
			
			int classTeam = ZR_GetClassTeamID(g_iPersonalClasses[i], ZR_CLASS_CACHE_ORIGINAL);
			#if defined DEBUG
			PrintToServer("[ZR-Personal Skins] Class %d team: %d, hasHuman: %d, hasZombie: %d", g_iPersonalClasses[i], classTeam, g_PlayerData[client].hasHuman, g_PlayerData[client].hasZombie);
			#endif
			
			if ((g_PlayerData[client].hasHuman && classTeam == ZR_CLASS_TEAM_HUMANS) || (g_PlayerData[client].hasZombie && classTeam == ZR_CLASS_TEAM_ZOMBIES))
			{
				#if defined DEBUG
				PrintToServer("[ZR-Personal Skins] Found Personal Class for %N, class index: %d", client, g_iPersonalClasses[i]);
				#endif
				ZR_SetClientClassPersonal(client, g_iPersonalClasses[i], true);
			}
		}
	}
	else
	{
		#if defined DEBUG
		PrintToServer("[ZR-Personal Skins] Player %N has no personal skins configured", client);
		#endif
	}
}

/* To validate if the player can use the personal skin or not */
bool ValidatePersonalSkin(int client, const char[] modelKey, const char[] endKey, char[] model, int maxlen, int &skinEndTime = 0)
{
	g_hKV.GetString(modelKey, model, maxlen);
	
	#if defined DEBUG
	PrintToServer("[ZR-Personal Skins] ValidatePersonalSkin for %N - Key: %s, Model: '%s'", client, modelKey, model);
	#endif
	
	if(strlen(model) != 0)
	{
		bool has = false;
		int endTime = g_hKV.GetNum(endKey, 0);
		if(endTime != 0)
		{
			#if defined DEBUG
			PrintToServer("[ZR-Personal Skins] End Time for %N: %d", client, endTime);
			#endif
			if(endTime > GetTime())
			{
				has = true;
				skinEndTime = endTime;
			}
		}
		else
		{
			has = true;
		}
		
		if(has)
		{
			if (!IsModelFile(model))
			{
				#if defined DEBUG
				LogError("[ZR-Personal Skins] %L Personal Skins (%s) is not a model file. (.mdl)", client, (StrContains(modelKey, "zombie") == -1) ? "Human" : "Zombie");
				#endif
				has = false;
			}

			if (has && !IsModelPrecached(model))
				PrecacheModel(model, false);
		
			return has;
		}
	}
	
	return false;
}

public void ZR_OnClassAttributesApplied(int &client, int &classIndex)
{
	#if defined DEBUG
	PrintToServer("[ZR-Personal Skins] ZR_OnClassAttributesApplied: client %d, classIndex %d", client, classIndex);
	#endif

	if(!IsValidClient(client) || !IsPlayerAlive(client) || !(g_PlayerData[client].hasZombie || g_PlayerData[client].hasHuman))
	{
		#if defined DEBUG
		PrintToServer("[ZR-Personal Skins] Skipping %N - ValidClient: %d, Alive: %d, HasSkins: %d", client, IsValidClient(client), IsPlayerAlive(client), (g_PlayerData[client].hasZombie || g_PlayerData[client].hasHuman));
		#endif
		return;
	}
	
	#if defined DEBUG
	PrintToServer("[ZR-Personal Skins] Processing model application for %N", client);
	#endif
	
	// we want to check the team of this class
	int team = ZR_GetClassTeamID(classIndex, ZR_CLASS_CACHE_ORIGINAL);
	#if defined DEBUG
	PrintToServer("[ZR-Personal Skins] Class %d team: %d, ActiveClass: %d", classIndex, team, ZR_GetActiveClass(client));
	#endif
	
	if (team == ZR_CLASS_TEAM_ADMINS)
		return;
		
	bool found = false;
	for (int i = 0; i < MAX_PERSONAL_CLASSES; i++)
	{
		if (g_iPersonalClasses[i] < 0)
			continue;
		
		int personalClassTeam = ZR_GetClassTeamID(g_iPersonalClasses[i], ZR_CLASS_CACHE_ORIGINAL);
		#if defined DEBUG
		PrintToServer("[ZR-Personal Skins] Checking personal class %d (team %d) vs active class %d (team %d)", g_iPersonalClasses[i], personalClassTeam, ZR_GetActiveClass(client), team);
		#endif
		
		if (ZR_GetActiveClass(client) == g_iPersonalClasses[i] && team == personalClassTeam)
		{
			found = true;
			#if defined DEBUG
			PrintToServer("[ZR-Personal Skins] Found matching personal class for %N", client);
			#endif
			break;
		}
	}
	
	if (!found)
	{
		#if defined DEBUG
		PrintToServer("[ZR-Personal Skins] Could not apply skin model for %N, either classes were misconfigurated or player doesnt have pskin for this team", client);
		#endif
		
		return;
	}
	
	if (team == 0 && !g_PlayerData[client].hasZombie)
	{
		#if defined DEBUG
		PrintToServer("[ZR-Personal Skins] %N is zombie team but has no zombie skin", client);
		#endif
		return;
	}
	
	if (team == 1 && !g_PlayerData[client].hasHuman)
	{
		#if defined DEBUG
		PrintToServer("[ZR-Personal Skins] %N is human team but has no human skin", client);
		#endif
		return;
	}
	
	char thisModel[PLATFORM_MAX_PATH];
	switch(team)
	{
		case ZR_CLASS_TEAM_ZOMBIES: strcopy(thisModel, sizeof(thisModel), g_PlayerData[client].modelZombie);
		case ZR_CLASS_TEAM_HUMANS: strcopy(thisModel, sizeof(thisModel), g_PlayerData[client].modelHuman);
	}
	
	#if defined DEBUG
	PrintToServer("[ZR-Personal Skins] Applying model '%s' to %N (team %d)", thisModel, client, team);
	#endif
	
	SetEntityModel(client, thisModel);
}

bool IsModelFile(char[] model)
{
	char buf[4];
	GetExtension(model, buf, sizeof(buf));
	return !strcmp(buf, "mdl", false);
}

void GetExtension(char[] path, char[] buffer, int size)
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