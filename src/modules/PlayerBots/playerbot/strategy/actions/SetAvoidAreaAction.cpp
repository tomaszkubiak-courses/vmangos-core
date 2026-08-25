
#include "playerbot/playerbot.h"
#include "SetAvoidAreaAction.h"

#include "playerbot/strategy/values/PositionValue.h"
#include "Maps/PathFinder.h"
using namespace ai;


bool SetAvoidAreaAction::Execute(Event& event)
{
    // The navmesh area painting this used - PathFinder::setArea / getArea / setAreaCost -
    // is a cmangos extension to its pathfinder. This core's PathFinder (PathInfo) only
    // queries the mesh, so the avoid-area feature is not wired up here. See
    // doc/PLAYERBOT_PORT_SCOPE.md.
    return false;
}
