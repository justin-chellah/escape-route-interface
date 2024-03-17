#if defined _witch_spawn_demo_included
 #endinput
#endif
#define _witch_spawn_demo_included

#include <navmesh_lib>

Address TheZombieManager = Address_Null;

Handle g_hSDKCall_ZombieManager_IsSpaceForZombieHere = null;
Handle g_hSDKCall_ZombieManager_SpawnWitch = null;

methodmap ZombieManager
{
    public static bool IsSpaceForZombieHere( const float flVecPos[3] )
    {
        return SDKCall( g_hSDKCall_ZombieManager_IsSpaceForZombieHere, TheZombieManager, flVecPos );
    }

    public static bool SpawnWitch( const TerrorNavArea adrArea, const float flVecAngles[3], bool bRandomSpot )
    {
        return SDKCall( g_hSDKCall_ZombieManager_SpawnWitch, TheZombieManager, adrArea, flVecAngles, bRandomSpot );
    }
}