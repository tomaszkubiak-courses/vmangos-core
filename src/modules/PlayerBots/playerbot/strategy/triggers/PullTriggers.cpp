
#include "playerbot/playerbot.h"
#include "playerbot/strategy/Action.h"
#include "playerbot/strategy/generic/PullStrategy.h"
#include "PullTriggers.h"
#include "playerbot/strategy/values/PositionValue.h"
#include "playerbot/strategy/actions/PullActions.h"

using namespace ai;

bool PullStartTrigger::IsActive()
{
    const PullStrategy* strategy = PullStrategy::Get(ai);
    return strategy && strategy->IsPullPendingToStart();
}

bool ShouldPullTrigger::IsActive()
{
    // Dungeons only, deliberately. Outdoors a bot already has grinding and travel
    // behaviour that this would compete with, and a pull that goes wrong out there
    // only adds to the death numbers. Inside, somebody has to start the fight or
    // the group stands around until a real player does it.
    Map* map = bot->GetMap();
    if (!map || !map->IsDungeon())
        return false;

    if (!PlayerbotAI::IsTank(bot))
        return false;

    Group* group = bot->GetGroup();
    if (!group)
        return false;

    for (GroupReference* ref = group->GetFirstMember(); ref; ref = ref->next())
    {
        Player* member = ref->getSource();
        if (!member || !member->IsInWorld() || member->GetMapId() != bot->GetMapId())
            continue;

        // Never pull on top of a fight that is still running, and never onto a
        // corpse - somebody has to be raised first.
        if (member->IsInCombat() || !member->IsAlive())
            return false;

        // The healer decides the pace. Pulling with an empty healer is how a
        // group wipes on trash it could otherwise walk through.
        if (PlayerbotAI::IsHeal(member) && member->GetPowerType() == POWER_MANA)
        {
            const uint32 maxMana = member->GetMaxPower(POWER_MANA);
            if (maxMana && (100 * member->GetPower(POWER_MANA)) / maxMana < sPlayerbotAIConfig.mediumMana)
                return false;
        }
    }

    return PullNearestTargetAction::FindPullTarget(ai) != nullptr;
}

bool PullEndTrigger::IsActive()
{
    PullStrategy* strategy = PullStrategy::Get(ai);
    if (strategy && strategy->HasPullStarted())
    {
        Unit* target = strategy->GetTarget();
        if (target)
        {
            // A pull that has not gone off yet and can no longer be performed is
            // over now, not in fifteen seconds. PullMultiplier holds every other
            // action at zero relevance for as long as a pull target is set, so a
            // pull the bot cannot cast costs it the whole of its rotation and its
            // movement until the timeout below expires - and the next tick simply
            // requests the pull again. Once the pull action has actually gone off
            // the checks further down own the ending, so that the pull back
            // behaviour still gets to run.
            if (!strategy->HasPullBeenPerformed() && !strategy->CanDoPullAction(target))
            {
                return true;
            }

            // Check if the pull is taking too long
            const time_t secondsSincePullStarted = time(0) - strategy->GetPullStartTime();
            if (secondsSincePullStarted >= strategy->GetMaxPullTime())
            {
                return true;
            }
            else
            {
                float distanceToPullTarget = target->GetDistance(ai->GetBot());


                if (distanceToPullTarget <= ATTACK_DISTANCE || target->IsNonMeleeSpellCasted(true) || (ai->IsRanged(bot) && distanceToPullTarget <= ai->GetRange("spell")))
                {
                    if (ai->HasStrategy("pull back", BotState::BOT_STATE_COMBAT))
                    {
                        PositionMap& posMap = AI_VALUE(PositionMap&, "position");
                        PositionEntry pullPosition = posMap["pull"];
                        if (pullPosition.isSet())
                        {
                            distanceToPullTarget = bot->GetDistance(pullPosition.x, pullPosition.y, pullPosition.z);
                            return distanceToPullTarget <= ai->GetRange("follow");
                        }
                    }

                    // Check if the pulled target has approached the bot
                    return true;
                }
            }
        }
    }

    return false;
}
