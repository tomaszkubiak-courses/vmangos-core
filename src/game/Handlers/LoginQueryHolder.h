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

#ifndef MANGOS_LOGIN_QUERY_HOLDER_H
#define MANGOS_LOGIN_QUERY_HOLDER_H

#include "Common.h"
#include "ObjectGuid.h"
#include "Database/SqlOperations.h"

// The batch of character queries a login runs before the Player is built.
//
// This lived inside CharacterHandler.cpp until the playerbots module needed it:
// WorldSession::HandlePlayerLogin takes one, and the module logs a bot in through
// exactly that path, so the type has to be visible outside the translation unit.
// Initialize() is still defined in CharacterHandler.cpp next to the queries it fills.

class LoginQueryHolder : public SqlQueryHolder
{
private:
    uint32 m_accountId;
    ObjectGuid m_guid;
public:
    LoginQueryHolder(uint32 accountId, ObjectGuid guid)
        : SqlQueryHolder(guid.GetCounter()), m_accountId(accountId), m_guid(guid) { }
    ~LoginQueryHolder()
    {
        // Queries should NOT be deleted by user
        DeleteAllResults();
    }
    ObjectGuid GetGuid() const
    {
        return m_guid;
    }
    uint32 GetAccountId() const
    {
        return m_accountId;
    }
    bool Initialize();
};

#endif
