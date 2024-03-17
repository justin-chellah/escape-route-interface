#include <sourcemod>
#include <sdktools>

#define GAMEDATA_FILE   "escape_route_interface"

#define REQUIRE_EXTENSIONS
#include <sourcescramble>

#define TEAM_ANY            -1
#define TEAM_UNASSIGNED     0
#define TEAM_SPECTATOR      1
#define TEAM_SURVIVOR       2
#define	TEAM_INFECTED       3
#define TEAM_SCRIPTEDAI     4   // Left 4 Dead 1 bots

Handle g_hSDKCall_CEscapeRoute_GetPositionOnPath = null;
Handle g_hSDKCall_ForEachTerrorPlayer_HighestFlowDistance = null;
Handle g_hSDKCall_CBaseEntity_GetRefEHandle = null;

// CEscapeRoute instance
Address g_adrSpawnPath = Address_Null;

public int Native_CEscapeRoute_GetPositionOnPath( Handle hPlugin, int nParams )
{
    float flFlowDistance = GetNativeCell( 1 );
    float vecPosOut[3];
    SDKCall( g_hSDKCall_CEscapeRoute_GetPositionOnPath, g_adrSpawnPath, flFlowDistance, vecPosOut );
    SetNativeArray( 2, vecPosOut, sizeof( vecPosOut ) );
    return 1;
}

public any Native_TheEscapeRoute( Handle hPlugin, int nParams )
{
    return g_adrSpawnPath;
}

public any Native_GetHighestFlowDistance( Handle hPlugin, int nParams )
{
    int iTeam = GetNativeCell( 1 );
    if ( iTeam <= TEAM_UNASSIGNED || iTeam > TEAM_SCRIPTEDAI )  // TODO: does TEAM_SCRIPTEDAI check make sense?
    {
        return ThrowNativeError( SP_ERROR_INDEX, "Team index %d is invalid", iTeam );
    }

    int fFlags = GetNativeCell( 4 );
    int eFlowType = GetNativeCell( 5 );

    // struct HighestFlowDistance
    // {
    //     /* 0 */ float m_flFlowDistance;
    //     /* 4 */ int m_iTeam;
    //     /* 8 */ int m_iPlayerCount;
    //     /* 12 */ CTerrorPlayer *m_iHighestFlowPlayer;
    //     /* 16 */ int m_fFilterFlags;
    //     /* 20 */ TerrorNavArea::FlowType m_flowType;
    // }

    MemoryBlock hBlock = new MemoryBlock( 0x18 );
    hBlock.StoreToOffset( 0,        -9999,      NumberType_Int32 );
    hBlock.StoreToOffset( 4,        iTeam,      NumberType_Int32 );
    hBlock.StoreToOffset( 8,        0,          NumberType_Int32 );
    hBlock.StoreToOffset( 12,       0,          NumberType_Int32 );
    hBlock.StoreToOffset( 16,       fFlags,     NumberType_Int32 );
    hBlock.StoreToOffset( 20,       eFlowType,  NumberType_Int32 );

    SDKCall( g_hSDKCall_ForEachTerrorPlayer_HighestFlowDistance, hBlock.Address );

    int nPlayerCount = hBlock.LoadFromOffset( 8, NumberType_Int32 );
    SetNativeCellRef( 2, nPlayerCount );

    Address adrHighestFlowPlayer = view_as< Address >( hBlock.LoadFromOffset( 12, NumberType_Int32 ) );
    if ( adrHighestFlowPlayer )
    {
        Address adrRefEHandle = SDKCall( g_hSDKCall_CBaseEntity_GetRefEHandle, adrHighestFlowPlayer );
        int iClient = EntRefToEntIndex( LoadFromAddress( adrRefEHandle, NumberType_Int32 ) | ( 1 << 31 ) );
        SetNativeCellRef( 3, iClient );
    }
    else
    {
        SetNativeCellRef( 3, INVALID_ENT_REFERENCE );
    }

    float flFlowDistance = view_as< float >( hBlock.LoadFromOffset( 0, NumberType_Int32 ) );
    return flFlowDistance;
}

