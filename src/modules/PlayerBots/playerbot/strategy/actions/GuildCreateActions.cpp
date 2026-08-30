
#include "playerbot/playerbot.h"
#include "GuildCreateActions.h"
#include "playerbot/RandomPlayerbotFactory.h"
#include "playerbot/LootObjectStack.h"
#ifndef MANGOSBOT_ZERO
#ifdef CMANGOS
#include "Arena/ArenaTeam.h"
#endif
#ifdef MANGOS
#include "ArenaTeam.h"
#endif
#endif
#include "playerbot/ServerFacade.h"
#include "playerbot/TravelMgr.h"
#include "Guild/GuildMgr.h"

using namespace ai;

bool BuyPetitionAction::Execute(Event& event)
{
    std::list<ObjectGuid> vendors = ai->GetAiObjectContext()->GetValue<std::list<ObjectGuid> >("nearest npcs")->Get();
    bool vendored = false, result = false;
    for (std::list<ObjectGuid>::iterator i = vendors.begin(); i != vendors.end(); ++i)
    {
        ObjectGuid vendorguid = *i;
        Creature* pCreature = bot->GetNPCIfCanInteractWith(vendorguid, UNIT_NPC_FLAG_PETITIONER);
        if (!pCreature)
            continue;

        std::string guildName = RandomPlayerbotFactory::CreateRandomGuildName();
        if (guildName.empty())
            continue;

        WorldPacket data(CMSG_PETITION_BUY);

        data << pCreature->GetObjectGuid();
        data << uint32(0);
        data << uint64(0);
        data << guildName.c_str();
#ifdef MANGOSBOT_TWO
        data << std::string("");
#else
        data << uint32(0);
#endif
        data << uint32(0);
        data << uint32(0);
        data << uint32(0);
        data << uint32(0);
        data << uint32(0);
        data << uint32(0);
        data << uint32(0);
        data << uint32(0);
        data << uint32(0);
        data << uint32(0);
        data << uint16(0);
        data << uint8(0);

#ifdef MANGOSBOT_TWO
        for (int i = 0; i < 10; ++i)
            data << std::string("");
#endif

        data << uint32(0); // index
        data << uint32(0);

        bot->GetSession()->BotHandlePetitionBuyOpcode(data);

        return true;
    }

    return false;
}

bool BuyPetitionAction::isUseful()
{
    return canBuyPetition(bot);
};

bool BuyPetitionAction::canBuyPetition(Player* bot)
{
    if (!sPlayerbotAIConfig.randomBotFormGuild)
        return false;

    if (bot->GetGuildId())
        return false;

    if (bot->GetGuildIdInvited())
        return false;    

    PlayerbotAI* ai = GetBotAI(bot);
    AiObjectContext* context = ai->GetAiObjectContext();

    if (AI_VALUE2(uint32, "item count", "Hitem:5863:"))
        return false;

    if (ai->GetGuilderType() == GuilderType::SOLO)
        return false;

    if (ai->GetGrouperType() == GrouperType::SOLO)
        return false;

    if (!ai->HasStrategy("guild", BotState::BOT_STATE_NON_COMBAT))
        return false;

    uint32 cost = 1000; //GUILD_CHARTER_COST;

    if (AI_VALUE2(uint32, "free money for", uint32(NeedMoneyFor::guild)) < cost)
        return false;

    return true;
}

