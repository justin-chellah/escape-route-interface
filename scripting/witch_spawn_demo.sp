#include <sourcemod>
#include <sdktools>

#define GAMEDATA_FILE   "witch_spawn_demo"

#include <witch_spawn_demo>

#define REQUIRE_PLUGIN
#include <escape_route_interface>
#include <navmesh_lib>

#define TEAM_ANY            -1
#define TEAM_UNASSIGNED     0
#define TEAM_SPECTATOR      1
#define TEAM_SURVIVOR       2
#define	TEAM_INFECTED       3
#define TEAM_SCRIPTEDAI     4   // Left 4 Dead 1 bots

Handle g_hSDKCall_SearchSurroundingAreas_RemoveWanderersScan = null;
ConVar director_threat_clear_radius = null;

void SearchSurroundingAreas_RemoveWanderersScan( CNavArea adrArea, const float flVecPos[3], float flRadius, int fFlags = 0, int iTeam = TEAM_ANY )
{
    SDKCall( g_hSDKCall_SearchSurroundingAreas_RemoveWanderersScan, adrArea, flVecPos, Address_Null/* unused */, flRadius, fFlags, iTeam );
}

void SpawnWitch()
{
    // Only include survivors, but filter out those who are at the exit checkpoint
    int iTeam = TEAM_SURVIVOR;
    FlowDistanceFilter efFlags = FlowDistanceFilter_ExitCheckpoint;
    TerrorNavAreaFlowType eFlowType = TerrorNavAreaFlow_TowardGoal;

    float flHighestFlowDist = GetHighestFlowDistance( iTeam, _, _, efFlags, eFlowType );

    // How far do we want to offset the witch spawn from where the player is currently along the flow?
    float flFlowDistBuffer = 1600.0;

    float flFlowPercent = FloatAbs( ( flHighestFlowDist + flFlowDistBuffer ) / TerrorNavMesh.GetMaxFlowDistance() );
    float vecPos[3];
    CEscapeRoute.GetPositionOnPath( flFlowPercent, vecPos );

    TerrorNavArea adrArea = view_as< TerrorNavArea >( CNavMesh.GetNavArea( vecPos ) );
    if ( adrArea )
    {
        for ( CNavArea.MakeNewMarker(); !adrArea.IsMarked(); adrArea = adrArea.GetNextEscapeStep() )
        {
            // Useful to detour and include custom rules here so that the game also respects them
            if ( adrArea.IsValidForWanderingPopulation() )
            {
                // We're afraid of water
                if ( !adrArea.IsUnderwater() )
                {
                    float flVecCenter[3];
                    adrArea.GetCenter( flVecCenter );
                    flVecCenter[2] += 10.0;
                    if ( ZombieManager.IsSpaceForZombieHere( flVecCenter ) && !adrArea.m_fPotentiallyVisibleToSurvivorFlags/* spawn them out of player sight */ )
                    {
                        bool bSpawned = ZombieManager.SpawnWitch( adrArea, { 0.0, 0.0, 0.0 }/* we don't care; it's just a demo */, false/* spawn them right in the center */ );
                        if ( bSpawned )
                        {
                            SearchSurroundingAreas_RemoveWanderersScan( adrArea, flVecCenter, director_threat_clear_radius.FloatValue );
                        }

                        break;
                    }
                }
            }

            adrArea.Mark();
        }
    }
}

// https://www.unknowncheats.me/forum/general-programming-and-reversing/375888-address-direct-reference.html
Address GetFunctionAddressFromRelativeCall( Address adr )
{
    Address adrRelativeCall = LoadFromAddress( adr, NumberType_Int32 );
    Address adrFunction = adr + view_as< Address >( 4 )/* sizeof( int ) */ + adrRelativeCall;
    return adrFunction;
}

public Action Command_SpawnWitch( int iClient, int nArgs )
{
    SpawnWitch();
    return Plugin_Handled;
}

