/*
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

// Raw WorldPacket entry points for the playerbots module.
//
// A driven character has no client, so the module acts for it by building the packet
// a client would have sent and calling the handler itself. The handlers here take
// parsed packet structs, which the module has no way to produce, so each one gets a
// Bot-prefixed twin that parses a WorldPacket and forwards.
//
// Prefixed rather than overloaded because Opcodes.cpp deduces each handler's packet
// class from decltype(&WorldSession::HandleXOpcode); a second overload makes that name
// ambiguous and the whole opcode table stops compiling. The module's call sites are
// rewritten from ->HandleX( to ->BotHandleX( when it is vendored.
//
// Generated mechanically from the declarations in WorldSession.h - the body of every
// one of these is the same three lines. Compiled only when BUILD_PLAYERBOTS is on;
// the declarations in WorldSession.h carry the same guard.

#include "WorldSession.h"
#include "WorldPacket.h"
#include "Packet.h"

#include "Packets/AuctionHouse.h"
#include "Packets/Mail.h"
#include "Packets/Battleground.h"
#include "Packets/Channel.h"
#include "Packets/Character.h"
#include "Packets/Duel.h"
#include "Packets/Group.h"
#include "Packets/Guild.h"
#include "Packets/Item.h"
#include "Packets/Loot.h"
#include "Packets/Misc.h"
#include "Packets/Movement.h"
#include "Packets/Npc.h"
#include "Packets/Pet.h"
#include "Packets/Petition.h"
#include "Packets/Quest.h"
#include "Packets/Trade.h"

void WorldSession::BotHandleCharCreateOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Character::CharCreate packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleCharCreateOpcode(packet);
}

void WorldSession::BotHandleMoveTeleportAckOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Movement::MoveTeleportAck packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleMoveTeleportAckOpcode(packet);
}

void WorldSession::BotHandleMoveWorldportAckOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleMoveWorldportAckOpcode(packet);
}

void WorldSession::BotHandleMountSpecialAnimOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleMountSpecialAnimOpcode(packet);
}

void WorldSession::BotHandleRepopRequestOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleRepopRequestOpcode(packet);
}

void WorldSession::BotHandleAutostoreLootItemOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Loot::AutoStoreLootItem packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleAutostoreLootItemOpcode(packet);
}

void WorldSession::BotHandleLootMoneyOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleLootMoneyOpcode(packet);
}

void WorldSession::BotHandleLootOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Loot::LootUnit packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleLootOpcode(packet);
}

void WorldSession::BotHandleLootReleaseOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Loot::LootRelease packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleLootReleaseOpcode(packet);
}

void WorldSession::BotHandleLogoutRequestOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleLogoutRequestOpcode(packet);
}

void WorldSession::BotHandleLogoutCancelOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleLogoutCancelOpcode(packet);
}

void WorldSession::BotHandleAreaTriggerOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Misc::AreaTrigger packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleAreaTriggerOpcode(packet);
}

void WorldSession::BotHandleGameObjectUseOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Misc::GameObjectUse packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGameObjectUseOpcode(packet);
}

void WorldSession::BotHandleGroupInviteOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Group::GroupInvite packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGroupInviteOpcode(packet);
}

void WorldSession::BotHandleGroupAcceptOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGroupAcceptOpcode(packet);
}

void WorldSession::BotHandleGroupSetLeaderOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Group::GroupSetLeader packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGroupSetLeaderOpcode(packet);
}

void WorldSession::BotHandleGroupDisbandOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGroupDisbandOpcode(packet);
}

#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_10_2
void WorldSession::BotHandleRaidReadyCheckOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Group::RaidReadyCheckFromClient packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleRaidReadyCheckOpcode(packet);
}
#endif

void WorldSession::BotHandlePetitionBuyOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Petition::PetitionBuy packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandlePetitionBuyOpcode(packet);
}

void WorldSession::BotHandlePetitionSignOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Petition::PetitionSign packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandlePetitionSignOpcode(packet);
}

void WorldSession::BotHandlePetitionDeclineOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Petition::PetitionDecline packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandlePetitionDeclineOpcode(packet);
}

void WorldSession::BotHandleOfferPetitionOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Petition::OfferPetition packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleOfferPetitionOpcode(packet);
}

void WorldSession::BotHandleTurnInPetitionOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Petition::TurnInPetition packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleTurnInPetitionOpcode(packet);
}

void WorldSession::BotHandleGuildInviteOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Guild::GuildInvite packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGuildInviteOpcode(packet);
}

void WorldSession::BotHandleGuildRemoveOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Guild::GuildRemove packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGuildRemoveOpcode(packet);
}

void WorldSession::BotHandleGuildAcceptOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGuildAcceptOpcode(packet);
}

void WorldSession::BotHandleGuildDeclineOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGuildDeclineOpcode(packet);
}

void WorldSession::BotHandleGuildPromoteOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Guild::GuildPromote packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGuildPromoteOpcode(packet);
}

void WorldSession::BotHandleGuildDemoteOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Guild::GuildDemote packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGuildDemoteOpcode(packet);
}

void WorldSession::BotHandleGuildLeaveOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGuildLeaveOpcode(packet);
}

void WorldSession::BotHandleGuildLeaderOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Guild::GuildLeader packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGuildLeaderOpcode(packet);
}

void WorldSession::BotHandleGossipHelloOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Npc::GossipHello packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGossipHelloOpcode(packet);
}

void WorldSession::BotHandleGossipSelectOptionOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Npc::GossipSelectOption packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleGossipSelectOptionOpcode(packet);
}

void WorldSession::BotHandleDuelAcceptedOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Duel::DuelAccepted packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleDuelAcceptedOpcode(packet);
}

void WorldSession::BotHandleDuelCancelledOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Duel::DuelCancelled packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleDuelCancelledOpcode(packet);
}

void WorldSession::BotHandleAcceptTradeOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Trade::AcceptTrade packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleAcceptTradeOpcode(packet);
}

void WorldSession::BotHandleBeginTradeOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleBeginTradeOpcode(packet);
}

void WorldSession::BotHandleCancelTradeOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleCancelTradeOpcode(packet);
}

void WorldSession::BotHandleClearTradeItemOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Trade::ClearTradeItem packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleClearTradeItemOpcode(packet);
}

void WorldSession::BotHandleInitiateTradeOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Trade::InitiateTrade packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleInitiateTradeOpcode(packet);
}

void WorldSession::BotHandleSetTradeGoldOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Trade::SetTradeGold packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleSetTradeGoldOpcode(packet);
}

void WorldSession::BotHandleSetTradeItemOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Trade::SetTradeItem packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleSetTradeItemOpcode(packet);
}

void WorldSession::BotHandleAutoEquipItemOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Item::AutoEquipItem packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleAutoEquipItemOpcode(packet);
}

void WorldSession::BotHandleSellItemOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Item::SellItem packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleSellItemOpcode(packet);
}

void WorldSession::BotHandleAutoStoreBagItemOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Item::AutoStoreBagItem packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleAutoStoreBagItemOpcode(packet);
}

void WorldSession::BotHandleQuestgiverAcceptQuestOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Quest::QuestgiverAcceptQuest packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleQuestgiverAcceptQuestOpcode(packet);
}

void WorldSession::BotHandleTextEmoteOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Misc::TextEmote packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleTextEmoteOpcode(packet);
}

void WorldSession::BotHandleReclaimCorpseOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Misc::ReclaimCorpse packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleReclaimCorpseOpcode(packet);
}

void WorldSession::BotHandleResurrectResponseOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Misc::ResurrectResponse packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleResurrectResponseOpcode(packet);
}

void WorldSession::BotHandleSummonResponseOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Misc::SummonResponse packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleSummonResponseOpcode(packet);
}

void WorldSession::BotHandleJoinChannelOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Channel::JoinChannel packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleJoinChannelOpcode(packet);
}

#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_6_1
void WorldSession::BotHandleBattlemasterJoinOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Battleground::BattlemasterJoin packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleBattlemasterJoinOpcode(packet);
}
#endif

void WorldSession::BotHandleBattlefieldStatusOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleBattlefieldStatusOpcode(packet);
}

void WorldSession::BotHandleBattleFieldPortOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Battleground::BattleFieldPort packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleBattleFieldPortOpcode(packet);
}

#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_4_2
void WorldSession::BotHandleLeaveBattlefieldOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Battleground::LeaveBattlefield packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleLeaveBattlefieldOpcode(packet);
}
#endif

void WorldSession::BotHandleRandomRollOpcode(WorldPacket& recvPacket)
{
    WorldPackets::Group::RandomRoll packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleRandomRollOpcode(packet);
}

void WorldSession::BotHandleResetInstancesOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleResetInstancesOpcode(packet);
}

void WorldSession::BotHandleSelfResOpcode(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleSelfResOpcode(packet);
}

void WorldSession::BotHandleMovementOpcodes(WorldPacket& recvPacket)
{
    WorldPackets::Movement::MovementPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleMovementOpcodes(packet);
}

void WorldSession::BotHandlePetAction(WorldPacket& recvPacket)
{
    WorldPackets::Pet::PetAction packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandlePetAction(packet);
}

void WorldSession::BotHandleAuctionSellItem(WorldPacket& recvPacket)
{
    WorldPackets::AuctionHouse::AuctionSellItem packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleAuctionSellItem(packet);
}

void WorldSession::BotHandleAuctionPlaceBid(WorldPacket& recvPacket)
{
    WorldPackets::AuctionHouse::AuctionPlaceBid packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleAuctionPlaceBid(packet);
}

void WorldSession::BotHandleMailTakeMoney(WorldPacket& recvPacket)
{
    WorldPackets::Mail::MailTakeMoney packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleMailTakeMoney(packet);
}

void WorldSession::BotHandleMailTakeItem(WorldPacket& recvPacket)
{
    WorldPackets::Mail::MailTakeItem packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleMailTakeItem(packet);
}

void WorldSession::BotHandleMailDelete(WorldPacket& recvPacket)
{
    WorldPackets::Mail::MailDelete packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleMailDelete(packet);
}

void WorldSession::BotHandleQueryNextMailTime(WorldPacket& recvPacket)
{
    NullClientPacket packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleQueryNextMailTime(packet);
}

void WorldSession::BotHandleBuybackItem(WorldPacket& recvPacket)
{
    WorldPackets::Item::BuybackItem packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleBuybackItem(packet);
}

void WorldSession::BotHandlePushQuestToParty(WorldPacket& recvPacket)
{
    WorldPackets::Quest::PushQuestToParty packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandlePushQuestToParty(packet);
}

void WorldSession::BotHandlePetAbandon(WorldPacket& recvPacket)
{
    WorldPackets::Pet::PetAbandon packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandlePetAbandon(packet);
}

void WorldSession::BotHandleMoveKnockBackAck(WorldPacket& recvPacket)
{
    WorldPackets::Movement::MoveKnockBackAck packet;
    packet.ReadFromWorldPacket(recvPacket);
    HandleMoveKnockBackAck(packet);
}
