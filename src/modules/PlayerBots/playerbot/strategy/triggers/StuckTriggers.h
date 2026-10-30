#pragma once
#include "playerbot/strategy/Trigger.h"
#include "playerbot/PlayerbotAIConfig.h"
#include <Maps/MoveMap.h>

#include "playerbot/BotSlots.h"
namespace ai
{
    template< typename... Args >
    std::string string_sprintf(const char* format, Args... args) {
        int length = std::snprintf(nullptr, 0, format, args...);
        assert(length >= 0);

        char* buf = new char[length + 1];
        std::snprintf(buf, length + 1, format, args...);

        std::string str(buf);
        delete[] buf;
        return str;
    }

    class MoveStuckTrigger : public Trigger
    {
    public:
        MoveStuckTrigger(PlayerbotAI* ai) : Trigger(ai, "move stuck", 5) {}

        virtual bool IsActive() override
        {
            if (ai->HasActivePlayerMaster())
                return false;

            if (ai->GetGroupMaster() && !GetBotAI(ai->GetGroupMaster()))
                return false;

            if (!ai->AllowActivity(ALL_ACTIVITY))
            {
                RESET_AI_VALUE(WorldPosition, "current position");
                return false;
            }

            WorldPosition botPos(bot);

            uint32 timeSinceLastMove = AI_VALUE2(uint32, "time since last change", "current position");

            if(timeSinceLastMove > 5 * MINUTE)
            {
                ai->TellDebug(ai->GetMaster(), "Stuck: Position did not change for " + std::to_string(timeSinceLastMove) + " seconds.", "debug stuck");

                return true;
            }

            uint32 distanceMoved = AI_VALUE2(uint32, "distance moved since", 10 * MINUTE);

            if (distanceMoved > 0 && distanceMoved < 50.0f)
            {
                ai->TellDebug(ai->GetMaster(), "Stuck: Only moved " + std::to_string(distanceMoved) + " yards in the last 10 minutes.", "debug stuck");

                return true;
            }

            return false;
        }
    };

    class MoveLongStuckTrigger : public Trigger
    {
    public:
        MoveLongStuckTrigger(PlayerbotAI* ai) : Trigger(ai, "move long stuck", 5) {}

        virtual bool IsActive() override
        {
            if (ai->HasActivePlayerMaster())
                return false;

            if (ai->GetGroupMaster() && !GetBotAI(ai->GetGroupMaster()))
                return false;

            if (!ai->AllowActivity(ALL_ACTIVITY))
            {
                RESET_AI_VALUE(WorldPosition, "current position");
                RESET_AI_VALUE(uint32, "experience");
                return false;
            }

            WorldPosition botPos(bot);

            // Penqle has no GetCurrentCell; use the bot's WorldPosition instead.
            Cell cell{}; (void)cell;

            GridPair grid = botPos.getGridPair();

            if (grid.x_coord < 0 || grid.x_coord >= MAX_NUMBER_OF_GRIDS)
            {
                ai->TellDebug(ai->GetMaster(), "Stuck: In invalid grid" + std::to_string(grid.x_coord) + "," + std::to_string(grid.y_coord), "debug stuck");

                return true;
            }

            if (grid.y_coord < 0 || grid.y_coord >= MAX_NUMBER_OF_GRIDS)
            {
                ai->TellDebug(ai->GetMaster(), "Stuck: In invalid grid" + std::to_string(grid.x_coord) + "," + std::to_string(grid.y_coord), "debug stuck");

                return true;
            }

#ifdef MANGOSBOT_TWO
            if (cell.GridX() > 0 && cell.GridY() > 0 && !MMAP::MMapFactory::createOrGetMMapManager()->IsMMapTileLoaded(botPos.getMapId(), 0, cell.GridX(), cell.GridY()) && !MMAP::MMapFactory::createOrGetMMapManager()->loadMap(botPos.getMapId(), 0, cell.GridX(), cell.GridY(), 0))
            {
                ai->TellDebug(ai->GetMaster(), "Stuck: In unloaded grid" + std::to_string(grid.x_coord) + "," + std::to_string(grid.y_coord), "debug stuck");

                return true;
            }
#else
            if (cell.GridX() > 0 && cell.GridY() > 0
                && !MMAP::MMapFactory::createOrGetMMapManager()->GetNavMesh(botPos.getMapId())
                && !MMAP::MMapFactory::createOrGetMMapManager()->loadMap(botPos.getMapId(), cell.GridX(), cell.GridY()))
            {
                ai->TellDebug(ai->GetMaster(), "Stuck: In unloaded grid" + std::to_string(grid.x_coord) + "," + std::to_string(grid.y_coord), "debug stuck");

                return true;
            }
#endif

            uint32 timeSinceLastMove = AI_VALUE2(uint32, "time since last change", "current position");

            if (timeSinceLastMove > 10 * MINUTE)
            {
                ai->TellDebug(ai->GetMaster(), "Stuck: Position did not change for " + std::to_string(timeSinceLastMove) + " seconds.", "debug stuck");

                return true;
            }

            uint32 timeSinceLastXp = AI_VALUE2(uint32, "time since last change", "experience");

            if (timeSinceLastXp < 15 * MINUTE)
                return false;

            uint32 distanceMoved = AI_VALUE2(uint32, "distance moved since", 15 * MINUTE);

            if (distanceMoved > 0 && distanceMoved < 50.0f)
            {
                ai->TellDebug(ai->GetMaster(), "Stuck: Only moved " + std::to_string(distanceMoved) + " yards in the last 10 minutes.", "debug stuck");

                return true;
            }

            return false;
        }
    };