public void OnPluginStart()
{
    GameData hGameData = new GameData( GAMEDATA_FILE );
    if ( hGameData == null )
    {
        SetFailState( "Unable to load gamedata file \"" ... GAMEDATA_FILE ... "\"" );
    }

#define GET_ADDRESS_WRAPPER(%0,%1)\
    %1 = hGameData.GetAddress(%0);\
    if (%1 == Address_Null)\
    {\
        delete hGameData;\
        SetFailState("Unable to find gamedata address entry or signature in binary for \"" ... %0 ... "\"");\
    }

    GET_ADDRESS_WRAPPER( "ZombieManager instance", TheZombieManager )

    Address adrSpawnWitchRelCall;
    GET_ADDRESS_WRAPPER( "ZombieManager::SpawnWitch relative call", adrSpawnWitchRelCall )

    Address adrRemoveWanderersRelCall;
    GET_ADDRESS_WRAPPER( "SearchSurroundingAreas<RemoveWanderersScan> relative call", adrRemoveWanderersRelCall )

    Address adrFnSpawnWitch = GetFunctionAddressFromRelativeCall( adrSpawnWitchRelCall )
    Address adrFnRemoveWanderers = GetFunctionAddressFromRelativeCall( adrRemoveWanderersRelCall )

#define PREP_SDKCALL_SET_FROM_CONF_WRAPPER(%0)\
    if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, %0)) \
    {\
        delete hGameData;\
        SetFailState("Unable to find gamedata signature entry or signature in binary for \"" ... %0 ... "\"");\
    }

    StartPrepSDKCall( SDKCall_Raw );
    PREP_SDKCALL_SET_FROM_CONF_WRAPPER( "ZombieManager::IsSpaceForZombieHere" )
    PrepSDKCall_SetReturnInfo( SDKType_Bool, SDKPass_Plain );
    PrepSDKCall_AddParameter( SDKType_Vector, SDKPass_ByRef );          // const Vector &pos
    g_hSDKCall_ZombieManager_IsSpaceForZombieHere = EndPrepSDKCall();

    StartPrepSDKCall( SDKCall_Raw );
    PrepSDKCall_SetAddress( adrFnSpawnWitch );
    PrepSDKCall_SetReturnInfo( SDKType_Bool, SDKPass_Plain );
    PrepSDKCall_AddParameter( SDKType_PlainOldData, SDKPass_Plain );    // const TerrorNavArea *area
    PrepSDKCall_AddParameter( SDKType_QAngle, SDKPass_ByRef );          // const QAngle& angles
    PrepSDKCall_AddParameter( SDKType_Bool, SDKPass_Plain );            // bool bRandomSpot
    g_hSDKCall_ZombieManager_SpawnWitch = EndPrepSDKCall();

    StartPrepSDKCall( SDKCall_Static );
    PrepSDKCall_SetAddress( adrFnRemoveWanderers );
    PrepSDKCall_AddParameter( SDKType_PlainOldData, SDKPass_Plain );            // CNavArea *area
    PrepSDKCall_AddParameter( SDKType_QAngle, SDKPass_ByRef );                  // const Vector& pos
    PrepSDKCall_AddParameter( SDKType_PlainOldData, SDKPass_Plain );            // RemoveWanderersScan &scan
    PrepSDKCall_AddParameter( SDKType_Float, SDKPass_Plain );                   // float radius
    PrepSDKCall_AddParameter( SDKType_PlainOldData, SDKPass_Plain );            // unsigned int flags
    PrepSDKCall_AddParameter( SDKType_PlainOldData, SDKPass_Plain );            // int team
    g_hSDKCall_SearchSurroundingAreas_RemoveWanderersScan = EndPrepSDKCall();

    delete hGameData;

    director_threat_clear_radius = FindConVar( "director_threat_clear_radius" );

    RegConsoleCmd( "sm_spawnwitch", Command_SpawnWitch );
}

public Plugin myinfo =
{
    name = "[L4D2] Witch Spawn Demo",
    author = "Justin \"Sir Jay\" Chellah",
    description = "Spawns a witch along the survivors' escape route, out of sight",
    version = "1.0.0",
    url = "https://www.justin-chellah.com"
};