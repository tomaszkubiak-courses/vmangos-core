
#include "playerbot/playerbot.h"
#include "QuestStrategies.h"

using namespace ai;

QuestStrategy::QuestStrategy(PlayerbotAI* ai) : PassTroughStrategy(ai)
{
    supported.push_back("accept quest");
}

void QuestStrategy::InitNonCombatTriggers(std::list<TriggerNode*>& triggers)
{
    PassTroughStrategy::InitNonCombatTriggers(triggers);

    triggers.push_back(new TriggerNode("quest share", NextAction::array(0, new NextAction("accept quest share", relevance), NULL)));

    // Hand in what can be handed in from where the bot is standing.
    //
    // The three triggers the derived strategies register below - "gossip hello",
    // "use game object", "complete quest" - are all master incoming packet
    // handlers, registered in the PlayerbotAI constructor, so they fire only
    // when a human sends that packet about that NPC. A bot with no master had
    // no packet path to a turn-in at all: its only route was RpgEndQuestTrigger,
    // which needs the questgiver to already be the chosen rpg target. Measured over 2h16m with
    // 2005 bots, TalkToQuestGiverAction ran 27 times - the human's group - while
    // 10598 finished quests sat in bot logs waiting to be handed in, 265 bots
    // pinned at the 20-quest cap by them.
    //
    // This trigger asks the cheaper question instead: is a hand-in possible right
    // here, right now. It is deliberately as narrow as the action it drives, so a
    // fired trigger means work exists rather than work might exist somewhere.
    triggers.push_back(new TriggerNode(
        "val::can turn in quest nearby",
        NextAction::array(0, new NextAction("talk to quest giver", relevance), NULL)));
};

void DefaultQuestStrategy::InitNonCombatTriggers(std::list<TriggerNode*> &triggers)
{
    QuestStrategy::InitNonCombatTriggers(triggers);

    triggers.push_back(new TriggerNode(
        "use game object",
        NextAction::array(0,
            new NextAction("talk to quest giver", relevance), NULL)));

    triggers.push_back(new TriggerNode(
        "gossip hello",
        NextAction::array(0,
            new NextAction("talk to quest giver", relevance), NULL)));

    triggers.push_back(new TriggerNode(
        "complete quest",
        NextAction::array(0, new NextAction("talk to quest giver", relevance), NULL)));
}

void AcceptAllQuestsStrategy::InitNonCombatTriggers(std::list<TriggerNode*> &triggers)
{
    QuestStrategy::InitNonCombatTriggers(triggers);

    triggers.push_back(new TriggerNode(
        "use game object",
        NextAction::array(0,
            new NextAction("talk to quest giver", relevance), new NextAction("accept all quests", relevance), NULL)));

    triggers.push_back(new TriggerNode(
        "gossip hello",
        NextAction::array(0,
            new NextAction("talk to quest giver", relevance), new NextAction("accept all quests", relevance), NULL)));

    triggers.push_back(new TriggerNode(
        "complete quest",
        NextAction::array(0, 
            new NextAction("talk to quest giver", relevance), new NextAction("accept all quests", relevance), NULL)));
}
