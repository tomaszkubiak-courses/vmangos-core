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

// Empty bodies for builds without the playerbots module (BUILD_PLAYERBOTS=OFF).
// The core calls these unconditionally, so without them the link fails on missing
// symbols. When the module is built it provides the real ones and this file is left
// out of the build; see src/game/CMakeLists.txt.

#include "PlayerbotHooks.h"

void Playerbot_Initialize()                                                             {}
void Playerbot_OnWorldStartup()                                                         {}
void Playerbot_OnWorldUpdate(uint32 /*diff*/)                                           {}
void Playerbot_OnPlayerLogin(Player* /*player*/)                                        {}
void Playerbot_OnBeforeLogout(Player* /*player*/)                                       {}
void Playerbot_OnReleaseToClient(Player* /*player*/)                                    {}
void Playerbot_OnPlayerUpdate(Player* /*player*/, uint32 /*diff*/)                       {}
void Playerbot_OnPacketHandled(WorldSession* /*session*/, ClientPacket const& /*packet*/) {}

bool Playerbot_OnSessionSendPacket(WorldSession* /*session*/, WorldPacket const& /*packet*/)
{
    return false;
}

void Playerbot_OnChatCommand(Player* /*master*/, uint32 /*type*/, std::string const& /*msg*/, uint32 /*lang*/, std::string const& /*to*/)
{
}

bool Playerbot_IsAIControlled(Player const* /*player*/)
{
    return false;
}

bool Playerbot_HasBots(Player const* /*player*/)
{
    return false;
}
