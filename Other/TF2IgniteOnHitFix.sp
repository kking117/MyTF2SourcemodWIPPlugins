#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <tf2attributes>

new LastDamageType[MAXPLAYERS+1]; //the last damagebits that hurt the player
new LastWeapon[MAXPLAYERS+1]; //the last weapon that hurt the player
new String:LastProjectile[MAXPLAYERS+1][255]; //the last entity that hurt the player

new BurnRef[MAXPLAYERS+1]; //the weapon that owns the burn
new BurnId[MAXPLAYERS+1]; //the client that owns the burn
new Float:LastReBurn[MAXPLAYERS+1];
new Float:ReBurn[MAXPLAYERS+1];
new Float:BurnDur[MAXPLAYERS+1];
new Float:BurnDmg[MAXPLAYERS+1];
//burns override burns unlike bleed, this means we don't have to track by slot

public Plugin myinfo = 
{
	name = "TF2 Ignite On Hit Fix",
	author = "kking117",
	description = "A simple fix that should've been done properly by the devs in the first place."
};

public void OnPluginStart()
{
	HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
	ClearBurnArrays(client);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(IsValidClient(client))
	{
		if(BurnDur[client]>=GetGameTime())
		{
			if(ReBurn[client]<=GetGameTime())
			{
				ReBurnTarget(client);
			}
		}
		else
		{
			if(BurnDur[client]>0.0)
			{
				TF2_RemoveCondition(client, TFCond_OnFire);
			}
		}
	}
	return Plugin_Continue;
}

