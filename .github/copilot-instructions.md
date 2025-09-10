# Copilot Instructions for ZR Personal Skins Plugin

## Repository Overview

This repository contains a **SourceMod plugin** for **Zombie Reloaded** that provides personal skin functionality for CS:S/CS:GO servers. Players with appropriate permissions can have custom zombie and human models applied automatically based on their Steam ID, IP, or name.

### Key Facts
- **Language**: SourcePawn (Source Engine scripting language)
- **Platform**: SourceMod 1.11.0+ (latest stable recommended)
- **Target Game**: Counter-Strike: Source / Counter-Strike: Global Offensive
- **Plugin Type**: Zombie Reloaded extension
- **Build System**: SourceKnight (configured in `sourceknight.yaml`)

## Architecture & Core Components

### Main Plugin File
- `addons/sourcemod/scripting/zr_personal_skins.sp` - Main plugin source (435 lines)
- Implements personal skin system using Zombie Reloaded class system
- Supports both class-based and team-based validation modes
- Includes VIP functionality with separate class identifiers

### Configuration Files
- `addons/sourcemod/data/zr_personal_skins.txt` - KeyValues format skin assignments
- `addons/sourcemod/configs/zr_personalskins_downloadslist.txt` - FastDL file list
- AutoExecConfig generates: `cfg/zombiereloaded/zr_personal_skins.cfg`

### Key Dependencies (managed by SourceKnight)
- `sourcemod` (1.11.0-git6934 or newer)
- `multicolors` - Enhanced chat color support
- `zombiereloaded` - Required base mod
- `smlib` - Common utility functions
- `utilshelper` - Additional utilities

## SourcePawn Development Standards

### Code Style (STRICTLY ENFORCED)
```sourcepawn
#pragma semicolon 1          // Always required
#pragma newdecls required    // Always required

// Indentation: tabs converted to 4 spaces
// Variable naming:
bool g_bGlobalVariable;      // Global vars: g_ prefix, camelCase
int iLocalVariable;          // Local vars: type prefix, camelCase
char sStringBuffer[256];     // Strings: s prefix
ConVar cvMyConVar;           // ConVars: cv prefix

// Function naming: PascalCase
public void OnPluginStart()
void MyCustomFunction()
```

### Memory Management (CRITICAL)
```sourcepawn
// CORRECT memory management
KeyValues kv = new KeyValues("root");
// ... use kv
delete kv;  // Always delete, never check null first

// NEVER use .Clear() - creates memory leaks
// StringMap map = new StringMap();
// map.Clear(); // ❌ WRONG - memory leak
// delete map;  // ✅ CORRECT
// map = new StringMap(); // ✅ Create new instance

// SQL operations - ALWAYS async
Database.Query(MyCallback, "SELECT * FROM table WHERE id = %d", clientId);
```

### Required Patterns
- All SQL queries MUST be asynchronous using methodmap
- Use StringMap/ArrayList instead of basic arrays when possible
- Implement proper error handling for all API calls
- Use translation files for user-facing messages
- Follow event-driven programming model

## Build System & Workflow

### SourceKnight Build System
```yaml
# sourceknight.yaml configures:
# - Dependencies (SourceMod, includes)
# - Build targets
# - Output paths
```

### Building the Plugin
```bash
# CI/CD uses SourceKnight action:
# maxime1907/action-sourceknight@v1

# Local development would use:
# sourceknight build
```

### Testing Strategy
- **No automated tests** - manual testing on development server required
- Test on CS:S/CS:GO development server with Zombie Reloaded
- Validate skin application with different permission levels
- Check memory usage with SourceMod profiler
- Test FastDL file downloads

## Plugin-Specific Architecture

### Core Functionality Flow
1. **OnPluginStart()** - Initialize ConVars, register commands
2. **OnConfigsExecuted()** - Load skin configurations from KeyValues file
3. **OnClientPostAdminFilter()** - Check client permissions and load personal skins
4. **ZR_OnClassAttributesApplied()** - Apply skin when ZR class changes
5. **OnClientDisconnect()** - Clean up client data

### Key Global Variables
```sourcepawn
// Permission tracking
bool g_bHasPersonalSkinsZombie[MAXPLAYERS + 1];
bool g_bHasPersonalSkinsHuman[MAXPLAYERS + 1];

// Model paths per client
char g_sPlayerModelZombie[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_sPlayerModelHuman[MAXPLAYERS+1][PLATFORM_MAX_PATH];

// Configuration
KeyValues g_KV;  // Skin assignments from file
```

