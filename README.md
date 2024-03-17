# [L4D2] Escape Route Interface
This is a very useful SourceMod plugin that allows developers to access the Escape Route entity and, for example, spawn specific items or infected along the survivors' escape route. If you've ever wanted to spawn Special Infected on the Survivor Path as the game does, then this is the tool.

You'll need to download the [NavMesh Library](https://github.com/justin-chellah/navmesh-lib) as well because this whole system is built upon the NavMesh.

There's a [plugin that demonstrates this system](https://github.com/justin-chellah/escape-route-interface/tree/main/scripting/witch_spawn_demo.sp) by spawning a witch on the escape route. I encourage you to check out the code to get an idea of how something like this works in Left 4 Dead.

# API
```
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
```

# Example Code
This piece of code was taken from the `CDirectorVersusMode::UpdateVersusBossSpawning()` function:

```
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
```

# Requirements
- [SourceMod 1.11+](https://www.sourcemod.net/downloads.php?branch=stable)
- [SourceScramble](https://github.com/nosoop/SMExt-SourceScramble)

# Docs
- [L4D Level Design/Nav Flow](https://developer.valvesoftware.com/wiki/L4D_Level_Design/Nav_Flow)
- [Development of Left 4 Dead by Mike Booth GDC Lecture](https://youtu.be/PJNQl3K58CQ?t=2420)

# Supported Platforms
- Windows
- Linux

# Supported Games
- Left 4 Dead 2