    // Both combat stuck triggers below measure how long the core's own combat flag has
    // held the same value, and that clock is deliberately not restarted when the unstuck
    // action resets the bot - the fifteen minute escalation needs to keep counting
    // through the five minute reset, so restarting it there would make the long trigger
    // unreachable. The consequence is that once the threshold is passed the condition
    // stays true for the whole rest of the episode, and at a five second check interval
    // that fired 209584 times in a single 22 hour run: the same futile reset over and
    // over, each one wiping the current target and the loot target it was about to use.
    // Report each episode once instead. The clock's own start time names the episode, so
    // remember which one was reported and wait for the clock to actually move on.
    class CombatStuckTriggerBase : public Trigger
    {
    public:
        CombatStuckTriggerBase(PlayerbotAI* ai, std::string name) : Trigger(ai, name, 5) {}

    protected:
        // The gates both triggers share, so a bot that is not fighting on its own behalf
        // is never reported as stuck in combat.
        bool IsUnsupervisedBotInCombat()
        {
            if (ai->GetState() != BotState::BOT_STATE_COMBAT)
                return false;

            if (ai->HasActivePlayerMaster())
                return false;

            if (ai->GetGroupMaster() && !GetBotAI(ai->GetGroupMaster()))
                return false;

            return ai->AllowActivity(ALL_ACTIVITY);
        }

        bool FireOnceForEpisode(uint32 timeSinceCombatChange)
        {
            // The delay was measured against a clock read inside the value and this one
            // is read after it, so the derived start time can come out a second early
            // when a second boundary falls between the two reads. A second of tolerance
            // covers that; a genuinely new episode is minutes away from the last one.
            time_t const episode = time(0) - timeSinceCombatChange;
            if (episode >= firedForEpisode - 1 && episode <= firedForEpisode + 1)
                return false;

            firedForEpisode = episode;
            return true;
        }

        // The bot has been dueling for longer than any duel it is going to win. Written
        // as now minus the start: the operands used to be the other way round, which for
        // a start time already in the past is always negative, so this never once fired.
        bool IsInEndlessDuel() const
        {
            return bot->m_duel && (time(0) - bot->m_duel->startTime) > 15 * MINUTE;
        }

        std::string DuelLengthText() const
        {
            return std::to_string(time(0) - bot->m_duel->startTime);
        }

    private:
        time_t firedForEpisode = 0;
    };

    class CombatStuckTrigger : public CombatStuckTriggerBase
    {
    public:
        CombatStuckTrigger(PlayerbotAI* ai) : CombatStuckTriggerBase(ai, "combat stuck") {}

        virtual bool IsActive() override
        {
            if (!IsUnsupervisedBotInCombat())
                return false;

            uint32 timeSinceCombatChange = AI_VALUE2(uint32, "time since last change", "combat::self target");
           
            if (timeSinceCombatChange > 5 * MINUTE && FireOnceForEpisode(timeSinceCombatChange))
            {
                ai->TellDebug(ai->GetMaster(), "Stuck: Combat did not change for " + std::to_string(timeSinceCombatChange) + " seconds.", "debug stuck");

                return true;
            }

            if (IsInEndlessDuel())
            {
                ai->TellDebug(ai->GetMaster(), "Stuck: In Duel for " + DuelLengthText() + " seconds.", "debug stuck");

                return true;
            }

            return false;
        }
    };