bool PetitionOfferAction::Execute(Event& event)
{
    uint32 petitionEntry = 5863; //GUILD_CHARTER
    std::list<Item*> petitions = AI_VALUE2(std::list<Item*>, "inventory items", chat->formatQItem(5863));

    if (petitions.empty())
        return false;

    // A charter whose petition record is gone - the guild was created, or the
    // petition was removed under it - is still an item in the bags, and offering
    // it only logs "[PetitionHandler] No petition exists for charter with guid N"
    // and does nothing. Offer one the guild manager still knows about.
    Item* petition = nullptr;
    Petition* petitionRecord = nullptr;
    for (Item* item : petitions)
    {
        if (!item)
            continue;

        Petition* record = sGuildMgr.GetPetitionByCharterGuid(item->GetObjectGuid());

        // A charter that already carries its last signature cannot be signed by anyone
        // else: HandlePetitionSignOpcode refuses it and the client greys the Sign button
        // out. Offering it around is pure noise - and it was the normal state here,
        // because bots never turned a completed charter in.
        if (!record || record->IsComplete())
            continue;

        petition = item;
        petitionRecord = record;
        break;
    }

    if (!petition)
        return false;

    ObjectGuid guid = event.getObject();

    Player* master = GetMaster();
    if (!master)
    {
        if (!guid)
            guid = bot->GetTargetGuid();
    }
    else {
        if (!guid)
            guid = master->GetTargetGuid();
    }

    if (!guid)
        return false;

    Player* player = sObjectMgr.GetPlayer(guid);

    if (!player)
        return false;

    WorldPacket data(CMSG_OFFER_PETITION);

#ifndef MANGOSBOT_ZERO
    data << uint32(0);
#endif
    data << petition->GetObjectGuid();
    data << guid;

    // Both of these used to be queries against `petition_sign`.`petition_guid` keyed by
    // the charter's item guid. That column holds the petition id instead, so the "has
    // this account signed already" guard never fired - which is why the same bot kept
    // offering the same charter to someone who had already signed it - and the signature
    // count written back below was always 0. The manager has both in memory.
    if (petitionRecord->GetSignatureForAccount(player->GetSession()->GetAccountId()))
        return false;

    bot->GetSession()->BotHandleOfferPetitionOpcode(data);

    context->GetValue<uint8>("petition signs")->Set(petitionRecord->GetSignatureCount());

    return true;
};

bool PetitionOfferNearbyAction::Execute(Event& event)
{
    uint32 found = 0;

    std::list<ObjectGuid> nearGuids = ai->GetAiObjectContext()->GetValue<std::list<ObjectGuid> >("nearest friendly players")->Get();
    for (auto& i : nearGuids)
    {
        Player* player = sObjectMgr.GetPlayer(i);

        if (!player)
            continue;

        if (player->GetGuildId())
            continue;

        if (player->GetGuildIdInvited())
            continue;

        if (!sPlayerbotAIConfig.randomBotInvitePlayer && IsRealPlayer(player))
            continue;

        PlayerbotAI* botAi = GetBotAI(player);

        if (botAi)
        {
            if (botAi->HasActivePlayerMaster()) //Do not invite alts of active players. 
                continue;
        }

        if (sServerFacade.GetDistance2d(bot, player) > sPlayerbotAIConfig.sightDistance)
            continue;

        if (sPlayerbotAIConfig.inviteChat && sServerFacade.GetDistance2d(bot, player) < sPlayerbotAIConfig.spellDistance && (sRandomPlayerbotMgr.IsFreeBot(bot) || !ai->HasActivePlayerMaster()))
        {
            std::map<std::string, std::string> placeholders;
            placeholders["%name"] = player->GetName();

            if(urand(0,3))
                bot->Say(BOT_TEXT2("Hey %name do you want create a guild together?", placeholders), (bot->GetTeam() == ALLIANCE ? LANG_COMMON : LANG_ORCISH));
            else
                bot->Say(BOT_TEXT2("Hey do you want to form a guild?", placeholders), (bot->GetTeam() == ALLIANCE ? LANG_COMMON : LANG_ORCISH));
        }

        //Parse rpg target to quest action.
        WorldPacket p(CMSG_QUESTGIVER_ACCEPT_QUEST);
        p << i;
        p.rpos(0);

        Event petitionOfferEvent = Event("petition offer nearby", p);
        if (PetitionOfferAction::Execute(petitionOfferEvent))
            found++;
    }

    return found > 0;
};

