#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <multicolors>
#include <zombiereloaded>
#include <utilshelper>

#define DATE_FORMAT "%m/%d/%Y - %H:%M:%S"

//#define DEBUG

/* CVARS */
ConVar g_cvZombies; 
ConVar g_cvHumans;
ConVar g_cvFileSettingsPath;
ConVar g_cvDownListPath;

ConVar g_cvClassIdentifierZombie;
ConVar g_cvClassIdentifierHuman;
ConVar g_cvClassIdentifierZombieVIP;
ConVar g_cvClassIdentifierHumanVIP;
ConVar g_cvTeamMode;

enum struct PlayerData {
	bool hasZombie;
	bool hasHuman;
	
	char modelZombie[PLATFORM_MAX_PATH];
	char modelHuman[PLATFORM_MAX_PATH];
	
	int endZombie;
	int endHuman;
	
	void Reset() {
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

char g_sClassIdentifierHuman[64];
char g_sClassIdentifierZombie[64];
char g_sClassIdentifierHumanVIP[64];
char g_sClassIdentifierZombieVIP[64];

/* Keyvalues */
KeyValues g_hKV;

public Plugin myinfo = {
	name = "[ZR] Personal Skins",
	description = "Gives a personal human or zombie skin",
	author = "FrozDark, maxime1907, .Rushaway, Dolly, zaCade (Remade by Dolly)",
	version = "2.2.3",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	RegPluginLibrary("ZR_PersonalSkins");
	return APLRes_Success;
}

public void OnPluginStart() {
	/* Paths Configs */
	g_cvDownListPath 		= CreateConVar("zr_personalskins_downloadslist", "addons/sourcemod/configs/zr_personalskins_downloadslist.txt", "Config path of the download list", FCVAR_NONE);
	g_cvFileSettingsPath 	= CreateConVar("zr_personalskins_skinslist", "addons/sourcemod/data/zr_personal_skins.txt", "Config path of the skin settings", FCVAR_NONE);

	/* Enable - Disable */
	g_cvZombies = CreateConVar("zr_personalskins_zombies_enable", "1", "Enable personal skin pickup for Zombies", _, true, 0.0, true, 1.0);
	g_cvHumans 	= CreateConVar("zr_personalskins_humans_enable", "1", "Enable personal skin pickup for Humans", _, true, 0.0, true, 1.0);

	/* Groups */
	g_cvClassIdentifierZombie 		= CreateConVar("zr_personalskins_group_zombie", "Personal-Skin-Zombie", "Class identifier name for personal skin zombie", FCVAR_PROTECTED);
	g_cvClassIdentifierHuman 		= CreateConVar("zr_personalskins_group_human", "Personal-Skin-Human", "Class identifier name for personal skin human", FCVAR_PROTECTED);
	g_cvClassIdentifierZombieVIP 	= CreateConVar("zr_personalskins_group_zombie_vip", "Personal-Skin-Zombie-VIP", "Class identifier name for personal skin zombie VIP", FCVAR_PROTECTED);
	g_cvClassIdentifierHumanVIP 	= CreateConVar("zr_personalskins_group_human_vip", "Personal-Skin-Human-VIP", "Class identifier name for personal skin human VIP", FCVAR_PROTECTED);
	g_cvTeamMode 					= CreateConVar("zr_personalskins_team_mode", "0", "0: validation par class identifier, 1: validation par team (T=zm, CT=human)", FCVAR_NONE, true, 0.0, true, 1.0);

	g_cvFileSettingsPath			.AddChangeHook(OnConVarChange);
	g_cvClassIdentifierZombie		.AddChangeHook(OnConVarChange);
	g_cvClassIdentifierHuman		.AddChangeHook(OnConVarChange);
	g_cvClassIdentifierZombieVIP	.AddChangeHook(OnConVarChange);
	g_cvClassIdentifierHumanVIP		.AddChangeHook(OnConVarChange);
	
	/* Initialize values + Handle plugin reload */
	g_cvFileSettingsPath			.GetString(g_sFileSettingsPath, sizeof(g_sFileSettingsPath));
	g_cvClassIdentifierZombie		.GetString(g_sClassIdentifierZombie, sizeof(g_sClassIdentifierZombie));
	g_cvClassIdentifierHuman		.GetString(g_sClassIdentifierHuman, sizeof(g_sClassIdentifierHuman));
	g_cvClassIdentifierZombieVIP	.GetString(g_sClassIdentifierZombieVIP, sizeof(g_sClassIdentifierZombieVIP));
	g_cvClassIdentifierHumanVIP		.GetString(g_sClassIdentifierHumanVIP, sizeof(g_sClassIdentifierHumanVIP));
	
	RegAdminCmd("zr_pskins_reload", Command_Reload, ADMFLAG_ROOT);
	RegConsoleCmd("sm_pskin", Command_pSkin);

	AutoExecConfig(true, "zr_personal_skins", "zombiereloaded");
}

/* Map End */
public void OnMapEnd() {
	delete g_hKV;

	// Restore cvar to 1, this is helpful when a specified team (or both) personal skin is/are disabled during a map, somehow cvars stay with the same value
	g_cvZombies.IntValue = 1;
	g_cvHumans.IntValue = 1;
}

/* Client Disconnect */
public void OnClientDisconnect(int client) {
	g_PlayerData[client].Reset();
}

/* Read the data file */
public void OnConfigsExecuted() {
	char downloadPath[PLATFORM_MAX_PATH];
	g_cvDownListPath.GetString(downloadPath, sizeof(downloadPath));

	g_hKV = new KeyValues("SkinSettings");
	
	if(!g_hKV.ImportFromFile(g_sFileSettingsPath)) {
		SetFailState("[ZR-Personal Skins] File '%s' not found!", g_sFileSettingsPath);
		delete g_hKV;
		return;
	}
	
	if(!FileExists(downloadPath, false))
	{
		LogError("[ZR-Personal Skins] Downloadslist '%s' not found", downloadPath);
		return;
	}
	
	File_ReadDownloadList(downloadPath);
}

/* Update settings path when it is changed */
public void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue) {
	if(convar == g_cvFileSettingsPath) {
		strcopy(g_sFileSettingsPath, sizeof(g_sFileSettingsPath), newValue);
		ClearKV(g_hKV);
		
		if (!g_hKV.ImportFromFile(g_sFileSettingsPath)) {
			SetFailState("[ZR-Personal Skins] File '%s' not found!", g_sFileSettingsPath);
		}
		
		return;
	}
	
	if (convar == g_cvClassIdentifierZombie) {
		strcopy(g_sClassIdentifierZombie, sizeof(g_sClassIdentifierZombie), newValue);
		return;
	}
	
	if(convar == g_cvClassIdentifierHuman) {
		strcopy(g_sClassIdentifierHuman, sizeof(g_sClassIdentifierHuman), newValue);
		return;
	}
	
	if (convar == g_cvClassIdentifierZombieVIP) {
		strcopy(g_sClassIdentifierZombieVIP, sizeof(g_sClassIdentifierZombieVIP), newValue);
		return;
	}

	if (convar == g_cvClassIdentifierHumanVIP) {
		strcopy(g_sClassIdentifierHumanVIP, sizeof(g_sClassIdentifierHumanVIP), newValue);
		return;
	}
}

/* Commands */
public Action Command_Reload(int client, int args) {
	if(g_hKV == null) {
		return Plugin_Handled;
	}

	ClearKV(g_hKV);
	if(!g_hKV.ImportFromFile(g_sFileSettingsPath)) {
		CReplyToCommand(client, "{green}[ZR] {red}File '%s' not found!", g_sFileSettingsPath);
		SetFailState("[ZR-Personal Skins] File '%s' not found!", g_sFileSettingsPath);
		return Plugin_Handled;
	}
	
	CReplyToCommand(client, "{green}[ZR] {default}Successfully reloaded Personal-Skin List.");
	LogAction(-1, -1, "[ZR-PersonalSkin] %L Reloaded the Personal-Skin List.", client);
	return Plugin_Handled;
}

public Action Command_pSkin(int client, int args) {
	if (!client) {
		return Plugin_Handled;
	}

	if (!g_PlayerData[client].hasZombie && !g_PlayerData[client].hasHuman) {
		CReplyToCommand(client, "{green}[ZR] {default}You don't have personal-skin");
	} else {
		ZR_MenuClass(client);
	}
	
	return Plugin_Handled;
}

// We use this instead of PostAdminCheck, bcs ZombieReloaded check class on post.
// Need to give the groups used as filter in playerclass before ZR check if user can access to it.
public void OnClientPostAdminFilter(int client) {
	if (g_hKV == null || IsFakeClient(client)) {
		return;
	}
	
	char steamID[24], ip[16], name[64];

	if(!GetClientIP(client, ip, sizeof(ip), true) || !GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID)) || !GetClientName(client, name, sizeof(name)))
		return;

	g_hKV.Rewind();
	if(!g_hKV.JumpToKey(steamID) && !g_hKV.JumpToKey(ip) && !g_hKV.JumpToKey(name)) {
		return;
	}
	
	/* Get Zombie Personal Skin Info */
	int zmSkinEndTime;
	if(ValidatePersonalSkin(client, "ModelZombie", "end_zombie", g_PlayerData[client].modelZombie, sizeof(PlayerData::modelZombie), zmSkinEndTime)) {
		g_PlayerData[client].hasZombie = true;
		if(zmSkinEndTime > 0) {
			g_PlayerData[client].endZombie = zmSkinEndTime;
		}
	} else {
		#if defined DEBUG
		PrintToServer("[ZR-Personal Skins] Could not Validate Zombie skin for %N, skin has probably ended", client);
		#endif
	}
	
	int humanEndTime;
	if(ValidatePersonalSkin(client, "ModelHuman", "end_human", g_PlayerData[client].modelHuman, sizeof(PlayerData::modelHuman), humanEndTime)) {
		g_PlayerData[client].hasHuman = true;
		if(humanEndTime > 0) {
			g_PlayerData[client].endHuman = humanEndTime;
		}
	} else {
		#if defined DEBUG
		PrintToServer("[ZR-Personal Skins] Could not Validate Human skin for %N, skin has probably ended", client);
		#endif
	}
	
	// No personal-skin found for this player - Stop here
	if (!g_PlayerData[client].hasZombie && !g_PlayerData[client].hasHuman) {
		return;
	}

	GrantCustom5Flag(client);
}

