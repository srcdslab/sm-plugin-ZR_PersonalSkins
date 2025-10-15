#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <multicolors>
#include <zombiereloaded>
#include <utilshelper>

#define MAX_PERSONAL_CLASSES 	64

// ConVars
ConVar g_cvZombies;
ConVar g_cvHumans;
ConVar g_cvFileSettingsPath;
ConVar g_cvDownListPath;

// Classes management
ArrayList g_arClasses;

enum struct ClassData {
	int index;
	char identifier[64];
	bool needsModel;
	int team;
}

enum struct PlayerData
{
	bool hasPersonal;

	char modelZombie[PLATFORM_MAX_PATH];
	char modelHuman[PLATFORM_MAX_PATH];

	int endZombie;
	int endHuman;

	void Reset()
	{
		this.hasPersonal = false;
		this.modelZombie[0] = '\0';
		this.modelHuman[0] = '\0';
		this.endZombie = 0;
		this.endHuman = 0;
	}
}

PlayerData g_PlayerData[MAXPLAYERS + 1];

// File paths
char g_sFileSettingsPath[PLATFORM_MAX_PATH];

// Data storage
KeyValues g_hKV;

public Plugin myinfo =
{
	name = "[ZR] Personal Skins",
	description = "Gives a personal human or zombie skin",
	author = "FrozDark, maxime1907, .Rushaway, Dolly, zaCade",
	version = "3.0.0",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ZR_PersonalSkins");
	return APLRes_Success;
}

public void OnPluginStart()
{
	// Configuration paths
	g_cvDownListPath 		= CreateConVar("zr_personalskins_downloadslist", "addons/sourcemod/configs/zr_personalskins_downloadslist.txt", "Config path of the download list", FCVAR_NONE);
	g_cvFileSettingsPath 	= CreateConVar("zr_personalskins_skinslist", "addons/sourcemod/data/zr_personal_skins.txt", "Config path of the skin settings", FCVAR_NONE);

	// Feature toggles
	g_cvZombies = CreateConVar("zr_personalskins_zombies_enable", "1", "Enable personal skin pickup for Zombies", _, true, 0.0, true, 1.0);
	g_cvHumans 	= CreateConVar("zr_personalskins_humans_enable", "1", "Enable personal skin pickup for Humans", _, true, 0.0, true, 1.0);

	g_cvFileSettingsPath.AddChangeHook(OnConVarChange);
	g_cvFileSettingsPath.GetString(g_sFileSettingsPath, sizeof(g_sFileSettingsPath));

	RegAdminCmd("zr_pskins_reload", Command_Reload, ADMFLAG_ROOT);
	RegConsoleCmd("sm_pskin", Command_pSkin);

	AutoExecConfig(true, "zr_personal_skins", "zombiereloaded");
}

public void OnMapEnd()
{
	// Reset cvars on map change
	g_cvZombies.IntValue = 1;
	g_cvHumans.IntValue = 1;
}

public void OnClientDisconnect(int client)
{
	g_PlayerData[client].Reset();
}

