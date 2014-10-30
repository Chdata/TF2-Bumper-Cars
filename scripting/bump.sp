/*
 Bumper Car Plugin
 By: Chdata

 Thanks to Dr. McKay for the model fix.

*/

#pragma semicolon 1
#include <sourcemod>
#include <tf2_stocks>
//#include <sdkhooks>

#define PLUGIN_VERSION "0x02"

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
new iCatTeam;

new bool:bWasDriving[MAXPLAYERS + 1] = {false,...};

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

    HookConVarChange(g_cvTeamOnly, CvarChange);

    AutoExecConfig(true, "plugin.bumpercar");

    RegAdminCmd("sm_bumpercar", Command_BumperCar, 0, "sm_car <noparam|#userid|name> <noparam|on|off> - Toggles bumper car on all targets or self");
    RegAdminCmd("sm_car", Command_BumperCar, 0, "sm_car <noparam|#userid|name> <noparam|on|off> - Toggles bumper car on all targets or self");

    AddMultiTargetFilter("@cars", CarTargetFilter, "all drivers", false);
    AddMultiTargetFilter("@!cars", CarTargetFilter, "all non-drivers", false);

    LoadTranslations("common.phrases");
}

public OnConfigsExecuted()
{
    iCatTeam = GetConVarInt(g_cvTeamOnly);
}

public CvarChange(Handle:hCvar, const String:oldValue[], const String:newValue[])
{
    if (hCvar == g_cvTeamOnly)
    {
        iCatTeam = GetConVarInt(hCvar);
    }
}

public OnMapStart()
{
    PrecacheModel("models/player/items/taunts/bumpercar/parts/bumpercar.mdl");
    PrecacheModel("models/player/items/taunts/bumpercar/parts/bumpercar_nolights.mdl");
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
    if (cond == TFCond:_JarateSwimming)
    {
        if (TF2_IsPlayerInCondition(client, TFCond:_BumperCar))
        {
            bWasDriving[client] = true;
            TF2_RemoveCondition(client, TFCond:_BumperCar);
        }
        else
        {
            bWasDriving[client] = false;
        }
    }
}

public TF2_OnConditionRemoved(client, TFCond:cond)
{
    if (cond == TFCond:_JarateSwimming)
    {
        if (bWasDriving[client] && !TF2_IsPlayerInCondition(client, TFCond_HalloweenGhostMode))
        {
            TF2_AddCondition(client, TFCond:_BumperCar, TFCondDuration_Infinite);
        }
    }
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

        SelfEnterCar(client);

        return Plugin_Handled;
    }
    else
    {
        new fFlags = COMMAND_FILTER_CONNECTED|COMMAND_FILTER_ALIVE;

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
            SelfEnterCar(client);
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
                bOn = !TF2_IsPlayerInCondition(target_list[0], TFCond:_BumperCar);

                if (target_list[0] == client)
                {
                    SelfEnterCar(client);
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
                    TryEnterCar(target_list[i]);
                }
                else
                {
                    TF2_RemoveCondition(target_list[i], TFCond:_BumperCar);
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
    if (!TF2_IsPlayerInCondition(client, TFCond:_JarateSwimming) && !TF2_IsPlayerInCondition(client, TFCond_HalloweenGhostMode))
    {
        TF2_AddCondition(client, TFCond:_BumperCar, TFCondDuration_Infinite);
        return true;
    }
    return false;
}

stock SelfEnterCar(client)
{
    if ((iCatTeam == 2 || iCatTeam == 3) && GetClientTeam(client) != iCatTeam)
    {
        ReplyToCommand(client, "[SM] Only %s team can toggle riding bumper cars.", iCatTeam == 2 ? "red" : "blu");
        return;
    }

    if (!IsPlayerAlive(client))
    {
        ReplyToCommand(client, "[SM] You must be alive to ride bumper cars.");
        return;
    }

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
        }
        else
        {
            ReplyToCommand(client, "[SM] You can't ride a bumper car in your current state.");
        }
    }
}