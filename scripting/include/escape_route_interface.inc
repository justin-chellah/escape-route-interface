#if defined _escape_route_interface_included
 #endinput
#endif
#define _escape_route_interface_included

#include <navmesh_lib>

enum FlowDistanceFilter
{
    FlowDistanceFilter_IncapPlayers         = 0x1,  // ignore incapacitated players
    FlowDistanceFilter_OnlyIncapPlayers     = 0x2,  // only consider non-incapacitated players
    FlowDistanceFilter_ExitCheckpoint       = 0x4,  // ignore players inside the exit checkpoint
    FlowDistanceFilter_Checkpoint           = 0x8,  // ignore players inside the checkpoint
}

methodmap CEscapeRoute
{
    /*
     * @param flFlowPercent     Player progress in percent along the flow as decimal (0.0 - 1.0)
     */
    public static native void GetPositionOnPath( float flFlowPercent, float flVecPosOut[3] );
};

/*
 * Returns the reference of the escape_route entity.
 */
native CEscapeRoute TheEscapeRoute();

/*
 * @param iTeam                     Team index (2 - 4).
 * @param nPlayerCount              (Optional) Total amount of players.
 * @param iHighestFlowPlayer        (Optional) Player who is furthest ahead according to flow distance.
 * @param fFlags                    Optional flags for filtering players.
 *
 * @return                          Flow distance, if applicable.
 */
native float GetHighestFlowDistance( int iTeam,
    int& nPlayerCount = 0,
    int& iHighestFlowPlayer = 0,
    FlowDistanceFilter eFlags = view_as< FlowDistanceFilter >( 0 ),
    TerrorNavAreaFlowType eFlowType = TerrorNavAreaFlow_TowardGoal );

public SharedPlugin __pl_escape_route_interface =
{
    name = "escape_route_interface",
    file = "escape_route_interface.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_escape_route_interface_SetNTVOptional()
{
    MarkNativeAsOptional( "CEscapeRoute.GetPositionOnPath" );
    MarkNativeAsOptional( "TheEscapeRoute" );
    MarkNativeAsOptional( "GetHighestFlowDistance" );
}
#endif