public Action:OnTakeDamage(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	new String:weaponname[256];
	if(IsValidClient(client))
	{
		if(IsValidEntity(weapon))
		{
			GetEntityClassname(weapon, weaponname, sizeof(weaponname));
		}
		if((damagetype & DMG_BURN) && (damagetype & DMG_PREVENT_PHYSICS_FORCE))
		{
			if(IsValidClient(attacker))
			{
				new flamer = EntRefToEntIndex(BurnRef[client]);
				if(IsValidEntity(flamer))
				{
					GetEntityClassname(flamer, weaponname, sizeof(weaponname));
					if(StrContains(weaponname, "tf_weapon_")>=0)
					{
						damage *= BurnDmg[client];
						weapon = flamer;
						if(TF2_IsPlayerInCondition(client, TFCond_OnFire))
						{
							damage *= EntityAttribVal(flamer, 795, 1.0);
							if(EntityAttribVal(flamer, 20, 0.0)!=0.0)
							{
								damagetype |= DMG_ACID;
							}
						}
						if(TF2_IsPlayerInCondition(client, TFCond_Dazed))
						{
							if(EntityAttribVal(flamer, 437, 0.0)!=0.0)
							{
								damagetype |= DMG_ACID;
							}
						}
						else
						{
							damage *= EntityAttribVal(flamer, 39, 1.0);
						}
						if(IsWet(client))
						{
							if(EntityAttribVal(flamer, 438, 0.0)!=0.0)
							{
								damagetype |= DMG_ACID;
							}
						}
						if(TF2_IsPlayerInCondition(client, TFCond_Disguised))
						{
							damage *= EntityAttribVal(flamer, 410, 1.0);
						}
						damage *= EntityAttribVal(flamer, 138, 1.0);
						damage *= EntityAttribVal(flamer, 71, 1.0);
						damage *= EntityAttribVal(flamer, 72, 1.0);
						flamer = GetClientOfUserId(BurnId[client]);
						if(IsValidClient(flamer))
						{
							if(TF2_IsPlayerInCondition(client, TFCond_OnFire))
							{
								damage *= EntityAttribVal(flamer, 795, 1.0);
								if(EntityAttribVal(flamer, 20, 0.0)!=0.0)
								{
									damagetype |= DMG_ACID;
								}
							}
							if(TF2_IsPlayerInCondition(client, TFCond_Dazed))
							{
								if(EntityAttribVal(flamer, 437, 0.0)!=0.0)
								{
									damagetype |= DMG_ACID;
								}
							}
							else
							{
								damage *= EntityAttribVal(flamer, 39, 1.0);
							}
							if(IsWet(client))
							{
								if(EntityAttribVal(flamer, 438, 0.0)!=0.0)
								{
									damagetype |= DMG_ACID;
								}
							}
							if(TF2_IsPlayerInCondition(client, TFCond_Disguised))
							{
								damage *= EntityAttribVal(flamer, 410, 1.0);
							}
							damage *= EntityAttribVal(flamer, 138, 1.0);
							damage *= EntityAttribVal(flamer, 71, 1.0);
							damage *= EntityAttribVal(flamer, 72, 1.0);
						}
					}
				}
			}
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action:OnTakeDamageAlive(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	new String:weaponname[256];
	if(IsValidClient(client))
	{
		LastDamageType[client] = damagetype;
		if(IsValidEntity(weapon))
		{
			LastWeapon[client] = EntIndexToEntRef(weapon);
		}
		else
		{
			LastWeapon[client] = -1;
		}
		Format(LastProjectile[client], 255, "");
		if(IsValidEntity(inflictor))
		{
			if(IsValidClient(inflictor))
			{
			}
			else
			{
				if(HasEntProp(inflictor, Prop_Data, "m_hOwnerEntity"))
				{
					GetEntityClassname(inflictor, weaponname, sizeof(weaponname));
					Format(LastProjectile[client], 255, weaponname);
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:OnPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker=GetClientOfUserId(GetEventInt(event, "attacker"));
	new damage=GetEventInt(event, "damageamount");
	new weapon = EntRefToEntIndex(LastWeapon[client]);
	new String:wepname[256];
	if(IsValidEntity(weapon))
	{
		GetEntityClassname(weapon, wepname, sizeof(wepname));
	}
	if(IsValidClient(attacker))
	{
		if(IsDirectDmg(LastDamageType[client], LastProjectile[client]))
		{	
			if(StrContains(wepname, "tf_weapon_")>=0)
			{
				if(StrEqual(wepname, "tf_weapon_flamethrower"))
				{
				}
				else if(StrEqual(wepname, "tf_weapon_rocketlauncher_fireball"))
				{
				}
				else if(StrEqual(wepname, "tf_weapon_compound_bow"))
				{
					//because arrows can be ignited they have a proper ignite duration
				}
				else if(StrEqual(wepname, "tf_weapon_particle_cannon")) 
				{
					//the cowmangler's charge shot means this weapon is coded with a proper ignite duration
					//however its duration is 6 seconds instead of 7.5 seconds (48 vs 60 damage) unlike the others
				}
				else if(StrEqual(wepname, "tf_weapon_fireaxe"))
				{
					//sharpened volcano fragment is the reason this has an ignite duration
				}
				else
				{
					if(EntityAttribVal(weapon, 208, 0.0)!=0.0)
					{
						BurnTarget(attacker, client, weapon);
					}
				}
			}
		}
	}
}

public Action:OnPlayerDeath(Handle:event, const String:eventName[], bool:dontBroadcast)
{
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker=GetClientOfUserId(GetEventInt(event, "attacker"));
	new damagetype = GetEventInt(event, "damagebits");
	new String:WeaponName[128];
	GetEventString(event, "weapon", WeaponName, 128);
	ClearBurnArrays(client);
	new weapon = EntRefToEntIndex(LastWeapon[client]);
	if((damagetype & DMG_PREVENT_PHYSICS_FORCE) && (damagetype & DMG_BURN))
	{
		SetEventString(event, "weapon", "flamethrower");
	}
	return Plugin_Continue;
}

public Action:OnRefreshLoadout(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client=GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidClient(client))
	{
		ClearBurnArrays(client);
	}
}

stock bool:IsValidClient(client, bool:replaycheck=true)
{
	if(client<=0 || client>MaxClients)
	{
		return false;
	}

	if(!IsClientInGame(client))
	{
		return false;
	}

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replaycheck)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	return true;
}

public TF2_OnConditionAdded(client, TFCond condition)
{
	if(condition == TFCond_OnFire)
	{
		if(LastReBurn[client]>=GetGameTime())
		{
		}
		else
		{
			ClearBurnArrays(client);
		}
	}
}

public TF2_OnConditionRemoved(client, TFCond condition)
{
	if(condition == TFCond_OnFire)
	{
		ClearBurnArrays(client);
	}
}

BurnTarget(client, target, weapon, Float:damage = 1.0, Float:duration = 7.55)
{
	if(IsValidClient(target) && IsValidClient(client))
	{
		if(!TF2_IsPlayerInCondition(target, TFCond_AfterburnImmune))
		{
			if(IsValidEntity(weapon))
			{
				duration *= EntityAttribVal(weapon, 73, 1.0);
				duration *= EntityAttribVal(weapon, 74, 1.0);
				duration *= EntityAttribVal(weapon, 828, 1.0);
				duration *= EntityAttribVal(weapon, 829, 1.0);
				
				ReBurn[target]=GetGameTime()+9.4;
				BurnDur[target]=GetGameTime()+duration;
				BurnDmg[target]=damage;
				LastReBurn[target]=GetGameTime()+0.1;
				BurnRef[target]=EntIndexToEntRef(weapon);
				BurnId[target] = GetClientUserId(client);
				TF2_IgnitePlayer(target, client);
			}
		}
	}
}

ReBurnTarget(target)
{
	if(IsValidClient(target))
	{
		ReBurn[target]=GetGameTime()+9.4;
		LastReBurn[target]=GetGameTime()+0.1;
		new client = GetClientOfUserId(BurnId[target]);
		if(IsValidClient(client))
		{
			TF2_IgnitePlayer(target, client);
		}
		else
		{
			TF2_IgnitePlayer(target, target);
		}
		
	}
}

stock bool:IsWet(client)
{
	if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 1)
	{
		return true;
	}
	if(TF2_IsPlayerInCondition(client, TFCond_Milked))
	{
		return true;
	}
	if(TF2_IsPlayerInCondition(client, TFCond_Jarated))
	{
		return true;
	}
	return false;
}

//just a small thing to filter out damagetypes the game typically believes are not "direct damage"
IsDirectDmg(bits, String:projectiletype[255])
{
	if(bits & DMG_SLASH)
	{
		if(!StrEqual(projectiletype, "tf_weapon_cleaver", false))
		{
			return false;
		}
	}
	else if((bits & DMG_BURN) && (bits & DMG_PREVENT_PHYSICS_FORCE))
	{
		return false;
	}
	return true;
}

//retrieves the value of an attribute placed on entity
//cannot retrive static attributes unfortunately
stock Float:EntityAttribVal(entity, index, Float:baseval)
{
    new Float:AttributeValue=baseval;
    if(IsValidEntity(entity))
	{
	    new Address:statbonus = TF2Attrib_GetByDefIndex(entity, index);
		if(statbonus!=Address_Null)
		{
			AttributeValue = TF2Attrib_GetValue(statbonus);
		}
	}
	return AttributeValue;
}

stock Float:PlayerAttribVal(client, index, Float:baseval, bool:mult, bool:active)
{
	new Float:AttributeValue=baseval;
	new Address:statbonus = TF2Attrib_GetByDefIndex(client, index);
	if(statbonus!=Address_Null)
	{
		AttributeValue = TF2Attrib_GetValue(statbonus);
		if(mult)
		{
			baseval *= AttributeValue;
		}
		else
		{
			baseval += AttributeValue;
		}
	}
	new activewep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	for(new slot = 0; slot<6; slot++)
	{
		new wep = GetPlayerWeaponSlot(client, slot);
		if(IsValidEntity(wep))
		{
			new bool:CanDo=true;
			if(active)
			{
				AttributeValue=baseval;
				statbonus = TF2Attrib_GetByDefIndex(wep, 128);
				if(statbonus!=Address_Null)
				{
					AttributeValue = TF2Attrib_GetValue(statbonus);
					if(AttributeValue!=0.0)
					{
						if(activewep==wep)
						{
							CanDo = true;
						}
						else
						{
							CanDo = false;
						}
					}
					else
					{
						CanDo = true;
					}
				}
				else
				{
					CanDo = true;
				}
			}
			else
			{
				AttributeValue=baseval;
				statbonus = TF2Attrib_GetByDefIndex(wep, 128);
				if(statbonus!=Address_Null)
				{
					AttributeValue = TF2Attrib_GetValue(statbonus);
					if(AttributeValue!=0.0)
					{
						CanDo = false;
					}
				}
				else
				{
					CanDo = true;
				}
			}
			if(CanDo)
			{
				AttributeValue=baseval;
				statbonus = TF2Attrib_GetByDefIndex(wep, index);
				if(statbonus!=Address_Null)
				{
					AttributeValue = TF2Attrib_GetValue(statbonus);
					if(mult)
					{
						baseval *= AttributeValue;
					}
					else
					{
						baseval += AttributeValue;
					}
				}
			}
		}
	}
	baseval = GetWearableAttrib(client, index, baseval, mult);
	return baseval;
}

ClearBurnArrays(target)
{
	ReBurn[target]=-1.0;
	BurnDur[target]=-1.0;
	BurnDmg[target]=1.0;
	BurnRef[target]=0;
	BurnId[target]=-1;
	LastReBurn[target]=-1.0;
}

stock Float:GetWearableAttrib(client, index, Float:baseval, bool:mult)
{
	new Float:AttributeValue=baseval;
	new Address:statbonus;
	new i = -1; 
	while ((i = FindEntityByClassname(i, "tf_wearabl*")) != -1)
	{ 
		if(client == GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity"))
		{
			if(IsValidEntity(i))
			{
				AttributeValue=baseval;
				statbonus = TF2Attrib_GetByDefIndex(i, index);
				if(statbonus!=Address_Null)
				{
					AttributeValue = TF2Attrib_GetValue(statbonus);
					if(mult)
					{
						baseval *= AttributeValue;
					}
					else
					{
						baseval += AttributeValue;
					}
				}
			}
		}
	}
	return baseval;
}