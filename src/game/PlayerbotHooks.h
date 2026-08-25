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

#ifndef MANGOS_PLAYERBOT_HOOKS_H
#define MANGOS_PLAYERBOT_HOOKS_H

#include "Common.h"

#include <string>

class ClientPacket;
class Player;
class WorldPacket;
class WorldSession;

// Every point at which the core reaches into the playerbots module.
//
// The core calls these unconditionally. When the module is not built
// (BUILD_PLAYERBOTS=OFF) the empty bodies in PlayerbotStubs.cpp satisfy the linker;
// when it is built, the module provides the real ones and the stub file is left out
// of the build. Nothing else in the core knows the module exists, and no header of
// it is ever included here.
//
// Keep this list short. A hook that only one module will ever want is usually better
// expressed as a query the module makes, not a call the core makes.

// Load the bot configuration. Called once, early in World::SetInitialWorldSettings,
// before any world data is needed.
void Playerbot_Initialize();

// Called at the end of World::SetInitialWorldSettings, once static world data is
// loaded. Bot population and the auction bot start here.
void Playerbot_OnWorldStartup();

// World tick.
void Playerbot_OnWorldUpdate(uint32 diff);

// A character has entered the world. Only a person at a client gets a controller for
// their alts, so the module decides from the session whether this is one.
void Playerbot_OnPlayerLogin(Player* player);

// Head of WorldSession::LogoutPlayer, while the Player is still valid.
void Playerbot_OnBeforeLogout(Player* player);

// A real client is taking over a character the module was driving. The AI has to stop
// ticking before the login handshake runs, or the two fight over the same Player.
void Playerbot_OnReleaseToClient(Player* player);

// Per character tick, from Player::Update.
void Playerbot_OnPlayerUpdate(Player* player, uint32 diff);

// About to send a packet to a session. Returning true means the module consumed it
// and it must not go any further: a driven character has no client to receive it, the
// AI reacts to the packet instead.
bool Playerbot_OnSessionSendPacket(WorldSession* session, WorldPacket const& packet);

// A packet from a client has been handled. Runs after the handler, so bots mirror an
// action their master has already taken.
//
// This is the parsed packet, not the bytes: the receive path turns a WorldPacket into
// a ClientPacket before queueing it, and the raw buffer does not survive that. The
// fields are on the packet already, and the opcode is Packet::GetOpcode().
void Playerbot_OnPacketHandled(WorldSession* session, ClientPacket const& packet);

// Chat sent by a player, offered to the bots that player commands.
void Playerbot_OnChatCommand(Player* master, uint32 type, std::string const& msg, uint32 lang, std::string const& to);

// Is this character being driven by the module rather than by a person?
bool Playerbot_IsAIControlled(Player const* player);

// Does this player command any bots?
bool Playerbot_HasBots(Player const* player);

#endif
