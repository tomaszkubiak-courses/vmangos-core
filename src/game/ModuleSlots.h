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

#ifndef MANGOS_MODULE_SLOTS_H
#define MANGOS_MODULE_SLOTS_H

#include "Common.h"

// Per player storage slots for optional modules.
//
// A module that has to hang state off a Player claims a slot here and reaches it
// through Player::GetModuleSlot / SetModuleSlot. The core allocates the space and
// never reads it: what a slot points at, who owns it and when it is freed are the
// module's business.
//
// Claiming a slot is the only thing that needs a line in the core, so keep the list
// short and name the owner of each entry. Two modules must never share a number;
// nothing checks it at runtime.
//
// A flat array rather than a keyed map on purpose: the slot is read on every tick of
// every driven character, and a load from a fixed offset costs less than a lookup.

enum ModuleSlot : uint8
{
    MODULE_SLOT_BOT_AI  = 0,    // playerbots: PlayerbotAI for a driven character
    MODULE_SLOT_BOT_MGR = 1,    // playerbots: PlayerbotMgr for a player commanding bots

    MODULE_SLOT_MAX
};

#endif
