#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>
#include <tf2attributes>
#undef REQUIRE_EXTENSIONS
#tryinclude <dhooks>

#define DDCOMPILE true

//speedcap breaking stuff
new Handle:hConfig = null;
new Handle:ProcessMovement = null;
new Float:SpeedLimit=520.0;
new bool:DHooksOn=false;

#if DDCOMPILE
#include <ff2_dynamic_defaults>
#endif

#define PLUGIN_VERSION "1.0"

//TODO LIST:
//Finish spin_jump:
//- Fix up jumping near/above water
//Finish passive_roll
//- Improve rage draining customizability
//- Improve turning
//Finish homing_attack
//- AMS Support
//- Add homing onto sentryguns and dispensers if no player is found
//Collective
//- (Optional) Have model skins respect ubercharge
//- (Optional) Improve actor system by only creating the same amount as different models actually used
//-	change how moving works while in flying/noclip modes

#define Denied "vo/engineer_no01.mp3"

const DMG_ROLL = 0;
const DMG_HOME = 0;

//if you're wondering why everything is GC it's because it was called "ground_charge" originally
#define GCName "spin_dash"
#define GCAlias "GRC"

#define PRName "passive_roll"

#define HAName "homing_attack"
#define HAAlias "HOA"

#define RDName "roll_damage"

#define SJName "spin_jump"

new string_hud = 127;
new string_path = 255;

//animation model stuff
new Float:OFF_THE_MAP[3] = { 16383.0, 16383.0, -16383.0 }; //this is how improved_saxton handles prop models
new ActorRef[MAXPLAYERS+1][5];
new Float:NextAnim[MAXPLAYERS+1][5];
new Float:AnimLoop[MAXPLAYERS+1][5];
new String:CurAnim[MAXPLAYERS+1][128][5];
new bool:ActorActive[MAXPLAYERS+1][5];

new RollPart[MAXPLAYERS+1];

//for all players
new Float:GCIFrames[MAXPLAYERS+1];

//////////////////RDName///////////////////////////
//basic
new Float:FF2RDHitSpd[MAXPLAYERS+1]=510.0;
new Float:FF2RDBaseDmg[MAXPLAYERS+1]=0.1;
new Float:FF2RDMinDmg[MAXPLAYERS+1]=10.0;
new Float:FF2RDMaxDmg[MAXPLAYERS+1]=150.0;
new FF2RDDmgFix[MAXPLAYERS+1]=1;
new Float:FF2RDBaseKB[MAXPLAYERS+1]=0.25;
new Float:FF2RDBaseKBVert[MAXPLAYERS+1]=0.2;
new Float:FF2RDMinKB[MAXPLAYERS+1]=300.0;
new Float:FF2RDMaxKB[MAXPLAYERS+1]=800.0;
//snd
new String:SNDRDHit[MAXPLAYERS+1][255];
new SNDRDHitVol[MAXPLAYERS+1]=0;


new Float:FF2JDHitSpd[MAXPLAYERS+1];
new Float:FF2JDGoombSpd[MAXPLAYERS+1];
new Float:FF2JDBaseDmg[MAXPLAYERS+1];
new Float:FF2JDMinDmg[MAXPLAYERS+1];
new Float:FF2JDMaxDmg[MAXPLAYERS+1];
new FF2JDDmgFix[MAXPLAYERS+1];
new Float:FF2JDBaseKB[MAXPLAYERS+1];
new Float:FF2JDSelfKB[MAXPLAYERS+1];
new Float:FF2JDSelfKBVert[MAXPLAYERS+1];
new FF2JDSelfKBType[MAXPLAYERS+1];
new Float:FF2JDGoombMult[MAXPLAYERS+1];

new String:SNDJDHit[MAXPLAYERS+1][255];
new SNDJDHitVol[MAXPLAYERS+1];
new String:SNDJDGoomb[MAXPLAYERS+1][255];
new SNDJDGoombVol[MAXPLAYERS+1];

//hud
new String:HUDRDKillIcon[MAXPLAYERS+1][128];
//debug
new FF2RDDebug[MAXPLAYERS+1]=0;

//////////////////HANAME///////////////////////////
new bool:FF2HAEnable[MAXPLAYERS+1]=false;
new FF2HAButton[MAXPLAYERS+1]=0;
new Float:FF2HACool[MAXPLAYERS+1]=15.0;
new Float:FF2HACost[MAXPLAYERS+1]=50.0;
new Float:FF2HARange[MAXPLAYERS+1]=600.0;
new Float:FF2HAWind[MAXPLAYERS+1]=1.0;
new Float:FF2HAWindAlert[MAXPLAYERS+1]=1.0;
new Float:FF2HAWindVel[MAXPLAYERS+1]=10.0;
new Float:FF2HASpeed[MAXPLAYERS+1]=600.0;
new Float:FF2HADur[MAXPLAYERS+1]=1.0;
new Float:FF2HADurNo[MAXPLAYERS+1]=0.6;
new Float:FF2HANoRot[MAXPLAYERS+1]=90.0;
new Float:FF2HAHitVert[MAXPLAYERS+1]=500.0;
new Float:FF2HAHitVel[MAXPLAYERS+1]=0.5;
new Float:FF2HAStunDur[MAXPLAYERS+1]=1.5;
new FF2HAStunFlags[MAXPLAYERS+1]=96;

new Float:FF2HADmgPlayer[MAXPLAYERS+1]=100.0;
new Float:FF2HADmgOther[MAXPLAYERS+1]=216.0;
new FF2HADmgFix[MAXPLAYERS+1]=1;
new Float:FF2HAKnockBack[MAXPLAYERS+1]=400.0;

new String:SNDHAShoot[MAXPLAYERS+1][255];
new String:SNDHAWind[MAXPLAYERS+1][255];
new String:SNDHAHit[MAXPLAYERS+1][255];
new String:SNDHABeep[MAXPLAYERS+1][255];

new SNDHAHitType[MAXPLAYERS+1]=0;

new String:MDLHA[MAXPLAYERS+1][256];
new String:ANMHA[MAXPLAYERS+1][256];
new Float:ANMHADur[MAXPLAYERS+1];
new Float:ANMHAVert[MAXPLAYERS+1];
new Float:ANMHAHoriOffset[MAXPLAYERS+1];
new Float:ANMHAAngOffset[MAXPLAYERS+1];
new Float:ANMHAOffset[MAXPLAYERS+1];
new String:PRTHALaunch[MAXPLAYERS+1][255];
new String:PRTHATrail[MAXPLAYERS+1][255];
new Float:PRTHAOffset[MAXPLAYERS+1];


//hud
new HUDHAStyle[MAXPLAYERS+1]=0;
new Float:HUDHAOffset[MAXPLAYERS+1]=0.77;

new String:HUDHACool[MAXPLAYERS+1][128];
new String:HUDHARage[MAXPLAYERS+1][128];
new String:HUDHANo[MAXPLAYERS+1][128];
new String:HUDHAStun[MAXPLAYERS+1][128];
new String:HUDHANoRage[MAXPLAYERS+1][128];

new String:HUDHAHomeIcon[MAXPLAYERS+1][128];

new FF2HADebug[MAXPLAYERS+1];

//////////////////HANAME///////////////////////////

//////////////////PRNAME///////////////////////////
new FF2PRButton[MAXPLAYERS+1]=0;
new FF2PRAbilFlags[MAXPLAYERS+1]=0;

new bool:FF2PREnable[MAXPLAYERS+1]=false;
new Float:FF2PRMinRag[MAXPLAYERS+1]=0.0;
new Float:FF2PRDrain[MAXPLAYERS+1]=0.0;

new Float:FF2PRSpeed[MAXPLAYERS+1]=900.0;
new Float:FF2PRSpeedAir[MAXPLAYERS+1]=900.0;
new Float:FF2PRSpeedWater[MAXPLAYERS+1]=500.0;

new Float:FF2PRAccel[MAXPLAYERS+1]=3.0;
new Float:FF2PRAccelAir[MAXPLAYERS+1]=0.5;
new Float:FF2PRAccelWater[MAXPLAYERS+1]=1.0;

new Float:FF2PRDeccel[MAXPLAYERS+1]=-2.0;
new Float:FF2PRDeccelAir[MAXPLAYERS+1]=-0.5;
new Float:FF2PRDeccelWater[MAXPLAYERS+1]=-6.0;

new Float:FF2PRTurnRate[MAXPLAYERS+1][2];
new Float:FF2PRTurnRatePen[MAXPLAYERS+1]=1.0;
new Float:FF2PRTurnRateWater[MAXPLAYERS+1]=0.6;
new Float:FF2PRTurnRateAir[MAXPLAYERS+1]=0.3;
new Float:FF2PRRollMinSpeed[MAXPLAYERS+1]=250.0;

new Float:FF2PRTurnAssist[MAXPLAYERS+1]=1.0;
new Float:FF2PRTurnAssistAir[MAXPLAYERS+1]=0.3;
new Float:FF2PRTurnAssistWater[MAXPLAYERS+1]=0.6;

new FF2PRAttack[MAXPLAYERS+1];
new PRARollCondID[MAXPLAYERS+1][32];
new Float:PRARollSpd[MAXPLAYERS+1][32];

new FF2PRDDFlags[MAXPLAYERS+1]=0;
new FF2PRStunFlags[MAXPLAYERS+1]=0;

//dmg
new Float:FF2PRHitMult[MAXPLAYERS+1]=0.8;
new FF2PRRollCollide[MAXPLAYERS+1]=0;
new FF2PRRollCollideBuild[MAXPLAYERS+1]=0;

//snd
new String:SNDPRRoll[MAXPLAYERS+1][256];

//anim
new String:MDLPRRoll[MAXPLAYERS+1][256];
new String:ANMPRRoll[MAXPLAYERS+1][128];
new Float:ANMPRRollDur[MAXPLAYERS+1];
new Float:ANMPRRollOffset[MAXPLAYERS+1];
new Float:ANMPRRollHoriOffset[MAXPLAYERS+1];
new Float:ANMPRRollAngOffset[MAXPLAYERS+1];
new Float:ANMPRRollVert[MAXPLAYERS+1];
new String:PRTPRRoll[MAXPLAYERS+1][128];
new Float:PRTPRRollOffset[MAXPLAYERS+1];


//hud
new Float:HUDPROffset[MAXPLAYERS+1]=0.77;
new String:HUDPRRage[MAXPLAYERS+1][128];
new String:HUDPRCool[MAXPLAYERS+1][128];
new String:HUDPRNo[MAXPLAYERS+1][128];
new String:HUDPRActive[MAXPLAYERS+1][128];
new String:HUDPRStun[MAXPLAYERS+1][128];
new String:HUDPRWater[MAXPLAYERS+1][128];
new String:HUDPRNoRage[MAXPLAYERS+1][128];

//other
new FF2PRDebug[MAXPLAYERS+1];
//////////////////PRNAME///////////////////////////

//////////////////SJNAME///////////////////////////
new FF2SJEnable[MAXPLAYERS+1] = false;
new FF2SJAbilFlags[MAXPLAYERS+1] = 1;
new FF2SJStunFlags[MAXPLAYERS+1] = 6;

new FF2SJCollide[MAXPLAYERS+1] = 1;
new FF2SJCollideBuild[MAXPLAYERS+1] = 1;

new SJCondID[MAXPLAYERS+1][32];
new Float:SJCondSpd[MAXPLAYERS+1][32];

new Float:FF2SJGoombStunDur[MAXPLAYERS+1] = 0.0;
new FF2SJGoombStunFlags[MAXPLAYERS+1] = 0;
new FF2SJStunShield[MAXPLAYERS+1] = 0;

new String:SNDSJEnter[MAXPLAYERS+1][256];

new String:MDLSJ[MAXPLAYERS+1][256];
new String:ANMSJ[MAXPLAYERS+1][128];

new Float:ANMSJDur[MAXPLAYERS+1]=0.0;
new Float:ANMSJVert[MAXPLAYERS+1]=0.0;
new Float:ANMSJBaseAng[MAXPLAYERS+1]=0.0;
new Float:ANMSJHoriOffset[MAXPLAYERS+1]=0.0;
new Float:ANMSJAngOffset[MAXPLAYERS+1]=0.0;
new Float:ANMSJOffset[MAXPLAYERS+1]=0.0;
//////////////////SJNAME///////////////////////////

//////////////////GCNAME///////////////////////////
//resource reqs for ground charge
new Float:FF2GCCooldown[MAXPLAYERS+1]=15.0;

//variables for the ability
new FF2GCAbilFlags[MAXPLAYERS+1]=0;
new Float:FF2GCMinSpeed[MAXPLAYERS+1]=200.0;
new Float:FF2GCBaseSpeed[MAXPLAYERS+1]=600.0;
new Float:FF2GCMaxSpeed[MAXPLAYERS+1]=1200.0;
new Float:FF2GCDecaySpeed[MAXPLAYERS+1]=5.0;
new Float:FF2GCDecaySpeedAir[MAXPLAYERS+1]=5.0;
new Float:FF2GCDecaySpeedWater[MAXPLAYERS+1]=5.0;
new Float:FF2GCDuration[MAXPLAYERS+1]=2.0;
new FF2GCAttack[MAXPLAYERS+1]=2;
new Float:FF2GCTurnRate[MAXPLAYERS+1][2];
new Float:FF2GCTurnRatePen[MAXPLAYERS+1]=1.0;
new Float:FF2GCTurnRateWater[MAXPLAYERS+1]=0.6;
new Float:FF2GCTurnRateAir[MAXPLAYERS+1]=0.3;
new Float:FF2GCMinRollSpd[MAXPLAYERS+1]=1000.0;
new Float:FF2GCBuildRate[MAXPLAYERS+1]=0.0;
new Float:FF2GCBuildDecay[MAXPLAYERS+1]=0.0;
new Float:FF2GCBuildRateHold[MAXPLAYERS+1]=0.0;
new Float:FF2GCLaunchMultAir[MAXPLAYERS+1]=1.0;
new Float:FF2GCLaunchMultWater[MAXPLAYERS+1]=1.0;
new FF2GCDDFlags[MAXPLAYERS+1]=0;
new FF2GCSpinCondID[MAXPLAYERS+1][32];
new FF2GCStunFlags[MAXPLAYERS+1];

//dmg
new FF2GCRollCollide[MAXPLAYERS+1]=0;
new FF2GCRollCollideBuild[MAXPLAYERS+1]=0;
new Float:FF2GCHitMult[MAXPLAYERS+1]=0.8;
new Float:FF2GCSpinHit[MAXPLAYERS+1];

new GCARollCondID[MAXPLAYERS+1][32];
new Float:GCARollSpd[MAXPLAYERS+1][32];

//inputs
new FF2GCButton[MAXPLAYERS+1]=1;
new FF2GCBuildButton[MAXPLAYERS+1]=0;
new FF2GCReleaseButton[MAXPLAYERS+1]=0;

//audio
new String:SNDGCLaunch[MAXPLAYERS+1][256];
new String:SNDGCBuild[MAXPLAYERS+1][256];
new SNDGCPitchMin[MAXPLAYERS+1];
new SNDGCPitchMax[MAXPLAYERS+1];

new bool:FF2GCEnable[MAXPLAYERS+1]=false;

//graphic
new String:MDLGCRoll[MAXPLAYERS+1][256];
new String:MDLGCBuild[MAXPLAYERS+1][256];
new String:ANMGCRoll[MAXPLAYERS+1][128];
new String:ANMGCBuild[MAXPLAYERS+1][128];
new Float:ANMGCRollDur[MAXPLAYERS+1];
new Float:ANMGCBuildDur[MAXPLAYERS+1];
new Float:ANMGCRollVert[MAXPLAYERS+1];
new Float:ANMGCBuildVert[MAXPLAYERS+1];
new Float:ANMGCRollBaseAng[MAXPLAYERS+1];
new Float:ANMGCBuildBaseAng[MAXPLAYERS+1];
new Float:ANMGCRollAngOffset[MAXPLAYERS+1];
new Float:ANMGCRollHoriOffset[MAXPLAYERS+1];
new Float:ANMGCRollOffset[MAXPLAYERS+1];
new Float:ANMGCBuildAngOffset[MAXPLAYERS+1];
new Float:ANMGCBuildHoriOffset[MAXPLAYERS+1];
new Float:ANMGCBuildOffset[MAXPLAYERS+1];
new String:PRTGCLaunch[MAXPLAYERS+1][128];
new String:PRTGCRoll[MAXPLAYERS+1][128];
new Float:PRTGCRollOffset[MAXPLAYERS+1];

//hud
new HUDGCStyle[MAXPLAYERS+1]=0;
new Float:HUDGCOffset[MAXPLAYERS+1]=0.77;

new String:HUDGCCool[MAXPLAYERS+1][128];
new String:HUDGCRage[MAXPLAYERS+1][128];
new String:HUDGCNo[MAXPLAYERS+1][128];
new String:HUDGCBuild[MAXPLAYERS+1][128];

new String:HUDGCWarn[MAXPLAYERS+1][128];
new String:HUDGCHow[MAXPLAYERS+1][128];
new String:HUDGCStun[MAXPLAYERS+1][128];

new FF2GCDebug[MAXPLAYERS+1];
//////////////////GCNAME///////////////////////////

//variables to keep track of the client's abilities
new Float:GCSpinCharge[MAXPLAYERS+1];
new Float:GCNextCharge[MAXPLAYERS+1];
new Float:GCTime[MAXPLAYERS+1];
new Float:GCNextPush[MAXPLAYERS+1];
new Float:GCNextRoll[MAXPLAYERS+1];
new LastButtons[MAXPLAYERS+1];
new LastFlags[MAXPLAYERS+1];
new Float:LastPush[MAXPLAYERS+1];
new GCType[MAXPLAYERS+1];
new Float:LastAngles[MAXPLAYERS+1][3];
new Float:LastVel[MAXPLAYERS+1][3];
new Float:FixCollide[MAXPLAYERS+1];
new Float:LastRollHit[MAXPLAYERS+1];
new Float:LastHomeHit[MAXPLAYERS+1];
new Float:RunVel[MAXPLAYERS+1][3];
new Float:DmgVel[MAXPLAYERS+1][3];
new WallPenalty[MAXPLAYERS+1];
new Float:HANextCharge[MAXPLAYERS+1];
new Float:HAAngles[MAXPLAYERS+1][3];
new HATarget[MAXPLAYERS+1];
new Float:HAWind[MAXPLAYERS+1];
new Float:HADur[MAXPLAYERS+1];
new bool:CheckedTarget[MAXPLAYERS+1];
new bool:Jumped[MAXPLAYERS+1];
new Float:NextSpinJump[MAXPLAYERS+1];

//debug
new Float:LastSpeed[MAXPLAYERS+1];

//graphical stuff
new Handle:PRHUD;
new Handle:GroundHUD;
new Handle:HomeHUD;

new Handle:hTrace; //for wall checks

public Plugin:myinfo=
{
	name="Freak Fortress 2: Sonic Abilities",
	author="kking117",
	description="A subplugin for ff2 that adds abilities similar to the ones used by Sonic.",
	version=PLUGIN_VERSION,
};

new Handle:OnHaleRage=INVALID_HANDLE;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	OnHaleRage=CreateGlobalForward("VSH_OnDoRage", ET_Hook, Param_FloatByRef);
	return APLRes_Success;
}

public OnPluginStart2()
{
	PrecacheSound(Denied);
	HookEvent("arena_round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_win_panel", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("object_deflected", OnObjectDeflected, EventHookMode_Pre);
	PRHUD=CreateHudSynchronizer();
	GroundHUD=CreateHudSynchronizer();
	HomeHUD=CreateHudSynchronizer();
	if(LibraryExists("dhooks"))
	{
		hConfig = LoadGameConfigFile("tf2.gamemovement");
		if(hConfig)
		{
			ProcessMovement = DHookCreateFromConf(hConfig, "CTFGameMovement::ProcessMovement");
			if(DHookEnableDetour(ProcessMovement, false, CTFGameMovement_ProcessMovement))
			{
				PrintToServer("[ff2_sonicability] dhooks found, using good momentum code.");
				DHooksOn = true;
				// NOP out the assignment of m_flMaxSpeed
				MemoryPatch("ProcessMovement", hConfig, {0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90}, 7);
			}
			else
			{
				DHooksOn = false;
				ProcessMovement = null;
				PrintToServer("[ff2_sonicability] Failed to create \"CTFGameMovement::ProcessMovement\" detour! Using lame momentum code.");
			}
		}
		else
		{
			DHooksOn = false;
			PrintToServer("[ff2_sonicability] Failed to open \"gamedata/tf2.gamemovement.txt\"! Using lame momentum code.");
		}
	}
	else
	{
		PrintToServer("[ff2_sonicability] dhooks not found. Using lame momentum code.");
		DHooksOn = false;
	}
}

public void OnPluginEnd()
{
	if(DHooksOn)
	{
		DHookDisableDetour(ProcessMovement, false, CTFGameMovement_ProcessMovement);
		//repatch the m_flmaxspeed assignment
		MemoryPatch("ProcessMovement", hConfig, {0xC7, 0x43, 0x3C, 0x0, 0x0, 0x2, 0x44}, 7);
		delete hConfig;
		DHooksOn = false;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "dhooks"))
	{
		PrintToServer("[ff2_sonicability] dhooks removed! Using lame momentum code.");
		DHooksOn = false;
		DHookDisableDetour(ProcessMovement, false, CTFGameMovement_ProcessMovement);
		//repatch the m_flmaxspeed assignment
		MemoryPatch("ProcessMovement", hConfig, {0xC7, 0x43, 0x3C, 0x0, 0x0, 0x2, 0x44}, 7);
		delete hConfig;
	}
}

public OnClientPutInServer(client)
{
	ClearVariables(client);
}

public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	SpeedLimit = 520.0;
	new bool:AbilityUsed=false;
	for(new client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			ClearVariables(client);
			if(IsBoss(client))
			{
				new bool:HookDmg=false;
				new bool:CanHurt=false;
				if(FF2_HasAbility(FF2_GetBossIndex(client), this_plugin_name, GCName))
				{
					HookDmg = true;
					RegisterBossAbility(client, GCName);
					AbilityUsed=true;
				}
				if(FF2_HasAbility(FF2_GetBossIndex(client), this_plugin_name, PRName))
				{
					HookDmg = true;
					RegisterBossAbility(client, PRName);
					AbilityUsed=true;
				}
				if(FF2_HasAbility(FF2_GetBossIndex(client), this_plugin_name, HAName))
				{
					RegisterBossAbility(client, HAName);
					AbilityUsed=true;
				}
				if(FF2_HasAbility(FF2_GetBossIndex(client), this_plugin_name, RDName))
				{
					RegisterBossAbility(client, RDName);
					CanHurt=true;
				}
				if(FF2_HasAbility(FF2_GetBossIndex(client), this_plugin_name, SJName))
				{
					RegisterBossAbility(client, SJName);
				}
				if(HookDmg)
				{
					SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamageKBPre);
					SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamageKBPost);
				}
				if(!CanHurt)
				{
					FF2GCAbilFlags[client] = FF2GCAbilFlags[client] & ~8;
					FF2PRAbilFlags[client] = FF2PRAbilFlags[client] & ~8;
				}
			}
		}
	}
	if(AbilityUsed)
	{
		new entity = -1;
		while ((entity = FindEntityByClassname(entity, "trigger_catapult")) != INVALID_ENT_REFERENCE)
		{
			if(IsValidEntity(entity))
			{
				HookSingleEntityOutput(entity, "OnCatapulted", PushTouch);
			}
		}
		entity = -1;
		while ((entity = FindEntityByClassname(entity, "trigger_push")) != INVALID_ENT_REFERENCE)
		{
			if(IsValidEntity(entity))
			{
				HookSingleEntityOutput(entity, "OnStartTouch", PushTouch);
			}
		}
		entity = -1;
		while ((entity = FindEntityByClassname(entity, "trigger_apply_impulse")) != INVALID_ENT_REFERENCE)
		{
			if(IsValidEntity(entity))
			{
				HookSingleEntityOutput(entity, "OnStartTouch", PushTouch);
			}
		}
	}
	CreateTimer(0.25, ClientTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public PushTouch(const String:output[], entity, client, Float:delay)
{
	if(IsValidClient(client))
	{
		if(IsBoss(client))
		{
			new bool:Launched=false;
			if(FF2GCEnable[client])
			{
				if(GCType[client]==1)
				{
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", RunVel[client]);
					Launched=true;
					if(FF2GCDebug[client])
					{
						PrintToChat(client, "[%s] trigger_push touched, velocity was overwritten.", GCName);
					}
				}
				else if(GCType[client]==2)
				{
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", RunVel[client]);
					Launched=true;
					if(FF2GCDebug[client])
					{
						PrintToChat(client, "[%s] trigger_push touched, velocity was overwritten.", GCName);
					}
				}
			}
			if(!Launched)
			{
				if(FF2PREnable[client])
				{
					if(GCType[client]==5)
					{
						GetEntPropVector(client, Prop_Data, "m_vecVelocity", RunVel[client]);
						if(FF2GCDebug[client])
						{
							PrintToChatAll("[%s] trigger_push touched, velocity was overwritten.", GCName);
						}
					}
				}
			}
			//we'll let the homming attack ignore push effects for now
			//else if(FF2HAEnable[client])
			//{
			//}
		}
	}
}

public Action:OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	for(new client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			HideActor(client, 0);
			RemoveClientActor(client, 0);
			HideActor(client, 1);
			RemoveClientActor(client, 1);
			HideActor(client, 2);
			RemoveClientActor(client, 2);
			HideActor(client, 3);
			RemoveClientActor(client, 3);
			HideActor(client, 4);
			RemoveClientActor(client, 4);
			SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamageKBPre);
			SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamageKBPost);
			SDKUnhook(client, SDKHook_PreThink, Charge_PreThink);
			KillRollTrail(client);
			ClearVariables(client);
		}
	}
	return Plugin_Continue;
}

