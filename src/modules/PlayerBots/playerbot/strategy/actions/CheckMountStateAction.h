#pragma once

#include "playerbot/strategy/Action.h"
#include "MovementActions.h"
#include "playerbot/strategy/values/LastMovementValue.h"
#include "UseItemAction.h"

namespace ai
{
    class CheckMountStateAction : public UseAction 
    {
    public:
        CheckMountStateAction(PlayerbotAI* ai) : UseAction(ai, "check mount state") {}

#ifdef GenerateBotHelp
        virtual std::string GetHelpName() { return "check mount state"; }
        virtual std::string GetHelpDescription()
        {
            return "This action automatically mouts up or unmounts a bot based on:\n"
                   "- Location (outdoors only, battleground restrictions)\n"
                   "- Combat status (dismounts when in combat)\n"
                   "- Travel distance (mounts for long distances)\n"
                   "- Group coordination (matches master's mount state)\n"
                   "- Level requirements (minimum level 20/30/40 depending on expansion)";
        }
        virtual std::vector<std::string> GetUsedActions() { return {}; }
        virtual std::vector<std::string> GetUsedValues() { return {"mount list", "current mount speed"}; }
#endif 

        virtual bool Execute(Event& event) override;
        virtual bool isPossible() override { return true; }
        virtual bool isUseful() override;

    private:
        virtual bool CanFly() const;
        bool CanMountInBg() const;
        float GetAttackDistance() const;

    private:
        bool Mount(Player* requester, bool limitSpeedToGroup = false);
        bool UnMount() const;

        // Backoff between mount attempts that did not land. See Mount().
        time_t m_nextMountAttempt = 0;
        uint32 m_mountBackoff = 0;

        // A cast that has started but has not been seen to land yet. The event log entry is
        // written when the bot is actually mounted, not when the cast begins.
        std::string m_pendingMountName;
        uint32 m_pendingMountSpeed = 0;
    };
}