### Configuration System
- **Two modes**: Class identifier validation OR team-based validation
- **ConVar**: `zr_personalskins_team_mode` (0=class, 1=team)
- **VIP Support**: Separate class identifiers for VIP players
- **Hot-reload**: Admin command `zr_pskins_reload` for config changes

## Common Tasks & Patterns

### Adding New ConVars
```sourcepawn
ConVar g_cvNewSetting;

public void OnPluginStart() {
    g_cvNewSetting = CreateConVar("zr_ps_newsetting", "1", "Description", 
                                  _, true, 0.0, true, 1.0);
    g_cvNewSetting.AddChangeHook(CvarChanges);
    AutoExecConfig(true, "zr_personal_skins", "zombiereloaded");
}

public void CvarChanges(ConVar convar, const char[] oldValue, const char[] newValue) {
    if (convar == g_cvNewSetting) {
        // Handle change
    }
}
```

### File Operations
```sourcepawn
// Always check file existence
if (!FileExists(path, false)) {
    LogError("File not found: %s", path);
    return;
}

// Use KeyValues for structured data
KeyValues kv = new KeyValues("root");
if (!kv.ImportFromFile(path)) {
    SetFailState("Failed to load: %s", path);
    delete kv;
    return;
}
```

### Client Permission Checking
```sourcepawn
// Check admin flags (this plugin uses Custom5 flag)
if (CheckCommandAccess(client, "", ADMFLAG_CUSTOM5)) {
    // Grant permission
}

// Integration with ZR class system
int activeClass = ZR_GetActiveClass(client);
int personalClass = ZR_GetClassByIdentifier("Personal-Skin-Zombie");
if (activeClass == personalClass) {
    // Apply personal skin
}
```

## Critical Gotchas & Warnings

### SourcePawn-Specific Issues
- **String handling**: Always specify buffer sizes, use `strcopy()` not `=`
- **Array bounds**: MAXPLAYERS+1 for client arrays (index 0 unused)
- **Model validation**: Check file extension and precache status
- **Timer cleanup**: Cancel timers on plugin unload/map change

### ZR Integration Gotchas
- ZR class changes can happen multiple times per round
- Model application timing is critical (after ZR sets base model)
- Class identifiers are case-sensitive
- ZR_IsClientZombie/Human may return wrong values during infection

### Performance Considerations
- Minimize operations in `ZR_OnClassAttributesApplied` (called frequently)
- Cache ZR class lookups when possible
- Avoid string operations in hot paths
- Use debug builds for development only (`#define DEBUG`)

## Debugging & Troubleshooting

### Debug Mode
```sourcepawn
#define DEBUG  // Uncomment for verbose logging

// Provides detailed logs for:
// - Class assignments
// - Model path resolution
// - Precaching operations
```

### Common Issues
1. **Model not applied**: Check file extension, precache status, ZR class timing
2. **Permission errors**: Verify admin flags, ZR class configuration
3. **File not found**: Check paths in ConVars, file permissions
4. **Memory leaks**: Ensure KeyValues are deleted, avoid .Clear() on StringMap

### Validation Commands
- `zr_pskins_reload` - Reload configuration (ADMFLAG_ROOT)
- `sm_pskin` - Check personal skin status (console command)

## Deployment & Release

### File Structure for Deployment
```
addons/sourcemod/
├── plugins/zr_personal_skins.smx
├── configs/zr_personalskins_downloadslist.txt
├── data/zr_personal_skins.txt
└── cfg/zombiereloaded/zr_personal_skins.cfg (auto-generated)
```

### Version Management
- Use semantic versioning in plugin info
- Update version in `myinfo` structure
- Tag releases for CI/CD automation
- Maintain compatibility with SourceMod 1.11+

## Quick Reference

### Essential SourceMod APIs Used
- `CreateConVar()`, `AutoExecConfig()` - Configuration
- `RegAdminCmd()`, `RegConsoleCmd()` - Commands  
- `SetEntityModel()`, `PrecacheModel()` - Model handling
- `CheckCommandAccess()` - Permission checking
- `KeyValues` - Configuration file parsing

### ZR APIs Used
- `ZR_GetActiveClass()`, `ZR_IsValidClassIndex()`
- `ZR_GetClassByIdentifier()`
- `ZR_IsClientZombie()`, `ZR_IsClientHuman()`
- `ZR_OnClassAttributesApplied()` forward

### Performance Notes
- Plugin handles up to 64 clients (MAXPLAYERS)
- KeyValues reloaded only on map change or admin command
- Model paths cached per client for quick lookup
- Minimal memory footprint with proper cleanup