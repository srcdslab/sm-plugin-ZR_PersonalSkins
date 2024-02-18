#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <multicolors>
#include <zombiereloaded>
#include <utilshelper>

#undef REQUIRE_PLUGIN
#tryinclude <vip_core>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

//#define DEBUG
#define Grp_Zombie 		"Personal-Skin-Zombie"
#define Grp_Human 		"Personal-Skin-Human"
#define Grp_Zombie_VIP 		"Personal-Skin-Zombie-VIP"
#define Grp_Human_VIP 		"Personal-Skin-Human-VIP"

bool	g_bHasPersonalSkinsZombie[MAXPLAYERS + 1] = { false, ... },
		g_bHasPersonalSkinsHuman[MAXPLAYERS + 1] = { false, ... },
		g_bVipCore = false;

ConVar 	g_cvZombies,
		g_cvHumans,
		g_cvFileSettingsPath,
		g_cvDownListPath;

char 	g_sPlayerModelZombie[MAXPLAYERS+1][PLATFORM_MAX_PATH],
		g_sPlayerModelHuman[MAXPLAYERS+1][PLATFORM_MAX_PATH],
		g_sDownListPath[PLATFORM_MAX_PATH],
 		g_sFileSettingsPath[PLATFORM_MAX_PATH];

KeyValues g_KV;

GroupId GrpID_Human,
		GrpID_Human_VIP,
		GrpID_Zombie,
		GrpID_Zombie_VIP;

public Plugin myinfo =
{
	name = "[ZR] Personal Skins",
	description = "Gives a personal human or zombie skin",
	author = "FrozDark, maxime1907, .Rushaway, Dolly, zaCade",
	version = "2.0.0",
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("ZR_PersonalSkins");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvDownListPath = CreateConVar("zr_personalskins_downloadslist", "addons/sourcemod/configs/zr_personalskins_downloadslist.txt", "Config path of the download list", FCVAR_NONE, false, 0.0, false, 0.0);
	g_cvDownListPath.AddChangeHook(CvarChanges);

	g_cvFileSettingsPath = CreateConVar("zr_personalskins_skinslist", "addons/sourcemod/data/zr_personal_skins.txt", "Config path of the skin settings", FCVAR_NONE, false, 0.0, false, 0.0);
	g_cvFileSettingsPath.AddChangeHook(CvarChanges);

	g_cvZombies 	= CreateConVar("zr_personalskins_zombies_enable", "1", "Enable personal skin pickup for Zombies", _, true, 0.0, true, 1.0);
	g_cvHumans 		= CreateConVar("zr_personalskins_humans_enable", "1", "Enable personal skin pickup for Humans", _, true, 0.0, true, 1.0);

	RegAdminCmd("zr_pskins_reload", Command_Reload, ADMFLAG_ROOT);
	RegConsoleCmd("sm_pskin", Command_pSkin);

	AutoExecConfig(true, "zr_personal_skins", "zombiereloaded");
}

public void OnAllPluginsLoaded()
{
	g_bVipCore = LibraryExists("vip_core");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "vip_core"))
		g_bVipCore = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "vip_core"))
		g_bVipCore = false;
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i))
			continue;

		if (!g_bHasPersonalSkinsZombie[i] || !g_bHasPersonalSkinsHuman[i])
			continue;

		g_sPlayerModelZombie[i] = "\0";
		g_sPlayerModelHuman[i] = "\0";
	}

	delete g_KV;

	// Restore cvar to 1
	g_cvZombies.IntValue = 1;
	g_cvHumans.IntValue = 1;
}

public void OnConfigsExecuted()
{
	VerifyGroups();

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
		FakeClientCommand(client, "zclass"); // Print zclass menu to client, let him choose

	return Plugin_Handled;
}

// We use this instead of PostAdminCheck, bcs ZombieReloaded check class on post.
// Need to give the groups used as filter in playerclass before ZR check if user can access to it.
public void OnClientPostAdminFilter(int client)
{
	if (!client || IsClientSourceTV(client) || IsFakeClient(client))
		return;

	ResetClient(client);

	char SteamID[24];
	char IP[16];
	char name[64];

	if(!GetClientIP(client, IP, sizeof(IP), true) || !GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID)) || !GetClientName(client, name, sizeof(name)))
		return;

	if(g_KV == null)
		return;

	g_KV.Rewind();
	if(!g_KV.JumpToKey(SteamID) && g_KV.JumpToKey(IP) && g_KV.JumpToKey(name))
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

	AdminId AdmID;

	if ((AdmID = GetUserAdmin(client)) == INVALID_ADMIN_ID)
	{
		AdmID = CreateAdmin();
		SetUserAdmin(client, AdmID, true);
		LogMessage("Creating new admin for %L", client);
	}

	if (g_bHasPersonalSkinsZombie[client] && AdminInheritGroup(AdmID, GrpID_Zombie))
		LogMessage("%L added to group \"%s\"", client, Grp_Zombie);

	if (g_bHasPersonalSkinsHuman[client] && AdminInheritGroup(AdmID, GrpID_Human))
		LogMessage("%L added to group \"%s\"", client, Grp_Human);

