sm-plugin-ZR_PersonalSkins
> [!IMPORTANT]
> This version is using SourceMod group and playerclasses (!zclass) to access to Personal Skin

Create the admin group: `sourcemod/configs/admin_groups.cfg`
```
"Personal-Skins"
{
    "immunity" "0"
}
```
Exemple to use in `playerclasses.txt`
```
"personalskin_zombie"
{
    // General
    "enabled"               "yes"
    "team"                  "0"
    "team_default"          "no"
    "flags"                 "0"
    "group"                 "Personal-Skin-Zombie"
    
    "name"                  "Personal Skin"
    "description"           "Your private skin"
    
    // Model
    "model_path"            "models/player/pil/classic.mdl"
    "alpha_initial"         "255"
    "alpha_damaged"         "255"
    "alpha_damage"          "20000"
    
    // Hud
    "overlay_path"          ""
    "nvgs"                  "no"
    "fov"                   "90"
    
    // Effects
    "has_napalm"            "no"
    "napalm_time"           "5.0"
    
    // Player behavior
    "immunity_mode"         "none"
    "immunity_amount"       "0"
    "immunity_cooldown"     "60"
    "no_fall_damage"        "yes"
    
    "health"                "8000"
    "health_regen_interval" "1"
    "health_regen_amount"   "100"
    "health_infect_gain"    "500"
    "kill_bonus"            "2"
    
    "speed"                 "370"
    "knockback"             "3.2"
    "jump_height"           "1.15"
    "jump_distance"         "1.05"
}
```