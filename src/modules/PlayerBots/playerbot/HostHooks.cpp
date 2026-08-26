// Host-side glue for bot lifecycle and dispatch. Implements:
//   - Player::{Create,Remove}Playerbot{AI,Mgr}, Player::isRealPlayer
//   - Player::UpdatePlayerbotHooks (per-Player tick)
//   - World::{Update,Init}Playerbots* (world-tick driver, startup init)
//   - Player_DispatchBotOutgoing{Packet,ChatCommand} (free functions called
//     from WorldSession; the bot-AI null-check happens here so the host
//     call sites stay unconditional)
//
// Lives in the bot module so it sees both the host headers and the bot
// module's full PlayerbotAI / PlayerbotMgr types — the host declares the
// methods, only the bot module satisfies the linker with real bodies. The
// matching BUILD_PLAYERBOTS=OFF stubs live in src/game/PlayerbotStubs.cpp.

#include "playerbot/playerbot.h"
#include "Objects/Player.h"
#include "World.h"
#include "playerbot/RandomPlayerbotMgr.h"
#include "playerbot/RandomPlayerbotFactory.h"
#include "playerbot/PlayerbotAIConfig.h"
#include "ahbot/AhBot.h"
#include "BotDiagnostics.h"
#include "playerbot/AiFactory.h"
#include "playerbot/strategy/actions/ChangeTalentsAction.h"
#include "PlayerbotHooks.h"
#include "WorldSession.h"

// Lifecycle. These were Player:: members; the objects now live in the player
// slots this module claims (ModuleSlots.h), so the core neither allocates them
// nor knows their type. Bodies are unchanged.

void CreateBotAI(Player* player)
{
    if (!player || GetBotAI(player))
        return;

    SetBotAI(player, new PlayerbotAI(player));
}

void RemoveBotAI(Player* player)
{
    PlayerbotAI* ai = GetBotAI(player);
    if (!ai)
        return;

    delete ai;
    SetBotAI(player, nullptr);
}

void CreateBotMgr(Player* player)
{
    if (!player || GetBotMgr(player))
        return;

    SetBotMgr(player, new PlayerbotMgr(player));
    // RandomPlayerbotMgr tracks real players in its own `players` map
    // (used by SyncLevelWithPlayers, RandomBotLoginWithPlayer, LFG
    // auto-queue). Without this call the map never gets populated and
    // those features silently never trigger.
    sRandomPlayerbotMgr.OnPlayerLogin(player);
}

void RemoveBotMgr(Player* player)
{
    PlayerbotMgr* mgr = GetBotMgr(player);
    if (!mgr)
        return;

    // Log out the master's alt bots first; otherwise their PlayerbotAI
    // outlives the mgr and they linger in-world with a dangling master.
    mgr->LogoutAllBots();
    sRandomPlayerbotMgr.OnPlayerLogout(player);
    delete mgr;
    SetBotMgr(player, nullptr);
}

// Was Player::isRealPlayer(). Note it is not simply "has no AI": a person
// driving their own character through this module keeps a real session, and
// the address check is what tells the two apart.
bool IsRealPlayer(Player const* player)
{
    PlayerbotAI* ai = GetBotAI(player);
    return !ai || ai->IsRealPlayer();
}


// ---------------------------------------------------------------------------
// The core's side of the module: the free functions declared in
// src/game/PlayerbotHooks.h. The core calls these unconditionally and knows
// nothing else about this module.
//
// The donor reached the host through an AzerothCore-style hook framework
// (ScriptObjects.h) that VMaNGOS does not have. Adding one for a dozen hooks
// would have meant carrying an 817-line divergence in files upstream also
// edits, so the bodies of its PlayerbotWorldScript, PlayerbotServerScript and
// PlayerbotPlayerScript live here instead, one free function each.
// ---------------------------------------------------------------------------

void Playerbot_Initialize()
{
    sPlayerbotAIConfig.Initialize();
}

// Was PlayerbotWorldScript::OnStartup. Runs at the end of world init, where
// AhBot::Init needs the item storage already loaded.
void Playerbot_OnWorldStartup()
{
    if (!sPlayerbotAIConfig.enabled)
        return;

    RandomPlayerbotFactory::CreateRandomBots();
    auctionbot.Init();
}