public void ZR_OnClassLoaded()
{
	delete g_arClasses;

	delete g_hKV;
	g_hKV = new KeyValues("SkinSettings");

	if (!g_hKV.ImportFromFile(g_sFileSettingsPath))
	{
		delete g_hKV;
		SetFailState("[ZR-Personal Skins] File '%s' not found!", g_sFileSettingsPath);
		return;
	}

	g_arClasses = new ArrayList(ByteCountToCells(256));

	if (g_hKV.JumpToKey("Classes") && g_hKV.GotoFirstSubKey())
	{
		do
		{
			char identifier[sizeof(ClassData::identifier)];
			g_hKV.GetSectionName(identifier, sizeof(identifier));

		int index = ZR_GetClassByIdentifier(identifier, ZR_CLASS_CACHE_ORIGINAL);
		if (index == -1)
		{
			g_hKV.SetString("personal", "yes");
			index = ZR_RegClassIndex(g_hKV);
			if (index == -1)
			{
				LogError("[ZR-Personal Skins] Failed to register class: %s", identifier);
				continue;
			}
		}

			ClassData class;
			class.index = index;
			strcopy(class.identifier, sizeof(identifier), identifier);
			class.team = -1;
			g_arClasses.PushArray(class);

		} while (g_hKV.GotoNextKey());
	}

	g_hKV.Rewind();

	if (!g_hKV.JumpToKey("zr_personal_classes"))
	{
		delete g_hKV;
		delete g_arClasses;
		SetFailState("[ZR-Personal Skins] Could not find section \"zr_personal_classes\" in data file.");
		return;
	}

	if (!g_hKV.GotoFirstSubKey(.keyOnly=false))
	{
		delete g_hKV;
		delete g_arClasses;
		SetFailState("[ZR-Personal Skins] Could not find any class in personal classes section in data file.");
		return;
	}

	do
	{
		char classIdentifier[32];
		g_hKV.GetSectionName(classIdentifier, sizeof(classIdentifier));

		int teamIndex = g_hKV.GetNum(NULL_STRING, -1); // -1: force class model, 0/1: use personal model (zombie/human)
		if (teamIndex != -1 && teamIndex != ZR_CLASS_TEAM_ZOMBIES && teamIndex != ZR_CLASS_TEAM_HUMANS)
		{
			LogError("[ZR-Personal Skins] Skipping class %s - invalid team index: %d", classIdentifier, teamIndex);
			continue;
		}

		int classIndex = ZR_GetClassByIdentifier(classIdentifier, ZR_CLASS_CACHE_ORIGINAL);
		if (classIndex == -1)
		{
			LogError("[ZR-Personal Skins] Class %s not found in ZR class cache", classIdentifier);
			continue;
		}

		bool needsModel = teamIndex != -1;
		bool found = false;
		for (int i = 0; i < g_arClasses.Length; i++)
		{
			ClassData class;
			g_arClasses.GetArray(i, class, sizeof(class));
			if (class.index == classIndex)
			{
				found = true;
				class.needsModel = needsModel;
				class.team = teamIndex;
				g_arClasses.SetArray(i, class, sizeof(class));
				break;
			}
		}

		if (!found)
		{
			ClassData class;
			class.index = classIndex;
			class.needsModel = needsModel;
			strcopy(class.identifier, sizeof(ClassData::identifier), classIdentifier);
			class.team = teamIndex;
			g_arClasses.PushArray(class, sizeof(class));
		}
	} while (g_hKV.GotoNextKey(.keyOnly = false));

	if (!g_arClasses.Length)
	{
		delete g_arClasses;
		delete g_hKV;
		SetFailState("[ZR-Personal Skins] Could not find any class to create");
		return;
	}
}

public void OnConfigsExecuted()
{
	char downloadPath[PLATFORM_MAX_PATH];
	g_cvDownListPath.GetString(downloadPath, sizeof(downloadPath));

	if (!FileExists(downloadPath, false))
	{
		LogError("[ZR-Personal Skins] Downloadslist '%s' not found", downloadPath);
		return;
	}

	File_ReadDownloadList(downloadPath);
}

public void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	ZR_OnClassLoaded();
}

// Commands
public Action Command_Reload(int client, int args)
{
	if (g_hKV == null)
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

	if (!g_PlayerData[client].hasPersonal)
		CReplyToCommand(client, "{green}[ZR] {default}You don't have personal-skin");
	else
		ZR_MenuClass(client);

	return Plugin_Handled;
}

