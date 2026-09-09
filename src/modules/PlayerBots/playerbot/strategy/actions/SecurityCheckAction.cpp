
#include "playerbot/playerbot.h"
#include "playerbot/RandomPlayerbotMgr.h"
#include "SecurityCheckAction.h"

using namespace ai;

bool SecurityCheckAction::isUseful()
{
    // The master check comes first because it is a pointer read and decides the answer for
    // every bot the random manager owns: they have no master at all. IsRandomBot behind it
    // walks the random account list and then the event cache, which the "often" trigger was
    // paying for 71339 times over the eight hour run of 2026-09-09, always to reach false.
    Player* master = ai->GetMaster();
    if (!master || GetBotAI(master))
        return false;

    return master->GetSession()->GetSecurity() < SEC_GAMEMASTER && sRandomPlayerbotMgr.IsRandomBot(bot);
}

bool SecurityCheckAction::Execute(Event& event)
{
    Player* requester = event.getOwner() ? event.getOwner() : GetMaster();
    Group* group = bot->GetGroup();
    if (group)
    {
        LootMethod method = group->GetLootMethod();
        ItemQualities threshold = group->GetLootThreshold();
        if (method == MASTER_LOOT || method == FREE_FOR_ALL || threshold > ITEM_QUALITY_UNCOMMON)
        {
            if ((ai->GetGroupMaster()->GetSession()->GetSecurity() == SEC_PLAYER) && (!bot->GetGuildId() || bot->GetGuildId() != ai->GetGroupMaster()->GetGuildId()))
            {
                ai->TellError(requester, "I will play with this loot type only if I'm in your guild :/");
                ai->ChangeStrategy("+passive,+stay", BotState::BOT_STATE_NON_COMBAT);
                ai->ChangeStrategy("+passive,+stay", BotState::BOT_STATE_COMBAT);
            }
            return true;
        }
    }
    return false;
}
