#pragma once
#include "playerbot/strategy/Value.h"
#include "playerbot/TravelNode.h"

// Declared in MovementActions.h, which includes this header the other way
// around - a scoped enum with fixed underlying type forward-declares cleanly,
// and the Set() parameter below only passes it through.
enum class MovementPriority : uint8;

namespace ai
{
    class LastMovement
    {
    public:
        LastMovement()
        {
            clear();
        }

        LastMovement(LastMovement& other)
        {
            taxiNodes = other.taxiNodes;
            taxiMaster = other.taxiMaster;
            lastFollow = other.lastFollow;
            lastAreaTrigger = other.lastAreaTrigger;
            lastTransportEntry = other.lastTransportEntry;
            lastPath = other.lastPath;
            lastMoveShort = other.lastMoveShort;
            nextTeleport = other.nextTeleport;
            pathCollapseCount = other.pathCollapseCount;
            taxiFailEntry = other.taxiFailEntry;
            taxiFailCount = other.taxiFailCount;
            fleeCount = other.fleeCount;
            lastFleeAttempt = other.lastFleeAttempt;
            moveEvent = Event();
        }

        void clear()
        {
            lastPath.clear();
            lastFollow = NULL;
            lastAreaTrigger = 0;
            lastTransportEntry = 0;
            lastFlee = 0;
            fleeCount = 0;
            lastFleeAttempt = 0;
            lastMoveShort = WorldPosition();
            nextTeleport = 0;
            pathCollapseCount = 0;
            taxiFailEntry = 0;
            taxiFailCount = 0;
            moveEvent = Event();
        }

        void Set(Unit* lastFollow)
        {
            setPath(TravelPath());
            this->lastFollow = lastFollow;
        }

        void setPath(TravelPath path) { lastPath = path; }

        // Ported dungeon-clear movement records where it sent the bot and for
        // how long, and zeroes the wait to unblock the next order. This tree
        // never read such a wait (IsWaitingForLastMove answers false, see
        // MovementActions.h), so the field is bookkeeping the porting code
        // maintains for its own log lines - kept faithful, not load-bearing.
        void Set(uint32 mapId, float x, float y, float z, float o, float delay, MovementPriority /*priority*/)
        {
            lastMoveShort = WorldPosition(mapId, x, y, z, o);
            lastdelayTime = delay;
        }
        float lastdelayTime = 0.0f;
    public:
        std::vector<uint32> taxiNodes;
        ObjectGuid taxiMaster;
        Unit* lastFollow;
        uint32 lastAreaTrigger;
        uint32 lastTransportEntry;
        time_t lastFlee;
        // Number of flee actions dispatched in quick succession (within returnDelay of each
        // other). Used to detect a "subsequent" flee loop so spellcasting can take priority.
        uint32 fleeCount;
        // Wall-clock of the last dispatched flee, used to decide whether the next flee is
        // "subsequent" (close in time) or a fresh flee (window lapsed -> count resets).
        time_t lastFleeAttempt;
        TravelPath lastPath;
        WorldPosition lastMoveShort;
        time_t nextTeleport;
        // How many times in a row TravelPath::makeShortCut has thrown the freshly built path
        // away. One collapse is normal and the next tick rebuilds; a run of them means the
        // destination cannot be reached from where the bot is standing, and MoveTo2 has to
        // say so instead of reporting success it did not achieve. See MoveTo2.
        uint32 pathCollapseCount;
        // Which flight path leg MinimalMove last failed to board, and how many times running.
        // Counted per leg so a retry budget on one leg does not carry over to the next.
        uint32 taxiFailEntry;
        uint32 taxiFailCount;
        Event moveEvent;
    };

    class LastMovementValue : public ManualSetValue<LastMovement&>
    {
    public:
        LastMovementValue(PlayerbotAI* ai) : ManualSetValue<LastMovement&>(ai, data) {}
    private:
        LastMovement data = LastMovement();
    };

    class StayTimeValue : public ManualSetValue<time_t>
    {
    public:
        StayTimeValue(PlayerbotAI* ai) : ManualSetValue<time_t>(ai, 0) {}
    };

    class LastLongMoveValue : public CalculatedValue<WorldPosition>
    {
    public:
        LastLongMoveValue(PlayerbotAI* ai) : CalculatedValue<WorldPosition>(ai, "last long move", 30) {}

        WorldPosition Calculate() override;
    };


    class HomeBindValue : public CalculatedValue<WorldPosition>
    {
    public:
        HomeBindValue(PlayerbotAI* ai) : CalculatedValue<WorldPosition>(ai, "home bind", 30) {}

        WorldPosition Calculate() override;

        virtual std::string Format() override;
    };
}
