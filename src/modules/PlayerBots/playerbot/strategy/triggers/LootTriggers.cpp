
#include "playerbot/playerbot.h"
#include "LootTriggers.h"
#include "playerbot/LootObjectStack.h"
#include "playerbot/PlayerbotAIConfig.h"

#include "playerbot/ServerFacade.h"
using namespace ai;

bool LootAvailableTrigger::IsActive()
{
    return AI_VALUE(bool, "has available loot") &&
            (
                    sServerFacade.IsDistanceLessOrEqualThan(AI_VALUE2(float, "distance", "loot target"), INTERACTION_DISTANCE) ||
                    AI_VALUE(std::list<ObjectGuid>, "all targets").empty()
            ) &&
            !AI_VALUE2(bool, "combat", "self target") &&
            !AI_VALUE2(bool, "mounted", "self target");
}

bool FarFromCurrentLootTrigger::IsActive()
{
    LootObject loot = AI_VALUE(LootObject, "loot target");

    if (!loot.IsLootPossible(bot))
        return false;

    // Abandon loot the bot cannot safely reach without breaking its follow leash.
    // "move to loot" runs at priority 7 but "out of free move range" fires "follow" at
    // ACTION_HIGH (20). A corpse is only reachable without oscillation if the master is
    // within followDistance + GetMaxLootDistance of it — otherwise the bot must leave the
    // leash to reach the corpse and follow immediately wins, causing a yo-yo.
    Player* master = ai->GetMaster();
    if (master && master != bot)
    {
        Creature* creature = ai->GetCreature(loot.guid);
        if (creature && sServerFacade.GetDeathState(creature) == CORPSE)
        {
            float safeRange = sPlayerbotAIConfig.followDistance + bot->GetMaxLootDistance(creature);
            if (sServerFacade.GetDistance2d(master, creature) > safeRange)
                return false;
        }
    }

    // Must agree with "can loot" and OpenLootAction::DoLoot, or the bot either sits short of
    // a target it cannot loot or keeps firing a loot action the server refuses.
    return !loot.IsInReach(bot);
}

bool CanLootTrigger::IsActive()
{
    return AI_VALUE(bool, "can loot");
}
