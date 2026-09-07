#include "playerbot/playerbot.h"
#include "RacialsStrategy.h"

using namespace ai;

// Every node here used to be registered for every bot, so a human paladin was asked about
// War Stomp and a tauren about Stoneform on every tick of every fight. The action then
// answered "impossible" because the bot does not know the spell, and the answer was
// recomputed from scratch the next tick. In a nine and a half hour run that cost 3825352
// evaluations of "war stomp" alone, 3797202 of them impossible, plus another 3.79 million
// for the "reach spell" prerequisite behind it; stoneform, perception, escape artist and
// cannibalize added 2.75 million more between them. A racial is granted at character
// creation, so the bot's race is a complete answer to whether it has one, and answering it
// once at strategy init costs nothing.
void RacialsStrategy::InitNonCombatTriggers(std::list<TriggerNode*> &triggers)
{
    uint8 const race = ai->GetBot()->GetRace();

    if (race == RACE_TAUREN)
    {
        triggers.push_back(new TriggerNode(
            "melee medium aoe",
            NextAction::array(0, new NextAction("war stomp", 71.0f), NULL)));

        triggers.push_back(new TriggerNode(
            "war stomp",
            NextAction::array(0, new NextAction("war stomp", 71.0f), NULL)));
    }

    if (race == RACE_UNDEAD)
    {
        triggers.push_back(new TriggerNode(
            "cannibalize",
            NextAction::array(0, new NextAction("cannibalize", 71.0f), NULL)));

        triggers.push_back(new TriggerNode(
            "will of the forsaken",
            NextAction::array(0, new NextAction("will of the forsaken", 71.0f), NULL)));
    }

    if (race == RACE_HUMAN)
    {
        triggers.push_back(new TriggerNode(
            "perception",
            NextAction::array(0, new NextAction("perception", 71.0f), NULL)));
    }

    if (race == RACE_GNOME)
    {
        triggers.push_back(new TriggerNode(
            "rooted",
            NextAction::array(0, new NextAction("escape artist", 71.0f), NULL)));
    }

    // Deliberately disabled, independently of the race gate: restoring it means picking a
    // relevance, not just uncommenting.
    /*if (race == RACE_NIGHTELF)
    {
        triggers.push_back(new TriggerNode(
            "shadowmeld",
            NextAction::array(0, new NextAction("shadowmeld", 71.0f), NULL)));
    }*/

    if (race == RACE_TROLL)
    {
        triggers.push_back(new TriggerNode(
            "berserking",
            NextAction::array(0, new NextAction("berserking", 58.0f), NULL)));
    }

    if (race == RACE_ORC)
    {
        triggers.push_back(new TriggerNode(
            "blood fury",
            NextAction::array(0, new NextAction("blood fury", 71.0f), NULL)));
    }

    if (race == RACE_DWARF)
    {
        triggers.push_back(new TriggerNode(
            "stoneform",
            NextAction::array(0, new NextAction("stoneform", 71.0f), NULL)));
    }

    // Mana Tap and Arcane Torrent are blood elf racials and there is no blood elf here, so
    // the nodes that used to sit at the end of this list are gone rather than gated.
}

void RacialsStrategy::InitCombatTriggers(std::list<TriggerNode*>& triggers)
{
    InitNonCombatTriggers(triggers);
}