// https://www.unknowncheats.me/forum/general-programming-and-reversing/375888-address-direct-reference.html
Address GetFunctionAddressFromRelativeCall( Address adr )
{
    Address adrRelativeCall = LoadFromAddress( adr, NumberType_Int32 );
    Address adrFunction = adr + view_as< Address >( 4 )/* sizeof( int ) */ + adrRelativeCall;
    return adrFunction;
}

public void OnEntityDestroyed( int iEntity )
{
    char szClassname[32];
    GetEntityClassname( iEntity, szClassname, sizeof( szClassname ) );

    if ( StrEqual( szClassname, "escape_route" ) )
    {
        g_adrSpawnPath = Address_Null;
    }
}

public void OnEntityCreated( int iEntity, const char[] szClassname )
{
    if ( StrEqual( szClassname, "escape_route" ) )
    {
        g_adrSpawnPath = GetEntityAddress( iEntity );
    }
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

#define PREP_SDKCALL_SET_FROM_CONF_SIGNATURE_WRAPPER(%0)\
    if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, %0)) \
    {\
        delete hGameData;\
        SetFailState("Unable to find gamedata signature entry or signature in binary for \"" ... %0 ... "\"");\
    }

    StartPrepSDKCall( SDKCall_Raw );
    PREP_SDKCALL_SET_FROM_CONF_SIGNATURE_WRAPPER( "CEscapeRoute::GetPositionOnPath" )
    PrepSDKCall_AddParameter( SDKType_Float, SDKPass_Plain );                                   // float flFlowDistance
    PrepSDKCall_AddParameter( SDKType_Vector, SDKPass_Pointer, _, VENCODE_FLAG_COPYBACK );      // Vector *pPosOut
    g_hSDKCall_CEscapeRoute_GetPositionOnPath = EndPrepSDKCall();

    Address adrRelCall;
    GET_ADDRESS_WRAPPER( "ForEachTerrorPlayer<HighestFlowDistance> relative call", adrRelCall )

    // Using this function saves the amount of game data we need as it provides some great options for filtering players
    StartPrepSDKCall( SDKCall_Static );
    PrepSDKCall_SetAddress( GetFunctionAddressFromRelativeCall( adrRelCall ) );
    PrepSDKCall_SetReturnInfo( SDKType_Bool, SDKPass_Plain );
    PrepSDKCall_AddParameter( SDKType_PlainOldData, SDKPass_Plain );                // HighestFlowDistance &
    g_hSDKCall_ForEachTerrorPlayer_HighestFlowDistance = EndPrepSDKCall();

#define PREP_SDKCALL_SET_FROM_CONF_VIRTUAL_WRAPPER(%0)\
    if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, %0)) \
    {\
        delete hGameData;\
        SetFailState("Unable to find gamedata offset entry for \"" ... %0 ... "\"");\
    }

    StartPrepSDKCall( SDKCall_Raw );
    PREP_SDKCALL_SET_FROM_CONF_VIRTUAL_WRAPPER( "CBaseEntity::GetRefEHandle" )
    PrepSDKCall_SetReturnInfo( SDKType_PlainOldData, SDKPass_Plain );
    g_hSDKCall_CBaseEntity_GetRefEHandle = EndPrepSDKCall();

    delete hGameData;

    int iEntity = FindEntityByClassname( INVALID_ENT_REFERENCE, "escape_route" );
    if ( iEntity != INVALID_ENT_REFERENCE )
    {
        g_adrSpawnPath = GetEntityAddress( iEntity );
    }
}

public APLRes AskPluginLoad2( Handle hMyself, bool bLate, char[] szError, int nErrMax )
{
    RegPluginLibrary( "escape_route_interface" );
    CreateNative( "CEscapeRoute.GetPositionOnPath", Native_CEscapeRoute_GetPositionOnPath );
    CreateNative( "TheEscapeRoute", Native_TheEscapeRoute );
    CreateNative( "GetHighestFlowDistance", Native_GetHighestFlowDistance );
    return APLRes_Success;
}

public Plugin myinfo =
{
    name = "[L4D2] CEscapeRoute Interface",
    author = "Justin \"Sir Jay\" Chellah",
    description = "Allows developers to take advantage of features that allow them to do things with the escape route of the Survivors",
    version = "1.0.0",
    url = "https://www.justin-chellah.com"
};