
#include "playerbot/playerbot.h"
#include "PetitionSignAction.h"
#include "Guild/GuildMgr.h"
#ifndef MANGOSBOT_ZERO
#ifdef CMANGOS
#include "Arena/ArenaTeam.h"
#endif
#ifdef MANGOS
#include "ArenaTeam.h"
#endif
#endif

using namespace ai;

bool PetitionSignAction::Execute(Event& event)
{
    Player* requester = event.getOwner() ? event.getOwner() : GetMaster();
    WorldPacket p(event.getPacket());
    p.rpos(0);
    ObjectGuid petitionGuid;
    ObjectGuid inviter;
    uint8 unk = 0;
    bool isArena = false;
    p >> petitionGuid >> inviter;
    uint32 type = 9;

#ifndef MANGOSBOT_ZERO
    auto result = CharacterDatabase.PQuery("SELECT `type` FROM `petition` WHERE `petitionguid` = '%u'", petitionGuid.GetCounter());
    if (!result)
    {
        return false;
    }

    Field* fields = result->Fetch();
    type = fields[0].GetUInt32();
#endif

    bool accept = true;

    if (type != 9)
    {
#ifndef MANGOSBOT_ZERO
        isArena = true;
        uint8 slot = ArenaTeam::GetSlotByType(ArenaType(type));
        if (bot->GetArenaTeamId(slot))
        {
            // player is already in an arena team
            ai->TellError(requester, "Sorry, I am already in such team");
            accept = false;
        }
#endif
    }
    else
    {
        if (bot->GetGuildId())
        {
            ai->TellError(requester, "Sorry, I am in a guild already");
            accept = false;
        }

        if (bot->GetGuildIdInvited())
        {
            ai->TellError(requester, "Sorry, I am invited to a guild already");
            accept = false;
        }

        // check for same acc id
        /*QueryResult* result = CharacterDatabase.PQuery("SELECT playerguid FROM petition_sign WHERE player_account = '%u' AND petitionguid = '%u'", bot->GetSession()->GetAccountId(), petitionGuid.GetCounter());

        if (result)
        {
            ai->TellError("Sorry, I already signed this pettition");
            accept = false;
        }
        delete result;*/
    }

    // The petition can be gone by the time this action runs - the owner may
    // have turned the charter in or destroyed it since the offer. On vanilla
    // the only existence check above is inside #ifndef MANGOSBOT_ZERO, so it
    // is compiled out here and the bot signed blind, which is what produced
    // "[PetitionHandler] No petition exists for charter with guid N" in the
    // server log.
    Petition* offered = sGuildMgr.GetPetitionByCharterGuid(petitionGuid);

    Player* _inviter = sObjectMgr.GetPlayer(inviter);

    // TEMP DIAGNOSTIC [PETDIAG] - only when a real player is the one asking, so the
    // bots signing for each other cost nothing. Remove once the cause is known.
    if (_inviter && IsRealPlayer(_inviter))
    {
        DenyReason reason = DenyReason::PLAYERBOT_DENY_NONE;
        PlayerbotSecurityLevel level = ai->GetSecurity()->LevelFor(_inviter, &reason, true);
        sLog.Out(LOG_BASIC, LOG_LVL_MINIMAL, "[PETDIAG] %s got offer from %s: petition %s, accept %u, guild %u, invited %u, security %u (need %u) deny %u, bgqueue %u",
                 bot->GetName(), _inviter->GetName(), offered ? "found" : "MISSING", accept ? 1 : 0,
                 bot->GetGuildId(), bot->GetGuildIdInvited(), (uint32)level,
                 (uint32)PlayerbotSecurityLevel::PLAYERBOT_SECURITY_GUILD, (uint32)reason,
                 bot->InBattleGroundQueue() ? 1 : 0);
    }

    if (!offered)
        return false;

    if (!_inviter)
        return false;

    if (_inviter == bot)
        return false;

    if (!accept || !ai->GetSecurity()->CheckLevelFor(PlayerbotSecurityLevel::PLAYERBOT_SECURITY_GUILD, false, _inviter, true))
    {
        WorldPacket data(MSG_PETITION_DECLINE);
        data << petitionGuid;
        bot->GetSession()->BotHandlePetitionDeclineOpcode(data);
        sLog.outDetail("Bot #%d <%s> declines %s invite", bot->GetGUIDLow(), bot->GetName(), isArena ? "Arena" : "Guild");
        return false;
    }
    if (accept)
    {
        WorldPacket data(CMSG_PETITION_SIGN, 20);
        data << petitionGuid << unk;
        bot->GetSession()->BotHandlePetitionSignOpcode(data);
        bot->Say("Thanks for the invite!", LANG_UNIVERSAL);
        sLog.outDetail("Bot #%d <%s> accepts %s invite", bot->GetGUIDLow(), bot->GetName(), isArena ? "Arena" : "Guild");
        return true;
    }
    return false;
}