
#include "playerbot/playerbot.h"
#include "DuelTargetValue.h"

using namespace ai;

Unit* DuelTargetValue::Calculate()
{
    if (!bot->m_duel || bot->m_duel->opponent.IsEmpty()) return nullptr;
    return bot->GetMap()->GetUnit(bot->m_duel->opponent);
}
