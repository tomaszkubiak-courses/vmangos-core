
#include "playerbot/playerbot.h"
#include "MaintenanceStrategy.h"

using namespace ai;

void MaintenanceStrategy::InitNonCombatTriggers(std::list<TriggerNode*> &triggers)
{
    triggers.push_back(new TriggerNode(
        "random",
        NextAction::array(0, new NextAction("clean quest log", 6.0f), NULL)));

    // Relief when the log is actually full, rather than only when a coin flip
    // says so. The entry above fires often enough - "random" is a one-in-seven
    // roll every RepeatDelay - but it sits at 6.0, below every travel action
    // (6.28 to 6.98), and the engine runs the highest-relevance action that
    // succeeds. Travel always wants the slot, so the tidy-up almost never got
    // one. Measured over 2h16m with 2005 bots: 265 sat at exactly 20 active
    // quests, the point at which RpgStartQuestTrigger stops offering new ones,
    // and 819 at 15 or more.
    //
    // Priced above the travel request actions (highest 6.96) and below the two
    // travel-target bookkeeping actions at 6.98 and 6.99, which cost nothing and
    // are what let the bot notice it is standing at a questgiver. The trigger's
    // own five-second check interval is the throttle on a bot whose log cannot
    // be cleaned at all.
    triggers.push_back(new TriggerNode(
        "quest log nearly full",
        NextAction::array(0, new NextAction("clean quest log", 6.97f), NULL)));

    triggers.push_back(new TriggerNode(
        "random",
        NextAction::array(0, new NextAction("use random recipe", 1.0f), NULL)));

    triggers.push_back(new TriggerNode(
        "random",
        NextAction::array(0, new NextAction("open random item", 0.9f), NULL)));

    triggers.push_back(new TriggerNode(
        "random",
        NextAction::array(0, new NextAction("disenchant random item", 1.0f), NULL)));

    triggers.push_back(new TriggerNode(
        "random",
        NextAction::array(0, new NextAction("enchant random item", 1.0f), NULL)));

    triggers.push_back(new TriggerNode(
        "random",
        NextAction::array(0, new NextAction("smart destroy item", 1.0f), NULL)));

    triggers.push_back(new TriggerNode(
        "move stuck",
        NextAction::array(0, new NextAction("unstuck", 0.7f), NULL)));

    triggers.push_back(new TriggerNode(
        "move long stuck",
        NextAction::array(0, new NextAction("unstuck", 0.9f), NULL)));

    triggers.push_back(new TriggerNode(
        "random",
        NextAction::array(0, new NextAction("use random quest item", 0.9f), NULL)));

    triggers.push_back(new TriggerNode(
        "random",
        NextAction::array(0, new NextAction("auto share quest", 0.9f), NULL)));

    triggers.push_back(new TriggerNode(
        "random",
        NextAction::array(0, new NextAction("auto complete quest", 1.0f), NULL)));
}
