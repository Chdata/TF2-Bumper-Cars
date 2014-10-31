/*
 Bumper Car Plugin
 By: Chdata

 Thanks to Dr. McKay for the model fix.

 m_flKartNextAvailableBoost
 m_iKartHealth
 m_iKartState
 m_flTorsoScale
 m_flHandScale 

*/

#pragma semicolon 1
#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>

#define PLUGIN_VERSION "0x07"

enum
{
    _BumperCar = 82,
    _KartSpeedBoost,
    _BalloonHead,
    _SmallHeadMeleeOnly,
    _JarateSwimming,
    _NoMove,
    _NoMoveGateBlock,
    _NoMoveGateBlock2
}

new Handle:g_cvTeamOnly;
new g_iCatTeam;

new Handle:g_cvBoostTime;
new Float:g_flBoostTime;
//new Float:g_flActivateFrame[MAXPLAYERS + 1] = {-1.0,...};

new Handle:g_cvHeadScale;
new Float:g_flHeadScale;

new Handle:g_cvKeepCar;
new g_iKeepCar;

new bool:g_bKeepCar[MAXPLAYERS + 1] = {false,...};  // Whether to keep car after respawn
new bool:g_bWasDriving[MAXPLAYERS + 1] = {false,...}; // Whether to keep car after certain tf conditions are applied

public Plugin:myinfo = {
    name = "Bumpa cars",
    author = "Chdata",
    description = "Put people into bumper cars",
    version = PLUGIN_VERSION,
    url = "http://steamcommunity.com/groups/tf2data"
};

public OnPluginStart()
{
    CreateConVar(
        "cv_bumpercar_version", PLUGIN_VERSION,
        "Bumpercar Version",
        FCVAR_REPLICATED|FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY
    );

    g_cvTeamOnly = CreateConVar(
        "cv_bumpercar_teamonly", "0",
        "0 = Anyone can enter bumper cars via command | 2 = Only red | 3 = Only blu | Anything else = Anyone can",
        FCVAR_PLUGIN|FCVAR_NOTIFY,
        true, 0.0, true, 3.0
    );

    g_cvBoostTime = CreateConVar(
        "cv_bumpercar_boosttime", "1.5",
        "Boost duration for any boosts. -1.0 = infinite until right mouse clicked again. 0.0 = disable boosting",
        FCVAR_PLUGIN|FCVAR_NOTIFY,
        true, -1.0, true, 999999.0
    );

    g_cvHeadScale = CreateConVar(
        "cv_bumpercar_headscale", "3.0",
        "Player head scale when put into a bumper car.",
        FCVAR_PLUGIN|FCVAR_NOTIFY,
        true, 0.1, true, 3.0
    );

    g_cvKeepCar = CreateConVar(
        "cv_bumpercar_respawn", "1",
        "1 = Keep car on respawn | 0 = Lose car after death | 2 = Everyone automagically spawns in a car all the time",
        FCVAR_PLUGIN|FCVAR_NOTIFY,
        true, 0.0, true, 2.0
    );

    HookConVarChange(g_cvTeamOnly, CvarChange);
    HookConVarChange(g_cvBoostTime, CvarChange);
    HookConVarChange(g_cvHeadScale, CvarChange);
    HookConVarChange(g_cvKeepCar, CvarChange);

    HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_PostNoCopy);

    AutoExecConfig(true, "plugin.bumpercar");

    RegAdminCmd("sm_bumpercar", Command_BumperCar, 0, "sm_car <noparam|#userid|name> <noparam|on|off> - Toggles bumper car on all targets or self");
    RegAdminCmd("sm_car", Command_BumperCar, 0, "sm_car <noparam|#userid|name> <noparam|on|off> - Toggles bumper car on all targets or self");

    AddMultiTargetFilter("@cars", CarTargetFilter, "all drivers", false);
    AddMultiTargetFilter("@!cars", CarTargetFilter, "all non-drivers", false);

    LoadTranslations("common.phrases");

    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }
}