// Was PlayerbotWorldScript::OnUpdate.
void Playerbot_OnWorldUpdate(uint32 diff)
{
    if (!sPlayerbotAIConfig.enabled)
        return;

    sRandomPlayerbotMgr.UpdateAI(diff);

    // Runs here, and only here: World::Update has already waited for every map
    // thread by this point, so deleting a bot's Player cannot pull the object out
    // from under a map that is still updating it.
    PlayerbotHolder::ProcessQueuedLogouts();
    auctionbot.Update();
}

// Was PlayerbotServerScript::CanPacketSend, with the sense flipped: that one
// returned false to suppress, this returns true. A driven character never
// reaches the network - the AI reacts to the packet instead (group invites,
// battleground status, vendor errors).
bool Playerbot_OnSessionSendPacket(WorldSession* session, WorldPacket const& packet)
{
    if (!session)
        return false;

    Player* player = session->GetPlayer();
    if (!player)
        return false;

    PlayerbotAI* ai = GetBotAI(player);
    if (!ai)
        return false;

    ai->HandleBotOutgoingPacket(packet);
    return true;
}

// Was PlayerbotServerScript::OnPacketHandled, which fed the master's packet to
// PlayerbotMgr::HandleMasterIncomingPacket so bots mirror what their owner just
// did - accepting a quest, selecting a gossip option, and so on.
//
// Not wired up yet. That function reads raw packet bytes, and this core parses a
// WorldPacket into a typed ClientPacket before queueing it, so no buffer survives
// to the point where a handler has run. Reaching it means teaching the module to
// read the parsed packet instead. Until then bots do not mirror their master.
void Playerbot_OnPacketHandled(WorldSession* /*session*/, ClientPacket const& /*packet*/)
{
}

// Was PlayerbotPlayerScript::OnChatCommand.
void Playerbot_OnChatCommand(Player* master, uint32 type, std::string const& msg, uint32 lang, std::string const& to)
{
    if (!master || !sPlayerbotAIConfig.enabled)
        return;

    if (PlayerbotMgr* mgr = GetBotMgr(master))
        mgr->HandleCommand(type, msg, lang, to);
}

// Was PlayerbotPlayerScript::OnLogin. Only a person at a client gets a
// controller for their alts.
//
// The AI is not attached yet at this point, so asking whether the character has
// one tells us nothing. The session address does: a bot session carries "<BOT>".
void Playerbot_OnPlayerLogin(Player* player)
{
    if (!player || !player->GetSession())
        return;

    std::string const& addr = player->GetSession()->GetRemoteAddress();
    if (addr == "disconnected/bot" || addr == "<BOT>")
        return;

    CreateBotMgr(player);
}

// Was PlayerbotPlayerScript::OnBeforeLogout.
void Playerbot_OnBeforeLogout(Player* player)
{
    RemoveBotAI(player);
    RemoveBotMgr(player);
}

// Was PlayerbotPlayerScript::OnReleaseToClient. A real client is taking the
// character over; an AI still ticking on it fights the login handshake and the
// client hangs on the loading screen.
void Playerbot_OnReleaseToClient(Player* player)
{
    RemoveBotAI(player);
}

// Was PlayerbotPlayerScript::OnUpdate.
void Playerbot_OnPlayerUpdate(Player* player, uint32 diff)
{
    if (!player || !sPlayerbotAIConfig.enabled)
        return;

    if (PlayerbotAI* ai = GetBotAI(player))
    {
        SC_PHASE("Playerbot_OnPlayerUpdate/ai.UpdateAI", player->GetName());
        ai->UpdateAI(diff);
    }

    if (PlayerbotMgr* mgr = GetBotMgr(player))
    {
        SC_PHASE("Playerbot_OnPlayerUpdate/mgr.UpdateAI", player->GetName());
        mgr->UpdateAI(diff);
    }
}

bool Playerbot_IsAIControlled(Player const* player)
{
    return player && GetBotAI(player) != nullptr;
}

bool Playerbot_HasBots(Player const* player)
{
    return player && GetBotMgr(player) != nullptr;
}