public Action:OnPlayerDeath(Handle:event, const String:eventName[], bool:dontBroadcast)
{
	if(FF2_IsFF2Enabled())
	{
		new client=GetClientOfUserId(GetEventInt(event, "userid"));
		new attacker=GetClientOfUserId(GetEventInt(event, "attacker"));
		if(IsValidClient(client))
		{
			if(IsValidClient(attacker))
			{
				if(IsBoss(attacker))
				{
					if(LastRollHit[client]>=GetGameTime())
					{
						SetEventString(event, "weapon_logclassname", "rolling_kill");
						if(strlen(HUDRDKillIcon[attacker])>0)
						{
							SetEventString(event, "weapon", HUDRDKillIcon[attacker]);
						}
					}
					else if(LastHomeHit[client]>=GetGameTime())
					{
						SetEventString(event, "weapon_logclassname", "homing_attack");
						if(strlen(HUDHAHomeIcon[attacker])>0)
						{
							SetEventString(event, "weapon", HUDHAHomeIcon[attacker]);
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:OnObjectDeflected(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(!GetEventInt(event, "weaponid"))
	{
		new victim = GetClientOfUserId(GetEventInt(event, "ownerid"));
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		if(IsValidClient(client))
		{
			if(IsBoss(victim))
			{
				if(!TF2_IsPlayerInCondition(victim, TFCond_MegaHeal))
				{
					//hacky work around for airblasting bosses during various states
					if(FF2PREnable[victim] && GCType[victim]==5)
					{
						new Float:vel[3];
						GetEntPropVector(victim, Prop_Data, "m_vecVelocity", vel);
						RunVel[victim][0] = vel[0];
						RunVel[victim][1] = vel[1];
						RunVel[victim][2] = vel[1];
						PrintToServer("[%s] Pushed for %.2f force.", PRName, GetVectorLength(vel));
					}
					else if(FF2GCEnable[victim] && (GCType[victim]==1 || GCType[victim]==2))
					{
						new Float:vel[3];
						GetEntPropVector(victim, Prop_Data, "m_vecVelocity", vel);
						RunVel[victim][0] = vel[0];
						RunVel[victim][1] = vel[1];
						RunVel[victim][2] = vel[1];
						if(FF2GCDebug[victim])
						{
							PrintToServer("[%s] Pushed for %.2f force.", GCName, GetVectorLength(vel));
						}
					}
					else if(FF2HAEnable[victim] && GCType[victim]==3)
					{
						new Float:angle[3];
						GetClientEyeAngles(client, angle);
						HATarget[victim] = -1;
						HAAngles[victim][0] = angle[0];
						HAAngles[victim][1] = angle[1];
						HAAngles[victim][2] = angle[2];
						if(FF2GCDebug[victim])
						{
							PrintToServer("[%s] Homing attack defelected.", HAName);
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:OnTakeDamageKBPre(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if(IsBoss(client))
	{
		if((FF2PREnable[client] && GCType[client]==5) || GCType[client]==1 || GCType[client]==2)
		{
			if(GetVectorLength(damageForce)>0.0)
			{
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", DmgVel[client]);
			}
		}
	}
	return Plugin_Continue;
}

public Action:OnTakeDamageKBPost(client, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if(IsBoss(client))
	{
		if((FF2PREnable[client] && GCType[client]==5) || GCType[client]==1 || GCType[client]==2)
		{
			if(GetVectorLength(damageForce)>0.0)
			{
				new Float:vel[3];
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
				//PrintToServer("KB | X:%.2f | Z:%.2f | Y:%.2f", vel[0]-DmgVel[client][0], vel[1]-DmgVel[client][1], vel[2]-DmgVel[client][2]);
				RunVel[client][0] += vel[0]-DmgVel[client][0];
				RunVel[client][1] += vel[1]-DmgVel[client][1];
				RunVel[client][2] += vel[2]-DmgVel[client][2];
			}
		}
	}
	return Plugin_Continue;
}

RegisterBossAbility(client, String:ability_name[])
{
	if(IsBoss(client))
	{
		new boss=FF2_GetBossIndex(client);
		if(!strcmp(ability_name, GCName))
		{
			new String:ArgStr[255];
			FF2GCEnable[client] = true;
			FF2GCButton[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 1, 0);
			FF2GCAbilFlags[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 2, 1);
			
			
			FF2GCCooldown[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 3, 8.0);
			if (FF2GCCooldown[client]<1.0)
			{
				FF2GCCooldown[client]=1.0;
			}
			GCNextCharge[client] = GetGameTime()+FF2GCCooldown[client]*0.5;
			FF2GCDuration[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 4, 2.0);
			
			FF2GCBaseSpeed[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 5, 600.0);
			FF2GCMaxSpeed[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 6, 1200.0);
			FF2GCMinSpeed[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 7, 200.0);
			FF2GCMinRollSpd[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 8, 1000.0);
			FF2GCDecaySpeed[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 9, -1.0);
			FF2GCDecaySpeedAir[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 10, -2.0);
			FF2GCDecaySpeedWater[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 11, -4.0);
			FF2GCLaunchMultAir[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 12, 1.0);
			FF2GCLaunchMultWater[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 13, 1.0);
			//arg 14
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 14, ArgStr, string_path);
			new String:list[32][2];
			ExplodeString(ArgStr, " ; ", list, sizeof(list), sizeof(list));
			FF2GCTurnRate[client][0] = StringToFloat(list[0]);
			FF2GCTurnRate[client][1] = StringToFloat(list[1]);
			//
			FF2GCTurnRatePen[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 15, 1.0);
			FF2GCTurnRateAir[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 16, 0.6);
			FF2GCTurnRateWater[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 17, 0.3);
			FF2GCAttack[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 18, 2);
			CreateAddcondGCList(client, boss); //arg19
			FF2GCStunFlags[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 20, 6);
			FF2GCDDFlags[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 21, 0);
			
			FF2GCRollCollide[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 23, 1);
			FF2GCRollCollideBuild[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 24, 1);
			FF2GCHitMult[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 25, 0.8);
			
			
			FF2GCReleaseButton[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 33, 0);
			FF2GCBuildButton[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 34, 1);
			FF2GCBuildRate[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 35, 0.0);
			FF2GCBuildRateHold[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 36, 0.0);
			FF2GCBuildDecay[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 37, 0.0);
			CreateSpinCondList(client, boss); //arg38
			FF2GCSpinHit[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 39, 0.0);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 40, SNDGCLaunch[client], string_path);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 41, SNDGCBuild[client], string_path);
			SNDGCPitchMin[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 42, 128);
			SNDGCPitchMax[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 43, 128);
			
			if(SNDGCPitchMin[client]<0)
			{
				SNDGCPitchMin[client] = 0;
			}
			else if(SNDGCPitchMin[client]>255)
			{
				SNDGCPitchMin[client] = 255;
			}
			
			if(SNDGCPitchMax[client]<0)
			{
				SNDGCPitchMax[client] = 0;
			}
			else if(SNDGCPitchMax[client]>255)
			{
				SNDGCPitchMax[client] = 255;
			}
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 50, MDLGCRoll[client], string_path);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 51, ANMGCRoll[client], string_hud);
			ANMGCRollDur[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 52, 0.0);
			ANMGCRollVert[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 53, 0.0);
			ANMGCRollBaseAng[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 54, 0.0);
			ANMGCRollHoriOffset[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 55, 0.0);
			ANMGCRollAngOffset[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 56, 0.0);
			ANMGCRollOffset[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 57, 0.0);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 58, MDLGCBuild[client], string_path);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 59, ANMGCBuild[client], string_hud);
			ANMGCBuildDur[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 60, 0.0);
			ANMGCBuildVert[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 61, 0.0);
			ANMGCBuildBaseAng[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 62, 0.0);
			ANMGCBuildHoriOffset[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 63, 0.0);
			ANMGCBuildAngOffset[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 64, 0.0);
			ANMGCBuildOffset[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 65, 0.0);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 66, PRTGCLaunch[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 67, PRTGCRoll[client], string_hud);
			PRTGCRollOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 68, 0.0);
			
			HUDGCStyle[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 70, 0);
			HUDGCOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 71, 0.77);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 72, HUDGCCool[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 73, HUDGCRage[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 74, HUDGCNo[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 75, HUDGCBuild[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 76, HUDGCHow[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 77, HUDGCWarn[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 78, HUDGCStun[client], string_hud);
			
			ReplaceString(HUDGCCool[client], 128, "\\n", "\n");
			ReplaceString(HUDGCRage[client], 128, "\\n", "\n");
			ReplaceString(HUDGCNo[client], 128, "\\n", "\n");
			ReplaceString(HUDGCBuild[client], 128, "\\n", "\n");
			ReplaceString(HUDGCHow[client], 128, "\\n", "\n");
			ReplaceString(HUDGCWarn[client], 128, "\\n", "\n");
			ReplaceString(HUDGCStun[client], 128, "\\n", "\n");
			
			FF2GCDebug[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 99, 0);
			if(FF2GCDebug[client]!=0)
			{
				PrintToServer("[%s] Boss has debug mode enabled", GCName);
			}
		
			
			ReplaceString(HUDGCHow[client], string_hud, "\\n", "\n");
			ReplaceString(HUDGCWarn[client], string_hud, "\\n", "\n");
			ReplaceString(HUDGCStun[client], string_hud, "\\n", "\n");
			
			new String:ModelName[255];
			if(strlen(ANMGCRoll[client])>0)
			{
				if(strlen(MDLGCRoll[client])>0)
				{
					SetupAnimationActor(client, MDLGCRoll[client], 0);
				}
				else
				{
					GetEntPropString(client, Prop_Data, "m_ModelName", ModelName, 255);
					SetupAnimationActor(client, ModelName, 0);
				}
			}
			if(strlen(ANMGCBuild[client])>0)
			{
				if(strlen(MDLGCBuild[client])>0)
				{
					SetupAnimationActor(client, MDLGCBuild[client], 1);
				}
				else
				{
					GetEntPropString(client, Prop_Data, "m_ModelName", ModelName, 255);
					SetupAnimationActor(client, ModelName, 1);
				}
			}
			
			SpeedLimit = 5000.0;
		}
		else if(!strcmp(ability_name, PRName))
		{
			new String:ArgStr[255];
			FF2PRButton[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 1, 0);
			
			FF2PREnable[client] = true;
			FF2PRAbilFlags[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 2, 0);
			
			FF2PRMinRag[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 3, 0.0);
			FF2PRDrain[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 4, 0.0);
			
			FF2PRSpeed[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 5, 900.0);
			FF2PRSpeedAir[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 6, 900.0);
			FF2PRSpeedWater[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 7, 500.0);

			FF2PRAccel[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 8, 3.0);
			FF2PRAccelAir[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 9, 0.5);
			FF2PRAccelWater[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 10, 1.0);

			FF2PRDeccel[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 11, -2.0);
			FF2PRDeccelAir[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 12, -0.5);
			FF2PRDeccelWater[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 13, -6.0);
			
			//arg 14
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 14, ArgStr, string_path);
			new String:list[32][2];
			ExplodeString(ArgStr, " ; ", list, sizeof(list), sizeof(list));
			FF2PRTurnRate[client][0] = StringToFloat(list[0]);
			FF2PRTurnRate[client][1] = StringToFloat(list[1]);
			//
			FF2PRTurnRatePen[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 15, 1.0);
			FF2PRTurnRateAir[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 16, 0.6);
			FF2PRTurnRateWater[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 17, 0.3);
			FF2PRRollMinSpeed[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 18, 250.0);
			
			FF2PRTurnAssist[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 19, 2.0);
			FF2PRTurnAssistAir[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 21, 0.2);
			FF2PRTurnAssistWater[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 22, 0.6);
			
			FF2PRAttack[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 23, 2);
			CreateAddcondPRList(client, boss); //arg21
			
			FF2PRStunFlags[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 24, 0);
			FF2PRDDFlags[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 25, 0);
			
			FF2PRRollCollide[client]=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 26, 1);
			FF2PRRollCollideBuild[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 27, 1);
			FF2PRHitMult[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 28, 0.75);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 40, SNDPRRoll[client], string_path);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 50, MDLPRRoll[client], string_path);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 51, ANMPRRoll[client], string_hud);
			ANMPRRollDur[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 52, 0.8);
			ANMPRRollVert[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 53, 1.0);
			ANMPRRollHoriOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 54, -0.4);
			ANMPRRollAngOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 55, -0.3);
			ANMPRRollOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 56, -10.0);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 58, PRTPRRoll[client], string_hud);
			PRTPRRollOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 59, -110.0);
			
			new String:ModelName[255];
			if(strlen(ANMPRRoll[client])>0)
			{
				if(strlen(MDLPRRoll[client])>0)
				{
					SetupAnimationActor(client, MDLPRRoll[client], 3);
				}
				else
				{
					GetEntPropString(client, Prop_Data, "m_ModelName", ModelName, 255);
					SetupAnimationActor(client, ModelName, 3);
				}
			}
			HUDPROffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 60, 0.68);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 61, HUDPRCool[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 62, HUDPRRage[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 63, HUDPRNo[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 64, HUDPRActive[client], string_hud);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 65, HUDPRStun[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 66, HUDPRWater[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 67, HUDPRNoRage[client], string_hud);
			
			ReplaceString(HUDPRCool[client], 128, "\\n", "\n");
			ReplaceString(HUDPRRage[client], 128, "\\n", "\n");
			ReplaceString(HUDPRNo[client], 128, "\\n", "\n");
			ReplaceString(HUDPRActive[client], 128, "\\n", "\n");
			ReplaceString(HUDPRStun[client], 128, "\\n", "\n");
			ReplaceString(HUDPRWater[client], 128, "\\n", "\n");
			ReplaceString(HUDPRNoRage[client], 128, "\\n", "\n");

			FF2PRDebug[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 99, 0);
			if(FF2PRDebug[client]!=0)
			{
				PrintToServer("[%s] Boss has debug mode enabled", PRName);
			}
			
			if(FF2PRButton[client]<0)
			{
				SetChargeState(client, 5);
			}
			
			SpeedLimit = 5000.0;
		}
		else if(!strcmp(ability_name, RDName))
		{
			FF2RDHitSpd[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 1, 510.0);
			FF2RDBaseDmg[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 2, 10.0);
			FF2RDMinDmg[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 3, 10.0);
			FF2RDMaxDmg[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 4, 149.0);
			FF2RDDmgFix[client]=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 5, 1);
			FF2RDBaseKB[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 6, 0.25);
			FF2RDBaseKBVert[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 7, 0.2);
			FF2RDMinKB[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 8, 300.0);
			FF2RDMaxKB[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 9, 800.0);

			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 20, SNDRDHit[client], string_path);
			SNDRDHitVol[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 21, 0);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 40, HUDRDKillIcon[client], string_path);
			
			FF2JDHitSpd[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 30, 510.0);
			FF2JDGoombSpd[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 31, -250.0);
			FF2JDBaseDmg[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 32, 10.0);
			FF2JDMinDmg[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 33, 10.0);
			FF2JDMaxDmg[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 34, 149.0);
			FF2JDDmgFix[client]=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 35, 1);
			FF2JDBaseKB[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 36, 0.25);
			FF2JDSelfKB[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 37, -0.6);
			FF2JDSelfKBVert[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 38, -0.4);
			FF2JDSelfKBType[client]=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 39, 0);
			FF2JDGoombMult[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 40, 1.5);

			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 50, SNDJDHit[client], string_path);
			SNDJDHitVol[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 51, 0);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 52, SNDJDGoomb[client], string_path);
			SNDJDGoombVol[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 53, 0);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 60, HUDRDKillIcon[client], string_path);
			
			FF2RDDebug[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 99, 0);
			if(FF2RDDebug[client]!=0)
			{
				PrintToServer("[%s] Boss has debug mode enabled", RDName);
			}
		}
		else if(!strcmp(ability_name, HAName))
		{
			FF2HAEnable[client] = true;
			FF2HAButton[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 1, 0);
			
			
			FF2HACool[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 3, 15.0);
			HANextCharge[client] = GetGameTime()+(FF2HACool[client]*0.5);
			FF2HACost[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 4, 50.0);
			FF2HARange[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 5, 600.0);
			FF2HAWind[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 6, 1.0);
			if(FF2HAWind[client]<0.0)
			{
				FF2HAWind[client]=0.0;
			}
			FF2HAWindAlert[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 7, 0.4);
			if(FF2HAWindAlert[client]<0.0)
			{
				FF2HAWindAlert[client]=0.0;
			}
			FF2HAWindVel[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 8, 10.0);
			FF2HASpeed[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 9, 600.0);
			FF2HADur[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 10, 1.0);
			FF2HADurNo[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 11, 0.6);
			FF2HANoRot[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 12, 90.0);
			FF2HAHitVert[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 13, 500.0);
			FF2HAHitVel[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 14, 0.5);
			FF2HAStunDur[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 15, 1.5);
			FF2HAStunFlags[client]=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 16, 96);

			FF2HADmgPlayer[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 20, 100.0);
			FF2HADmgOther[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 21, 216.0);
			FF2HADmgFix[client]=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 22, 1);
			FF2HAKnockBack[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 23, 400.0);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 30, SNDHAShoot[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 31, SNDHAWind[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 32, SNDHAHit[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 33, SNDHABeep[client], string_hud);
			
			SNDHAHitType[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 34, 0);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 40, MDLHA[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 41, ANMHA[client], string_hud);
			ANMHADur[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 42, 0.0);
			ANMHAOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 43, 1.0);
			ANMHAHoriOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 44, 0.0);
			ANMHAAngOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 45, 0.0);
			ANMHAVert[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 46, 0.0);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 47, PRTHALaunch[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 48, PRTHATrail[client], string_hud);
			PRTHAOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 49, -90.0);
			
			new String:ModelName[255];
			if(strlen(ANMHA[client])>0)
			{
				if(strlen(MDLHA[client])>0)
				{
					SetupAnimationActor(client, MDLHA[client], 2);
				}
				else
				{
					GetEntPropString(client, Prop_Data, "m_ModelName", ModelName, 255);
					SetupAnimationActor(client, ModelName, 2);
				}
			}
			
			HUDHAStyle[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 50, 1);
			HUDHAOffset[client] = FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 51, 0.77);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 52, HUDHACool[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 53, HUDHARage[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 54, HUDHANo[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 56, HUDHAStun[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 57, HUDHANoRage[client], string_hud);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 59, HUDHAHomeIcon[client], string_hud);
			
			
			ReplaceString(HUDHACool[client], 128, "\\n", "\n");
			ReplaceString(HUDHARage[client], 128, "\\n", "\n");
			ReplaceString(HUDHANo[client], 128, "\\n", "\n");
			ReplaceString(HUDHAStun[client], 128, "\\n", "\n");
			ReplaceString(HUDHANoRage[client], 128, "\\n", "\n");
			
			
			FF2HADebug[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 99, 0);
			if(FF2HADebug[client]!=0)
			{
				PrintToServer("[%s] Boss has debug mode enabled", HAName);
			}
		}
		else if(!strcmp(ability_name, SJName))
		{
			FF2SJEnable[client] = true;
			FF2SJAbilFlags[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 2, 1);
			
			FF2SJStunFlags[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 3, 6);
			
			FF2SJCollide[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 23, 1);
			FF2SJCollideBuild[client] = FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 24, 1);
			CreateAddcondSJList(client, boss); //arg25
			
			FF2SJGoombStunDur[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 26, 0.0);
			FF2SJGoombStunFlags[client]=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 27, 0);
			FF2SJStunShield[client]=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 28, 0);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 40, SNDSJEnter[client], string_path);
			
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 50, MDLSJ[client], string_path);
			FF2_GetAbilityArgumentString(boss, this_plugin_name, ability_name, 51, ANMSJ[client], string_hud);
			ANMSJDur[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 52, 0.0);
			ANMSJOffset[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 53, 0.0);
			ANMSJBaseAng[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 54, 0.0);
			ANMSJHoriOffset[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 55, 0.0);
			ANMSJAngOffset[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 56, 0.0);
			ANMSJVert[client]=FF2_GetAbilityArgumentFloat(boss, this_plugin_name, ability_name, 57, 0.0);
			
			new String:ModelName[255];
			if(strlen(ANMSJ[client])>0)
			{
				if(strlen(MDLSJ[client])>0)
				{
					SetupAnimationActor(client, MDLSJ[client], 4);
				}
				else
				{
					GetEntPropString(client, Prop_Data, "m_ModelName", ModelName, 255);
					SetupAnimationActor(client, ModelName, 4);
				}
			}
		}
	}
}