/* To validate if the player can use the personal skin or not */
bool ValidatePersonalSkin(int client, const char[] modelKey, const char[] endKey, char[] model, int maxlen, int &skinEndTime = 0) {
	if(g_hKV.GetString(modelKey, model, maxlen)
		&& strlen(model) != 0) {
		bool has = false;
		char endTime[24];
		g_hKV.GetString(endKey, endTime, sizeof(endTime));
		if(endTime[0]) {
			// for end time (useful if skin was rewarded during an event and there is an end for it)
			// be careful with the date format otherwise the function will return an error
			#if defined DEBUG
			PrintToServer("[ZR-Personal Skins] End Time for %N: %s", client, endTime);
			#endif
			int endTimeStamp = ParseTime(endTime, DATE_FORMAT);
			if(endTimeStamp > GetTime()) {
				has = true;
				skinEndTime = endTimeStamp;
			}
		} else {
			has = true;
		}
		
		if(has) {
			if (!IsModelFile(model))
			{
				LogError("[ZR-Personal Skins] %L Personal Skins (Zombie) is not a model file. (.mdl)", client);
				has = false;
			}

			if (has && !IsModelPrecached(model)) {
				PrecacheModel(model, false);
			}

			return has;
		}
	}
	
	return false;
}

public void OnRebuildAdminCache(AdminCachePart part) {
	if (part != AdminCache_Admins) {
		return;
	}

	for (int client = 1; client <= MaxClients; client++) {
		if (!IsClientInGame(client) || IsFakeClient(client) || (!g_PlayerData[client].hasZombie && !g_PlayerData[client].hasHuman)) {
			continue;
		}

		GrantCustom5Flag(client);
	}
}

