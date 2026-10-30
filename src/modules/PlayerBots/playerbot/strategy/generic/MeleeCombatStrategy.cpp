
#include "playerbot/playerbot.h"
#include "MeleeCombatStrategy.h"

using namespace ai;

void MeleeCombatStrategy::InitCombatTriggers(std::list<TriggerNode*> &triggers)
{
    triggers.push_back(new TriggerNode(
        "enemy out of melee",
        NextAction::array(0, new NextAction("reach melee", ACTION_MOVE), NULL)));

    triggers.push_back(new TriggerNode(
        "enemy too close for melee",
        NextAction::array(0, new NextAction("move out of enemy contact", static_cast<float>(ACTION_NORMAL) + 8.0f), NULL)));
}

void SetBehindCombatStrategy::InitCombatTriggers(std::list<TriggerNode*> &triggers)
{
    // From cmangos/playerbots eda0c9e3: off - the combat stance puts melee behind the target.
    // "set behind" ran 4.3 million times in a 36 hour run, 3.8 million of them impossible. Rogue
    // and feral strategies, which need the back for backstab and shred, keep their own triggers.
}

void ChaseJumpStrategy::InitNonCombatTriggers(std::list<TriggerNode*>& triggers)
{
    triggers.push_back(new TriggerNode(
        "very often",
        NextAction::array(0, new NextAction("jump::chase", static_cast<float>(ACTION_MOVE) + 9.0f), NULL)));
}

void ChaseJumpStrategy::InitCombatTriggers(std::list<TriggerNode *> &triggers)
{
    InitNonCombatTriggers(triggers);
}

void ChaseJumpStrategy::InitReactionTriggers(std::list<TriggerNode *> &triggers)
{
    InitNonCombatTriggers(triggers);
}