ClearVariables(client)
{
	//////////GCNAME//////////
	FF2GCEnable[client]=false;
	FF2GCButton[client]=1;
	FF2GCCooldown[client]=15.0;
	FF2GCMinSpeed[client]=200.0;
	FF2GCBaseSpeed[client]=600.0;
	FF2GCMaxSpeed[client]=1200.0;
	FF2GCDecaySpeed[client]= -1.0;
	FF2GCDecaySpeedAir[client] = -2.0;
	FF2GCDecaySpeedWater[client] = -4.0;
	FF2GCLaunchMultAir[client] = 1.0;
	FF2GCLaunchMultWater[client] = 1.0;
	FF2GCDuration[client]=2.0;
	FF2GCAttack[client] = 2;
	FF2GCAbilFlags[client] = 0;
	FF2GCRollCollide[client] = 0;
	FF2GCRollCollideBuild[client] = 0;
	FF2GCTurnRate[client][0] = 7.5;
	FF2GCTurnRate[client][1] = 10.0;
	FF2GCMinRollSpd[client] = 1000.0;
	FF2GCBuildButton[client] = 1;
	FF2GCReleaseButton[client] = 0;
	FF2GCBuildRate[client] = 0.0;
	FF2GCBuildDecay[client] = 0.0;
	FF2GCBuildRateHold[client] = 0.0;
	FF2GCDDFlags[client] = 0;
	FF2GCSpinHit[client] = 0.0;
	ClearGCAddcondList(client);
	ClearGCSpinCondList(client);
	FF2GCStunFlags[client] = 0;
	FF2GCTurnRateAir[client] = 0.0;
	FF2GCTurnRateWater[client] = 0.0;
	FF2GCTurnRate[client][0] = 5.0;
	FF2GCTurnRate[client][1] = 7.5;
	
	Format(SNDGCLaunch[client], string_path, "");
	Format(SNDGCBuild[client], string_path, "");
	SNDGCPitchMin[client] = 128;
	SNDGCPitchMax[client] = 128;
	
	Format(MDLGCRoll[client], string_path, "");
	Format(MDLGCBuild[client], string_path, "");
	Format(ANMGCRoll[client], string_hud, "");
	Format(ANMGCBuild[client], string_hud, "");
	ANMGCRollVert[client]=0.0;
	ANMGCRollBaseAng[client]=0.0;
	ANMGCBuildVert[client]=0.0;
	ANMGCBuildBaseAng[client]=0.0;
	ANMGCRollHoriOffset[client] = 0.0;
	ANMGCRollAngOffset[client]=0.0;
	ANMGCRollOffset[client]=0.0;
	ANMGCBuildHoriOffset[client] = 0.0;
	ANMGCBuildAngOffset[client]=0.0;
	ANMGCBuildOffset[client]=0.0;
	ANMGCRollDur[client] = 0.0;
	ANMGCBuildDur[client] = 0.0;
	Format(PRTGCLaunch[client], string_hud, "");
	Format(PRTGCRoll[client], string_hud, "");
	PRTGCRollOffset[client] = 0.0;
	
	HUDGCStyle[client]=0;
	HUDGCOffset[client]=0.77;
	Format(HUDGCCool[client], string_hud, "");
	Format(HUDGCRage[client], string_hud, "");
	Format(HUDGCNo[client], string_hud, "");
	Format(HUDGCBuild[client], string_hud, "");
	
	Format(HUDGCHow[client], string_hud, "");
	Format(HUDGCWarn[client], string_hud, "");
	Format(HUDGCStun[client], string_hud, "");
	
	FF2GCDebug[client] = 0;
	//////////GCNAME//////////
	
	//////////SJNAME//////////
	FF2SJEnable[client] = false;
	FF2SJAbilFlags[client] = 1;
	FF2SJStunFlags[client] = 6;

	FF2SJCollide[client] = 1;
	FF2SJCollideBuild[client] = 1;
	ClearSJAddcondList(client);
	
	FF2SJGoombStunDur[client]=0.0;
	FF2SJGoombStunFlags[client]=0;
	FF2SJStunShield[client]=0;

	Format(SNDSJEnter[client], string_path, "");
	Format(MDLSJ[client], string_path, "");
	
	Format(ANMSJ[client], string_hud, "");

	ANMSJDur[client]=0.0;
	ANMSJVert[client]=0.0;
	ANMSJBaseAng[client]=0.0;
	ANMSJHoriOffset[client]=0.0;
	ANMSJAngOffset[client]=0.0;
	ANMSJOffset[client]=0.0;
	//////////SJNAME//////////
	
	//////////PRNAME//////////
	FF2PREnable[client] = false;
	FF2PRButton[client] = 0;
	
	FF2PRMinRag[client] = 0.0;
	FF2PRDrain[client] = 0.0;
	
	FF2PRSpeed[client]=900.0;
	FF2PRSpeedAir[client]=900.0;
	FF2PRSpeedWater[client]=500.0;

	FF2PRAccel[client]=3.0;
	FF2PRAccelAir[client]=0.5;
	FF2PRAccelWater[client]=1.0;

	FF2PRDeccel[client]=-2.0;
	FF2PRDeccelAir[client]=-0.5;
	FF2PRDeccelWater[client]=-6.0;
	
	FF2PRTurnRate[client][0] = 5.0;
	FF2PRTurnRate[client][1] = 7.5;
	FF2PRTurnRatePen[client] = 1.0;
	FF2PRTurnRateAir[client] = 0.6;
	FF2PRTurnRateWater[client] = 0.3;
	FF2PRRollMinSpeed[client] = 250.0;
	
	FF2PRTurnAssist[client] = 1.5;
	FF2PRTurnAssistAir[client] = 0.2;
	FF2PRTurnAssistWater[client] = 0.6;
	
	FF2PRAttack[client] = 0;
	ClearPRAddcondList(client);
	
	FF2PRDDFlags[client] = 0;
	FF2PRStunFlags[client] = 0;
	
	FF2PRRollCollide[client] = 0;
	FF2PRRollCollideBuild[client] = 0;
	
	Format(MDLPRRoll[client], string_path, "");
	Format(ANMPRRoll[client], string_hud, "");
	ANMPRRollDur[client]=0.8;
	ANMPRRollOffset[client]=-10.0;
	ANMPRRollHoriOffset[client]=-0.4;
	ANMPRRollAngOffset[client]=-0.3;
	ANMPRRollVert[client]=1.0;
	Format(PRTPRRoll[client], string_hud, "");
	PRTPRRollOffset[client]=-110.0;
	
	HUDPROffset[client] = 0.68;
	Format(HUDPRCool[client], string_hud, "");
	Format(HUDPRRage[client], string_hud, "");
	Format(HUDPRNo[client], string_hud, "");
	Format(HUDPRActive[client], string_hud, "");
	Format(HUDPRStun[client], string_hud, "");
	Format(HUDPRWater[client], string_hud, "");
	Format(HUDPRNoRage[client], string_hud, "");
	
	FF2PRDebug[client]=0;
	//////////PRNAME//////////
	
	//////////HANAME//////////
	FF2HAEnable[client]=false;
	FF2HAButton[client]=0;
	
	FF2HACool[client]=15.0;
	FF2HACost[client]=50.0;
	FF2HARange[client]=600.0;
	FF2HAWind[client]=1.0;
	FF2HAWindAlert[client]=0.4;
	FF2HAWindVel[client]=10.0;
	FF2HASpeed[client]=600.0;
	FF2HADur[client]=1.0;
	FF2HADurNo[client]=0.6;
	FF2HANoRot[client]=90.0;
	FF2HAHitVert[client]=500.0;
	FF2HAHitVel[client]=0.5;
	FF2HAStunDur[client]=1.5;
	FF2HAStunFlags[client]=96;

	FF2HADmgPlayer[client]=100.0;
	FF2HADmgOther[client]=216.0;
	FF2HADmgFix[client]=1;
	FF2HAKnockBack[client]=400.0;
	
	Format(SNDHAShoot[client], string_path, "");
	Format(SNDHAWind[client], string_path, "");
	Format(SNDHAHit[client], string_path, "");
	Format(SNDHABeep[client], string_path, "");
	
	SNDHAHitType[client]=0;
	
	Format(MDLHA[client], string_path, "");
	Format(ANMHA[client], string_path, "");
	ANMHADur[client] = 0.0;
	ANMHAOffset[client] = 1.0;
	ANMHAHoriOffset[client] = 0.0;
	ANMHAAngOffset[client] = 0.0;
	ANMHAVert[client] = 0.0;
	Format(PRTHALaunch[client], string_path, "");
	Format(PRTHATrail[client], string_path, "");
	PRTHAOffset[client] = 0.0;
	
	HUDHAStyle[client] = 1;
	HUDHAOffset[client]=0.77;
	Format(HUDHACool[client], string_hud, "");
	Format(HUDHARage[client], string_hud, "");
	Format(HUDHANo[client], string_hud, "");
	Format(HUDHAStun[client], string_hud, "");
	Format(HUDHANoRage[client], string_hud, "");
	
	
	FF2HADebug[client] = 0;

	//////////HANAME//////////
	
	//////////RDNAME//////////
	FF2RDHitSpd[client]=510.0;
	FF2RDBaseDmg[client]=0.1;
	FF2RDMinDmg[client]=10.0;
	FF2RDMaxDmg[client]=149.0;
	FF2RDDmgFix[client]=1;
	FF2RDBaseKB[client]=0.25;
	FF2RDBaseKBVert[client]=0.25;
	FF2RDMinKB[client]=300.0;
	FF2RDMaxKB[client]=800.0;
	
	Format(SNDRDHit[client], string_path, "");
	SNDRDHitVol[client]=0;
	
	
	FF2JDHitSpd[client]=400.0;
	FF2JDGoombSpd[client]=-250.0;
	FF2JDBaseDmg[client]=0.1;
	FF2JDMinDmg[client]=10.0;
	FF2JDMaxDmg[client]=149.0;
	FF2JDDmgFix[client]=1;
	FF2JDBaseKB[client]=0.25;
	FF2JDSelfKB[client]=-0.6;
	FF2JDSelfKBVert[client]=-0.4;
	FF2JDSelfKBType[client]=0;
	FF2JDGoombMult[client]=1.5;

	Format(SNDJDHit[client], string_path, "");
	SNDJDHitVol[client]=0;
	Format(SNDJDGoomb[client], string_path, "");
	SNDJDGoombVol[client]=0;
	
	Format(HUDRDKillIcon[client], string_hud, "");
	
	FF2RDDebug[client]=0;
	//////////RDNAME//////////
	
	GCSpinCharge[client] = -1.0;
	GCNextCharge[client] = -1.0;
	GCNextPush[client] = -1.0;
	GCNextRoll[client] = -1.0;
	GCIFrames[client] = -1.0;
	GCType[client] = 0;
	FixCollide[client] = -1.0;
	HANextCharge[client] = -1.0;
	HATarget[client] = -1;
	HAWind[client] = -1.0;
	HADur[client] = -1.0;
	CheckedTarget[client] = false;
	
	RunVel[client][0] = 0.0;
	RunVel[client][1] = 0.0;
	RunVel[client][2] = 0.0;
	
	ActorActive[client][0]=false;
	ActorActive[client][1]=false;
	ActorActive[client][2]=false;
	ActorActive[client][3]=false;
	ActorActive[client][4]=false;
	
	LastRollHit[client] = 0.0;
	LastHomeHit[client] = 0.0;
	
	//////////GENERIC//////////
	Jumped[client]=false;
	NextSpinJump[client]=0.0;
}

//this has no real business being here, but I left it anyway just in case
public Action:FF2_OnAbility2(boss, const String:plugin_name[], const String:ability_name[], status)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
	{
		return;
	}
	//new slot=FF2_GetAbilityArgument(boss, this_plugin_name, ability_name, 0);
	//new client=GetClientOfUserId(FF2_GetBossUserId(boss));
	//if(!strcmp(ability_name, GCName))
	//{
	//}
}

public Charge_PreThink(client)
{
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 1.0);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
	{
	}
	else
	{
		if(IsValidClient(client))
		{
			if(IsPlayerAlive(client))
			{
				if(FixCollide[client]>0.0)
				{
					if(FixCollide[client]<=GetGameTime())
					{
						if(GetEntProp(client, Prop_Data, "m_CollisionGroup")!=5)
						{
							if(!HullCheck(client, NULL_VECTOR, 2))
							{
								SetPlayerCollision(client, 5);
								FixCollide[client]=-1.0;
								if(FF2GCDebug[client]!=0)
								{
									PrintToServer("[%s] Set player %i collision to normal", GCName, client);
								}
							}
							else
							{
								FixCollide[client]+=0.25;
							}
						}
					}
				}
				if(IsBoss(client))
				{
					new bool:StopRoll=false;
					new DidPress = 0;
					if(ActorActive[client][0])
					{
						if(ANMGCRollDur[client]>0.0)
						{
							if(NextAnim[client][0]>0.0)
							{
								AnimateActor(client, CurAnim[client][0], 0);
								NextAnim[client][0]=GetGameTime()+AnimLoop[client][0];
							}
						}
						UpdateActorLocation(client, 0);
					}
					else if(ActorActive[client][1])
					{
						if(ANMGCBuildDur[client]>0.0)
						{
							if(NextAnim[client][1]>0.0)
							{
								AnimateActor(client, CurAnim[client][1], 1);
								NextAnim[client][1]=GetGameTime()+AnimLoop[client][1];
							}
						}
						UpdateActorLocation(client, 1);
					}
					else if(ActorActive[client][2])
					{
						if(ANMHADur[client]>0.0)
						{
							if(NextAnim[client][2]>0.0)
							{
								AnimateActor(client, CurAnim[client][2], 2);
								NextAnim[client][2]=GetGameTime()+AnimLoop[client][2];
							}
						}
						UpdateActorLocation(client, 2);
					}
					else if(ActorActive[client][3])
					{
						if(ANMPRRollDur[client]>0.0)
						{
							if(NextAnim[client][3]>0.0)
							{
								AnimateActor(client, CurAnim[client][3], 3);
								NextAnim[client][3]=GetGameTime()+AnimLoop[client][3];
							}
						}
						UpdateActorLocation(client, 3);
					}
					else if(ActorActive[client][4])
					{
						if(ANMSJDur[client]>0.0)
						{
							if(NextAnim[client][4]>0.0)
							{
								AnimateActor(client, CurAnim[client][4], 4);
								NextAnim[client][4]=GetGameTime()+AnimLoop[client][4];
							}
						}
						UpdateActorLocation(client, 4);
					}
					new actweapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
					new Float:fVel[3];
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel);
					fVel[2] = 0.0;
					new Float:CurSpeed = GetVectorLength(fVel);
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel);
					if(FF2SJEnable[client])
					{
						if(IsSwimmingStrict(client))
						{
							if(FF2SJAbilFlags[client] & 4)
							{
								if(FF2SJAbilFlags[client] & 1)
								{
									if(Jumped[client])
									{
										EndJump(client, true);
									}
									else
									{
										NextSpinJump[client] = GetGameTime()+0.1;
									}
								}
								else if(IsSwimming(client))
								{
									if(Jumped[client])
									{
										EndJump(client, true);
									}
									else
									{
										NextSpinJump[client] = GetGameTime()+0.1;
									}
								}
							}
						}
						else if(GetEntityFlags(client) & FL_ONGROUND)
						{
							if(Jumped[client])
							{
								EndJump(client, true);
							}
						}
						if(JustJumped(client, buttons))
						{
							DoJump(client, false);
						}
						else if(FF2SJAbilFlags[client] & 1)
						{
							if(IsAirborne(client))
							{
								DoJump(client, false);
							}
						}
						if(ClientHasStunFlags(client, FF2SJStunFlags[client]))
						{
							EndJump(client, true);
						}
						if(Jumped[client])
						{
							if(FF2SJAbilFlags[client] & 8)
							{
								if(GetVectorLength(fVel)>=FF2JDHitSpd[client] || fVel[2]<=FF2JDGoombSpd[client])
								{
									HullCheck(client, NULL_VECTOR, 4);
								}
							}
							ApplySJAddcond(client, fVel[2]);
						}
					}
					if(FF2PREnable[client])
					{
						if(FF2PRAbilFlags[client] & 16)
						{
							if(GCType[client]==0 || GCType[client]==5)
							{
								if(GCNextRoll[client]<=GetGameTime())
								{
									if(CurSpeed >= FF2PRRollMinSpeed[client])
									{
										if((buttons & IN_DUCK) && !(buttons & IN_JUMP))
										{
											if(CanUsePR(client)==0)
											{
												if(GetEntityFlags(client) & FL_ONGROUND)
												{
													SetChargeState(client, 2);
												}
												else if(GCType[client]!=0)
												{
													if(LastPush[client]+0.23<GetGameTime())
													{
													}
													else
													{
														SetChargeState(client, 2);
													}
												}
											}
										}
									}
								}
							}
						}
						if(GCType[client]==0)
						{
							if(GCNextRoll[client]<=GetGameTime())
							{
								if(FF2PRButton[client]==1)
								{
									if((buttons & IN_ATTACK2) && !(LastButtons[client] & IN_ATTACK2))
									{
										PRS_Invoke(client);
									}
								}
								else if(FF2PRButton[client]==2)
								{
									if((buttons & IN_ATTACK3) && !(LastButtons[client] & IN_ATTACK3))
									{
										PRS_Invoke(client);
									}
								}
								else if(FF2PRButton[client]==3)
								{
									if((buttons & IN_RELOAD) && !(LastButtons[client] & IN_RELOAD))
									{
										PRS_Invoke(client);
									}
								}
								else if(FF2PRButton[client]==0)
								{
									if((buttons & IN_ATTACK) && !(LastButtons[client] & IN_ATTACK))
									{
										PRS_Invoke(client);
									}
								}
								else
								{
									if(IsSwimming(client))
									{
										if(!(FF2PRAbilFlags[client] & 4))
										{
											SetChargeState(client, 5);
										}
									}
									else if(GetEntityFlags(client) & FL_ONGROUND)
									{
										SetChargeState(client, 5);
									}
									else
									{
										if(!(FF2PRAbilFlags[client] & 2))
										{
											SetChargeState(client, 5);
										}
									}
								}
							}
						}
						else if(GCType[client]==5)
						{
							if(DHooksOn)
							{
								if(GetEntityFlags(client) & FL_ONGROUND)
								{
									LastPush[client]=GetGameTime();
								}
							}
							else
							{
								if((GetEntityFlags(client) & FL_ONGROUND) && !IsSwimming(client))
								{
									//this is for when the boss needs to go beyond the speed limit
									if(CurSpeed>450.0)
									{
										//we teleport the boss up a bit if they're on the floor during the charge
										//this is so we don't have to deal with tf2's ground speed cap shenanigans
										//fundamentally works like a bunny hop but not nearly as noticable
										new Float:location[3];
										GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", location);
										//a dodgy work around for steep slopes
										new Float:slopebonus = GetGameTime()-LastPush[client];
										if(slopebonus>0.2)
										{
											slopebonus=0.0;
										}
										else if(slopebonus<0.0)
										{
											slopebonus=0.0;
										}
										location[2]+=25.0-(slopebonus*25.0);
										//don't do this if it would get the player caught in geometry
										if(!HullCheck(client, location, 0))
										{
											TeleportEntity(client, location, NULL_VECTOR, NULL_VECTOR);
											LastPush[client]=GetGameTime();
										}
									}
									else
									{
										LastPush[client]=GetGameTime();
									}
								}
							}
							if(HullCheck(client, NULL_VECTOR, 5))
							{
								RunVel[client][0] = fVel[0];
								RunVel[client][1] = fVel[1];
							}
							//this actually helps me push the boss past the speed limit
							TF2_AddCondition(client, TFCond_LostFooting, 0.3);
							//velocity code
							if(GCNextPush[client]<=GetGameTime())
							{
								if(IsSwimming(client))
								{
									fVel[0] = RunVel[client][0];
									fVel[1] = RunVel[client][1];
									//fVel[2] = RunVel[client][2];
									TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);
									if(FF2PRAbilFlags[client] & 4)
									{
										StopRoll = true;
									}
								}
								else if(LastPush[client]+0.3<GetGameTime())
								{
									fVel[0] = RunVel[client][0];
									fVel[1] = RunVel[client][1];
									TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);
									if(FF2PRAbilFlags[client] & 2)
									{
										StopRoll = true;
									}
								}
								else
								{
									fVel[0] = RunVel[client][0];
									fVel[1] = RunVel[client][1];
									TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);
								}
								GCNextPush[client]=GetGameTime()+0.1;
							}
							if(buttons & IN_FORWARD)
							{
								if(buttons & IN_MOVELEFT)
								{
									ChangeRunForce(client, 45.0, false);
									RotateRunPassive(client, 45.0);
								}
								else if(buttons & IN_MOVERIGHT)
								{
									ChangeRunForce(client, -45.0, false);
									RotateRunPassive(client, -45.0);
								}
								else
								{
									ChangeRunForce(client, 0.0, false);
									RotateRunPassive(client, 0.0);
								}
							}
							else if(buttons & IN_BACK)
							{
								if(buttons & IN_MOVELEFT)
								{
									ChangeRunForce(client, 135.0, false);
									RotateRunPassive(client, 135.0);
								}
								else if(buttons & IN_MOVERIGHT)
								{
									ChangeRunForce(client, 225.0, false);
									RotateRunPassive(client, 225.0);
								}
								else
								{
									ChangeRunForce(client, 180.0, false);
									RotateRunPassive(client, 180.0);
								}
							}
							else if(buttons & IN_MOVELEFT)
							{
								ChangeRunForce(client, 90.0, false);
								RotateRunPassive(client, 90.0);
							}
							else if(buttons & IN_MOVERIGHT)
							{
								ChangeRunForce(client, -90.0, false);
								RotateRunPassive(client, -90.0);
							}
							if(!IsSwimming(client))
							{
								if(LastPush[client]+0.23<GetGameTime())
								{
								}
								else
								{
									if((buttons & IN_JUMP) && !(LastButtons[client] & IN_JUMP))
									{
										DoJump(client, true);
										if(FF2PRAbilFlags[client] & 2)
										{
											StopRoll = true;
										}
									}
								}
							}
							if(GCNextRoll[client]<=GetGameTime())
							{
								if(FF2PRButton[client]>-1)
								{
									if(FF2PRButton[client]==1)
									{
										if((buttons & IN_ATTACK2) && !(LastButtons[client] & IN_ATTACK2))
										{
											StopRoll = true;
										}
									}
									else if(FF2PRButton[client]==2)
									{
										if((buttons & IN_ATTACK3) && !(LastButtons[client] & IN_ATTACK3))
										{
											StopRoll = true;
										}
									}
									else if(FF2PRButton[client]==3)
									{
										if((buttons & IN_RELOAD) && !(LastButtons[client] & IN_RELOAD))
										{
											StopRoll = true;
										}
									}
									else
									{
										if((buttons & IN_ATTACK) && !(LastButtons[client] & IN_ATTACK))
										{
											StopRoll = true;
										}
									}
								}
							}
							if((FF2PRAbilFlags[client] & 16) && FF2PRButton[client]<0)
							{
								//don't use certain args in mode 5 with certain settings
							}
							else
							{
								if(GetVectorLength(RunVel[client])>=FF2RDHitSpd[client])
								{
									if(strlen(PRTPRRoll[client])>0)
									{
										if(RollPart[client]==0)
										{
											CreateRollTrail(client, PRTPRRoll[client], PRTPRRollOffset[client], ANMPRRollVert[client]);
										}
									}
								}
								else
								{
									KillRollTrail(client);
								}
								if(PRARollCondID[client][0]>0)
								{
									ApplyPRAddcond(client, GetVectorLength(RunVel[client]));
								}
								if(FF2PRAttack[client]==2)
								{
									if(actweapon != GetPlayerWeaponSlot(client, 2))
									{
										buttons = buttons & ~IN_ATTACK;
										buttons = buttons & ~IN_ATTACK2;
										buttons = buttons & ~IN_ATTACK3;
										DidPress = DidPress & IN_ATTACK2;
										DidPress = DidPress & IN_ATTACK3;
									}
								}
								else if(FF2PRAttack[client]==1)
								{
									buttons = buttons & ~IN_ATTACK;
									buttons = buttons & ~IN_ATTACK2;
									buttons = buttons & ~IN_ATTACK3;
									DidPress = DidPress & IN_ATTACK2;
									DidPress = DidPress & IN_ATTACK3;
								}
								if(TF2_IsPlayerInCondition(client, TFCond_Dazed))
								{
									if(FF2PRStunFlags[client]>0)
									{
										if(ClientHasStunFlags(client, FF2PRStunFlags[client]))
										{
											StopRoll = true;
										}
									}
								}
								if(FF2PRButton[client]>-1)
								{
									if(FF2PRDrain[client]!=0.0)
									{
										new Float:ragez = FF2_GetBossCharge(FF2_GetBossIndex(client), 0);
										ragez -= FF2PRDrain[client];
										if (ragez < 0.0)
										{
											FF2_SetBossCharge(FF2_GetBossIndex(client), 0, 0.0);
										}
										else
										{
											FF2_SetBossCharge(FF2_GetBossIndex(client), 0, ragez);
										}
									}
									if(FF2PRMinRag[client]>0.0)
									{
										if(!(FF2PRAbilFlags[client] & 64))
										{
											if(FF2_GetBossCharge(FF2_GetBossIndex(client), 0)<FF2PRMinRag[client])
											{
												StopRoll = true;
											}
										}
									}
								}
							}
							ApplyDeccelForce(client, false);
						}
						else if(GCType[client] == 2)
						{
							if(GCTime[client]>=GetGameTime())
							{
								if(HullCheck(client, NULL_VECTOR, 5))
								{
									//RunVel[client][0] = fVel[0];
									//RunVel[client][1] = fVel[1];
									//we'll rapidly drain it instead
									//because setting it to vel while rolling is kinda munted
									WallPenalty[client]+=1;
									ScaleRunForce(client, GetVectorLength(RunVel[client])+(WallPenalty[client]*-1.5));
								}
								else
								{
									if(WallPenalty[client]>0)
									{
										WallPenalty[client]-=2;
										if(WallPenalty[client]<0)
										{
											WallPenalty[client]=0;
										}
										else if(WallPenalty[client]>20)
										{
											WallPenalty[client]=20;
										}
									}
								}
								if(DHooksOn)
								{
									if(GetEntityFlags(client) & FL_ONGROUND)
									{
										LastPush[client]=GetGameTime();
									}
								}
								else
								{
									if(GetVectorLength(RunVel[client])>=450.0)
									{
										//ground detection and a few and bunny hop code
										if(GetEntityFlags(client) & FL_ONGROUND)
										{
											//we teleport the boss up a bit if they're on the floor during the charge
											//this is so we don't have to deal with tf2's ground speed cap shenanigans
											//fundamentally works like a bunny hop but not nearly as noticable
											new Float:location[3];
											GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", location);
											//a dodgy work around for steep slopes
											new Float:slopebonus = GetGameTime()-LastPush[client];
											if(slopebonus>0.2)
											{
												slopebonus=0.0;
											}
											else if(slopebonus<0.0)
											{
												slopebonus=0.0;
											}
											location[2]+=25.0-(slopebonus*25.0);
											//don't do this if it would get the player caught in geometry
											if(!HullCheck(client, location, 0))
											{
												TeleportEntity(client, location, NULL_VECTOR, NULL_VECTOR);
												LastPush[client]=GetGameTime();
											}
										}
									}
								}
								//this actually helps me push the boss past the speed limit
								TF2_AddCondition(client, TFCond_LostFooting, 0.3);
								//velocity code
								if(GCNextPush[client]<=GetGameTime())
								{
									if(IsSwimming(client))
									{
										fVel[0] = RunVel[client][0];
										fVel[1] = RunVel[client][1];
										fVel[1] = RunVel[client][2];
										TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);
									}
									else if(LastPush[client]+0.3<GetGameTime())
									{
										fVel[0] = RunVel[client][0];
										fVel[1] = RunVel[client][1];
										TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);
									}
									else
									{
										fVel[0] = RunVel[client][0];
										fVel[1] = RunVel[client][1];
										TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);
									}
									GCNextPush[client]=GetGameTime()+0.1;
								}
								if(buttons & IN_FORWARD)
								{
									RotateRunToAim(client, 1.0);
								}
								else if(buttons & IN_BACK)
								{
									RotateRunToAim(client, 1.25);
								}
								else
								{
									RotateRunToAim(client, 1.0);
								}
								if(GetVectorLength(RunVel[client])>=FF2RDHitSpd[client])
								{
									if(strlen(PRTPRRoll[client])>0)
									{
										if(RollPart[client]==0)
										{
											CreateRollTrail(client, PRTPRRoll[client], PRTPRRollOffset[client], ANMPRRollVert[client]);
										}
									}
								}
								else
								{
									KillRollTrail(client);
								}
								if(PRARollCondID[client][0]>0)
								{
									ApplyPRAddcond(client, GetVectorLength(RunVel[client]));
								}
								if(FF2PRAttack[client]==2)
								{
									if(actweapon != GetPlayerWeaponSlot(client, 2))
									{
										buttons = buttons & ~IN_ATTACK;
										buttons = buttons & ~IN_ATTACK2;
										buttons = buttons & ~IN_ATTACK3;
										DidPress = DidPress & IN_ATTACK2;
										DidPress = DidPress & IN_ATTACK3;
									}
								}
								else if(FF2PRAttack[client]==1)
								{
									buttons = buttons & ~IN_ATTACK;
									buttons = buttons & ~IN_ATTACK2;
									buttons = buttons & ~IN_ATTACK3;
									DidPress = DidPress & IN_ATTACK2;
									DidPress = DidPress & IN_ATTACK3;
								}
								if(TF2_IsPlayerInCondition(client, TFCond_Dazed))
								{
									if(FF2PRStunFlags[client]>0)
									{
										if(ClientHasStunFlags(client, FF2PRStunFlags[client]))
										{
											StopRoll = true;
										}
									}
								}
								if(GetVectorLength(RunVel[client])<=FF2PRRollMinSpeed[client])
								{
									StopRoll = true;
								}
								if(!(FF2PRAbilFlags[client] & 32) && !(buttons & IN_DUCK))
								{
									StopRoll = true;
								}
								if(!IsSwimming(client))
								{
									if(LastPush[client]+0.23<GetGameTime())
									{
									}
									else
									{
										if((buttons & IN_JUMP) && !(LastButtons[client] & IN_JUMP))
										{
											DoJump(client, true);
											if(GCType[client]==5)
											{
												if(FF2PRAbilFlags[client] & 2)
												{
													StopRoll = true;
												}
											}
										}
									}
								}
								else
								{
									if(FF2PRAbilFlags[client] & 4)
									{
										StopRoll = true;
									}
								}
								if(FF2PRDrain[client]!=0.0)
								{
									new Float:ragez = FF2_GetBossCharge(FF2_GetBossIndex(client), 0);
									ragez -= FF2PRDrain[client];
									if (ragez < 0.0)
									{
										FF2_SetBossCharge(FF2_GetBossIndex(client), 0, 0.0);
									}
									else
									{
										FF2_SetBossCharge(FF2_GetBossIndex(client), 0, ragez);
									}
								}
								if(FF2PRMinRag[client]>0.0)
								{
									if(!(FF2PRAbilFlags[client] & 128))
									{
										if(FF2_GetBossCharge(FF2_GetBossIndex(client), 0)<FF2PRMinRag[client])
										{
											StopRoll = true;
										}
									}
								}
								ApplyDeccelForce(client, false);
							}
							else
							{
								StopRoll=true;
							}
						}
					}
					if(FF2HAEnable[client])
					{
						if(GCType[client]==0 || GCType[client]==5)
						{
							if(FF2HAButton[client]==1)
							{
								if((buttons & IN_ATTACK2) && !(LastButtons[client] & IN_ATTACK2))
								{
									HOA_Invoke(client);
								}
							}
							if(FF2HAButton[client]==2)
							{
								if((buttons & IN_ATTACK3) && !(LastButtons[client] & IN_ATTACK3))
								{
									HOA_Invoke(client);
								}
							}
							else if(FF2HAButton[client]==3)
							{
								if((buttons & IN_RELOAD) && !(LastButtons[client] & IN_RELOAD))
								{
									HOA_Invoke(client);
								}
							}
							else
							{
								if((buttons & IN_ATTACK) && !(LastButtons[client] & IN_ATTACK))
								{
									HOA_Invoke(client);
								}
							}
						}
						else if(GCType[client]==3)
						{
							//disable these during it
							buttons = buttons & ~IN_ATTACK;
							buttons = buttons & ~IN_ATTACK2;
							buttons = buttons & ~IN_ATTACK3;
							buttons = buttons & ~IN_JUMP;
							if(HADur[client]>=GetGameTime())
							{
								if(HullCheck(client, NULL_VECTOR, 3))
								{
									EndHomingAttack(client, true);
								}
								else
								{
									HomeIntoTarget(client);
								}
							}
							else
							{
								if(HAWind[client]>=GetGameTime())
								{
									fVel[0] *=0.98;
									fVel[1] *=0.98;
									if(fVel[2]>FF2HAWindVel[client]*4.0)
									{
									}
									else if(fVel[2]>FF2HAWindVel[client]*2.0)
									{
										fVel[2] += FF2HAWindVel[client]*0.125;
									}
									else if(fVel[2]>FF2HAWindVel[client])
									{
										fVel[2] += FF2HAWindVel[client]*0.25;
									}
									else if(fVel[2]<FF2HAWindVel[client]*-1.0)
									{
										fVel[2] += FF2HAWindVel[client]*1.5;
									}
									else
									{
										fVel[2] += FF2HAWindVel[client];
									}
									TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);
									//we get our target and inform them a bit early so they can react
									if(!CheckedTarget[client])
									{
										if(HAWind[client]-FF2HAWindAlert[client]<=GetGameTime())
										{
											GetHomingTarget(client);
										}
									}
									//force the boss off ground for this ability
									if(GetEntityFlags(client) & FL_ONGROUND)
									{
										new Float:location[3];
										GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", location);
										new Float:slopebonus = GetGameTime()-LastPush[client];
										if(slopebonus>0.2)
										{
											slopebonus=0.0;
										}
										else if(slopebonus<0.0)
										{
											slopebonus=0.0;
										}
										location[2]+=25.0-(slopebonus*25.0);
										if(!HullCheck(client, location, 0))
										{
											TeleportEntity(client, location, NULL_VECTOR, NULL_VECTOR);
											LastPush[client]=GetGameTime();
										}
									}
								}
								else if(HAWind[client]>0.0)
								{
									HAWind[client]=-1.0;
									if(HATarget[client]>=-1)
									{
										HADur[client]=GetGameTime()+FF2HADur[client];
										TF2_StunPlayer(client, FF2HADur[client], 0.0, 4, client);
									}
									else
									{
										HADur[client]=GetGameTime()+FF2HADurNo[client];
										TF2_StunPlayer(client, FF2HADurNo[client], 0.0, 4, client);
									}
									if(strlen(SNDHAShoot[client])>0)
									{
										EmitSoundToAll(SNDHAShoot[client], client);
									}
									new Float:angle[3];
									GetClientEyeAngles(client, angle);
									HAAngles[client][0]=angle[0];
									HAAngles[client][1]=angle[1];
									HAAngles[client][2]=angle[2];
									if(strlen(PRTHALaunch[client])>0)
									{
										CreateParticle(client, PRTHALaunch[client]);
									}
									if(strlen(PRTHATrail[client])>0)
									{
										CreateRollTrail(client, PRTHATrail[client], PRTHAOffset[client], ANMHAVert[client]);
									}
								}
								else
								{
									EndHomingAttack(client, false);
								}
							}
						}
					}
					if(FF2GCEnable[client])
					{
						if(GCType[client]==0 || GCType[client]==5)
						{
							if(FF2GCButton[client]==1)
							{
								if((buttons & IN_ATTACK2) && !(LastButtons[client] & IN_ATTACK2))
								{
									GRC_Invoke(client);
								}
							}
							else if(FF2GCButton[client]==2)
							{
								if((buttons & IN_ATTACK3) && !(LastButtons[client] & IN_ATTACK3))
								{
									GRC_Invoke(client);
								}
							}
							else if(FF2GCButton[client]==3)
							{
								if((buttons & IN_RELOAD) && !(LastButtons[client] & IN_RELOAD))
								{
									GRC_Invoke(client);
								}
							}
							else
							{
								if((buttons & IN_ATTACK) && !(LastButtons[client] & IN_ATTACK))
								{
									GRC_Invoke(client);
								}
							}
						}
						else if(GCType[client] == 4)
						{
							if(TF2_IsPlayerInCondition(client, TFCond_Dazed))
							{
								if(FF2GCStunFlags[client]>0)
								{
									if(ClientHasStunFlags(client, FF2GCStunFlags[client]))
									{
										GCNextCharge[client] = GetGameTime()+FF2GCCooldown[client];
										StopRoll=true;
									}
								}
							}
							if(FF2GCSpinHit[client]>0.0)
							{
								HullCheck(client, NULL_VECTOR, 1);
							}
							ApplySpinAddcond(client);
							new Float:fangles[3];
							GetClientEyeAngles(client, fangles);
							SetEntPropVector(client, Prop_Data, "m_angRotation", fangles);
							if(FF2GCReleaseButton[client]==1)
							{
								if((buttons & IN_ATTACK2) && !(LastButtons[client] & IN_ATTACK2))
								{
									SetChargeState(client, 1);
								}
								if(buttons & IN_ATTACK2)
								{
									buttons = buttons & ~IN_ATTACK2;
									DidPress |= IN_ATTACK2;
								}
							}
							else if(FF2GCReleaseButton[client]==2)
							{
								if((buttons & IN_ATTACK3) && !(LastButtons[client] & IN_ATTACK3))
								{
									SetChargeState(client, 1);
								}
								if(buttons & IN_ATTACK3)
								{
									buttons = buttons & ~IN_ATTACK3;
									DidPress |= IN_ATTACK3;
								}
							}
							else if(FF2GCReleaseButton[client]==3)
							{
								if((buttons & IN_RELOAD) && !(LastButtons[client] & IN_RELOAD))
								{
									SetChargeState(client, 1);
								}
							}
							else if(FF2GCReleaseButton[client]==4)
							{
								if((buttons & IN_JUMP) && !(LastButtons[client] & IN_JUMP))
								{
									SetChargeState(client, 1);
								}
								if(buttons & IN_JUMP)
								{
									buttons = buttons & ~IN_JUMP;
									DidPress |= IN_JUMP;
								}
							}
							else
							{
								if((buttons & IN_ATTACK) && !(LastButtons[client] & IN_ATTACK))
								{
									SetChargeState(client, 1);
								}
								if(buttons & IN_ATTACK)
								{
									buttons = buttons & ~IN_ATTACK;
									DidPress |= IN_ATTACK;
								}
							}
							if(FF2GCBuildButton[client]==1)
							{
								if((buttons & IN_ATTACK2) && !(LastButtons[client] & IN_ATTACK2))
								{
									BuildCharge(client, 0, true);
								}
								else
								{
									if((buttons & IN_ATTACK2) && (LastButtons[client] & IN_ATTACK2))
									{
										BuildCharge(client, 1, false);
									}
									else
									{
										BuildCharge(client, 2, false);
									}
								}
								if(buttons & IN_ATTACK2)
								{
									DidPress |= IN_ATTACK2;
								}
							}
							else if(FF2GCBuildButton[client]==2)
							{
								if((buttons & IN_ATTACK3) && !(LastButtons[client] & IN_ATTACK3))
								{
									BuildCharge(client, 0, true);
								}
								else
								{
									if((buttons & IN_ATTACK3) && (LastButtons[client] & IN_ATTACK3))
									{
										BuildCharge(client, 1, false);
									}
									else
									{
										BuildCharge(client, 2, false);
									}
								}
								if(buttons & IN_ATTACK3)
								{
									DidPress |= IN_ATTACK3;
								}
							}
							else if(FF2GCBuildButton[client]==3)
							{
								if((buttons & IN_RELOAD) && !(LastButtons[client] & IN_RELOAD))
								{
									BuildCharge(client, 0, true);
								}
								else
								{
									if((buttons & IN_RELOAD) && (LastButtons[client] & IN_RELOAD))
									{
										BuildCharge(client, 1, false);
									}
									else
									{
										BuildCharge(client, 2, false);
									}
								}
							}
							else if(FF2GCBuildButton[client]==4)
							{
								if((buttons & IN_JUMP) && !(LastButtons[client] & IN_JUMP))
								{
									BuildCharge(client, 0, true);
								}
								else
								{
									if((buttons & IN_JUMP) && (LastButtons[client] & IN_JUMP))
									{
										BuildCharge(client, 1, false);
									}
									else
									{
										BuildCharge(client, 2, false);
									}
								}
								if(buttons & IN_JUMP)
								{
									DidPress |= IN_JUMP;
								}
							}
							else
							{
								if((buttons & IN_ATTACK) && !(LastButtons[client] & IN_ATTACK))
								{
									BuildCharge(client, 0, true);
								}
								else
								{
									if((buttons & IN_ATTACK) && (LastButtons[client] & IN_ATTACK))
									{
										BuildCharge(client, 1, false);
									}
									else
									{
										BuildCharge(client, 2, false);
									}
								}
								if(buttons & IN_ATTACK)
								{
									DidPress |= IN_ATTACK;
								}
							}
							buttons = buttons & ~IN_ATTACK;
							buttons = buttons & ~IN_ATTACK2;
							buttons = buttons & ~IN_ATTACK3;
							buttons = buttons & ~IN_JUMP;
							buttons = buttons & ~IN_RELOAD;
						}
						else if(GCType[client] == 1)
						{
							if(GCTime[client]>=GetGameTime())
							{
								if(TF2_IsPlayerInCondition(client, TFCond_Dazed))
								{
									if(FF2GCStunFlags[client]>0)
									{
										if(ClientHasStunFlags(client, FF2GCStunFlags[client]))
										{
											StopRoll=true;
										}
									}
								}
								
								
								//disable normal jumps during the charge
								if(buttons & IN_JUMP)
								{
									if(!(LastButtons[client] & IN_JUMP))
									{
										if(!IsSwimming(client))
										{
											if(LastPush[client]+0.23<GetGameTime())
											{
											}
											else
											{
												if(GetVectorLength(RunVel[client]) <= FF2GCMinRollSpd[client])
												{
													DoJump(client, true);
													StopRoll=true;
												}
											}
										}
									}
									DidPress |= IN_JUMP;
								}
								buttons = buttons & ~IN_JUMP;
								if(GetVectorLength(RunVel[client])>=FF2GCMinSpeed[client])
								{
									if(GCARollCondID[client][0]>0)
									{
										ApplyGCAddcond(client, GetVectorLength(RunVel[client]));
									}
									if(GetVectorLength(RunVel[client])>=FF2RDHitSpd[client])
									{
										if(strlen(PRTGCRoll[client])>0)
										{
											if(RollPart[client]==0)
											{
												CreateRollTrail(client, PRTGCRoll[client], PRTGCRollOffset[client], ANMGCRollVert[client]);
											}
										}
									}
									else
									{
										KillRollTrail(client);
									}
									if(HullCheck(client, NULL_VECTOR, 1))
									{
										//RunVel[client][0] = fVel[0];
										//RunVel[client][1] = fVel[1];
										//we'll rapidly drain it instead
										//because setting it to vel while rolling is kinda munted
										WallPenalty[client]+=1;
										ScaleRunForce(client, GetVectorLength(RunVel[client])+(WallPenalty[client]*-1.5));
									}
									else
									{
										if(WallPenalty[client]>0)
										{
											WallPenalty[client]-=2;
											if(WallPenalty[client]<0)
											{
												WallPenalty[client]=0;
											}
											else if(WallPenalty[client]>20)
											{
												WallPenalty[client]=20;
											}
										}
									}
									if(DHooksOn)
									{
										if(GetEntityFlags(client) & FL_ONGROUND)
										{
											LastPush[client]=GetGameTime();
										}
									}
									else
									{
										//ground detection and a few and bunny hop code
										if(GetEntityFlags(client) & FL_ONGROUND)
										{
											//we teleport the boss up a bit if they're on the floor during the charge
											//this is so we don't have to deal with tf2's ground speed cap shenanigans
											//fundamentally works like a bunny hop but not nearly as noticable
											new Float:location[3];
											GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", location);
											//a dodgy work around for steep slopes
											new Float:slopebonus = GetGameTime()-LastPush[client];
											if(slopebonus>0.2)
											{
												slopebonus=0.0;
											}
											else if(slopebonus<0.0)
											{
												slopebonus=0.0;
											}
											location[2]+=25.0-(slopebonus*25.0);
											//don't do this if it would get the player caught in geometry
											if(!HullCheck(client, location, 0))
											{
												TeleportEntity(client, location, NULL_VECTOR, NULL_VECTOR);
												LastPush[client]=GetGameTime();
											}
										}
									}
									//this actually helps me push the boss past the speed limit
									TF2_AddCondition(client, TFCond_LostFooting, 0.3);
									//velocity code
									if(GCNextPush[client]<=GetGameTime())
									{
										if(IsSwimming(client))
										{
											fVel[0] = RunVel[client][0];
											fVel[1] = RunVel[client][1];
											//fVel[2] = RunVel[client][2];
											TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);
										}
										else if(LastPush[client]+0.23<GetGameTime())
										{
											fVel[0] = RunVel[client][0];
											fVel[1] = RunVel[client][1];
											TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);
										}
										else
										{
											fVel[0] = RunVel[client][0];
											fVel[1] = RunVel[client][1];
											TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fVel);
										}
										GCNextPush[client]=GetGameTime()+0.1;
									}
									if(buttons & IN_FORWARD)
									{
										ChangeRunForce(client, 0.0, true);
										RotateRunToAim(client, 1.0);
									}
									else if(buttons & IN_BACK)
									{
										ChangeRunForce(client, 180.0, true);
										RotateRunToAim(client, 1.25);
									}
									else
									{
										ChangeRunForce(client, 0.0, true);
										RotateRunToAim(client, 1.0);
									}
								}
								else
								{
									StopRoll=true;
								}
								if(FF2GCAttack[client]==2)
								{
									if(actweapon != GetPlayerWeaponSlot(client, 2))
									{
										buttons = buttons & ~IN_ATTACK;
										buttons = buttons & ~IN_ATTACK2;
										buttons = buttons & ~IN_ATTACK3;
									}
								}
								else if(FF2GCAttack[client]==1)
								{
									buttons = buttons & ~IN_ATTACK;
									buttons = buttons & ~IN_ATTACK2;
									buttons = buttons & ~IN_ATTACK3;
								}
								ApplyDeccelForce(client, true);
							}
							else
							{
								StopRoll=true;
							}
						}
					}
					if(StopRoll)
					{
						EndRoll(client);
					}
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", LastVel[client]);
					GetClientEyeAngles(client, LastAngles[client]);
					LastButtons[client]= buttons;
					LastButtons[client] |= DidPress;
					LastFlags[client] = GetEntityFlags(client);
					if(GCType[client]!=0)
					{
						if(buttons & IN_BACK)
						{
							buttons = buttons & ~IN_BACK;
						}
					}
				}
				else
				{
					if(ActorActive[client][0])
					{
						HideActor(client, 0);
					}
					if(ActorActive[client][1])
					{
						HideActor(client, 1);
					}
					if(ActorActive[client][2])
					{
						HideActor(client, 2);
					}
					if(ActorActive[client][3])
					{
						HideActor(client, 3);
					}
					if(ActorActive[client][4])
					{
						HideActor(client, 4);
					}
				}
			}
		}
	}
    return Plugin_Changed;
}