public OnConfigsExecuted()
{
    g_iCatTeam = GetConVarInt(g_cvTeamOnly);
    g_flBoostTime = GetConVarFloat(g_cvBoostTime);
    if (g_flBoostTime < 0)
    {
        g_flBoostTime = -1.0;
    }

    g_flHeadScale = GetConVarFloat(g_cvHeadScale);
    g_iKeepCar = GetConVarInt(g_cvKeepCar);
}

public CvarChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
    if (hCvar == g_cvTeamOnly)
    {
        g_iCatTeam = GetConVarInt(g_cvTeamOnly);
    }
    else if (hCvar == g_cvBoostTime)
    {
        g_flBoostTime = GetConVarFloat(g_cvBoostTime);
        if (g_flBoostTime < 0)
        {
            g_flBoostTime = -1.0;
        }
    }
    else if (hCvar == g_cvHeadScale)
    {
        g_flHeadScale = GetConVarFloat(g_cvHeadScale);
    }
    else if (hCvar == g_cvKeepCar)
    {
        g_iKeepCar = GetConVarInt(g_cvKeepCar);
    }
}

public OnClientPostAdminCheck(client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(iVictim, &iAtker, &iInflictor, &Float:flDamage, &iDmgType, &iWeapon, Float:vDmgForce[3], Float:vDmgPos[3], iDmgCustom)
{
    if (IsValidClient(iVictim))
    {
        if (TF2_IsPlayerInCondition(iVictim, TFCond:_BumperCar))
        {
            decl String:s[16];
            GetEdictClassname(iAtker, s, sizeof(s));
            if (StrEqual(s, "trigger_hurt", false))
            {
                ForcePlayerSuicide(iVictim);
            }
        }
        else if (IsValidClient(iAtker) && !TF2_IsPlayerInCondition(iVictim, TFCond:_BumperCar) && TF2_IsPlayerInCondition(iAtker, TFCond:_BumperCar))
        {
            flDamage *= 2.0;
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}

public OnMapStart()
{
    PrecacheModel("models/player/items/taunts/bumpercar/parts/bumpercar.mdl");
    PrecacheModel("models/player/items/taunts/bumpercar/parts/bumpercar_nolights.mdl");

    PrecacheSound("weapons/bumper_car_speed_boost_start.wav", true);
    PrecacheSound("weapons/bumper_car_speed_boost_stop.wav", true);

    //PrecacheSound("weapons/buffed_off.wav", true);
    //PrecacheSound("weapons/buffed_on.wav"", true);

    PrecacheSound("weapons/bumper_car_hit_ball.wav", true);
    PrecacheSound("weapons/bumper_car_hit_ghost.wav", true);
    PrecacheSound("weapons/bumper_car_hit_hard.wav", true);
    PrecacheSound("weapons/bumper_car_hit_into_air.wav", true);
    PrecacheSound("weapons/bumper_car_spawn.wav", true);
    PrecacheSound("weapons/bumper_car_spawn_from_lava.wav", true);

    PrecacheSound("weapons/bumper_car_accelerate.wav", true); // These seem to already always work.
    PrecacheSound("weapons/bumper_car_decelerate.wav", true); // Except not for people other than me? lul
    PrecacheSound("weapons/bumper_car_decelerate_quick.wav", true);
    PrecacheSound("weapons/bumper_car_go_loop.wav", true);
    PrecacheSound("weapons/bumper_car_hit1.wav", true);
    PrecacheSound("weapons/bumper_car_hit2.wav", true);
    PrecacheSound("weapons/bumper_car_hit3.wav", true);
    PrecacheSound("weapons/bumper_car_hit4.wav", true);
    PrecacheSound("weapons/bumper_car_hit5.wav", true);
    PrecacheSound("weapons/bumper_car_hit6.wav", true);
    PrecacheSound("weapons/bumper_car_hit7.wav", true);
    PrecacheSound("weapons/bumper_car_hit8.wav", true);
    PrecacheSound("weapons/bumper_car_jump.wav", true);
    PrecacheSound("weapons/bumper_car_jump_land.wav", true);
    PrecacheSound("weapons/bumper_car_screech.wav", true);
}

public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if (g_iKeepCar != 0 && (g_bKeepCar[client] || g_iKeepCar == 2))
    {
        TryEnterCar(client);
        g_bWasDriving[client] = true;
    }
}

public bool:CarTargetFilter(const String:pattern[], Handle:clients)
{
    new bool:non = pattern[1] == '!';
    for (new client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && IsPlayerAlive(client) && FindValueInArray(clients, client) == -1)
        {
            if (TF2_IsPlayerInCondition(client, TFCond:_BumperCar))
            {
                if (!non)
                {
                    PushArrayCell(clients, client);
                }
            }
            else if (non)
            {
                PushArrayCell(clients, client);
            }
        }
    }

    return true;
}

public TF2_OnConditionAdded(client, TFCond:cond)
{
    switch (cond)
    {
        case (TFCond:_JarateSwimming), TFCond_Taunting:
        {
            if (TF2_IsPlayerInCondition(client, TFCond:_BumperCar))
            {
                g_bWasDriving[client] = true;
                TF2_RemoveCondition(client, TFCond:_BumperCar);
            }
            else
            {
                g_bWasDriving[client] = false;
            }
        }
        case (TFCond:_BumperCar):
        {
            if (g_flHeadScale != 3.0)
            {
                SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
            }
            //RequestFrame(Post_CarEnable, GetClientUserId(client));
        }
        case (TFCond:_KartSpeedBoost):
        {
            if (g_flBoostTime != 1.5)
            {
                TF2_RemoveCondition(client, TFCond:_KartSpeedBoost);
                if (g_flBoostTime != 0.0)
                {
                    TF2_AddCondition(client, TFCond:_KartSpeedBoost, g_flBoostTime);

                    if (g_flBoostTime == -1.0)
                    {
                        SetEntPropFloat(client, Prop_Send, "m_flKartNextAvailableBoost", GetGameTime()+999999.0);
                    }
                    else
                    {
                        SetEntPropFloat(client, Prop_Send, "m_flKartNextAvailableBoost", GetGameTime()+g_flBoostTime);
                    }
                }
            }
        }
    }
}

/*public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
    if (bool:(buttons & IN_ATTACK2) && g_flBoostTime < 0 && (GetGameTime() - g_flActivateFrame[client])>0.5)
    {
        TF2_RemoveCondition(client, TFCond:_KartSpeedBoost);
        SetEntPropFloat(client, Prop_Send, "m_flKartNextAvailableBoost", GetGameTime());
        g_flActivateFrame[client] = GetGameTime();
    }
}*/

/*public Post_CarEnable(any:data)
{
    new client = GetClientOfUserId(data);
    if (0 < client && client <= MaxClients && IsClientInGame(client))
    {
        SetEntPropFloat(client, Prop_Send, "m_flHeadScale", g_flHeadScale);
    }
}*/

public TF2_OnConditionRemoved(client, TFCond:cond)
{
    switch (cond)
    {
        case (TFCond:_JarateSwimming), TFCond_Taunting:
        {
            if (g_bWasDriving[client])
            {
                TryEnterCar(client);
                //TF2_AddCondition(client, TFCond:_BumperCar, TFCondDuration_Infinite);
            }
        }
        case (TFCond:_BumperCar):
        {
            SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
        }
        case (TFCond:_KartSpeedBoost):
        {
            if (g_flBoostTime < 0)
            {
                SetEntPropFloat(client, Prop_Send, "m_flKartNextAvailableBoost", GetGameTime());
            }
        }
    }
}

public OnPostThinkPost(client)
{
    SetEntPropFloat(client, Prop_Send, "m_flHeadScale", g_flHeadScale);
}

public Action:Command_BumperCar(client, argc)
{
    if (argc == 0)
    {
        if (!client)
        {
            ReplyToCommand(client, "[SM] Console cannot ride in bumper cars.");
            return Plugin_Handled;
        }

        if (!CheckCommandAccess(client, "adm_bumpercar_self", 0))
        {
            ReplyToCommand(client, "[SM] %t.", "No Access");
            return Plugin_Handled;
        }

        g_bKeepCar[client] = SelfEnterCar(client);
        g_bWasDriving[client] = g_bKeepCar[client];

        return Plugin_Handled;
    }
    else
    {
        new fFlags = COMMAND_FILTER_CONNECTED;

        if (argc == 1)
        {
            fFlags |= COMMAND_FILTER_NO_MULTI;
        }

        decl String:arg1[32];
        GetCmdArg(1, arg1, sizeof(arg1));

        new bool:bSelf = StrEqual(arg1, "@me");

        if (!bSelf && !CheckCommandAccess(client, "adm_bumpercar_target", ADMFLAG_CHEATS)) // If targeting someone else
        {
            ReplyToCommand(client, "[SM] You do not have access to targeting others.");
            return Plugin_Handled;
        }
        else if (bSelf && !CheckCommandAccess(client, "adm_bumpercar_self", 0))
        {
            ReplyToCommand(client, "[SM] %t.", "No Access");
            return Plugin_Handled;
        }

        if (bSelf)
        {
            g_bKeepCar[client] = SelfEnterCar(client);
            g_bWasDriving[client] = g_bKeepCar[client];
            return Plugin_Handled;
        }

        decl String:target_name[MAX_TARGET_LENGTH];
        decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
        
        if ((target_count = ProcessTargetString(
                arg1,
                client, 
                target_list, 
                MAXPLAYERS, 
                fFlags,
                target_name,
                sizeof(target_name),
                tn_is_ml)) > 0)
        {
            decl String:arg2[80];
            GetCmdArg(2, arg2, sizeof(arg2));

            decl bool:bOn;

            if (target_count == 1)
            {
                if (argc == 1)
                {
                    bOn = !TF2_IsPlayerInCondition(target_list[0], TFCond:_BumperCar);
                }
                else
                {
                    bOn = (StrEqual(arg2, "on") || arg2[0] == '1');
                }
                
                if (target_list[0] == client)
                {
                    g_bKeepCar[client] = SelfEnterCar(client); // _:bOn
                    g_bWasDriving[client] = g_bKeepCar[client];
                    return Plugin_Handled;
                }
            }
            else if (target_count > 1 && argc < 2)
            {
                ReplyToCommand(client, "[SM] Usage: sm_car - Specify <on|off> when multi-targeting");
                return Plugin_Handled;
            }
            else
            {
                bOn = (StrEqual(arg2, "on") || arg2[0] == '1');
            }

            // IntToString(_:bOn, arg2, sizeof(arg2));

            for (new i = 0; i < target_count; i++)
            {
                if (bOn)
                {
                    if (IsPlayerAlive(target_list[i]))
                    {
                        TryEnterCar(target_list[i]);
                    }
                    g_bKeepCar[target_list[i]] = true;
                    g_bWasDriving[target_list[i]] = true;
                }
                else
                {
                    TF2_RemoveCondition(target_list[i], TFCond:_BumperCar);
                    g_bKeepCar[target_list[i]] = false;
                    g_bWasDriving[target_list[i]] = false;
                }

                //if (AreClientCookiesCached(target_list[i]))
                //{
                //    SetClientCookie(target_list[i], g_cCarCookie, arg2);
                //}
            }
            
            ShowActivity2(client, "[SM] ", "%sed bumper car on %s.", !bOn?"Remov":"Add", target_name);

            //if (GetConVarBool(g_cvLogs))
            //{
            //    LogAction(client, target_list[0], "\"%L\" %sed bumper car on \"%L\"", client, bOn?"remov":"add", target_list[0]);
            //}
        }
        else
        {
            ReplyToTargetError(client, target_count);
        }

    }

    return Plugin_Handled;
}

stock bool:TryEnterCar(client)
{
    if (!TF2_IsPlayerInCondition(client, TFCond:_JarateSwimming) && !TF2_IsPlayerInCondition(client, TFCond_HalloweenGhostMode) && !TF2_IsPlayerInCondition(client, TFCond_Taunting))
    {
        if ((g_iCatTeam == 2 || g_iCatTeam == 3) && GetClientTeam(client) != g_iCatTeam)
        {
            return false;
        }

        TF2_AddCondition(client, TFCond:_BumperCar, TFCondDuration_Infinite);
        return true;
    }
    return false;
}

stock bool:SelfEnterCar(client) // , iOn=-1
{
    if ((g_iCatTeam == 2 || g_iCatTeam == 3) && GetClientTeam(client) != g_iCatTeam)
    {
        ReplyToCommand(client, "[SM] Only %s team can toggle riding bumper cars.", g_iCatTeam == 2 ? "red" : "blu");
        return false;
    }

    if (!IsPlayerAlive(client))
    {
        ReplyToCommand(client, "[SM] You must be alive to ride bumper cars.");
        return false;
    }

    /*if (iOn != -1)
    {
        if (bool:iOn)
        {
            if (TF2_IsPlayerInCondition(client, TFCond:_BumperCar))
            {
                ReplyToCommand(client, "[SM] You are now still riding a bumper car!");
            }
            else
            {
                if (TryEnterCar(client))
                {
                    ReplyToCommand(client, "[SM] You are now riding a bumper car!");
                }
                else
                {
                    ReplyToCommand(client, "[SM] You can't ride a bumper car in your current state.");
                }
            }
        }
        else
        {
            // lol this is silly
        }

        return;
    }*/

    if (TF2_IsPlayerInCondition(client, TFCond:_BumperCar))
    {
        TF2_RemoveCondition(client, TFCond:_BumperCar);
        ReplyToCommand(client, "[SM] You have exited your bumper car.");
    }
    else
    {
        if (TryEnterCar(client))
        {
            ReplyToCommand(client, "[SM] You are now riding a bumper car!");
            return true;
        }
        else
        {
            ReplyToCommand(client, "[SM] You can't ride a bumper car in your current state.");
        }
    }
    return false;
}

stock bool:IsValidClient(iClient)
{
    if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient)) return false;
    if (GetEntProp(iClient, Prop_Send, "m_bIsCoaching")) return false;
    return true;
}