bool PetitionTurnInAction::Execute(Event& event)
{
    Player* requester = event.getOwner() ? event.getOwner() : GetMaster();
    std::list<ObjectGuid> vendors = ai->GetAiObjectContext()->GetValue<std::list<ObjectGuid> >("nearest npcs")->Get();
    bool vendored = false, result = false;

    std::list<Item*> petitions = AI_VALUE2(std::list<Item*>, "inventory items", chat->formatQItem(5863));

    if (petitions.empty())
        return false;

    // Hand in the charter that actually has its signatures, not whichever one happens to
    // sit first in the bags: a bot can carry a charter whose petition record is gone, and
    // HandleTurnInPetitionOpcode refuses anything short of the full count.
    Item* petition = nullptr;
    Petition* petitionRecord = nullptr;
    for (Item* item : petitions)
    {
        if (!item)
            continue;

        Petition* record = sGuildMgr.GetPetitionByCharterGuid(item->GetObjectGuid());
        if (record && record->IsComplete())
        {
            petition = item;
            petitionRecord = record;
            break;
        }
    }

    if (!petition)
        return false;

    // Charter names are drawn from ai_playerbot_guild_names, which only excludes names
    // already taken by a guild - two bots can and do end up carrying charters with the
    // same name. HandleTurnInPetitionOpcode then answers ERR_GUILD_NAME_EXISTS_S and
    // returns, leaving "can hand in petition" true forever, so the loser would walk back
    // to a guild master every time and never form a guild. Take a fresh name instead.
    if (sGuildMgr.GetGuildByName(petitionRecord->GetName()))
    {
        std::string const newName = RandomPlayerbotFactory::CreateRandomGuildName();
        if (newName.empty())
            return false;

        petitionRecord->Rename(newName);
    }

    for (std::list<ObjectGuid>::iterator i = vendors.begin(); i != vendors.end(); ++i)
    {
        ObjectGuid vendorguid = *i;
        Creature* pCreature = bot->GetNPCIfCanInteractWith(vendorguid, UNIT_NPC_FLAG_PETITIONER);
        if (!pCreature)
            continue;

        WorldPacket data(CMSG_TURN_IN_PETITION, 8);

        data << petition->GetObjectGuid();

        bot->GetSession()->BotHandleTurnInPetitionOpcode(data);

        if (bot->GetGuildId())
        {
            Guild* guild = sGuildMgr.GetGuildById(bot->GetGuildId());
            uint32 st, cl, br, bc, bg;
            bg = urand(0, 51);
            bc = urand(0, 17);
            cl = urand(0, 17);
            br = urand(0, 7);
            st = urand(0, 180);
            guild->SetEmblem(st, cl, br, bc, bg);           

            //LANG_GUILD_VETERAN -> can invite, private and initiate -> personal note.
            guild->SetRankRights(2, GR_RIGHT_GCHATLISTEN | GR_RIGHT_GCHATSPEAK | GR_RIGHT_INVITE | GR_RIGHT_EPNOTE);
            guild->SetRankRights(3, GR_RIGHT_GCHATLISTEN | GR_RIGHT_GCHATSPEAK | GR_RIGHT_EPNOTE);
            guild->SetRankRights(4, GR_RIGHT_GCHATLISTEN | GR_RIGHT_GCHATSPEAK | GR_RIGHT_EPNOTE);
        }

        return true;
    }

    //Select a new target to travel to. 
    TravelTarget newTarget = TravelTarget(ai);

    ai->TellDebug(requester, "Handing in guild petition", "debug travel");

    TravelTarget* oldTarget = AI_VALUE(TravelTarget*, "travel target");

    if (oldTarget->GetStatus() == TravelStatus::TRAVEL_STATUS_PREPARE)
        return false;

    if (oldTarget->GetDestination())
    {
        TravelDestination* dest = oldTarget->GetDestination();

        EntryTravelDestination* eDest = dynamic_cast<EntryTravelDestination*>(dest);

        if (eDest && eDest->HasNpcFlag(UNIT_NPC_FLAG_PETITIONER))
            return false;
    }

    oldTarget->SetStatus(TravelStatus::TRAVEL_STATUS_EXPIRED);

    return ai->DoSpecificAction("request named travel target::petition", Event("can hand in petition"), true);
};