public Action:ClientTimer(Handle:timer)
{
    if(!FF2_IsFF2Enabled() || FF2_GetRoundState()!=1)
	{
	    return Plugin_Stop;
	}
	for(new client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client))
		{
			if(IsPlayerAlive(client))
			{
				if(IsBoss(client))
				{
					if(FF2HAEnable[client])
					{
						//did this to test airblasting the boss during a homing attack
						//I'll leave it here anyway since it might scare the shit out of unsuspecting players
						if(IsFakeClient(client))
						{
							if(CanUseHA(client)==0)
							{
								if(FF2HACost[client]<=0.0)
								{
									HOA_Invoke(client);
								}
								else if(FF2_GetBossCharge(FF2_GetBossIndex(client), 0)<100.0)
								{
									HOA_Invoke(client);
								}
							}
						}
						//0 = nothing is limiting it from use
						//1 = on cooldown
						//2 = stunned
						//3 = not enough rage
						//4 = on the ground
						//5 = in a rolling state
						//7 = ability is disabled by the config
						if(HANextCharge[client]<=GetGameTime())
						{
							if(CanUseHA(client)==0)
							{
								SetHudTextParams(-1.0, HUDHAOffset[client], 0.35, 255, 64, 64, 255, 0, 0.2, 0.0, 0.1);
								ShowSyncHudText(client, HomeHUD, HUDHARage[client], FF2HACost[client]);
							}
							else
							{
								SetHudTextParams(-1.0, HUDHAOffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
								ShowSyncHudText(client, HomeHUD, HUDHANo[client], FF2HACost[client]);
							}
						}
						else
						{
							new Float:chargeprcnt = HANextCharge[client]-GetGameTime();
							if(HUDHAStyle[client]==1)
							{
								chargeprcnt = 100.0 - (((HANextCharge[client]-GetGameTime()) / FF2HACool[client])*100.0);
								//so it doesn't say -0% sometimes
								if (chargeprcnt<0.0)
								{
									chargeprcnt=0.0;
								}
							}
							SetHudTextParams(-1.0, HUDHAOffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
							ShowSyncHudText(client, HomeHUD, HUDHACool[client], chargeprcnt);
						}
					}
					if(FF2PREnable[client])
					{
						if(FF2PRDebug[client]!=0)
						{
							if(GCType[client]==5)
							{
								SetHudTextParams(-1.0, HUDPROffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
								ShowSyncHudText(client, PRHUD, "ForceSpeed: %.2f hu/s | Accel: %.2f hu/s", GetVectorLength(RunVel[client]), (GetVectorLength(RunVel[client])-LastSpeed[client])*4.0);
								LastSpeed[client] = GetVectorLength(RunVel[client]);
							}
						}
						else
						{
							if((FF2PRAbilFlags[client] & 16) && FF2PRButton[client]<0)
							{
								if(GCType[client]==2)
								{
									SetHudTextParams(-1.0, HUDPROffset[client], 0.35, 66, 244, 104, 255, 0, 0.2, 0.0, 0.1);
									ShowSyncHudText(client, PRHUD, HUDPRActive[client]);
								}
								else
								{
									if(GCNextRoll[client]<=GetGameTime())
									{
										if(CanUsePR(client)==0)
										{
											SetHudTextParams(-1.0, HUDPROffset[client], 0.35, 255, 64, 64, 255, 0, 0.2, 0.0, 0.1);
											ShowSyncHudText(client, PRHUD, HUDPRRage[client], FF2PRMinRag[client]);
										}
										else
										{
											SetHudTextParams(-1.0, HUDPROffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
											ShowSyncHudText(client, PRHUD, HUDPRNo[client], FF2PRMinRag[client]);
										}
									}
									else
									{
										SetHudTextParams(-1.0, HUDPROffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
										ShowSyncHudText(client, PRHUD, HUDPRCool[client]);
									}
								}
							}
							else
							{
								if(GCType[client]==5)
								{
									SetHudTextParams(-1.0, HUDPROffset[client], 0.35, 66, 244, 104, 255, 0, 0.2, 0.0, 0.1);
									ShowSyncHudText(client, PRHUD, HUDPRActive[client]);
								}
								else
								{
									if(GCNextRoll[client]<=GetGameTime())
									{
										if(CanUsePR(client)==0)
										{
											SetHudTextParams(-1.0, HUDPROffset[client], 0.35, 255, 64, 64, 255, 0, 0.2, 0.0, 0.1);
											ShowSyncHudText(client, PRHUD, HUDPRRage[client], FF2PRMinRag[client]);
										}
										else
										{
											SetHudTextParams(-1.0, HUDPROffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
											ShowSyncHudText(client, PRHUD, HUDPRNo[client], FF2PRMinRag[client]);
										}
									}
									else
									{
										SetHudTextParams(-1.0, HUDPROffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
										ShowSyncHudText(client, PRHUD, HUDPRCool[client]);
									}
								}
							}
						}
					}
					if(FF2GCEnable[client])
					{
						if(GCType[client]==4)
						{
							SetHudTextParams(-1.0, HUDGCOffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
							ShowSyncHudText(client, GroundHUD, HUDGCBuild[client], GCSpinCharge[client]*100.0);
						}
						else
						{
							if(FF2GCDebug[client]!=0 && (GCType[client]==1 || GCType[client]==2))
							{
								SetHudTextParams(-1.0, HUDGCOffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
								ShowSyncHudText(client, GroundHUD, "ForceSpeed: %.2f hu/s | Accel: %.2f hu/s", GetVectorLength(RunVel[client]), (GetVectorLength(RunVel[client])-LastSpeed[client])*4.0);
								LastSpeed[client] = GetVectorLength(RunVel[client]);
							}
							else
							{
								new Float:chargeprcnt = GCNextCharge[client]-GetGameTime();
								if(HUDGCStyle[client]==1)
								{
									chargeprcnt = 100.0 - (((GCNextCharge[client]-GetGameTime()) / FF2GCCooldown[client])*100.0);
									//so it doesn't say -0% sometimes
									if (chargeprcnt<0.0)
									{
										chargeprcnt=0.0;
									}
								}
								if(CanUseGC(client)==0)
								{
									SetHudTextParams(-1.0, HUDGCOffset[client], 0.35, 255, 64, 64, 255, 0, 0.2, 0.0, 0.1);
									ShowSyncHudText(client, GroundHUD, HUDGCRage[client], chargeprcnt);
								}
								else if(CanUseGC(client)==1)
								{
									SetHudTextParams(-1.0, HUDGCOffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
									ShowSyncHudText(client, GroundHUD, HUDGCCool[client], chargeprcnt);
								}
								else
								{
									SetHudTextParams(-1.0, HUDGCOffset[client], 0.35, 255, 255, 255, 255, 0, 0.2, 0.0, 0.1);
									ShowSyncHudText(client, GroundHUD, HUDGCNo[client]);
								}
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public void HOA_Invoke(client)
{
	new result = CanUseHA(client);
	if(result==0)
	{
		if(FF2HACost[client]>0.0)
		{
			FF2_SetBossCharge(FF2_GetBossIndex(client), 0, FF2_GetBossCharge(FF2_GetBossIndex(client), 0) - FF2HACost[client]);
		}
		HANextCharge[client] = GetGameTime()+FF2HACool[client];
		SetChargeState(client, 3);
	}
	else if(result==3) //not enough rage
	{
		PrintCenterText(client, HUDHANoRage[client]);
		EmitSoundToClient(client, Denied);
	}
	else if(result==2) //stunned
	{
		PrintCenterText(client, HUDHAStun[client]);
		EmitSoundToClient(client, Denied);
	}
}

public void GRC_Invoke(client)
{
	new result = CanUseGC(client);
	if(result==0)
	{
		if(FF2GCBaseSpeed[client]==FF2GCMaxSpeed[client])
		{
			SetChargeState(client, 1);
		}
		else
		{
			SetChargeState(client, 4);
			PrintCenterText(client, HUDGCHow[client]);
		}
	}
	else if(result==4)
	{
		PrintCenterText(client, HUDGCStun[client]);
		EmitSoundToClient(client, Denied);
	}
	else if(result==5 || result==6)
	{
		PrintCenterText(client, HUDGCWarn[client]);
		EmitSoundToClient(client, Denied);
	}
}

public void PRS_Invoke(client)
{
	new result = CanUsePR(client);
	if(result==0)
	{
		SetChargeState(client, 5);
	}
	else if(result==4)
	{
		PrintCenterText(client, HUDPRNoRage[client]);
		EmitSoundToClient(client, Denied);
	}
	else if(result==3)
	{
		PrintCenterText(client, HUDPRStun[client]);
		EmitSoundToClient(client, Denied);
	}
	else if(result==2 || result==1)
	{
		PrintCenterText(client, HUDPRWater[client]);
		EmitSoundToClient(client, Denied);
	}
}

SetChargeState(client, type)
{
	HideAllActors(client);
	new LastState = GCType[client];
	KillRollTrail(client);
	GCType[client] = type;
	if(FF2GCDebug[client]!=0)
	{
		PrintToServer("[%s] Roll State set to %i", GCName, GCType[client]);
		PrintToChat(client, "[%s] Roll State set to %i", GCName, GCType[client]);
	}
	GCNextPush[client] = GetGameTime()+0.06;
	GCNextRoll[client] = GetGameTime()+0.6;
	LastPush[client] = GetGameTime()-0.24;
	#if DDCOMPILE
			DD_SetDisabled(client, false, false, false, false);
	#endif
	if(type==1) //launch mode
	{
		EndJump(client, false);
		WallPenalty[client]=0;
		#if DDCOMPILE
			DD_SetDisabled(client, bool:(FF2GCDDFlags[client] & 1), bool:(FF2GCDDFlags[client] & 2), bool:(FF2GCDDFlags[client] & 4), bool:(FF2GCDDFlags[client] & 8));
		#endif
		if(!(FF2GCAbilFlags[client] & 1))
		{
			GCNextCharge[client] = GetGameTime()+FF2GCCooldown[client];
		}
		GCTime[client] = GetGameTime()+FF2GCDuration[client];
		if(strlen(ANMGCRoll[client])>0)
		{
			AnimateActor(client, ANMGCRoll[client], 0, ANMGCRollDur[client], true);
		}
		GCNextCharge[client] = GetGameTime()+FF2GCCooldown[client];
		if(GCSpinCharge[client]>0.0)
		{
			if(IsSwimming(client))
			{
				SetRunForce(client, 0.0, GetChargeSpeed(client)*FF2GCLaunchMultWater[client]);
			}
			else if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				SetRunForce(client, 0.0, GetChargeSpeed(client)*FF2GCLaunchMultAir[client]);
			}
			else
			{
				SetRunForce(client, 0.0, GetChargeSpeed(client));
			}
		}
		else
		{
			if(IsSwimming(client))
			{
				SetRunForce(client, 0.0, FF2GCBaseSpeed[client]*FF2GCLaunchMultWater[client]);
			}
			else if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				SetRunForce(client, 0.0, FF2GCBaseSpeed[client]*FF2GCLaunchMultAir[client]);
			}
			else
			{
				SetRunForce(client, 0.0, FF2GCBaseSpeed[client]);
			}
		}
		if(strlen(SNDGCLaunch[client])>0)
		{
			EmitSoundToAll(SNDGCLaunch[client], client);
		}
		if(strlen(PRTGCLaunch[client])>0)
		{
			CreateParticle(client, PRTGCLaunch[client]);
		}
	}
	else if(type==2) //rolling mode
	{
		WallPenalty[client]=0;
		#if DDCOMPILE
			DD_SetDisabled(client, bool:(FF2PRDDFlags[client] & 1), bool:(FF2PRDDFlags[client] & 2), bool:(FF2PRDDFlags[client] & 4), bool:(FF2PRDDFlags[client] & 8));
		#endif
		GCTime[client] = GetGameTime()+FF2GCDuration[client];
		if(strlen(ANMGCRoll[client])>0)
		{
			AnimateActor(client, ANMGCRoll[client], 0, ANMGCRollDur[client], true);
		}
		new Float:angles[3];
		new Float:vel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
		//vel[2] = 0.0;
		GetVectorAngles(vel, angles);
		TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
		RunVel[client][0] = vel[0];
		RunVel[client][1] = vel[1];
		if(strlen(SNDGCBuild[client])>0)
		{
			EmitSoundToAll(SNDGCBuild[client], client, _, _, _, _, SNDGCPitchMin[client]);
		}
	}
	else if(type==3) //homing mode
	{
		EndJump(client, false);
		SDKHook(client, SDKHook_PreThink, Charge_PreThink);
		HATarget[client] = -2;
		CheckedTarget[client] = false;
		HAWind[client] = GetGameTime()+FF2HAWind[client]+FF2HAWindAlert[client];
		HADur[client] = -1.0;
		TF2_StunPlayer(client, FF2HAWind[client], 0.0, 4, client);
		#if DDCOMPILE
			DD_SetDisabled(client, true, true, true, true);
		#endif
		if(strlen(ANMHA[client])>0)
		{
			AnimateActor(client, ANMHA[client], 2, ANMHADur[client], true);
		}
		if(strlen(SNDHAWind[client])>0)
		{
			EmitSoundToAll(SNDHAWind[client], client);
		}
	}
	else if(type==4) //charge up mode
	{
		EndJump(client, false);
		HideActor(client, 4);
		SDKHook(client, SDKHook_PreThink, Charge_PreThink);
		#if DDCOMPILE
			DD_SetDisabled(client, true, true, true, true);
		#endif
		GCSpinCharge[client]=0.0;
		if(strlen(ANMGCBuild[client])>0)
		{
			AnimateActor(client, ANMGCBuild[client], 1, ANMGCBuildDur[client], true);
		}
		if(strlen(SNDGCBuild[client])>0)
		{
			EmitSoundToAll(SNDGCBuild[client], client, _, _, _, _, SNDGCPitchMin[client]);
		}
	}
	else if(type==5) //passive roll mode
	{
		if((FF2PRAbilFlags[client] & 16) && FF2PRButton[client]<0)
		{
			//don't use certain args in mode 5 with certain settings
		}
		else
		{
			#if DDCOMPILE
				DD_SetDisabled(client, bool:(FF2PRDDFlags[client] & 1), bool:(FF2PRDDFlags[client] & 2), bool:(FF2PRDDFlags[client] & 4), bool:(FF2PRDDFlags[client] & 8));
			#endif
			if(strlen(ANMPRRoll[client])>0)
			{
				AnimateActor(client, ANMPRRoll[client], 3, ANMPRRollDur[client], true);
			}
			if(strlen(SNDPRRoll[client])>0)
			{
				EmitSoundToAll(SNDPRRoll[client], client);
			}
		}
		GCNextRoll[client] = GetGameTime()+0.6;
		//new Float:angles[3];
		new Float:vel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
		vel[2] = 0.0;
		//GetVectorAngles(vel, angles);
		RunVel[client][0] = vel[0];
		RunVel[client][1] = vel[1];
		//TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
		if(FF2PRButton[client]<0 && (LastState==0 || LastState==5))
		{
			GCNextRoll[client] = GetGameTime();
		}
	}
}

EndRoll(client)
{
	SDKUnhook(client, SDKHook_PreThink, Charge_PreThink);
	GCTime[client]=-1.0;
	if(FF2PREnable[client] && FF2PRButton[client]<0)
	{
		if(IsSwimming(client))
		{
			if(FF2PRAbilFlags[client] & 4)
			{
				SetChargeState(client, 0);
			}
			else
			{
				SetChargeState(client, 5);
			}
		}
		else if(GetEntityFlags(client) & FL_ONGROUND)
		{
			if(GCType[client]==5)
			{
				SetChargeState(client, 0);
			}
			else
			{
				SetChargeState(client, 5);
			}
		}
		else
		{
			if(FF2PRAbilFlags[client] & 2)
			{
				SetChargeState(client, 0);
			}
			else
			{
				SetChargeState(client, 5);
			}
		}
	}
	else
	{
		SetChargeState(client, 0);
	}
	//FixCollide[client] = GetGameTime();
}

GetHomingTarget(client)
{
	new target = -1;
	new Float:clpos[3];
	new Float:tapos[3];
	GetClientEyePosition(client, clpos);
	new Float:mindist = FF2HARange[client]+1.0;
	for(new i=1; i<=MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			if(IsPlayerAlive(i))
			{
				if(GetClientTeam(i)!=GetClientTeam(client))
				{
					GetClientEyePosition(i, tapos);
					if(GetVectorDistance(clpos, tapos)<mindist)
					{
						if(InClearView(clpos, tapos, client))
						{
							target = i;
							mindist = GetVectorDistance(clpos, tapos);
						}
					}
				}
			}
		}
	}
	if(IsValidClient(target))
	{
		if(FF2HADebug[client]!=0)
		{
			PrintToServer("[%s] Homing found target %i.", HAName, target);
			PrintToChat(client, "[%s] Homing found target %i.", HAName, target);
		}
		if(strlen(SNDHABeep[client])>0)
		{
			EmitSoundToClient(client, SNDHABeep[client]);
			EmitSoundToClient(target, SNDHABeep[client]);
		}
		HATarget[client] = GetClientUserId(target);
	}
	else
	{
		if(FF2HADebug[client]!=0)
		{
			PrintToServer("[%s] No homing target found.", HAName);
			PrintToChat(client, "[%s] No homing target found.", HAName);
		}
	}
	CheckedTarget[client] = true;
	if(HAWind[client]<=GetGameTime())
	{
		HomeIntoTarget(client);
	}
}

HomeIntoTarget(client)
{
	new Float:eyeangle[3];
	new Float:angle[3];
	new Float:vel[3];
	if(HATarget[client]>=0)
	{
		new target = GetClientOfUserId(HATarget[client]);
		if(IsValidClient(target))
		{
			new Float:clpos[3];
			new Float:tapos[3];
			GetClientEyePosition(client, clpos);
			GetClientEyePosition(target, tapos);
			if(InClearView(clpos, tapos, client))
			{
				SubtractVectors(tapos, clpos, angle);
				NormalizeVector(angle, angle);
				GetVectorAngles(angle, eyeangle); 
				GetAngleVectors(eyeangle, angle, NULL_VECTOR, NULL_VECTOR);
				vel[0] = angle[0]*FF2HASpeed[client];
				vel[1] = angle[1]*FF2HASpeed[client];
				vel[2] = angle[2]*FF2HASpeed[client];
				TeleportEntity(client, NULL_VECTOR, eyeangle, vel);
			}
			else
			{
				GetClientEyeAngles(client, angle);
				GetAngleVectors(angle, angle, NULL_VECTOR, NULL_VECTOR);
				vel[0] = angle[0]*FF2HASpeed[client];
				vel[1] = angle[1]*FF2HASpeed[client];
				vel[2] = angle[2]*FF2HASpeed[client];
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
			}
		}
		else
		{
			HATarget[client] = -1;
		}
	}
	if(HATarget[client]<0)
	{
		if(HATarget[client] == -2)
		{
			if(FF2HANoRot[client]<-180.0 || FF2HANoRot[client]>180.0)
			{
				GetClientEyeAngles(client, angle);
				GetAngleVectors(angle, angle, NULL_VECTOR, NULL_VECTOR);
				vel[0] = angle[0]*FF2HASpeed[client];
				vel[1] = angle[1]*FF2HASpeed[client];
				vel[2] = angle[2]*FF2HASpeed[client];
			}
			else
			{
				HAAngles[client][0] = FF2HANoRot[client];
				GetAngleVectors(HAAngles[client], angle, NULL_VECTOR, NULL_VECTOR);
				vel[0] = angle[0]*FF2HASpeed[client];
				vel[1] = angle[1]*FF2HASpeed[client];
				vel[2] = angle[2]*FF2HASpeed[client];
			}
		}
		else
		{
			GetAngleVectors(HAAngles[client], angle, NULL_VECTOR, NULL_VECTOR);
			vel[0] = angle[0]*FF2HASpeed[client];
			vel[1] = angle[1]*FF2HASpeed[client];
			vel[2] = angle[2]*FF2HASpeed[client];
		}
		TeleportEntity(client, NULL_VECTOR, HAAngles[client], vel);
	}
}

EndHomingAttack(client, bool:Hit)
{
	SDKUnhook(client, SDKHook_PreThink, Charge_PreThink);
	KillRollTrail(client);
	#if DDCOMPILE
		DD_SetDisabled(client, false, false, false, false);
	#endif
	if(FF2PREnable[client] && FF2PRButton[client]<0)
	{
		SetChargeState(client, 5);
	}
	else
	{
		SetChargeState(client, 0);
	}
	//FixCollide[client] = GetGameTime();
	new Float:vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	HADur[client] = -1.0;
	//using hullchecks on demand didn't work right
	//so we'll just do this here
	if(Hit)
	{
		if(FF2HAStunDur[client]>0.0)
		{
			TF2_StunPlayer(client, FF2HAStunDur[client], 0.0, FF2HAStunFlags[client], client);
		}
		new Float:angle[3];
		GetClientEyeAngles(client, angle);
		angle[0] = FF2HANoRot[client];
		GetAngleVectors(angle, angle, NULL_VECTOR, NULL_VECTOR);
		vel[0] = angle[0]*FF2HASpeed[client];
		vel[1] = angle[1]*FF2HASpeed[client];
		vel[2] = FF2HAHitVert[client];
		vel[0] *= FF2HAHitVel[client];
		vel[1] *= FF2HAHitVel[client];
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
	}
	RunVel[client][0] = vel[0];
	RunVel[client][1] = vel[1];
	if(FF2SJAbilFlags[client] & 1)
	{
		if(IsAirborne(client))
		{
			DoJump(client, false);
		}
	}
}

BuildCharge(client, type, bool:noise)
{
	switch(type)
	{
		case 0:
		{
			GCSpinCharge[client]+=FF2GCBuildRate[client];
		}
		case 1:
		{
			GCSpinCharge[client]+=FF2GCBuildRateHold[client];
		}
		case 2:
		{
			GCSpinCharge[client]+=FF2GCBuildDecay[client];
		}
	}
	if(GCSpinCharge[client]>1.0)
	{
		GCSpinCharge[client]=1.0;
	}
	else if(GCSpinCharge[client]<0.0)
	{
		GCSpinCharge[client]=0.0;
	}
	if(noise)
	{
		if(strlen(SNDGCBuild[client])>0)
		{
			EmitSoundToAll(SNDGCBuild[client], client, _, _, _, _, GetChargePitch(client));
		}
	}
}

stock GetChargePitch(client)
{
	if(SNDGCPitchMin[client]==SNDGCPitchMax[client])
	{
		return SNDGCPitchMin[client];
	}
	else
	{
		return RoundToNearest(SNDGCPitchMin[client]+((SNDGCPitchMax[client]-SNDGCPitchMin[client])*GCSpinCharge[client]));
	}
}

stock Float:GetChargeSpeed(client)
{
	return FF2GCBaseSpeed[client]+((FF2GCMaxSpeed[client] - FF2GCBaseSpeed[client])*GCSpinCharge[client]);
}

SetPlayerCollision(client, type)
{
	SetEntProp(client, Prop_Data, "m_CollisionGroup", type);
}

SetBuildCollision(entity, type)
{
	SetPlayerCollision(entity, type);
	CreateTimer(0.75, Timer_RestoreBuildCollide, EntIndexToEntRef(entity));
}

public Action:Timer_RestoreBuildCollide(Handle:timer, entityref)
{
	new entity = EntRefToEntIndex(entityref);
	if(IsValidEntity(entity))
	{
		if(HullCheck(entity, NULL_VECTOR, 2))
		{
			CreateTimer(0.25, Timer_RestoreBuildCollide, entityref);
		}
		else
		{
			SetPlayerCollision(entity, 21);
		}
	}
	return Plugin_Continue;
}
	

stock CanUsePR(client)
{
	//0 = nothing is limiting it from use
	//1 = the ability is disabled in air
	//2 = the ability is disabled in water
	//3 = the user is stunned
	//4 = not enough rage
	if(IsSwimming(client))
	{
		if(FF2PRAbilFlags[client] & 4)
		{
			return 2;
		}
	}
	else if(!(GetEntityFlags(client) & FL_ONGROUND))
	{
		if(FF2PRAbilFlags[client] & 2)
		{
			return 1;
		}
	}
	if(TF2_IsPlayerInCondition(client, TFCond_Dazed))
	{
		if(ClientHasStunFlags(client, FF2PRStunFlags[client]))
		{
			return 3;
		}
		else
		{
			new stun = GetEntProp(client, Prop_Send, "m_iStunFlags");
			if((stun & 2) || (stun & 64))
			{
				return 3;
			}
		}
	}
	if(FF2PRMinRag[client]>0.0)
	{
		if(FF2_GetBossCharge(FF2_GetBossIndex(client), 0)<FF2PRMinRag[client])
		{
			return 4;
		}
	}
	if(FF2PRDrain[client]>0.0)
	{
		if(FF2_GetBossCharge(FF2_GetBossIndex(client), 0)<=0.0)
		{
			return 4;
		}
	}
	return 0;
}

stock CanUseGC(client)
{
	//0 = nothing is limiting it from use
	//1 = on cooldown
	//2 = currently rolling/in the middle of a charge
	//3 = the ability is currently in the middle of a launch and is configured to not track cooldown at this moment
	//4 = the boss is currently stunned and cannot use it because of it
	//5 = the ability can't be used because they're swimming and it's configured as such
	//6 = the ability can't be used because they're not on the ground and it's configured as such
	
	if(FF2GCAbilFlags[client] & 1)
	{
		if(GCType[client]==1)
		{
			if(GetVectorLength(RunVel[client])>=FF2GCMinRollSpd[client])
			{
				return 2;
			}
		}
	}
	if(GCNextCharge[client]>=GetGameTime())
	{
		return 1;
	}
	if(GCType[client]==1 || GCType[client]==2 || GCType[client]==3)
	{
		return 2;
	}
	if(TF2_IsPlayerInCondition(client, TFCond_Dazed))
	{
		if(ClientHasStunFlags(client, FF2GCStunFlags[client]))
		{
			return 4;
		}
		else
		{
			new stun = GetEntProp(client, Prop_Send, "m_iStunFlags");
			if((stun & 2) || (stun & 64))
			{
				return 4;
			}
		}
	}
	if(FF2GCAbilFlags[client] & 4)
	{
		if(IsSwimming(client))
		{
			return 5;
		}
	}
	if(FF2GCAbilFlags[client] & 2)
	{
		if(!IsSwimming(client) && !(GetEntityFlags(client) & FL_ONGROUND))
		{
			return 6;
		}
	}
	return 0;
}

stock CanUseHA(client)
{
	//0 = nothing is limiting it from use
	//1 = on cooldown
	//2 = stunned
	//3 = not enough rage
	//4 = on the ground (no longer used)
	//5 = in a rolling state
	//7 = ability is disabled by the config
	if(!FF2HAEnable[client])
	{
		return 7;
	}
	if(HANextCharge[client]>GetGameTime())
	{
		return 1;
	}
	else
	{
		if(GCType[client]!=0 && GCType[client]!=5)
		{
			return 5;
		}
		if(FF2_GetBossCharge(FF2_GetBossIndex(client), 0)<FF2HACost[client])
		{
			return 3;
		}
		new stun = GetEntProp(client, Prop_Send, "m_iStunFlags");
		if((stun & 64) || (stun & 2))
		{
			return 2;
		}
	}
	return 0;
}

stock bool:IsBoss(client)
{
	if(IsValidClient(client))
	{
		if(FF2_GetBossIndex(client) >= 0)
		{
			return true;
		}
	}
	return false;
}

IsFlying(client)
{
	new MoveType:movetype = GetEntityMoveType(client);
	if(movetype == MOVETYPE_FLY)
	{
		PrintToServer("flying");
	}
	else if(movetype == MOVETYPE_FLYGRAVITY)
	{
		PrintToServer("flying_gravity");
	}
	else if(movetype == MOVETYPE_NOCLIP)
	{
		PrintToServer("nocliping");
	}
}

stock bool:IsAirborne(client)
{
	if(!IsSwimming(client))
	{
		if(GCType[client]==0 || GCType[client]==3)
		{
			if(!(GetEntityFlags(client) & FL_ONGROUND))
			{
				return true;
			}
		}
		else
		{
			if(LastPush[client]+0.23<GetGameTime())
			{
				return true;
			}
		}
	}
	return false;
}

stock bool:IsSwimmingStrict(client)
{
	if(GetEntityFlags(client) & FL_INWATER)
	{
		return true;
	}
	if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 3)
	{
		return true;
	}
	return false;
}

stock bool:IsSwimming(client)
{
	if(GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 3)
	{
		return true;
	}
	return false;
}

//we have to simulate knockback due to the way this all works
stock Float:GetKnockBackMult(client, attacker)
{
	if(IsValidClient(client))
	{
		new Float:kbmult = 1.0;
		new Address:statbonus;
		if(client==attacker)
		{
			statbonus = TF2Attrib_GetByDefIndex(client, 58);
			if(statbonus!=Address_Null)
			{
				kbmult *= TF2Attrib_GetValue(statbonus);
			}
			statbonus = TF2Attrib_GetByDefIndex(client, 59);
			if(statbonus!=Address_Null)
			{
				kbmult *= TF2Attrib_GetValue(statbonus);
			}
		}
		statbonus = TF2Attrib_GetByDefIndex(client, 252);
		if(statbonus!=Address_Null)
		{
			kbmult *= TF2Attrib_GetValue(statbonus);
		}
		statbonus = TF2Attrib_GetByDefIndex(client, 525);
		if(statbonus!=Address_Null)
		{
			kbmult *= TF2Attrib_GetValue(statbonus);
		}
		new activewep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		for(new wep = 0; wep<=8; wep++)
		{
			new wepid = GetPlayerWeaponSlot(client, wep);
			new bool:Skip = false;
			if(IsValidEntity(wepid))
			{
				statbonus = TF2Attrib_GetByDefIndex(wepid, 128);
				if(statbonus!=Address_Null)
				{
					if(TF2Attrib_GetValue(statbonus)!=0.0)
					{
						if(activewep!=wepid)
						{
							Skip = true;
						}
					}
				}
				if(!Skip)
				{
					if(client==attacker)
					{
						statbonus = TF2Attrib_GetByDefIndex(wepid, 58);
						if(statbonus!=Address_Null)
						{
							kbmult *= TF2Attrib_GetValue(statbonus);
						}
						statbonus = TF2Attrib_GetByDefIndex(wepid, 59);
						if(statbonus!=Address_Null)
						{
							kbmult *= TF2Attrib_GetValue(statbonus);
						}
					}
					statbonus = TF2Attrib_GetByDefIndex(wepid, 252);
					if(statbonus!=Address_Null)
					{
						kbmult *= TF2Attrib_GetValue(statbonus);
					}
					statbonus = TF2Attrib_GetByDefIndex(wepid, 525);
					if(statbonus!=Address_Null)
					{
						kbmult *= TF2Attrib_GetValue(statbonus);
					}	
				}
			}
		}
		return kbmult;
	}
	return 1.0;
}

//also jumpheight
stock Float:GetJumpHeightMult(client)
{
	if(IsValidClient(client))
	{
		new Float:jhmult = 1.0;
		new Address:statbonus;
		statbonus = TF2Attrib_GetByDefIndex(client, 326);
		if(statbonus!=Address_Null)
		{
			jhmult *= TF2Attrib_GetValue(statbonus);
		}
		statbonus = TF2Attrib_GetByDefIndex(client, 443);
		if(statbonus!=Address_Null)
		{
			jhmult *= TF2Attrib_GetValue(statbonus);
		}
		statbonus = TF2Attrib_GetByDefIndex(client, 550);
		if(statbonus!=Address_Null)
		{
			jhmult *= TF2Attrib_GetValue(statbonus);
		}
		statbonus = TF2Attrib_GetByDefIndex(client, 524);
		if(statbonus!=Address_Null)
		{
			jhmult *= TF2Attrib_GetValue(statbonus);
		}
		new activewep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		for(new wep = 0; wep<=8; wep++)
		{
			new wepid = GetPlayerWeaponSlot(client, wep);
			new bool:Skip = false;
			if(IsValidEntity(wepid))
			{
				//128 - Provide On Active:
				statbonus = TF2Attrib_GetByDefIndex(wepid, 128);
				if(statbonus!=Address_Null)
				{
					if(TF2Attrib_GetValue(statbonus)!=0.0)
					{
						if(activewep!=wepid)
						{
							Skip = true;
						}
					}
				}
				if(!Skip)
				{
					statbonus = TF2Attrib_GetByDefIndex(wepid, 326);
					if(statbonus!=Address_Null)
					{
						jhmult *= TF2Attrib_GetValue(statbonus);
					}
					statbonus = TF2Attrib_GetByDefIndex(wepid, 443);
					if(statbonus!=Address_Null)
					{
						jhmult *= TF2Attrib_GetValue(statbonus);
					}
					statbonus = TF2Attrib_GetByDefIndex(wepid, 550);
					if(statbonus!=Address_Null)
					{
						jhmult *= TF2Attrib_GetValue(statbonus);
					}
				}
				if(activewep==wepid)
				{
					statbonus = TF2Attrib_GetByDefIndex(wepid, 524);
					if(statbonus!=Address_Null)
					{
						jhmult *= TF2Attrib_GetValue(statbonus);
					}
				}
			}
		}
		return jhmult;
	}
	return 1.0;
}

stock RotateToShortest(Float:Angle, Float:DesiredAngle)
{
    Angle+=180.0;
	DesiredAngle+=180.0;
	//PrintToChatAll("%.0f", Angle);
	new Float:Diff = Angle-DesiredAngle;
	if(Diff<0.0)
	{
	    Diff*=-1.0;
	}
	if(Angle < DesiredAngle)
	{
	    if(Diff<180.0)
		{
		    return 1; //+
		}
		else
		{
		    return 2; //-
		}
	}
	else
	{
	    if(Diff<180.0)
		{
		    return 2; //-
		}
		else
		{
		    return 1; //+
		}
	}
}

stock bool:ClientHasStunFlags(client, flags)
{
	if(IsValidClient(client) && flags>0)
	{
		new stun = GetEntProp(client, Prop_Send, "m_iStunFlags");
		if(flags & 1)
		{
			if(stun & 1)
			{
				return true;
			}
		}
		if(flags & 8)
		{
			if(stun & 128)
			{
				return true;
			}
		}
		if(flags & 2)
		{
			if((stun & 64) && !(stun & 128))
			{
				return true;
			}
		}
		if(flags & 4)
		{
			if(stun & 2)
			{
				return true;
			}
		}
	}
	return false;
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

RotateRunPassive(client, Float:TurnAngle)
{
	if(IsValidClient(client))
	{
		new Float:angle[3];
		new Float:velangle[3];
		new Float:oldangle[3];
		GetClientEyeAngles(client, angle);
		angle[1]+=TurnAngle;
		GetVectorAngles(RunVel[client], velangle);
		if(velangle[1]!=angle[1])
		{
			if(angle[1]>360.0)
			{
				angle[1]-=360.0;
			}
			else if(angle[1]<0.0)
			{
				angle[1]+=360.0;
			}
			if(velangle[1]-angle[1]<=100.0 && velangle[1]-angle[1]>=-100.0)
			{
				oldangle[1] = velangle[1];
				new Float:TurnRate = FF2PRTurnAssist[client];
				if(IsSwimming(client))
				{
					TurnRate *= FF2PRTurnAssistWater[client];
				}
				else if(LastPush[client]+0.23<GetGameTime())
				{
					TurnRate *= FF2PRTurnAssistAir[client];
				}
				if(TurnRate!=0.0)
				{
					if(RotateToShortest(velangle[1], angle[1])==1)
					{
						velangle[1]+=TurnRate;
						if(RotateToShortest(velangle[1], angle[1])==2)
						{
							velangle[1]=angle[1];
						}
					}
					else if(RotateToShortest(velangle[1], angle[1])==2)
					{
						velangle[1]-=TurnRate;
						if(RotateToShortest(velangle[1], angle[1])==1)
						{
							velangle[1]=angle[1];
						}
					}
					GetAngleVectors(velangle, velangle, NULL_VECTOR, NULL_VECTOR);
					new Float:Speed = GetVectorLength(RunVel[client]);
					RunVel[client][0] = Speed*velangle[0];
					RunVel[client][1] = Speed*velangle[1];
				}
			}
		}
	}
}

RotateRunToAim(client, Float:TurnMult)
{
	if(IsValidClient(client))
	{
		new Float:angle[3];
		new Float:velangle[3];
		new Float:oldangle[3];
		GetClientEyeAngles(client, angle);
		GetVectorAngles(RunVel[client], velangle);
		if(velangle[1]!=angle[1])
		{
			if(GCType[client]==2)
			{
				if(angle[1]>360.0)
				{
					angle[1]-=360.0;
				}
				else if(angle[1]<0.0)
				{
					angle[1]+=360.0;
				}
				oldangle[1] = velangle[1];
				new Float:TurnRate = FF2PRTurnRate[client][0]*TurnMult;
				new Float:TurnRateMax = FF2PRTurnRate[client][1]*TurnMult;
				if(IsSwimming(client))
				{
					TurnRate *= FF2PRTurnRateWater[client];
					TurnRateMax *= FF2PRTurnRateWater[client];
				}
				else if(LastPush[client]+0.23<GetGameTime())
				{
					TurnRate *= FF2PRTurnRateAir[client];
					TurnRateMax *= FF2PRTurnRateAir[client];
				}
				if(RotateToShortest(velangle[1], angle[1])==1)
				{
					velangle[1]+=TurnRateMax;
					if(RotateToShortest(velangle[1], angle[1])==2)
					{
						velangle[1]=angle[1];
					}
				}
				else if(RotateToShortest(velangle[1], angle[1])==2)
				{
					velangle[1]-=TurnRateMax;
					if(RotateToShortest(velangle[1], angle[1])==1)
					{
						velangle[1]=angle[1];
					}
				}
				new Float:diff = oldangle[1]-velangle[1];
				if(diff<0.0)
				{
					diff*=-1.0;
				}
				if(diff>180.0)
				{
					diff-=360.0;
					if(diff<0.0)
					{
						diff*=-1.0;
					}
				}
				if(diff>TurnRate)
				{
					diff*=FF2PRTurnRatePen[client];
					if(diff<0.0)
					{
						diff*=-1.0;
					}
				}
				else
				{
					diff = 0.0;
				}
				GetAngleVectors(velangle, velangle, NULL_VECTOR, NULL_VECTOR);
				new Float:Speed = GetVectorLength(RunVel[client]);
				RunVel[client][0] = velangle[0]*(Speed-diff);
				RunVel[client][1] = velangle[1]*(Speed-diff);
			}
			else
			{
				if(angle[1]>360.0)
				{
					angle[1]-=360.0;
				}
				else if(angle[1]<0.0)
				{
					angle[1]+=360.0;
				}
				oldangle[1] = velangle[1];
				new Float:TurnRate = FF2GCTurnRate[client][0]*TurnMult;
				new Float:TurnRateMax = FF2GCTurnRate[client][1]*TurnMult;
				if(IsSwimming(client))
				{
					TurnRate *= FF2GCTurnRateWater[client];
					TurnRateMax *= FF2GCTurnRateWater[client];
				}
				else if(LastPush[client]+0.23<GetGameTime())
				{
					TurnRate *= FF2GCTurnRateAir[client];
					TurnRateMax *= FF2GCTurnRateAir[client];
				}
				if(RotateToShortest(velangle[1], angle[1])==1)
				{
					velangle[1]+=TurnRateMax;
					if(RotateToShortest(velangle[1], angle[1])==2)
					{
						velangle[1]=angle[1];
					}
				}
				else if(RotateToShortest(velangle[1], angle[1])==2)
				{
					velangle[1]-=TurnRateMax;
					if(RotateToShortest(velangle[1], angle[1])==1)
					{
						velangle[1]=angle[1];
					}
				}
				new Float:diff = oldangle[1]-velangle[1];
				if(diff<0.0)
				{
					diff*=-1.0;
				}
				if(diff>180.0)
				{
					diff-=360.0;
					if(diff<0.0)
					{
						diff*=-1.0;
					}
				}
				if(diff>TurnRate)
				{
					diff*=FF2GCTurnRatePen[client];
					if(diff<0.0)
					{
						diff*=-1.0;
					}
				}
				else
				{
					diff = 0.0;
				}
				GetAngleVectors(velangle, velangle, NULL_VECTOR, NULL_VECTOR);
				new Float:Speed = GetVectorLength(RunVel[client]);
				RunVel[client][0] = velangle[0]*(Speed-diff);
				RunVel[client][1] = velangle[1]*(Speed-diff);
			}
		}
	}
}

ScaleRunForce(client, Float:newval)
{
	newval = newval/GetVectorLength(RunVel[client]);
	ScaleVector(RunVel[client], newval);
}

SetRunForce(client, Float:xangleoff, Float:amount)
{
	if(IsValidClient(client))
	{
		new Float:angle[3];
		GetClientEyeAngles(client, angle);
		angle[0] = 0.0;
		angle[1] += xangleoff;
		GetAngleVectors(angle, angle, NULL_VECTOR, NULL_VECTOR);
		RunVel[client][0]=angle[0]*amount;
		RunVel[client][1]=angle[1]*amount;
	}
}

ChangeRunForce(client, Float:xangleoff, bool:rolls = true)
{
	if(IsValidClient(client))
	{
		new Float:vel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
		vel[2] = 0.0;
		new Float:force = FF2PRAccel[client];
		
		new Float:angle[3];
		new Float:anglevec[3];
		GetClientEyeAngles(client, angle);
		if(!IsSwimming(client))
		{
			angle[0] = 0.0;
		}
		angle[1] += xangleoff;
		GetAngleVectors(angle, anglevec, NULL_VECTOR, NULL_VECTOR);
		
		if(rolls)
		{
			if(GCType[client]==2)
			{
				if(IsSwimming(client))
				{
					force = FF2PRDeccelWater[client];
				}
				else if(LastPush[client]+0.23<GetGameTime())
				{
					force = FF2PRDeccelAir[client];
				}
				else
				{
					force = FF2PRDeccel[client];
				}
			}
			else
			{
				if(IsSwimming(client))
				{
					force = FF2GCDecaySpeedWater[client]*0.5;
				}
				else if(LastPush[client]+0.23<GetGameTime())
				{
					force = FF2GCDecaySpeedAir[client]*0.5;
				}
				else
				{
					force = FF2GCDecaySpeed[client]*0.5;
				}
			}
			force *= -1.0;
			
			RunVel[client][0]+=anglevec[0]*force;
			RunVel[client][1]+=anglevec[1]*force;
			if(IsSwimming(client))
			{
				RunVel[client][2]+=anglevec[2]*force;
			}
			else
			{
				RunVel[client][2]=0.0;
			}
		}
		else
		{
			new Float:dirspeed[3];
			dirspeed[0] = anglevec[0]*RunVel[client][0];
			dirspeed[1] = anglevec[1]*RunVel[client][1];
			//dirspeed[2] = anglevec[2]*RunVel[client][2];
			new Float:dirspeedhori = GetVectorLength(dirspeed);
			new Float:MaxSpeed = FF2PRSpeed[client];
			if(IsSwimming(client))
			{
				force = (FF2PRAccelWater[client]*(1.0+((dirspeedhori*-1.0)/FF2PRSpeedWater[client])));
				MaxSpeed = FF2PRSpeedWater[client];
			}
			else if(LastPush[client]+0.23<GetGameTime())
			{
				force = (FF2PRAccelAir[client]*(1.0+((dirspeedhori*-1.0)/FF2PRSpeedAir[client])));
				MaxSpeed = FF2PRSpeedAir[client];
			}
			else
			{
				force = (FF2PRAccel[client]*(1.0+((dirspeedhori*-1.0)/FF2PRSpeed[client])));
			}
			new Float:newvel[3];
			newvel[0]=dirspeed[0]+(anglevec[1]*force);
			newvel[1]=dirspeed[1]+(anglevec[1]*force);
			new Float:postspeeddir = GetVectorLength(newvel);
			
			RunVel[client][0]+=anglevec[0]*force;
			RunVel[client][1]+=anglevec[1]*force;
			
			if(postspeeddir > MaxSpeed)
			{
				ScaleVector(RunVel[client], MaxSpeed/dirspeedhori);
			}
			if(IsSwimming(client))
			{
				RunVel[client][2]+=anglevec[2]*force;
			}
			else
			{
				RunVel[client][2]=-10.0;
			}
		}
	}
}

ApplyDeccelForce(client, bool:rolls = false)
{
	if(IsValidClient(client))
	{
		if(rolls)
		{
			new Float:speed = GetVectorLength(RunVel[client]);
			if(IsSwimming(client))
			{
				speed += FF2GCDecaySpeedWater[client];
			}
			else if(LastPush[client]+0.23<GetGameTime())
			{
				speed += FF2GCDecaySpeedAir[client];
			}
			else
			{
				speed += FF2GCDecaySpeed[client];
			}
			if(speed<0.0)
			{
				speed = 0.0;
			}
			if(speed!=0.0 && GetVectorLength(RunVel[client])!=0.0)
			{
				new Float:scale = speed/GetVectorLength(RunVel[client]);
				ScaleVector(RunVel[client], scale);
			}
		}
		else
		{
			new Float:speed = GetVectorLength(RunVel[client]);
			if(GCType[client]==2)
			{
				if(IsSwimming(client))
				{
					speed += FF2PRDeccelWater[client]*0.5;
				}
				else if(LastPush[client]+0.23<GetGameTime())
				{
					speed += FF2PRDeccelAir[client]*0.5;
				}
				else
				{
					speed += FF2PRDeccel[client]*0.5;
				}
				if(speed<0.0)
				{
					speed = 0.0;
				}
				if(speed!=0.0 && GetVectorLength(RunVel[client])!=0.0)
				{
					new Float:scale = speed/GetVectorLength(RunVel[client]);
					ScaleVector(RunVel[client], scale);
				}
			}
			else
			{
				if(IsSwimming(client))
				{
					speed += FF2PRDeccelWater[client];
				}
				else if(LastPush[client]+0.23<GetGameTime())
				{
					speed += FF2PRDeccelAir[client];
				}
				else
				{
					speed += FF2PRDeccel[client];
				}
				if(speed<0.0)
				{
					speed = 0.0;
				}
				if(speed!=0.0 && GetVectorLength(RunVel[client])!=0.0)
				{
					new Float:scale = speed/GetVectorLength(RunVel[client]);
					ScaleVector(RunVel[client], scale);
				}
			}
		}
	}
}

stock bool:HullCheck(client, Float:location[3], type = 0)
{
    new Float:vecMins[3], Float:vecMaxs[3];
	new Float:vecOrigin[3];
	new Float:vel[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", vecOrigin);
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", vecMaxs);
	GetEntPropVector(client, Prop_Send, "m_vecMins", vecMins);
	
	if(type == 2) //collision recorrection check
	{
		hTrace = TR_TraceHullFilterEx(vecOrigin, vecOrigin, vecMins, vecMaxs, MASK_PLAYERSOLID, TraceFilterCollide, client);
	}
	else if(type == 1) //wall prediction and damage for spin_dash
	{
		if(IsSwimming(client))
		{
		}
		else if(LastPush[client]+0.23<GetGameTime())
		{
		}
		else
		{
			//only keep step height into acount while on the ground
			vecMins[2]+=GetEntPropFloat(client, Prop_Send, "m_flStepSize")+1.0;
		}
		GetVectorAngles(RunVel[client], vel);
		GetAngleVectors(vel, vel, NULL_VECTOR, NULL_VECTOR);
		location[0] = vecOrigin[0]+(vel[0]*15.0);
		location[1] = vecOrigin[1]+(vel[1]*15.0);
		location[2] = vecOrigin[2];
		hTrace = TR_TraceHullFilterEx(vecOrigin, location, vecMins, vecMaxs, MASK_PLAYERSOLID, TraceFilterChargeHurt, client);
	}
	else if(type == 5) //wall prediction and damage for passive_roll
	{
		if(IsSwimming(client))
		{
		}
		else if(LastPush[client]+0.23<GetGameTime())
		{
		}
		else
		{
			//only keep step height into acount while on the ground
			vecMins[2]+=GetEntPropFloat(client, Prop_Send, "m_flStepSize")+1.0;
		}
		GetVectorAngles(RunVel[client], vel);
		GetAngleVectors(vel, vel, NULL_VECTOR, NULL_VECTOR);
		location[0] = vecOrigin[0]+(vel[0]*15.0);
		location[1] = vecOrigin[1]+(vel[1]*15.0);
		location[2] = vecOrigin[2];
		hTrace = TR_TraceHullFilterEx(vecOrigin, location, vecMins, vecMaxs, MASK_PLAYERSOLID, TraceFilterPassiveHurt, client);
	}
	else if(type == 3) //wall prediction and damage for homing attack
	{
		GetVectorAngles(LastVel[client], vel);
		GetAngleVectors(vel, vel, NULL_VECTOR, NULL_VECTOR);
		location[0] = vecOrigin[0]+(vel[0]*15.0);
		location[1] = vecOrigin[1]+(vel[1]*15.0);
		location[2] = vecOrigin[2]+(vel[2]*15.0);
		hTrace = TR_TraceHullFilterEx(vecOrigin, location, vecMins, vecMaxs, MASK_PLAYERSOLID, TraceFilterHomeHurt, client);
	}
	else if(type == 4) //damage for spin jump
	{
		GetVectorAngles(LastVel[client], vel);
		GetAngleVectors(vel, vel, NULL_VECTOR, NULL_VECTOR);
		location[0] = vecOrigin[0]+(vel[0]*5.0)+(LastVel[client][0]*0.015);
		location[1] = vecOrigin[1]+(vel[1]*5.0)+(LastVel[client][1]*0.015);
		location[2] = vecOrigin[2]+(vel[2]*5.0)+(LastVel[client][2]*0.015);
		hTrace = TR_TraceHullFilterEx(vecOrigin, location, vecMins, vecMaxs, MASK_PLAYERSOLID, TraceFilterSpinJump, client);
	}
	else //basic check, we want to know if we'll collide before recorrecting the position
	{
		if(IsSwimming(client))
		{
		}
		else if(LastPush[client]+0.23<GetGameTime())
		{
		}
		else
		{
			//only keep step height into acount while on the ground
			vecMins[2]+=GetEntPropFloat(client, Prop_Send, "m_flStepSize")+1.0;
		}
		//prediction for rolling into crawl spaces
		GetVectorAngles(RunVel[client], vel);
		GetAngleVectors(vel, vel, NULL_VECTOR, NULL_VECTOR);
		location[0] = location[0]+(vel[0]*10.0);
		location[1] = location[1]+(vel[1]*10.0);
		hTrace = TR_TraceHullFilterEx(vecOrigin, location, vecMins, vecMaxs, MASK_PLAYERSOLID, TraceFilterChargeReloc, client);
	}
	if(hTrace != INVALID_HANDLE)
	{
		if(TR_DidHit(hTrace))
		{
			CloseHandle(hTrace);
			return true;
		}
		else
		{
			CloseHandle(hTrace);
			return false;
		}
	}
	return false;
}

stock bool:TraceFilterChargeReloc(entity, contentsMask, any:ent)
{
	if(entity == ent)
	{
		return false;
	}
	else if(IsValidEntity(entity))
	{
	    new String:ClassName[255];
		GetEntityClassname(entity, ClassName, sizeof(ClassName));
		if(!StrContains(ClassName, "tf_zombie", false)) //tf2 skeleton
		{
		    return false;
		}
	}
	return true;
}

stock bool:TraceFilterCollide(entity, contentsMask, any:ent)
{
	if(entity == ent)
	{
		return false;
	}
	else if(IsValidClient(entity))
	{
		if(GetEntProp(ent, Prop_Data, "m_iTeamNum")!=GetEntProp(entity, Prop_Data, "m_iTeamNum"))
		{
			return true;
		}
	}
	return false;
}

stock bool:TraceFilterSpinJump(entity, contentsMask, any:ent)
{
	if(entity == ent)
	{
		return false;
	}
	else if(IsValidEntity(entity))
	{
		new String:classname[100];
		GetEntityClassname(entity, classname, sizeof(classname));
		if(HasEntProp(entity, Prop_Data, "m_iTeamNum"))
		{
			if(GetEntProp(ent, Prop_Data, "m_iTeamNum")!=GetEntProp(entity, Prop_Data, "m_iTeamNum"))
			{
				new HurtType = 0;
				if(StrContains(classname, "obj_")>=0)
				{
					if(GCIFrames[ent]<=GetGameTime())
					{
						HurtType=2;
					}
				}
				else if(StrEqual(classname, "tf_zombie", false))
				{
					if(GCIFrames[ent]<=GetGameTime())
					{
						HurtType=3;
					}
				}
				else if(StrEqual(classname, "player", false))
				{
					if(GCIFrames[entity]<=GetGameTime())
					{
						HurtType=1;
					}
				}
				if(HurtType>0)
				{
					new Float:clientposition[3], Float:targetposition[3], Float:targetmaxs[3];
					GetClientAbsOrigin(ent, clientposition);
					GetEntPropVector(entity, Prop_Send, "m_vecOrigin", targetposition);
					GetEntPropVector(entity, Prop_Send, "m_vecMaxs", targetmaxs);
					
					new Float:targetheight = targetmaxs[2];
					new Float:heightdiff = clientposition[2] - targetposition[2];
					
					new Float:clientvel[3];
					GetEntPropVector(ent, Prop_Data, "m_vecVelocity", clientvel);
					if(heightdiff>targetheight && clientvel[2]<=FF2JDGoombSpd[ent]) //we stand ontop the target and we have a good vertical to horizontal speed ratio
					{
						ApplyDamageSJ(ent, entity, true);
					}
					else if(GetVectorLength(clientvel)>=FF2JDHitSpd[ent])
					{
						ApplyDamageSJ(ent, entity, false);
					}
					else
					{
						HurtType = -1;
					}
					
					if(HurtType==1)
					{
						if(FF2SJCollide[ent]!=0)
						{
							SetPlayerCollision(ent, 2);
							FixCollide[ent]=GetGameTime()+0.25;
							SetPlayerCollision(entity, 2);
							FixCollide[entity]=GetGameTime()+0.25;
						}
					}
					else if(HurtType==2)
					{
						if(FF2SJCollideBuild[ent]!=0)
						{
							SetPlayerCollision(ent, 2);
							FixCollide[ent]=GetGameTime()+0.25;
							SetBuildCollision(entity, 2);
						}
					}
					return true;
				}
			}
		}
	}
	return false;
}

stock bool:TraceFilterHomeHurt(entity, contentsMask, any:ent)
{
	if(entity == ent)
	{
		return false;
	}
	else if(IsValidEntity(entity))
	{
		new String:classname[100];
		GetEntityClassname(entity, classname, sizeof(classname));
		if(HasEntProp(entity, Prop_Data, "m_iTeamNum"))
		{
			if(GetEntProp(ent, Prop_Data, "m_iTeamNum")!=GetEntProp(entity, Prop_Data, "m_iTeamNum"))
			{
				new bool:CanHurt=false;
				if(StrContains(classname, "obj_")>=0)
				{
					if(GCIFrames[ent]<=GetGameTime())
					{
						CanHurt=true;
					}
				}
				else if(StrEqual(classname, "tf_zombie", false))
				{
					if(GCIFrames[ent]<=GetGameTime())
					{
						CanHurt=true;
					}
				}
				else if(StrEqual(classname, "player", false))
				{
					if(GCIFrames[entity]<=GetGameTime())
					{
						CanHurt=true;
					}
				}
				if(CanHurt)
				{
					ApplyDamageHA(ent, entity);
					return true;
				}
			}
		}
		if(!StrContains(classname, "tf_projectile_", false)) //projectiles, cause apparently those are player solid
		{
			return false;
		}
	}
	return true;
}

//collision groups
//2 = this plugin disables player collisions with this
//5 = player and tf_zombie
//13 = projectiles
//20 = tf_zombie gibs
//21 = tf2 buildings

stock bool:TraceFilterPassiveHurt(entity, contentsMask, any:ent)
{
	if(entity == ent)
	{
		return false;
	}
	else if(IsValidEntity(entity))
	{
		new String:classname[100];
		GetEntityClassname(entity, classname, sizeof(classname));
		if(HasEntProp(entity, Prop_Data, "m_iTeamNum"))
		{
			if(GetEntProp(ent, Prop_Data, "m_iTeamNum")!=GetEntProp(entity, Prop_Data, "m_iTeamNum"))
			{
				if(FF2PRAbilFlags[ent] & 8)
				{
					if(GetVectorLength(LastVel[ent])>=FF2RDHitSpd[ent])
					{
						if((GCType[ent]==5 && !((FF2PRAbilFlags[ent] & 16) && FF2PRButton[ent]<0)) || GCType[ent]==2)
						{
							new HurtType=0;
							if(StrContains(classname, "obj_")>=0)
							{
								if(GCIFrames[ent]<=GetGameTime())
								{
									HurtType=2;
								}
							}
							else if(StrEqual(classname, "tf_zombie", false))
							{
								if(GCIFrames[ent]<=GetGameTime())
								{
									HurtType=3;
								}
							}
							else if(StrEqual(classname, "player", false))
							{
								if(GCIFrames[entity]<=GetGameTime())
								{
									HurtType=1;
								}
							}
							if(HurtType>0)
							{
								ApplyDamageRoll(ent, entity);
								if(HurtType==1)
								{
									if(FF2PRRollCollide[ent]!=0)
									{
										SetPlayerCollision(ent, 2);
										FixCollide[ent]=GetGameTime()+0.25;
										SetPlayerCollision(entity, 2);
										FixCollide[entity]=GetGameTime()+0.25;
									}
								}
								else if(HurtType==2)
								{
									if(FF2PRRollCollideBuild[ent]!=0)
									{
										SetPlayerCollision(ent, 2);
										FixCollide[ent]=GetGameTime()+0.25;
										SetBuildCollision(entity, 2);
									}
								}
								return false;
							}
						}
					}
				}
			}
		}
		new solidity = GetEntProp(entity, Prop_Data, "m_CollisionGroup");
		if(solidity==9)
		{
			return false;
		}
		else if(solidity==5)
		{
			if(StrEqual(classname, "tf_zombie", false))
			{
				return false;
			}
			else
			{
				if(HasEntProp(entity, Prop_Data, "m_iTeamNum"))
				{
					if(GetEntProp(ent, Prop_Data, "m_iTeamNum")!=GetEntProp(entity, Prop_Data, "m_iTeamNum"))
					{
						return true;
					}
					else
					{
						return false;
					}
				}
				else
				{
					return true;
				}
			}
		}
		else if(solidity==21)
		{
			if(HasEntProp(entity, Prop_Data, "m_iTeamNum"))
			{
				if(GetEntProp(ent, Prop_Data, "m_iTeamNum")!=GetEntProp(entity, Prop_Data, "m_iTeamNum"))
				{
					return true;
				}
				else
				{
					return false;
				}
			}
			else
			{
				return true;
			}
		}
		return false;
	}
	return true;
}

stock bool:TraceFilterChargeHurt(entity, contentsMask, any:ent)
{
	if(entity == ent)
	{
		return false;
	}
	else if(IsValidEntity(entity))
	{
		new String:classname[100];
		GetEntityClassname(entity, classname, sizeof(classname));
		if(HasEntProp(entity, Prop_Data, "m_iTeamNum"))
		{
			if(GetEntProp(ent, Prop_Data, "m_iTeamNum")!=GetEntProp(entity, Prop_Data, "m_iTeamNum"))
			{
				if(FF2GCAbilFlags[ent] & 8)
				{
					if((GCType[ent]==1 && GetVectorLength(LastVel[ent])>=FF2RDHitSpd[ent]) || GCType[ent]==4)
					{
						new HurtType=0;
						if(StrContains(classname, "obj_")>=0)
						{
							if(GCIFrames[ent]<=GetGameTime())
							{
								HurtType=2;
							}
						}
						else if(StrEqual(classname, "tf_zombie", false))
						{
							if(GCIFrames[ent]<=GetGameTime())
							{
								HurtType=3;
							}
						}
						else if(StrEqual(classname, "player", false))
						{
							if(GCIFrames[entity]<=GetGameTime())
							{
								HurtType=1;
							}
						}
						if(HurtType>0)
						{
							ApplyDamageRoll(ent, entity);
							if(HurtType==1)
							{
								if(FF2GCRollCollide[ent]!=0)
								{
									SetPlayerCollision(ent, 2);
									FixCollide[ent]=GetGameTime()+0.25;
									SetPlayerCollision(entity, 2);
									FixCollide[entity]=GetGameTime()+0.25;
								}
							}
							else if(HurtType==2)
							{
								if(FF2GCRollCollideBuild[ent]!=0)
								{
									SetPlayerCollision(ent, 2);
									FixCollide[ent]=GetGameTime()+0.25;
									SetBuildCollision(entity, 2);
								}
							}
							return false;
						}
					}
				}
			}
		}
		new solidity = GetEntProp(entity, Prop_Data, "m_CollisionGroup");
		if(solidity==9)
		{
			return false;
		}
		else if(solidity==5)
		{
			if(StrEqual(classname, "tf_zombie", false))
			{
				return false;
			}
			else
			{
				if(HasEntProp(entity, Prop_Data, "m_iTeamNum"))
				{
					if(GetEntProp(ent, Prop_Data, "m_iTeamNum")!=GetEntProp(entity, Prop_Data, "m_iTeamNum"))
					{
						return true;
					}
					else
					{
						return false;
					}
				}
				else
				{
					return true;
				}
			}
		}
		else if(solidity==21)
		{
			if(HasEntProp(entity, Prop_Data, "m_iTeamNum"))
			{
				if(GetEntProp(ent, Prop_Data, "m_iTeamNum")!=GetEntProp(entity, Prop_Data, "m_iTeamNum"))
				{
					return true;
				}
				else
				{
					return false;
				}
			}
			else
			{
				return true;
			}
		}
		return false;
	}
	return true;
}

stock bool:InClearView(Float:pos2[3], Float:pos[3], entity)
{
    hTrace = TR_TraceRayFilterEx(pos2, pos, MASK_SOLID, RayType_EndPoint, TraceFilterThroughNpc, entity);
	if(hTrace != INVALID_HANDLE)
	{
        if(TR_DidHit(hTrace))//if there's an obstruction
		{
		    CloseHandle(hTrace);
		    return false;
		}
		else//if there isn't a wall between them
		{
			CloseHandle(hTrace);
			return true;
		}
	}
	return false;
}

stock bool:TraceFilterThroughNpc(entity, contentsMask, any:ent)
{
	if(entity == ent)
	{
		return false;
	}
	else if(IsValidClient(entity))
	{
		return false;
	}
	else if(IsValidEntity(entity))
	{
		new String:entname[256];
		GetEntityClassname(entity, entname, sizeof(entname));
		if(StrEqual(entname, "tank_boss", false) || StrEqual(entname, "tf_zombie", false) || StrEqual(entname, "tf_robot_destruction_robot", false) || StrEqual(entname, "merasmus", false) || StrEqual(entname, "headless_hatman", false) || StrEqual(entname, "eyeball_boss", false))
		{
			return false;
		}
		else if(StrEqual(entname, "obj_sentrygun", false) || StrEqual(entname, "obj_dispenser", false) || StrEqual(entname, "obj_teleporter", false))
		{
			return false;
		}
		else if(StrContains(entname, "tf_projectile")>=0)
		{
			return false;
		}
	}
	return true;
}

ApplyDamageHA(client, victim)
{
	if(GCType[client]==3)
	{
		new Float:dmg = FF2HADmgPlayer[client];
		if(!IsValidClient(victim))
		{
			dmg = FF2HADmgOther[client];
		}
		if(FF2HADebug[client]!=0)
		{
			new String:classname[255];
			GetEntityClassname(victim, classname, sizeof(classname));
			PrintToServer("[%s] Homed into %s for %.2f damage.", HAName, classname, dmg);
			PrintToChat(client, "[%s] Homed into %s for %.2f damage.", HAName, classname, dmg);
		}
		if(IsValidClient(victim))
		{
			GCIFrames[victim]=GetGameTime()+0.5;
			if(FF2HADmgFix[client]!=0)
			{
				if(dmg<=160.0)
				{
					dmg*=0.33;
				}
			}
			ApplyForceHA(client, victim);
			LastHomeHit[victim]=GetGameTime();
		}
		else
		{
			GCIFrames[client]=GetGameTime()+0.2;
		}
		if(dmg!=0.0)
		{
			DamageEntity(victim, client, dmg, DMG_HOME);
		}
		if(strlen(SNDHAHit[client])>0)
		{
			if(SNDHAHitType[client]==1)
			{
				EmitSoundToAll(SNDHAHit[client], victim);
				EmitSoundToAll(SNDHAHit[client], client);
			}
			else if(SNDHAHitType[client]==2)
			{
				EmitSoundToAll(SNDHAHit[client], client);
			}
			else if(SNDHAHitType[client]==3)
			{
				EmitSoundToAll(SNDHAHit[client], victim);
			}
			else
			{
				new Float:loc[3];
				GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", loc);
				EmitSoundToAll(SNDHAHit[client], 0, _, _, _, _, _, _, loc);
			}
		}
		EndHomingAttack(client, true);
	}
}

ApplyForceHA(client, victim)
{
	if(!TF2_IsPlayerInCondition(victim, TFCond_MegaHeal))
	{
		new Float:vel[3];
		new Float:vel2[3];
		GetVectorAngles(LastVel[client], vel);
		GetAngleVectors(vel, vel, NULL_VECTOR, NULL_VECTOR);
		GetEntPropVector(victim, Prop_Data, "m_vecVelocity", vel2);
		vel2[0] += vel[0]*FF2HAKnockBack[client];
		vel2[1] += vel[1]*FF2HAKnockBack[client];
		vel2[2] += vel[2]*FF2HAKnockBack[client];
		TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vel2);
		TF2_AddCondition(victim, TFCond_LostFooting, 1.0);
		if(FF2HADebug[client]!=0)
		{
			if(GetVectorLength(LastVel[client])>0.0)
			{
				PrintToServer("[%s] Applied %.2f force to player at %.2f hu/s.", HAName, GetVectorLength(vel2), GetVectorLength(LastVel[client]));
				PrintToChat(client, "[%s] Applied %.2f force to player at %.2f hu/s.", HAName, GetVectorLength(vel2), GetVectorLength(LastVel[client]));
			}
			else
			{
				PrintToServer("[%s] Applied %.2f force to player at %.2f hu/s.", HAName, GetVectorLength(vel2), GetVectorLength(LastVel[client]));
				PrintToChat(client, "[%s] Applied %.2f force to player at %.2f hu/s.", HAName, GetVectorLength(vel2), GetVectorLength(LastVel[client]));
			}
		}
	}
}

ApplyDamageRoll(client, victim)
{
	if(GCType[client]==4)
	{
		new Float:vel[3];
		vel[0] = LastVel[client][0];
		vel[1] = LastVel[client][1];
		vel[2] = 0.0;
		new Float:dmg = GetChargeSpeed(client)*FF2RDBaseDmg[client];
		if(dmg>FF2RDMaxDmg[client])
		{
			dmg = FF2RDMaxDmg[client];
		}
		else if(dmg<FF2RDMinDmg[client])
		{
			dmg = FF2RDMinDmg[client];
		}
		dmg*= FF2GCSpinHit[client];
		if(FF2RDDebug[client]!=0)
		{
			if(IsValidEntity(victim) && !IsValidClient(victim))
			{
				new String:classname[255];
				GetEntityClassname(victim, classname, sizeof(classname));
				if(GetVectorLength(vel)>0.0)
				{
					PrintToServer("[%s] Spun %s for %.2f damage at %.2f hu/s.", RDName, classname, dmg, GetVectorLength(vel));
					PrintToChat(client, "[%s] Spun %s for %.2f damage at %.2f hu/s.", RDName, classname, dmg, GetVectorLength(vel));
				}
				else
				{
					PrintToServer("[%s] Spun %s for %.2f damage at %.2f hu/s.", RDName, classname, dmg, GetVectorLength(RunVel[client]));
					PrintToChat(client, "[%s] Spun %s for %.2f damage at %.2f hu/s.", RDName, classname, dmg, GetVectorLength(RunVel[client]));
				}
			}
			else
			{
				if(GetVectorLength(vel)>0.0)
				{
					PrintToServer("[%s] Spun player for %.2f damage at %.2f hu/s.", RDName, dmg, GetVectorLength(vel));
					PrintToChat(client, "[%s] Spun player for %.2f damage at %.2f hu/s.", RDName, dmg, GetVectorLength(vel));
				}
				else
				{
					PrintToServer("[%s] Spun player for %.2f damage at %.2f hu/s.", RDName, dmg, GetVectorLength(RunVel[client]));
					PrintToChat(client, "[%s] Spun player for %.2f damage at %.2f hu/s.", RDName, dmg, GetVectorLength(RunVel[client]));
				}
			}
		}
		
		if(IsValidEntity(victim) && !IsValidClient(victim))
		{
			GCIFrames[client]=GetGameTime()+0.5;
		}
		else
		{
			if(FF2RDDmgFix[client]!=0)
			{
				if(dmg<=160.0)
				{
					dmg*=0.33;
				}
			}
			ApplyForceRoll(client, victim);
			GCIFrames[victim]=GetGameTime()+0.75;
			LastRollHit[victim]=GetGameTime();
		}
		if(IsValidEntity(victim) && !IsValidClient(victim))
		{
			GCIFrames[client]=GetGameTime()+0.5;
		}
		else
		{
			if(FF2RDDmgFix[client]!=0)
			{
				if(dmg<=160.0)
				{
					dmg*=0.33;
				}
			}
			ApplyForceRoll(client, victim);
			GCIFrames[victim]=GetGameTime()+0.75;
			LastRollHit[victim]=GetGameTime();
		}
		DamageEntity(victim, client, dmg, DMG_ROLL);
		if(GCType[client]==1)
		{
			ScaleVector(RunVel[client], FF2GCHitMult[client]);
		}
		else
		{
			ScaleVector(RunVel[client], FF2PRHitMult[client]);
		}
		if(strlen(SNDRDHit[client])>0)
		{
			if(SNDRDHitVol[client]==1)
			{
				EmitSoundToAll(SNDRDHit[client], victim);
				EmitSoundToAll(SNDRDHit[client], client);
			}
			else if(SNDRDHitVol[client]==2)
			{
				EmitSoundToAll(SNDRDHit[client], client);
			}
			else if(SNDRDHitVol[client]==3)
			{
				EmitSoundToAll(SNDRDHit[client], victim);
			}
			else
			{
				new Float:loc[3];
				GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", loc);
				EmitSoundToAll(SNDRDHit[client], 0, _, _, _, _, _, _, loc);
			}
		}
	}
	else
	{
		new Float:vel[3];
		vel[0] = LastVel[client][0];
		vel[1] = LastVel[client][1];
		vel[2] = 0.0;
		new Float:dmg = GetVectorLength(RunVel[client])*FF2RDBaseDmg[client];
		if(GetVectorLength(vel)>0.0)
		{
			dmg = GetVectorLength(vel)*FF2RDBaseDmg[client];
		}
		if(dmg>FF2RDMaxDmg[client])
		{
			dmg = FF2RDMaxDmg[client];
		}
		else if(dmg<FF2RDMinDmg[client])
		{
			dmg = FF2RDMinDmg[client];
		}
		if(FF2RDDebug[client]!=0)
		{
			if(IsValidEntity(victim) && !IsValidClient(victim))
			{
				new String:classname[255];
				GetEntityClassname(victim, classname, sizeof(classname));
				if(GetVectorLength(vel)>0.0)
				{
					PrintToServer("[%s] Ran over %s for %.2f damage at %.2f hu/s.", RDName, classname, dmg, GetVectorLength(vel));
					PrintToChat(client, "[%s] Ran over %s for %.2f damage at %.2f hu/s.", RDName, classname, dmg, GetVectorLength(vel));
				}
				else
				{
					PrintToServer("[%s] Ran over %s for %.2f damage at %.2f hu/s.", RDName, classname, dmg, GetVectorLength(RunVel[client]));
					PrintToChat(client, "[%s] Ran over %s for %.2f damage at %.2f hu/s.", RDName, classname, dmg, GetVectorLength(RunVel[client]));
				}
			}
			else
			{
				if(GetVectorLength(vel)>0.0)
				{
					PrintToServer("[%s] Ran over player for %.2f damage at %.2f hu/s.", RDName, dmg, GetVectorLength(vel));
					PrintToChat(client, "[%s] Ran over player for %.2f damage at %.2f hu/s.", RDName, dmg, GetVectorLength(vel));
				}
				else
				{
					PrintToServer("[%s] Ran over player for %.2f damage at %.2f hu/s.", RDName, dmg, GetVectorLength(RunVel[client]));
					PrintToChat(client, "[%s] Ran over player for %.2f damage at %.2f hu/s.", RDName, dmg, GetVectorLength(RunVel[client]));
				}
			}
		}
		if(IsValidEntity(victim) && !IsValidClient(victim))
		{
			GCIFrames[client]=GetGameTime()+0.5;
		}
		else
		{
			if(FF2RDDmgFix[client]!=0)
			{
				if(dmg<=160.0)
				{
					dmg*=0.33;
				}
			}
			ApplyForceRoll(client, victim);
			GCIFrames[victim]=GetGameTime()+0.75;
			LastRollHit[victim]=GetGameTime();
		}
		DamageEntity(victim, client, dmg, DMG_ROLL);
		if(GCType[client]==1)
		{
			ScaleVector(RunVel[client], FF2GCHitMult[client]);
		}
		else
		{
			ScaleVector(RunVel[client], FF2PRHitMult[client]);
		}
		if(strlen(SNDRDHit[client])>0)
		{
			if(SNDRDHitVol[client]==1)
			{
				EmitSoundToAll(SNDRDHit[client], victim);
				EmitSoundToAll(SNDRDHit[client], client);
			}
			else if(SNDRDHitVol[client]==2)
			{
				EmitSoundToAll(SNDRDHit[client], client);
			}
			else if(SNDRDHitVol[client]==3)
			{
				EmitSoundToAll(SNDRDHit[client], victim);
			}
			else
			{
				new Float:loc[3];
				GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", loc);
				EmitSoundToAll(SNDRDHit[client], 0, _, _, _, _, _, _, loc);
			}
		}
	}
}

ApplyForceRoll(client, victim)
{
	if(!TF2_IsPlayerInCondition(victim, TFCond_MegaHeal))
	{
		new Float:vel[3];
		vel[2] = LastVel[client][2];
		new Float:ForceVert = GetVectorLength(RunVel[client]);
		if(GetVectorLength(LastVel[client])>0.0)
		{
			ForceVert = GetVectorLength(LastVel[client]);
		}
		vel[0] = LastVel[client][0];
		vel[1] = LastVel[client][1];
		vel[2] = 0.0;
		new Float:ForceHori = GetVectorLength(RunVel[client]);
		if(GetVectorLength(LastVel[client])>0.0)
		{
			ForceHori = GetVectorLength(LastVel[client]);
		}
		
		ForceHori *= FF2RDBaseKB[client];
		ForceVert *= FF2RDBaseKBVert[client];
		if(ForceHori>FF2RDMaxKB[client])
		{
			ForceHori = FF2RDMaxKB[client];
		}
		else if(ForceHori<FF2RDMinKB[client])
		{
			ForceHori = FF2RDMinKB[client];
		}
		if(ForceVert>FF2RDMaxKB[client])
		{
			ForceVert = FF2RDMaxKB[client];
		}
		else if(ForceVert<FF2RDMinKB[client])
		{
			ForceVert = FF2RDMinKB[client];
		}
		GetEntPropVector(victim, Prop_Data, "m_vecVelocity", vel);
		vel[0] += ForceHori;
		vel[1] += ForceHori;
		vel[2] += ForceVert;
		TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vel);
		TF2_AddCondition(victim, TFCond_LostFooting, 1.0);
		vel[0] = LastVel[client][0];
		vel[1] = LastVel[client][1];
		vel[2] = 0.0;
		if(FF2RDDebug[client]!=0)
		{
			if(GetVectorLength(LastVel[client])>0.0)
			{
				PrintToServer("[%s] Applied %.2f force to player at %.2f hu/s.", RDName, ForceHori, GetVectorLength(vel));
				PrintToChat(client, "[%s] Applied %.2f force to player at %.2f hu/s.", RDName, ForceHori, GetVectorLength(vel));
			}
			else
			{
				PrintToServer("[%s] Applied %.2f force to player at %.2f hu/s.", RDName, ForceHori, GetVectorLength(RunVel[client]));
				PrintToChat(client, "[%s] Applied %.2f force to player at %.2f hu/s.", RDName, ForceHori, GetVectorLength(RunVel[client]));
			}
		}
	}
}

ApplyDamageSJ(client, victim, bool:goomba)
{
	new Float:vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	new Float:dmg = GetVectorLength(vel)*FF2JDBaseDmg[client];
	if(dmg>FF2JDMaxDmg[client])
	{
		dmg = FF2JDMaxDmg[client];
	}
	else if(dmg<FF2JDMinDmg[client])
	{
		dmg = FF2JDMinDmg[client];
	}
	if(goomba && FF2JDGoombMult[client]==0.0)
	{
		return;
	}
	if(goomba)
	{
		dmg *= FF2JDGoombMult[client];
		if(IsValidClient(victim))
		{
			TF2_StunPlayer(victim, FF2SJGoombStunDur[client], 0.0, FF2SJGoombStunFlags[client], client);
			if(FF2SJStunShield[client]!=0 && GetWearableShield(victim)>-1)
			{
				dmg = 0.0;
			}
		}
	}
	if(FF2RDDebug[client]!=0)
	{
		if(IsValidEntity(victim) && !IsValidClient(victim))
		{
			new String:classname[255];
			GetEntityClassname(victim, classname, sizeof(classname));
			if(goomba)
			{
				PrintToServer("[%s] Stomped %s for %.2f damage at %.2f hu/s.", RDName, classname, dmg, GetVectorLength(vel));
				PrintToChat(client, "[%s] Stomped %s for %.2f damage at %.2f hu/s.", RDName, classname, dmg, GetVectorLength(vel));
			}
			else
			{
				PrintToServer("[%s] Spinjumped %s for %.2f damage at %.2f hu/s.", RDName, classname, dmg, GetVectorLength(vel));
				PrintToChat(client, "[%s] Spinjumped %s for %.2f damage at %.2f hu/s.", RDName, classname, dmg, GetVectorLength(vel));
			}
		}
		else
		{
			if(goomba)
			{
				PrintToServer("[%s] Stomped player for %.2f damage at %.2f hu/s.", RDName, dmg, GetVectorLength(vel));
				PrintToChat(client, "[%s] Stomped player for %.2f damage at %.2f hu/s.", RDName, dmg, GetVectorLength(vel));
			}
			else
			{
				PrintToServer("[%s] Spinjumped player for %.2f damage at %.2f hu/s.", RDName, dmg, GetVectorLength(vel));
				PrintToChat(client, "[%s] Spinjumped player for %.2f damage at %.2f hu/s.", RDName, dmg, GetVectorLength(vel));
			}
		}
	}
	if(IsValidEntity(victim) && !IsValidClient(victim))
	{
		GCIFrames[client]=GetGameTime()+0.5;
	}
	else
	{
		if(FF2JDDmgFix[client]!=0)
		{
			if(dmg<=160.0)
			{
				dmg*=0.33;
			}
		}
		GCIFrames[victim]=GetGameTime()+0.7;
		LastRollHit[victim]=GetGameTime();
	}
	if(dmg!=0.0)
	{
		DamageEntity(victim, client, dmg, DMG_ROLL);
	}
	ApplyForceSJ(client, victim);
	if(goomba && FF2JDGoombMult[client]!=1.0 && strlen(SNDJDGoomb[client])>0)
	{
		if(SNDJDGoombVol[client]==1)
		{
			EmitSoundToAll(SNDJDGoomb[client], victim);
			EmitSoundToAll(SNDJDGoomb[client], client);
		}
		else if(SNDJDGoombVol[client]==2)
		{
			EmitSoundToAll(SNDJDGoomb[client], client);
		}
		else if(SNDJDGoombVol[client]==3)
		{
			EmitSoundToAll(SNDJDGoomb[client], victim);
		}
		else
		{
			new Float:loc[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", loc);
			EmitSoundToAll(SNDJDGoomb[client], 0, _, _, _, _, _, _, loc);
		}
	}
	else if(strlen(SNDJDHit[client])>0)
	{
		if(SNDJDHitVol[client]==1)
		{
			EmitSoundToAll(SNDJDHit[client], victim);
			EmitSoundToAll(SNDJDHit[client], client);
		}
		else if(SNDJDHitVol[client]==2)
		{
			EmitSoundToAll(SNDJDHit[client], client);
		}
		else if(SNDJDHitVol[client]==3)
		{
			EmitSoundToAll(SNDJDHit[client], victim);
		}
		else
		{
			new Float:loc[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", loc);
			EmitSoundToAll(SNDJDHit[client], 0, _, _, _, _, _, _, loc);
		}
	}
	return;
}

ApplyForceSJ(client, victim)
{
	new Float:clpos[3];
	new Float:vipos[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", clpos);
	GetEntPropVector(victim, Prop_Data, "m_vecAbsOrigin", vipos);
	new Float:clvel[3];
	new Float:vivel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", clvel);
	GetEntPropVector(victim, Prop_Data, "m_vecVelocity", vivel);
	if(IsValidClient(victim) && FF2JDBaseKB[client]!=0.0)
	{
		vivel[0] +=clvel[0]*FF2JDBaseKB[client];
		vivel[1] +=clvel[1]*FF2JDBaseKB[client];
		vivel[2] +=clvel[2]*FF2JDBaseKB[client];
		TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, vivel);
		TF2_AddCondition(victim, TFCond_LostFooting, 1.0);
		if(FF2RDDebug[client]!=0)
		{
			PrintToServer("[%s] Applied %.2f force to player at %.2f hu/s.", RDName, GetVectorLength(clvel)*FF2JDBaseKB[client], GetVectorLength(clvel));
			PrintToChat(client, "[%s] Applied %.2f force to player at %.2f hu/s.", RDName, GetVectorLength(clvel)*FF2JDBaseKB[client], GetVectorLength(clvel));
		}
	}
	new Float:anglevec[3];
	SubtractVectors(vipos, clpos, anglevec);
    NormalizeVector(anglevec, anglevec);
	new Float:knockback = GetVectorLength(clvel)*FF2JDSelfKB[client];
	new Float:knockbackvert = GetVectorLength(clvel)*FF2JDSelfKBVert[client];
	if(FF2JDSelfKBType[client]==0)
	{
		clvel[0] =anglevec[0]*knockback;
		clvel[1] =anglevec[1]*knockback;
		clvel[2] =anglevec[2]*knockbackvert;
	}
	else
	{
		clvel[0] +=anglevec[0]*knockback;
		clvel[1] +=anglevec[1]*knockback;
		clvel[2] +=anglevec[2]*knockbackvert;
	}
	RunVel[client][0]=clvel[0];
	RunVel[client][1]=clvel[1];
	RunVel[client][2]=clvel[2];
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, clvel);
}

DamageEntity(client, attacker = 0, Float:dmg, dmg_type = DMG_GENERIC)
{
	if(IsValidClient(client) || IsValidEntity(client))
	{
		new damage = RoundToNearest(dmg);
		new String:dmg_str[16];
		IntToString(damage,dmg_str,16);
		new String:dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		new pointHurt=CreateEntityByName("point_hurt");
		if(pointHurt)
		{
			DispatchKeyValue(client,"targetname","targetsname_ff2_groundcharge");
			DispatchKeyValue(pointHurt,"DamageTarget","targetsname_ff2_groundcharge");
			DispatchKeyValue(pointHurt,"Damage",dmg_str);
			DispatchKeyValue(pointHurt,"DamageType",dmg_type_str);
			DispatchKeyValue(pointHurt,"classname", "");
			DispatchSpawn(pointHurt);
			if(IsValidEntity(attacker))
			{
			    new Float:AttackLocation[3];
		        GetEntPropVector(attacker, Prop_Send, "m_vecOrigin", AttackLocation);
				TeleportEntity(pointHurt, AttackLocation, NULL_VECTOR, NULL_VECTOR);
			}
			AcceptEntityInput(pointHurt,"Hurt",(attacker>0)?attacker:-1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			DispatchKeyValue(client,"targetname","donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}

CreateParticle(client, String:particlename[])
{
    if(IsValidClient(client))
	{
		new particle = CreateEntityByName("info_particle_system");
		if (IsValidEdict(particle))
		{
			new Float:pos[3];
			GetEntPropVector(client, Prop_Data, "m_vecOrigin", pos);
			DispatchKeyValue(particle, "targetname", "tf2particle");
			DispatchKeyValue(particle, "effect_name", particlename);
			DispatchKeyValue(particle, "angles", "-90.0, 0.0, 0.0"); 
			DispatchSpawn(particle);
			ActivateEntity(particle);
			AcceptEntityInput(particle, "start");
			TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
			CreateTimer(10.0, Timer_RemoveParticle, EntIndexToEntRef(particle));
		}
	}
}

public Action:Timer_RemoveParticle(Handle:timer, entity)
{
	entity = EntRefToEntIndex(entity);
	if(IsValidEntity(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

CreateRollTrail(client, String:particlename[], Float:angoffset, Float:offset)
{
    if(IsValidClient(client))
	{
		new particle = CreateEntityByName("info_particle_system");
		if (IsValidEdict(particle))
		{
			new Float:pos[3];
			new Float:angle[3];
			GetEntPropVector(client, Prop_Data, "m_angRotation", angle);
			angle[0]=angoffset;
			SetEntPropEnt(particle, Prop_Data, "m_hOwnerEntity", client);
			DispatchKeyValue(particle, "effect_name", particlename);
			SetVariantString("!activator");
			DispatchSpawn(particle);
			AcceptEntityInput(particle, "SetParent", client, particle, 0);
			TeleportEntity(particle, pos, angle, NULL_VECTOR);
		
			AcceptEntityInput(particle, "start");
			ActivateEntity(particle);
			RollPart[client] = EntIndexToEntRef(particle);
			
			if(offset>0.0)
			{
				new Float:loc[3];
				loc[2] += offset*1.5;
				TeleportEntity(particle, loc, NULL_VECTOR, NULL_VECTOR);
			}
			
			if(FF2GCDebug[client]!=0)
			{
				PrintToServer("[%s] Trail Created", GCName);
			}
		}
	}
}

KillRollTrail(client)
{
	if(RollPart[client]!=0)
	{
		new particle = EntRefToEntIndex(RollPart[client]);
		if(IsValidEntity(particle))
		{
			AcceptEntityInput(particle, "Kill");
		}
		RollPart[client]=0;
		if(FF2GCDebug[client]!=0)
		{
			PrintToServer("[%s] Trail Killed", GCName);
		}
	}
}

//sets a prop of the player's model doing a specific animation
SetupAnimationActor(client, String:actormodel[255], id)
{
    if(IsValidClient(client))
	{
		if(strlen(actormodel)>0)
		{
			//spawn and scale the model
			new actor = CreateEntityByName("prop_dynamic_override");
			if(IsValidEntity(actor))
			{
				SetEntityMoveType(actor, MOVETYPE_FLY);
				DispatchKeyValue(actor, "model", actormodel); 
				DispatchSpawn(actor);
				SetEntProp(actor, Prop_Send, "m_nSkin", GetClientTeam(client)-2);
				
				//teleport the model
				TeleportEntity(actor, OFF_THE_MAP, NULL_VECTOR, NULL_VECTOR);
				
				//set the default animation
				SetVariantString("stand_MELEE");
				AcceptEntityInput(actor, "SetDefaultAnimation");
				SetVariantString("stand_MELEE");
				AcceptEntityInput(actor, "SetAnimation");
				
				//record entity
				ActorRef[client][id] = EntIndexToEntRef(actor);
			}
		}
	}
}

AnimateActor(client, String:animation[], id, Float:looptime = -1.0, bool:setangle = false)
{
	if(IsValidClient(client))
	{
		new entity = EntRefToEntIndex(ActorRef[client][id]);
		if(IsValidEntity(entity))
		{
			new String:classname[255];
			GetEntityClassname(entity, classname, sizeof(classname));
			if(StrEqual(classname, "prop_dynamic"))
			{
				SetPlayerAlpha(client, 0);
				SetVariantString(animation);
				AcceptEntityInput(entity, "SetAnimation");
				Format(CurAnim[client][id], string_hud, animation);
				ActorActive[client][id]=true;
				AnimLoop[client][id] = looptime;
				if(looptime < 0.0)
				{
					NextAnim[client][id] = GetGameTime()+AnimLoop[client][id];
				}
				else
				{
					NextAnim[client][id] = GetGameTime()+looptime;
				}
				if(setangle)
				{
					new Float:angle[3];
					switch(id)
					{
						case 0:
						{
							angle[0] = ANMGCRollBaseAng[client];
						}
						case 1:
						{
							angle[0] = ANMGCBuildBaseAng[client];
						}
					}
					TeleportEntity(entity, NULL_VECTOR, angle, NULL_VECTOR);
				}
			}
		}
	}
}

UpdateActorLocation(client, id)
{
	if(IsValidClient(client))
	{
		new entity = EntRefToEntIndex(ActorRef[client][id]);
		if(IsValidEntity(entity))
		{
			new String:classname[255];
			GetEntityClassname(entity, classname, sizeof(classname));
			if(StrEqual(classname, "prop_dynamic"))
			{
				new Float:clscale = GetEntPropFloat(client, Prop_Send, "m_flModelScale");
				SetEntPropFloat(entity, Prop_Send, "m_flModelScale", clscale);
				new Float:angle[3];
				new Float:location[3];
				new Float:vel[3];
				GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", location);
				GetEntPropVector(client, Prop_Data, "m_angRotation", angle);
				angle[2] = 0.0;
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
				new Float:curspeed = GetVectorLength(vel)*0.01;
				//rotations and offsets
				if(id==0)
				{
					if(ANMGCRollVert[client]!=0.0)
					{
						new Float:propangle[3];
						GetEntPropVector(entity, Prop_Data, "m_angRotation", propangle);
						propangle[0]+=(ANMGCRollVert[client]*curspeed);
						if(propangle[0]>180.0)
						{
							propangle[0]-=360.0;
						}
						else if(propangle[0]<-180.0)
						{
							propangle[0]+=360.0;
						}
						angle[0]=propangle[0];
						new Float:offset = angle[0]*clscale*ANMGCRollAngOffset[client];
						
						if(offset<0.0)
						{
							offset*=-1.0;
						}
						location[2]+=offset;
						location[2]+=clscale*ANMGCRollOffset[client];
						if(propangle[0]<0.0)
						{
							if(propangle[0]<-90.0)
							{
								propangle[0]=-90.0+((propangle[0]+90.0)*-1.0);
							}
							if(propangle[0]<-60.0)
							{
								propangle[0]=-60.0;
							}
						}
						else
						{
							if(propangle[0]>90.0)
							{
								propangle[0]=90.0-(propangle[0]-90);
							}
							if(propangle[0]>60.0)
							{
								propangle[0]=60.0;
							}
						}
						new Float:offsetangle[3];
						GetAngleVectors(propangle, offsetangle, NULL_VECTOR, NULL_VECTOR);
						location[0]+=offsetangle[0]*(propangle[0]*ANMGCRollHoriOffset[client]);
						location[1]+=offsetangle[1]*(propangle[0]*ANMGCRollHoriOffset[client]);
					}
					else
					{
						angle[0] = 0.0;
					}
					
				}
				else if(id==1)
				{
					if(ANMGCBuildVert[client]!=0.0)
					{
						new Float:propangle[3];
						GetEntPropVector(entity, Prop_Data, "m_angRotation", propangle);
						propangle[0]+=ANMGCBuildVert[client]*(GetChargeSpeed(client)*0.01);
						if(propangle[0]>180.0)
						{
							propangle[0]-=360.0;
						}
						else if(propangle[0]<-180.0)
						{
							propangle[0]+=360.0;
						}
						angle[0]=propangle[0];
						new Float:offset = angle[0]*clscale*ANMGCBuildAngOffset[client];
						if(offset<0.0)
						{
							offset*=-1.0;
						}
						location[2]+=offset;
						location[2]+=clscale*ANMGCBuildOffset[client];
						if(propangle[0]<0.0)
						{
							if(propangle[0]<-90.0)
							{
								propangle[0]=-90.0+((propangle[0]+90.0)*-1.0);
							}
							if(propangle[0]<-60.0)
							{
								propangle[0]=-60.0;
							}
						}
						else
						{
							if(propangle[0]>90.0)
							{
								propangle[0]=90.0-(propangle[0]-90);
							}
							if(propangle[0]>60.0)
							{
								propangle[0]=60.0;
							}
						}
						new Float:offsetangle[3];
						GetAngleVectors(propangle, offsetangle, NULL_VECTOR, NULL_VECTOR);
						location[0]+=offsetangle[0]*((propangle[0]*ANMGCBuildHoriOffset[client])*clscale);
						location[1]+=offsetangle[1]*((propangle[0]*ANMGCBuildHoriOffset[client])*clscale);
					}
					else
					{
						angle[0] = 0.0;
					}
				}
				else if(id==2)
				{
					if(ANMHAOffset[client]!=0.0)
					{
						new Float:propangle[3];
						GetEntPropVector(entity, Prop_Data, "m_angRotation", propangle);
						propangle[0]+=ANMHAOffset[client];
						if(propangle[0]>180.0)
						{
							propangle[0]-=360.0;
						}
						else if(propangle[0]<-180.0)
						{
							propangle[0]+=360.0;
						}
						angle[0]=propangle[0];
						new Float:offset = angle[0]*clscale*ANMHAAngOffset[client];
						if(offset<0.0)
						{
							offset*=-1.0;
						}
						location[2]+=offset;
						location[2]+=clscale*ANMHAVert[client];
						if(propangle[0]<0.0)
						{
							if(propangle[0]<-90.0)
							{
								propangle[0]=-90.0+((propangle[0]+90.0)*-1.0);
							}
							if(propangle[0]<-60.0)
							{
								propangle[0]=-60.0;
							}
						}
						else
						{
							if(propangle[0]>90.0)
							{
								propangle[0]=90.0-(propangle[0]-90);
							}
							if(propangle[0]>60.0)
							{
								propangle[0]=60.0;
							}
						}
						new Float:offsetangle[3];
						GetAngleVectors(propangle, offsetangle, NULL_VECTOR, NULL_VECTOR);
						location[0]+=offsetangle[0]*((propangle[0]*ANMHAHoriOffset[client])*clscale);
						location[1]+=offsetangle[1]*((propangle[0]*ANMHAHoriOffset[client])*clscale);
					}
					else
					{
						angle[0] = 0.0;
					}
				}
				else if(id==3)
				{
					if(ANMPRRollVert[client]!=0.0)
					{
						new Float:propangle[3];
						new Float:actualangle[3];
						GetEntPropVector(client, Prop_Data, "m_vecVelocity", propangle);
						propangle[2]=0.0;
						GetVectorAngles(propangle, propangle);
						GetEntPropVector(entity, Prop_Data, "m_angRotation", actualangle);
						propangle[0]=actualangle[0];
						propangle[0]+=(ANMPRRollVert[client]*curspeed);
						if(propangle[0]>180.0)
						{
							propangle[0]-=360.0;
						}
						else if(propangle[0]<-180.0)
						{
							propangle[0]+=360.0;
						}
						angle[0]=propangle[0];
						angle[1]=propangle[1];
						
						new Float:offset = angle[0]*clscale*ANMPRRollAngOffset[client];
						
						if(offset<0.0)
						{
							offset*=-1.0;
						}
						location[2]+=offset;
						location[2]+=clscale*ANMPRRollOffset[client];
						if(propangle[0]<0.0)
						{
							if(propangle[0]<-90.0)
							{
								propangle[0]=-90.0+((propangle[0]+90.0)*-1.0);
							}
							if(propangle[0]<-60.0)
							{
								propangle[0]=-60.0;
							}
						}
						else
						{
							if(propangle[0]>90.0)
							{
								propangle[0]=90.0-(propangle[0]-90);
							}
							if(propangle[0]>60.0)
							{
								propangle[0]=60.0;
							}
						}
						new Float:offsetangle[3];
						GetAngleVectors(propangle, offsetangle, NULL_VECTOR, NULL_VECTOR);
						location[0]+=offsetangle[0]*(propangle[0]*ANMPRRollHoriOffset[client]);
						location[1]+=offsetangle[1]*(propangle[0]*ANMPRRollHoriOffset[client]);
					}
					else
					{
						angle[0] = 0.0;
					}
					
				}
				else if(id==4)
				{
					if(ANMSJOffset[client]!=0.0)
					{
						new Float:propangle[3];
						GetEntPropVector(entity, Prop_Data, "m_angRotation", propangle);
						propangle[0]+=ANMSJOffset[client];
						if(propangle[0]>180.0)
						{
							propangle[0]-=360.0;
						}
						else if(propangle[0]<-180.0)
						{
							propangle[0]+=360.0;
						}
						angle[0]=propangle[0];
						new Float:offset = angle[0]*clscale*ANMSJAngOffset[client];
						if(offset<0.0)
						{
							offset*=-1.0;
						}
						location[2]+=offset;
						location[2]+=clscale*ANMSJVert[client];
						if(propangle[0]<0.0)
						{
							if(propangle[0]<-90.0)
							{
								propangle[0]=-90.0+((propangle[0]+90.0)*-1.0);
							}
							if(propangle[0]<-60.0)
							{
								propangle[0]=-60.0;
							}
						}
						else
						{
							if(propangle[0]>90.0)
							{
								propangle[0]=90.0-(propangle[0]-90);
							}
							if(propangle[0]>60.0)
							{
								propangle[0]=60.0;
							}
						}
						new Float:offsetangle[3];
						GetAngleVectors(propangle, offsetangle, NULL_VECTOR, NULL_VECTOR);
						location[0]+=offsetangle[0]*((propangle[0]*ANMSJHoriOffset[client])*clscale);
						location[1]+=offsetangle[1]*((propangle[0]*ANMSJHoriOffset[client])*clscale);
					}
					else
					{
						angle[0] = 0.0;
					}
				}
				location[0]+=vel[0]*0.02;
				location[1]+=vel[1]*0.02;
				location[2]+=vel[2]*0.02;
				TeleportEntity(entity, location, angle, vel);
			}
		}
	}
}

HideActor(client, id)
{
	if(IsValidClient(client))
	{
		new entity = EntRefToEntIndex(ActorRef[client][id]);
		if(IsValidEntity(entity))
		{
			new String:classname[255];
			GetEntityClassname(entity, classname, sizeof(classname));
			if(StrEqual(classname, "prop_dynamic"))
			{
				TeleportEntity(entity, OFF_THE_MAP, NULL_VECTOR, NULL_VECTOR);
			}
		}
		ActorActive[client][id]=false;
		SetPlayerAlpha(client, 255);
	}
}

HideAllActors(client)
{
	if(strlen(ANMGCRoll[client])>0)
	{
		HideActor(client, 0);
	}
	if(strlen(ANMGCBuild[client])>0)
	{
		HideActor(client, 1);
	}
	if(strlen(ANMHA[client])>0)
	{
		HideActor(client, 2);
	}
	if(strlen(ANMPRRoll[client])>0)
	{
		HideActor(client, 3);
	}
}	

RemoveClientActor(client, id)
{
	if(IsValidClient(client))
	{
		SetPlayerAlpha(client, 255);
		new entity = EntRefToEntIndex(ActorRef[client][id]);
		if(IsValidEntity(entity))
		{
			new String:classname[255];
			GetEntityClassname(entity, classname, sizeof(classname));
			if(StrEqual(classname, "prop_dynamic"))
			{
				AcceptEntityInput(entity, "kill");
			}
		}
		ActorRef[client][id]=0;
		ActorActive[client][id]=false;
	}
}

UpdateAnim(client)
{
	if(GCType[client]==1 && !ActorActive[client][0]) //launch mode
	{
		if(strlen(ANMGCRoll[client])>0)
		{
			AnimateActor(client, ANMGCRoll[client], 0, ANMGCRollDur[client], true);
		}
	}
	else if(GCType[client]==2 && !ActorActive[client][0]) //rolling mode
	{
		if(strlen(ANMGCRoll[client])>0)
		{
			AnimateActor(client, ANMGCRoll[client], 0, ANMGCRollDur[client], true);
		}
	}
	else if(GCType[client]==3 && !ActorActive[client][2]) //homing mode
	{
		if(strlen(ANMHA[client])>0)
		{
			AnimateActor(client, ANMHA[client], 2, ANMHADur[client], true);
		}
	}
	else if(GCType[client]==4 && !ActorActive[client][1]) //charge up mode
	{
		if(strlen(ANMGCBuild[client])>0)
		{
			AnimateActor(client, ANMGCBuild[client], 1, ANMGCBuildDur[client], true);
		}
	}
	else if(GCType[client]==5 && !ActorActive[client][3]) //passive roll mode
	{
		if((FF2PRAbilFlags[client] & 16) && FF2PRButton[client]<0)
		{
		}
		else
		{
			if(strlen(ANMPRRoll[client])>0)
			{
				AnimateActor(client, ANMPRRoll[client], 3, ANMPRRollDur[client], true);
			}
		}
	}
}

SetPlayerAlpha(client, amount)
{
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntData(client, GetEntSendPropOffs(client, "m_clrRender") + 3, amount, 1, true);
	new weapon = 0;
	new i = 0;
	for(i = 0; i < 6; i++)
	{
		weapon = GetPlayerWeaponSlot(client, i);
		if(!IsValidClient(weapon) && IsValidEntity(weapon))
		{
			SetEntityRenderMode(weapon, RENDER_TRANSCOLOR);
			SetEntData(weapon, GetEntSendPropOffs(client, "m_clrRender") + 3, amount, 1, true);
		}
	}
	i = 0;
	if(!IsBoss(client)) //bosses shouldn't have wearables
	{
		while ((i = FindEntityByClassname(i, "tf_wearabl*")) != -1)
		{ 
			if(client == GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity"))
			{
				SetEntityRenderMode(i, RENDER_TRANSCOLOR);
				SetEntData(i, GetEntSendPropOffs(client, "m_clrRender") + 3, amount, 1, true);
			}
		}
	}
	while ((i = FindEntityByClassname(i, "tf_powerup_bottle")) != -1)
	{ 
		if(client == GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity"))
		{
			SetEntityRenderMode(i, RENDER_TRANSCOLOR);
			SetEntData(i, GetEntSendPropOffs(client, "m_clrRender") + 3, amount, 1, true);
		}
	}
}

ApplyGCAddcond(client, Float:curspeed)
{
	for(new i = 0; i < 31; i++)
	{
		if(GCARollCondID[client][i]>-1)
		{
			if(curspeed>=GCARollSpd[client][i])
			{
				TF2_AddCondition(client, TFCond:GCARollCondID[client][i], 0.2);
			}
		}
		else
		{
			break;
		}
	}
}

ApplyPRAddcond(client, Float:curspeed)
{
	for(new i = 0; i < 31; i++)
	{
		if(PRARollCondID[client][i]>-1)
		{
			if(curspeed>=PRARollSpd[client][i])
			{
				TF2_AddCondition(client, TFCond:PRARollCondID[client][i], 0.2);
			}
		}
		else
		{
			break;
		}
	}
}

CreateSpinCondList(client, boss)
{
	new String:cond[128];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, GCName, 38, cond, string_path);
	new String:conds[32][32];
	new count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		new id;
		for (new i = 0; i < count; i++)
		{
			id = StringToInt(conds[i]);
			if(id>-1)
			{
				if(i>31)
				{
					break;
				}
				FF2GCSpinCondID[client][i]=id;
			}
			else
			{
				break;
			}
		}
	}
}

ApplySpinAddcond(client)
{
	for(new i = 0; i < 31; i++)
	{
		if(FF2GCSpinCondID[client][i]>-1)
		{
			TF2_AddCondition(client, TFCond:FF2GCSpinCondID[client][i], 0.1);
		}
		else
		{
			break;
		}
	}
}

CreateAddcondSJList(client, boss)
{
	new String:cond[128];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, SJName, 25, cond, string_path);
	new String:conds[32][32];
	new count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		new id;
		new Float:spd;
		for (new i = 0; i < count; i+=2)
		{
			id = StringToInt(conds[i]);
			spd = StringToFloat(conds[i+1]);
			if(id>-1)
			{
				if(i>31)
				{
					break;
				}
				SJCondID[client][i]=id;
				SJCondSpd[client][i]=spd;
			}
			else
			{
				break;
			}
		}
	}
}

ApplySJAddcond(client, Float:fallspeed)
{
	for(new i = 0; i < 31; i++)
	{
		if(SJCondID[client][i]>-1)
		{
			if(fallspeed<=SJCondSpd[client][i])
			{
				TF2_AddCondition(client, TFCond:SJCondID[client][i], 0.2);
			}
		}
		else
		{
			break;
		}
	}
}


CreateAddcondPRList(client, boss)
{
	new String:cond[128];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, PRName, 21, cond, string_path);
	new String:conds[32][32];
	new count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		new id;
		new Float:spd;
		for (new i = 0; i < count; i+=2)
		{
			id = StringToInt(conds[i]);
			spd = StringToFloat(conds[i+1]);
			if(id>-1)
			{
				if(i>31)
				{
					break;
				}
				PRARollCondID[client][i]=id;
				PRARollSpd[client][i]=spd;
			}
			else
			{
				break;
			}
		}
	}
}

CreateAddcondGCList(client, boss)
{
	new String:cond[128];
	FF2_GetAbilityArgumentString(boss, this_plugin_name, GCName, 19, cond, string_path);
	new String:conds[32][32];
	new count = ExplodeString(cond, " ; ", conds, sizeof(conds), sizeof(conds));
	if (count > 0)
	{
		new id;
		new Float:spd;
		for (new i = 0; i < count; i+=2)
		{
			id = StringToInt(conds[i]);
			spd = StringToFloat(conds[i+1]);
			if(id>-1)
			{
				if(i>31)
				{
					break;
				}
				GCARollCondID[client][i]=id;
				GCARollSpd[client][i]=spd;
			}
			else
			{
				break;
			}
		}
	}
}

ClearSJAddcondList(client)
{
	for (new i = 0; i < 31; i+=2)
	{
		SJCondID[client][i]=-1;
		SJCondSpd[client][i]=0.0;
	}
}

ClearGCSpinCondList(client)
{
	for (new i = 0; i < 31; i++)
	{
		FF2GCSpinCondID[client][i]=-1;
	}
}

ClearGCAddcondList(client)
{
	for (new i = 0; i < 31; i+=2)
	{
		GCARollCondID[client][i]=-1;
		GCARollSpd[client][i]=0.0;
	}
}

ClearPRAddcondList(client)
{
	for (new i = 0; i < 31; i+=2)
	{
		PRARollCondID[client][i]=-1;
		PRARollSpd[client][i]=0.0;
	}
}

stock bool:JustJumped(client, buttons)
{
	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		if(!(GetEntityFlags(client) & FL_DUCKING))
		{
			if((buttons & IN_JUMP) && !(LastButtons[client] & IN_JUMP))
			{
				return true;
			}
		}
	}
	else if(FF2SJAbilFlags[client] & 2)
	{
		if((buttons & IN_JUMP) && !(LastButtons[client] & IN_JUMP))
		{
			return true;
		}
	}
	return false;
}

stock bool:CanJump(client)
{
	if(Jumped[client])
	{
		return false;
	}
	if(NextSpinJump[client]>GetGameTime())
	{
		return false;
	}
	if(ClientHasStunFlags(client, FF2SJStunFlags[client]))
	{
		return false;
	}
	if(FF2SJAbilFlags[client] & 4)
	{
		if(IsSwimmingStrict(client))
		{
			if(FF2SJAbilFlags[client] & 1)
			{
				return false;
			}
			else if(IsSwimming(client))
			{
				return false;
			}
		}
	}
	if(GCType[client]==0)
	{
		if(GetEntityFlags(client) & FL_ONGROUND)
		{
			return true;
		}
		else
		{
			if(FF2SJAbilFlags[client] & 1)
			{
				return true;
			}
			else if(FF2SJAbilFlags[client] & 2)
			{
				return true;
			}
		}
		return false;
	}
	//we can't do spin jumps during gctype 5 unless it's passive
	else if(GCType[client]==5)
	{
		if((FF2PRAbilFlags[client] & 16) && FF2PRButton[client]<0)
		{
			if(LastPush[client]+0.23<GetGameTime())
			{
				return true;
			}
			else
			{
				if(FF2SJAbilFlags[client] & 1)
				{
					return true;
				}
				else if(FF2SJAbilFlags[client] & 2)
				{
					return true;
				}
			}
			return false;
		}
	}
	return false;
}

DoJump(client, fakejump)
{
	if(fakejump)
	{
		new Float:jumpvel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", jumpvel);
		new Float:slopebonus = GetGameTime()-LastPush[client];
		if(slopebonus>0.2)
		{
			slopebonus=0.0;
		}
		else if(slopebonus<0.0)
		{
			slopebonus=0.0;
		}
		jumpvel[2]=289.0-(slopebonus*100.0);
		LastPush[client]-=0.23;
		jumpvel[2]*=GetJumpHeightMult(client);
		
		new Float:avgspeed = 0.0;
		if(jumpvel[0]>0.0)
		{
			avgspeed += jumpvel[0];
		}
		else
		{
			avgspeed += jumpvel[0]*-1.0;
		}
		if(jumpvel[1]>0.0)
		{
			avgspeed += jumpvel[1];
		}
		else
		{
			avgspeed += jumpvel[1]*-1.0;
		}
		avgspeed *= 0.5;
		if(avgspeed>520.0)
		{
			jumpvel[0]*=0.9;
			jumpvel[1]*=0.9;
		}
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, jumpvel);
	}
	if(FF2SJEnable[client])
	{
		if(CanJump(client))
		{
			NextSpinJump[client] = GetGameTime()+0.1;
			HideAllActors(client);
			Jumped[client]=true;
			if(strlen(ANMSJ[client])>0)
			{
				AnimateActor(client, ANMSJ[client], 4, ANMSJDur[client], true);
			}
			if(strlen(SNDSJEnter[client])>0)
			{
				EmitSoundToAll(SNDSJEnter[client], client);
			}
		}
	}
}

EndJump(client, bool:update)
{
	NextSpinJump[client] = GetGameTime()+0.1;
	Jumped[client]=false;
	if(ActorActive[client][4])
	{
		HideActor(client, 4);
		if(update)
		{
			UpdateAnim(client);
		}
	}
}

GetWearableShield(client)
{
	new i = -1; 
	while ((i = FindEntityByClassname(i, "tf_wearable_demoshield")) != -1)
	{ 
		if(IsValidEntity(i))
		{
			if(client == GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity"))
			{
				return i;
			}
		}
	}
	i = -1; 
	while ((i = FindEntityByClassname(i, "tf_wearable_razorback")) != -1)
	{
		if(IsValidEntity(i))
		{
			if(client == GetEntPropEnt(i, Prop_Send, "m_hOwnerEntity"))
			{
				return i;
			}
		}
	}
	return -1;
}

//dhooks speed cap breaking stuff below here
public MRESReturn CTFGameMovement_ProcessMovement(Handle hParams)
{
	DHookSetParamObjectPtrVar(hParams, 2, 60, ObjectValueType_Float, SpeedLimit);
	return MRES_ChangedHandled;
}

// Modified from Pelipoika
void MemoryPatch(const char[] patch, Handle &hConf, int[] PatchBytes, int iCount)
{
	Address iAddr = GameConfGetAddress(hConf, patch);
	if(iAddr == Address_Null)
	{
		LogError("Can't find %s address.", patch);
		return;
	}
	
	for (int i = 0; i < iCount; i++)
	{
		//int instruction = LoadFromAddress(iAddr + view_as<Address>(i), NumberType_Int8);
		//PrintToServer("%s 0x%x %i", patch, instruction, instruction);
		
		StoreToAddress(iAddr + view_as<Address>(i), PatchBytes[i], NumberType_Int8);
	}
}