/*
void CTFPlayer::PrecacheKart()
{
  CBaseEntity::PrecacheModel("models/player/items/taunts/bumpercar/parts/bumpercar.mdl", 1);
  CBaseEntity::PrecacheModel("models/props_halloween/bumpercar_cage.mdl", 1);
  
  CBaseEntity::PrecacheScriptSound("BumperCar.Spawn");
  CBaseEntity::PrecacheScriptSound("BumperCar.SpawnFromLava");
  CBaseEntity::PrecacheScriptSound("BumperCar.GoLoop");
  CBaseEntity::PrecacheScriptSound("BumperCar.Screech");
  CBaseEntity::PrecacheScriptSound("BumperCar.HitGhost");
  CBaseEntity::PrecacheScriptSound("BumperCar.Bump");
  CBaseEntity::PrecacheScriptSound("BumperCar.Bump");
  CBaseEntity::PrecacheScriptSound("BumperCar.BumpIntoAir");
  CBaseEntity::PrecacheScriptSound("BumperCar.SpeedBoostStart");
  CBaseEntity::PrecacheScriptSound("BumperCar.SpeedBoostStop");
  CBaseEntity::PrecacheScriptSound("BumperCar.Jump");
  CBaseEntity::PrecacheScriptSound("BumperCar.JumpLand");
  CBaseEntity::PrecacheScriptSound("sf14.Merasmus.DuckHunt.BonusDucks");
  
  PrecacheParticleSystem("kartimpacttrail");
  PrecacheParticleSystem("kart_dust_trail_red");
  PrecacheParticleSystem("kart_dust_trail_blue");
  
  return PrecacheParticleSystem("kartdamage_4");
}


*/