void GrantCustom5Flag(int client) {
	int flags = GetUserFlagBits(client);
	if (!(flags & ADMFLAG_CUSTOM5)) {
		flags |= ADMFLAG_CUSTOM5;
		SetUserFlagBits(client, flags);
		LogMessage("[ZR-Personal Skins] Granted custom5 flag to %L", client);
	}
}

public void ZR_OnClassAttributesApplied(int &client, int &classindex) {
	#if defined DEBUG
	LogMessage("[ZR-Personal Skins] ZR_OnClassAttributesApplied: %d | %d", client, classindex);
	#endif

	if(!IsValidClient(client) || !IsPlayerAlive(client) || !(g_PlayerData[client].hasZombie || g_PlayerData[client].hasHuman)) {
		return;
	}
	
	bool zm = ZR_IsClientZombie(client);
	if(zm && (!g_cvZombies.BoolValue || !g_PlayerData[client].hasZombie || (g_PlayerData[client].endZombie > 0 && g_PlayerData[client].endZombie <= GetTime()))) {
		return;
	}
	
	if(!zm && (!g_cvHumans.BoolValue || g_PlayerData[client].hasHuman || (g_PlayerData[client].endHuman > 0 && g_PlayerData[client].endHuman <= GetTime()))) {
		return;
	}
	
	char modelpath[PLATFORM_MAX_PATH];
	switch (g_cvTeamMode.IntValue) {
		case 0: {
			int activeClass = ZR_GetActiveClass(client);
			if(!ZR_IsValidClassIndex(activeClass)) {
				return;
			}
			
			int personalHumanClass 		= ZR_GetClassByIdentifier(g_sClassIdentifierHuman);
			int personalZombieClass 	= ZR_GetClassByIdentifier(g_sClassIdentifierZombie);
			int personalHumanClassVIP 	= ZR_GetClassByIdentifier(g_sClassIdentifierHumanVIP);
			int	personalZombieClassVIP 	= ZR_GetClassByIdentifier(g_sClassIdentifierZombieVIP);
			
			#if defined DEBUG
				LogMessage("[ZR-Personal Skins] %N has active class %d", client, activeClass);
				LogMessage("[ZR-Personal Skins] Personal human: %d", personalHumanClass);
				LogMessage("[ZR-Personal Skins] Personal zombie: %d", personalZombieClass);
				LogMessage("[ZR-Personal Skins] Personal human VIP: %d", personalHumanClassVIP);
				LogMessage("[ZR-Personal Skins] Personal zombie VIP: %d", personalZombieClassVIP);
			#endif
			
			if(zm) {
				if(activeClass != personalZombieClass && activeClass != personalZombieClassVIP) {
					return;
				}
				
				strcopy(modelpath, sizeof(modelpath), g_PlayerData[client].modelZombie);
			} else {
				if(activeClass != personalHumanClass && activeClass != personalHumanClassVIP) {
					return;
				}
				
				strcopy(modelpath, sizeof(modelpath), g_PlayerData[client].modelHuman);
			}
		}
		
		case 1: {
			if (zm)
				strcopy(modelpath, sizeof(modelpath), g_PlayerData[client].modelZombie);
			else
				strcopy(modelpath, sizeof(modelpath), g_PlayerData[client].modelHuman);
		}
		
		default: return;
	}

	// Player has a Personal-Skin but no model related to the current team or model_path wasn't set.
	if (strlen(modelpath) == 0)
		return;

	#if defined DEBUG
	LogMessage("[ZR-Personal Skins] %L new model path stored: %s", client, modelpath);
	#endif

	if (!IsModelFile(modelpath))
	{
		PrintToChat(client, "[SM] A configuration error was caught on your model, can't apply it.");
		LogError("[ZR-Personal Skins] Model extension is not an .mdl (%s)", modelpath);
		return;
	}

	// Should never happen, but to be safe attempt hotfix on the fly
	if (!IsModelPrecached(modelpath))
	{
		PrecacheModel(modelpath);
		#if defined DEBUG
		LogMessage("[ZR-Personal Skins] Model not precached, attempting an hotfix by Precaching the model on the fly.. (%s)", modelpath);
		#endif

		if (!IsModelPrecached(modelpath))
		{
			PrintToChat(client, "[SM] A technical error was caught on your model, can't apply it.");
			LogError("[ZR-Personal Skins] Model not precached, not applying model.. \"%s\"", modelpath);
			return;
		}

		#if defined DEBUG
		LogMessage("[ZR-Personal Skins] Hotfix: Model has been preached.. Yay! (%s)", modelpath);
		#endif
	}

	SetEntityModel(client, modelpath);
}

void ClearKV(KeyValues kv) {
	if(kv == null) {
		return;
	}
	
	kv.Rewind();

	if(!kv.GotoFirstSubKey()) {
		return;
	}

	do {
		kv.DeleteThis();
		kv.Rewind();
	}

	while(kv.GotoNextKey());
	kv.Rewind();
}

bool IsModelFile(char[] model) {
	char buf[4];
	GetExtension(model, buf, sizeof(buf));
	return !strcmp(buf, "mdl", false);
}

void GetExtension(char[] path, char[] buffer, int size) {
	int extpos = FindCharInString(path, '.', true);
	if (extpos == -1) {
		buffer[0] = '\0';
		return;
	}
	
	extpos++;
	strcopy(buffer, size, path[extpos]);
}