    // From cmangos/playerbots 6823423e: in combat, standing still, and neither the bot's health
    // nor any attacker's has changed for motionlessGiveUpSec - a stand-off nobody is fighting.
    class CombatStandoffTrigger : public Trigger
    {
    public:
        CombatStandoffTrigger(PlayerbotAI* ai) : Trigger(ai, "combat standoff", 5) {}

        virtual bool IsActive() override
        {
            if (ai->GetState() != BotState::BOT_STATE_COMBAT || ai->HasActivePlayerMaster() ||
                (ai->GetGroupMaster() && !GetBotAI(ai->GetGroupMaster())) || !ai->AllowActivity(ALL_ACTIVITY) ||
                bot->IsMoving())
            {
                lastSignature = 0;
                lastChange = time(0);
                return false;
            }

            std::list<ObjectGuid> const attackers = AI_VALUE(std::list<ObjectGuid>, "attackers");
            uint32 signature = (uint32)bot->GetHealthPercent() * 1000;
            uint32 counted = 0;
            for (ObjectGuid const& guid : attackers)
            {
                if (counted >= 10)
                    break;

                Unit* attacker = ai->GetUnit(guid);
                if (!attacker || !attacker->IsAlive())
                    continue;

                signature += (uint32)(attacker->GetHealthPercent() * 7.0f);
                counted++;
            }

            time_t const now = time(0);
            if (!counted)
            {
                lastSignature = 0;
                lastChange = now;
                return false;
            }

            // The signature carries an offset so a real one never equals the reset value.
            signature += 1;
            if (signature != lastSignature)
            {
                lastSignature = signature;
                lastChange = now;
                return false;
            }

            return (now - lastChange) >= sPlayerbotAIConfig.motionlessGiveUpSec;
        }

    private:
        uint32 lastSignature = 0;
        time_t lastChange = time(0);
    };

    // From cmangos/playerbots 6823423e: Engine::TrackLoop saw the same movement action run for
    // motionlessGiveUpSec without the bot moving, losing health or changing target.
    class MovementLoopStuckTrigger : public Trigger
    {
    public:
        MovementLoopStuckTrigger(PlayerbotAI* ai) : Trigger(ai, "movement loop stuck", 5) {}

        virtual bool IsActive() override
        {
            if (ai->HasActivePlayerMaster() || (ai->GetGroupMaster() && !GetBotAI(ai->GetGroupMaster())) || !ai->AllowActivity(ALL_ACTIVITY))
                return false;

            return AI_VALUE(int, "movement loop age") >= (int)sPlayerbotAIConfig.motionlessGiveUpSec;
        }
    };

    class CombatLongStuckTrigger : public CombatStuckTriggerBase
    {
    public:
        CombatLongStuckTrigger(PlayerbotAI* ai) : CombatStuckTriggerBase(ai, "combat long stuck") {}

        virtual bool IsActive() override
        {
            if (!IsUnsupervisedBotInCombat())
                return false;

            uint32 timeSinceCombatChange = AI_VALUE2(uint32, "time since last change", "combat::self target");

            if (timeSinceCombatChange > 15 * MINUTE && FireOnceForEpisode(timeSinceCombatChange))
            {
                ai->TellDebug(ai->GetMaster(), "Stuck: Combat did not change for " + std::to_string(timeSinceCombatChange) + " seconds.", "debug stuck");

                return true;
            }

            if (IsInEndlessDuel())
            {
                ai->TellDebug(ai->GetMaster(), "Stuck: In Duel for " + DuelLengthText() + " seconds.", "debug stuck");

                return true;
            }

            return false;
        }
    };

    class LeaderIsAfkTrigger : public Trigger
    {
    public:
        LeaderIsAfkTrigger(PlayerbotAI* ai) : Trigger(ai, "leader is afk", 10) {}

        virtual bool IsActive() override
        {
            if (ai->HasRealPlayerMaster())
                return false;

            if (Group* group = bot->GetGroup())
            {
                Player* leader = sObjectMgr.GetPlayer(group->GetLeaderGuid());
                if (!leader)
                    return false;

                return leader->IsAFK();
            }

            return false;
        }
    };
}