#if defined _vip_core_included
	if (g_bVipCore && VIP_IsClientVIP(client))
	{
		if(g_bHasPersonalSkinsZombie[client] && AdminInheritGroup(AdmID, GrpID_Zombie_VIP))
			LogMessage("%L added to group \"%s\"", client, Grp_Zombie_VIP);

		if(g_bHasPersonalSkinsHuman[client] && AdminInheritGroup(AdmID, GrpID_Human_VIP))
			LogMessage("%L added to group \"%s\"", client, Grp_Human_VIP);
	}
#endif
}

public void ZR_OnClassAttributesApplied(int &client, int &classindex)
{
	#if defined DEBUG
	LogMessage("ZR_OnClassAttributesApplied: %d | %d", client, classindex);
	#endif

	if(IsValidClient(client) && IsPlayerAlive(client) && (g_bHasPersonalSkinsZombie[client] || g_bHasPersonalSkinsHuman[client]))
	{
		int iActiveClass = ZR_GetActiveClass(client);
		int iPersonalHumanClass = ZR_GetClassByIdentifier("personalskin_human");
		int iPersonalZombieClass = ZR_GetClassByIdentifier("personalskin_zombie");
		int iPersonalHumanClassVIP = ZR_GetClassByIdentifier("personalskin_human_vip");
		int iPersonalZombieClassVIP = ZR_GetClassByIdentifier("personalskin_zombie_vip");

		#if defined DEBUG
		LogMessage("%N has active class %d", client, iActiveClass);
		LogMessage("Personal human: %d", iPersonalHumanClass);
		LogMessage("Personal zombie: %d", iPersonalZombieClass);
		LogMessage("Personal human VIP: %d", iPersonalHumanClassVIP);
		LogMessage("Personal zombie VIP: %d", iPersonalZombieClassVIP);
		#endif

		// If user is not using a Personal-Skin, stop here.
		if (ZR_IsValidClassIndex(iActiveClass) && (!(iActiveClass == iPersonalHumanClass || iActiveClass == iPersonalZombieClass || iActiveClass == iPersonalHumanClassVIP || iActiveClass == iPersonalZombieClassVIP)))
			return;

		char modelpath[PLATFORM_MAX_PATH];
		if (ZR_IsClientZombie(client) && ZR_IsValidClassIndex(iActiveClass) && iActiveClass == iPersonalZombieClass || iActiveClass == iPersonalZombieClassVIP)
			Format(modelpath, sizeof(modelpath), g_sPlayerModelZombie[client][0]);
		else if (ZR_IsClientHuman(client) && ZR_IsValidClassIndex(iActiveClass) && iActiveClass == iPersonalHumanClass || iActiveClass == iPersonalHumanClassVIP)
			Format(modelpath, sizeof(modelpath), g_sPlayerModelHuman[client][0]);

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
		else
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

stock void VerifyGroups()
{
    VerifyAndCreateGroup(Grp_Zombie, GrpID_Zombie);
    VerifyAndCreateGroup(Grp_Human, GrpID_Human);

#if defined _vip_core_included
    VerifyAndCreateGroup(Grp_Zombie_VIP, GrpID_Zombie_VIP);
    VerifyAndCreateGroup(Grp_Human_VIP, GrpID_Human_VIP);
#endif
}

stock void VerifyAndCreateGroup(const char[] groupName, GroupId groupID)
{
    if (!VerifyGroup(groupName, groupID))
    {
        CreateGroup(groupName, groupID);

        if (!VerifyGroup(groupName, groupID))
			SetFailState("Could not create the Admin Group (\"%s\") for give Personal-Skins access.", groupName);
    }
    else
        LogMessage("Admin group \"%s\" already exists.", groupName);
}

stock bool VerifyGroup(const char[] groupName, GroupId groupID)
{
    groupID = FindAdmGroup(groupName);
    return groupID != INVALID_GROUP_ID;
}

stock void CreateGroup(const char[] groupName, GroupId groupID)
{
    groupID = CreateAdmGroup(groupName);
    groupID.ImmunityLevel = 0;
    LogMessage("Creating new admin group \"%s\"", groupName);
}