// Grant class access before ZR validates permissions
public void OnClientPostAdminFilter(int client)
{
	if (g_hKV == null || g_arClasses == null || IsFakeClient(client))
		return;

	char steamID[24], ip[16];

	if (!GetClientIP(client, ip, sizeof(ip), true) || !GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID)))
		return;

	g_hKV.Rewind();

	if (!g_hKV.JumpToKey(steamID) && !g_hKV.JumpToKey(ip))
		return;

	// Validate personal skins
	if (g_cvZombies.BoolValue && ValidatePersonalSkin("ModelZombie", "end_zombie", g_PlayerData[client].modelZombie, sizeof(PlayerData::modelZombie)))
	{
		g_PlayerData[client].hasPersonal = true;
	}

	if (g_cvHumans.BoolValue && ValidatePersonalSkin("ModelHuman", "end_human", g_PlayerData[client].modelHuman, sizeof(PlayerData::modelHuman)))
	{
		g_PlayerData[client].hasPersonal = true;
	}

	bool hasZombie = g_cvZombies.BoolValue && g_PlayerData[client].modelZombie[0] != '\0';
	bool hasHuman = g_cvHumans.BoolValue && g_PlayerData[client].modelHuman[0] != '\0';

	if (!g_hKV.JumpToKey("Classes"))
		return;

	for (int i = 0; i < g_arClasses.Length; i++)
	{
		ClassData class;
		g_arClasses.GetArray(i, class, sizeof(class));

		if (class.needsModel)
		{
			if (class.team == ZR_CLASS_TEAM_ZOMBIES && !hasZombie)
				continue;

			if (class.team == ZR_CLASS_TEAM_HUMANS && !hasHuman)
				continue;
		}
		else
		{
			char value[2];
			g_hKV.GetString(class.identifier, value, sizeof(value));

			if (!(value[0] && StringToInt(value) > 0))
				continue;
		}

		ZR_SetClientClassPersonal(client, class.index, true);
		if (!g_PlayerData[client].hasPersonal)
			g_PlayerData[client].hasPersonal = true;
	}
}

// Validate personal skin availability and expiration
bool ValidatePersonalSkin(const char[] modelKey, const char[] endKey, char[] model, int maxlen)
{
	g_hKV.GetString(modelKey, model, maxlen);

	if (strlen(model) != 0)
	{
		bool has = false;
		int endTime = g_hKV.GetNum(endKey, 0);
		if (endTime != 0)
		{
			if (endTime > GetTime())
				has = true;
		}
		else
			has = true;

		if (has)
		{
			if (!IsModelFile(model))
				has = false;

			if (has && !IsModelPrecached(model))
				PrecacheModel(model, false);

			return has;
		}
	}

	return false;
}

public void ZR_OnClassAttributesApplied(int &client, int &classIndex)
{
	if (!g_hKV)
		return;

	if (!g_PlayerData[client].hasPersonal || !IsValidClient(client) || !IsPlayerAlive(client))
		return;

	bool hasZombie = g_cvZombies.BoolValue && g_PlayerData[client].modelZombie[0] != '\0';
	bool hasHuman = g_cvHumans.BoolValue && g_PlayerData[client].modelHuman[0] != '\0';

	ClassData targetClass;
	bool found = false;

	for (int i = 0; i < g_arClasses.Length; i++)
	{
		ClassData class;
		g_arClasses.GetArray(i, class, sizeof(class));
		if (class.index == classIndex)
		{
			targetClass = class;
			found = true;
			break;
		}
	}

	if (!found)
		return;

	// Skip if class doesn't need personal model
	if (!targetClass.needsModel)
		return;

	// Check if player has required personal model for this class
	bool hasRequiredModel = false;
	if (targetClass.team == ZR_CLASS_TEAM_ZOMBIES && hasZombie)
		hasRequiredModel = true;
	else if (targetClass.team == ZR_CLASS_TEAM_HUMANS && hasHuman)
		hasRequiredModel = true;

	if (!hasRequiredModel)
		return;

	int team = ZR_GetClassTeamID(classIndex, ZR_CLASS_CACHE_ORIGINAL);

	char thisModel[PLATFORM_MAX_PATH];
	switch (team)
	{
		case ZR_CLASS_TEAM_ZOMBIES: strcopy(thisModel, sizeof(thisModel), g_PlayerData[client].modelZombie);
		case ZR_CLASS_TEAM_HUMANS: strcopy(thisModel, sizeof(thisModel), g_PlayerData[client].modelHuman);
	}

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
