
#include "playerbot/playerbot.h"
#include "PossibleTargetsValue.h"
#include "PossibleAttackTargetsValue.h"
#include "FreeMoveValues.h"

#include "playerbot/ServerFacade.h"
#include "Maps/GridNotifiers.h"
#include "Maps/GridNotifiersImpl.h"
#include "Maps/CellImpl.h"

#ifdef _WIN32
#include <excpt.h>
#include "CrashDump.h"
#include "Errors.h"
#endif

using namespace ai;
using namespace MaNGOS;

#ifdef _WIN32
namespace
{
    // 0xC0000005, spelled out so this file does not have to pull in windows.h.
    unsigned long const kAccessViolation = 0xC0000005;

    // Dumps are capped: a corrupt grid faults on every bot on the map, every
    // tick, and an uncapped handler would fill the disk in a minute.
    unsigned int const kMaxReports = 3;
    unsigned int g_reportCount = 0;

    int ReportTargetScanFault(unsigned long code, void* exceptionPointers, Player* player)
    {
        if (code != kAccessViolation)
            return EXCEPTION_CONTINUE_SEARCH; // not ours - let it reach the process filter

        ++g_reportCount;

        if (g_reportCount > kMaxReports)
        {
            sLog.outError("PossibleTargetsValue: target scan faulted again (occurrence %u), bot %s",
                g_reportCount, player ? player->GetName() : "<null>");
            return EXCEPTION_EXECUTE_HANDLER;
        }

        // Runs before the stack unwinds, so the trace below is the faulting one
        // and not this handler's.
        if (player)
        {
            sLog.outError("PossibleTargetsValue: access violation scanning targets for bot %s "
                          "(guid %u, map %u, zone %u, at %.2f %.2f %.2f)",
                player->GetName(), player->GetGUIDLow(),
                player->GetMapId(), player->GetZoneId(),
                player->GetPositionX(), player->GetPositionY(), player->GetPositionZ());
        }
        else
            sLog.outError("PossibleTargetsValue: access violation scanning targets for a null bot");

        MaNGOS::Errors::PrintStacktrace(0, 64);

        if (char const* dumpPath = MaNGOS::CrashDump::Write(exceptionPointers))
            sLog.outError("PossibleTargetsValue: crash dump written to %s", dumpPath);

        return EXCEPTION_EXECUTE_HANDLER;
    }

    // The visit gets a frame of its own because MSVC will not accept __try in a
    // function that has objects to unwind, and because catching the fault here
    // keeps the searcher and the target list - which do have destructors - out of
    // the unwind path entirely.
    bool VisitTargetsGuarded(Player* player, UnitListSearcher<AnyUnfriendlyUnitInObjectRangeCheck>& searcher, float range)
    {
        __try
        {
            Cell::VisitAllObjects(player, searcher, range);
            return true;
        }
        __except (ReportTargetScanFault(GetExceptionCode(), GetExceptionInformation(), player))
        {
            return false;
        }
    }
}
#endif

std::list<ObjectGuid> PossibleTargetsValue::Calculate()
{
    float rangeCheck = range;
    bool shouldIgnoreValidate = false;
    if (!qualifier.empty())
    {
        rangeCheck = Qualified::getMultiQualifierInt(qualifier, 0, ":");
        shouldIgnoreValidate = Qualified::getMultiQualifierInt(qualifier, 1, ":");
    }

    std::list<Unit*> targets;
    FindPossibleTargets(bot, targets, rangeCheck);

    std::list<ObjectGuid> results;
    for (std::list<Unit*>::iterator i = targets.begin(); i != targets.end(); ++i)
    {
        Unit* unit = *i;
        if (unit && (shouldIgnoreValidate || AcceptUnit(unit)))
        {
            results.push_back(unit->GetObjectGuid());
        }
    }

    return results;
}

void PossibleTargetsValue::FindUnits(std::list<Unit*> &targets)
{
    FindPossibleTargets(bot, targets, range);
}

bool PossibleTargetsValue::AcceptUnit(Unit* unit)
{
    return IsValid(unit, bot, ignoreLos);
}

void PossibleTargetsValue::FindPossibleTargets(Player* player, std::list<Unit*>& targets, float range)
{
    if (!player || !player->IsInWorld() || !player->GetMap())
        return;

    MaNGOS::AnyUnfriendlyUnitInObjectRangeCheck u_check(player, player, range);
    MaNGOS::UnitListSearcher<MaNGOS::AnyUnfriendlyUnitInObjectRangeCheck> searcher(targets, u_check);

#ifdef _WIN32
    // This scan walks every unit the grid holds and dereferences each one. A
    // stale entry - a Unit freed while it was still linked into a cell - is read
    // here rather than where it was freed, so the crash names this function and
    // says nothing about who left the pointer behind. Catching the fault turns
    // that into a log line that names the bot, the map and the position, and
    // leaves a dump behind to identify the object.
    //
    // Surviving an access violation means continuing on a process that may
    // already be damaged. That is the deliberate trade while the cause is being
    // narrowed: the alternative here is not a healthy server, it is the same
    // crash with less to go on.
    if (!VisitTargetsGuarded(player, searcher, range))
        targets.clear();
#else
    Cell::VisitAllObjects(player, searcher, range);
#endif
}

bool PossibleTargetsValue::IsFriendly(Unit* target, Player* player)
{
    bool friendly = false;
    if (sServerFacade.IsFriendlyTo(target, player))
    {
        friendly = true;

#ifndef MANGOSBOT_ZERO
        // Check if the target is another player in a duel/arena
        Player* targetPlayer = dynamic_cast<Player*>(target);
        if (targetPlayer)
        {
            // If the target is in an arena with the player and is not on the same team
            if (targetPlayer->InArena() && player->InArena() && (targetPlayer->GetBGTeam() != player->GetBGTeam()))
            {
                friendly = false;
            }
        }
#endif
    }

    return friendly;
}

bool PossibleTargetsValue::IsAttackable(Unit* target, Player* player)
{
    const bool inVehicle = GetBotAI(player) && GetBotAI(player)->IsInVehicle();
    return !target->HasFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_NOT_ATTACKABLE_1) &&
           !target->HasFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_UNTARGETABLE) &&
           (inVehicle || !target->HasFlag(UNIT_FIELD_FLAGS, UNIT_FLAG_UNINTERACTIBLE)) &&
           !target->HasAuraType(SPELL_AURA_SPIRIT_OF_REDEMPTION);
}

bool PossibleTargetsValue::IsValid(Unit* target, Player* player, bool ignoreLos)
{
    // If the target is available
    if (target && target->IsInWorld() && (target->GetMapId() == player->GetMapId()))
    {
        // If the target is dead
        if (sServerFacade.UnitIsDead(target))
        {
            return false;
        }

        // If the target is friendly
        if (IsFriendly(target, player))
        {
            return false;
        }

        // If the target can't be attacked
        if (!IsAttackable(target, player))
        {
            return false;
        }

        // Being in combat with *this* target is a reason to know where it is
        // without seeing it. Being in combat at all is not: player->IsInCombat()
        // used to be part of this, which meant a bot fighting anyone could pick
        // out every stealthed player within range.
        bool isInCombatWithTarget = target->GetVictim() == player || 
                                     target->GetThreatManager().getThreat(player) > 0.0f;

        if (!ignoreLos && !isInCombatWithTarget)
        {
            if (!target->IsVisibleForOrDetect(player, player->GetCamera().GetBody(), true))
            {
                return false;
            }
        }
        if (!CanFreeMoveValue::CanFreeAttack(GetBotAI(player), target))
            return false;

        return true;
    }

    return false;
}