bool PetitionTurnInAction::isUseful()
{
    if (!sPlayerbotAIConfig.randomBotFormGuild)
        return false;

    if (!ai->HasStrategy("travel", BotState::BOT_STATE_NON_COMBAT))
        return false;

    if (!ChooseTravelTargetAction::isUseful())
        return false;

    bool inCity = false;
    AreaTableEntry const* areaEntry = GetAreaEntryByAreaID(sServerFacade.GetAreaId(bot));
    if (areaEntry)
    {
        if (areaEntry->ZoneId)
            areaEntry = GetAreaEntryByAreaID(areaEntry->ZoneId);

        if (areaEntry && areaEntry->Flags & AREA_FLAG_CAPITAL)
            inCity = true;
    }

    return inCity && !bot->GetGuildId() && AI_VALUE2(uint32, "item count", chat->formatQItem(5863)) && AI_VALUE(uint8, "petition signs") >= sWorld.getConfig(CONFIG_UINT32_MIN_PETITION_SIGNS) && !AI_VALUE(bool, "travel target traveling");
};

bool BuyTabardAction::Execute(Event& event)
{
    Player* requester = event.getOwner() ? event.getOwner() : GetMaster();
    bool canBuy = ai->DoSpecificAction("buy", Event("buy tabard", "|cHitem:5976:|r"),true);

    if (canBuy && AI_VALUE2(uint32, "item count", chat->formatQItem(5976)))
        return true;

    TravelTarget* oldTarget = AI_VALUE(TravelTarget*, "travel target");

    if (oldTarget->GetStatus() == TravelStatus::TRAVEL_STATUS_PREPARE)
        return false;

    if (oldTarget->GetDestination())
    {
        TravelDestination* dest = oldTarget->GetDestination();

        EntryTravelDestination* eDest = dynamic_cast<EntryTravelDestination*>(dest);

        if (eDest && eDest->HasNpcFlag(UNIT_NPC_FLAG_TABARDDESIGNER))
            return false;
    }

    return ai->DoSpecificAction("request named travel target::tabard", Event("can buy tabard"), true);  
};

bool BuyTabardAction::isUseful()
{
    if (!ai->HasStrategy("travel", BotState::BOT_STATE_NON_COMBAT))
        return false;

    if (!ai->AllowActivity(TRAVEL_ACTIVITY))
        return false;

    if (bot->GetGroup() && !bot->GetGroup()->IsLeader(bot->GetObjectGuid()))
        if (ai->HasStrategy("follow", BotState::BOT_STATE_NON_COMBAT) || ai->HasStrategy("wander", BotState::BOT_STATE_NON_COMBAT) || ai->HasStrategy("stay", BotState::BOT_STATE_NON_COMBAT) || ai->HasStrategy("guard", BotState::BOT_STATE_NON_COMBAT))
            return false;

    if (AI_VALUE(bool, "has available loot"))
    {
        LootObject lootObject = AI_VALUE(LootObjectStack*, "available loot")->GetLoot(sPlayerbotAIConfig.lootDistance);
        if (lootObject.IsLootPossible(bot))
            return false;
    }

    bool inCity = false;
    AreaTableEntry const* areaEntry = GetAreaEntryByAreaID(sServerFacade.GetAreaId(bot));
    if (areaEntry)
    {
        if (areaEntry->ZoneId)
            areaEntry = GetAreaEntryByAreaID(areaEntry->ZoneId);

        if (areaEntry && areaEntry->Flags & AREA_FLAG_CAPITAL)
            inCity = true;
    }

    return inCity && bot->GetGuildId() && !AI_VALUE2(uint32, "item count", chat->formatQItem(5976)) && AI_VALUE2(uint32, "free money for", uint32(NeedMoneyFor::guild)) >= 10000 && !AI_VALUE(bool, "travel target traveling");
};