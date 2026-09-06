
#include "playerbot/playerbot.h"
#include "TravelStrategy.h"
#include "playerbot/TravelMgr.h"

using namespace ai;

float TravelActionMultiplier::GetValue(Action* action)
{
    if (action == NULL) return 1.0f;

    bool hasTarget = AI_VALUE(bool, "travel target active");
    std::string name = action->getName();

    if (hasTarget && name.find("request") == 0)
    {
        if (name.find("guild meeting") != std::string::npos)
            return 1.0f;
        if (name.find("reagent vendor") != std::string::npos)
            return 1.0f;
        if (name.find("guild order") != std::string::npos)
            return 1.0f;

        return 0.0f;
    }

    return 1.0f;
}

void TravelStrategy::InitNonCombatMultipliers(std::list<Multiplier*>& multipliers)
{
    multipliers.push_back(new TravelActionMultiplier(ai));
}

NextAction** TravelStrategy::GetDefaultNonCombatActions()
{
    return NextAction::array(0, new NextAction("travel", 1.0f), NULL);
}

void TravelStrategy::InitNonCombatTriggers(std::list<TriggerNode*>& triggers)
{
    //The way these actions work:
    //One of these request target actions will trigger and start fetching destinations. 
    //While fetching no other travel action will be usefull except choose travel target.
    //Choose travel target will wait for the fetching to complete and then set a new target.
    //If no target was found the request action is marked as no targets found and can no longer trigger until reset.
    //The next request action will then trigger until a good target is found.
    //If no targets are found reset will clear all actions and start from the top.

    //All the standard choose travel target actions using either a specific val trigger or a generic purpose trigger.
    const std::vector<std::tuple<std::string, TravelDestinationPurpose, float>> PurposeActions =
    {        
        {"",TravelDestinationPurpose::AH, 6.95f},                                                //See isAllowed  90%
        {"",TravelDestinationPurpose::Vendor, 6.94f},                                                          // 90%
        {"",TravelDestinationPurpose::Repair, 6.93f},                                                          // 90%
        {"val::and::{should get money,can get mail,should get mail}", TravelDestinationPurpose::Mail, 6.79f},  //100%
        {"val::should get money", TravelDestinationPurpose::Grind, 6.77f},                                     // 90%
        {"",TravelDestinationPurpose::Mail, 6.6f},                                                             // 30%
        {"",TravelDestinationPurpose::GatherMining, 6.5f},                                                     // 90%/40% in group
        {"",TravelDestinationPurpose::GatherSkinning, 6.5f},                                                   // 90%/40% in group
        {"",TravelDestinationPurpose::GatherHerbalism, 6.5f},                                                  // 90%/40% in group
        {"",TravelDestinationPurpose::GatherFishing, 6.5f},                                                    // 90%/40% in group
        {"",TravelDestinationPurpose::Boss, 6.4f},                                                             // 50%
        // Grind was 6.27 here - dead last, one step below GenericRpg (6.28). Live data
        // (bot_intention.csv over a 7hr/20-bot run) confirmed this: GenericRpg got picked
        // over 2x as often as Grind (5.4% vs 2.5% of samples) whenever a bot had any
        // active travel purpose at all. Moved above Explore/GenericRpg so unconditional
        // grinding wins that priority race instead of losing to aimless wandering.
        {"",TravelDestinationPurpose::Grind, 6.35f},                                                          // 100%
        {"",TravelDestinationPurpose::Explore, 6.29f},                                                         // 10%
        {"",TravelDestinationPurpose::GenericRpg, 6.28f},                                                      // 50%
    };

    for (auto& [condition, purpose, relevance] : PurposeActions)
    {
        std::string trigger = condition.empty() ? "val::need travel purpose::" + std::to_string((uint32)purpose) : condition;
        triggers.push_back(new TriggerNode(
            trigger,
            NextAction::array(0, new NextAction("request travel target::" + std::to_string((uint32)purpose), relevance), NULL)));
    }

    //Specific named exceptions
    const std::vector<std::tuple<std::string, std::string, float>> StringActions =
    {
        {"val::should travel named::trainer class","request named travel target::trainer class", 6.89f},      // See isAllowed   25%
        //{"val::should travel named::trainer pet","request named travel target::trainer pet", 6.88f},        // 25%
        {"val::should travel named::trainer mount","request named travel target::trainer mount", 6.87f},      // 25%
        {"val::should travel named::mount","request named travel target::mount", 6.86f},                      // 25%
        {"val::should travel named::city","request named travel target::city", 6.85f},                        // 10%
        {"val::and::{has strategy::rpg quest,has focus travel target}","request quest travel target", 6.84f}, //100%
        {"val::should travel named::pvp","request named travel target::pvp", 6.83f},                          // 25%
        {"val::should travel named::guild meeting","request named travel target::guild meeting", 6.96f},      //100%
        {"val::should travel named::reagent vendor","request named travel target::reagent vendor", 6.955f},   //100%
        {"val::should travel named::guild order","request named travel target::guild order", 6.95f},          //100%
        {"val::and::{has strategy::rpg quest,should get money}", "request quest travel target", 6.78f},       // 90%
        {"val::not::travel target active","refresh travel target", 6.7f},                                     // 90%
        {"val::not::travel target active","choose group travel target", 6.65f},                               // 50%
        {"val::should travel named::trainer trade","request named travel target::trainer trade", 6.51f},      // 25%
        // Plain quest travel was 6.3 - below Grind 6.35, Boss 6.4, all four
        // Gather 6.5, Mail 6.6/6.79, grind-for-money 6.77 and trainer class 6.89.
        // Every one of those is satisfiable at all times, so the unconditional
        // quest entry only reached the queue when nothing else wanted the slot:
        // 203 of 8365 travel targets over 2h16m with 2005 bots, 2.4%. The effect
        // is not that bots quest slowly, it is that they stop. They accept quests
        // from whatever they walk past, finish the objectives while grinding, and
        // never travel back to hand in - 10598 quest rows sat at
        // QUEST_STATUS_COMPLETE, 265 bots were pinned at the 20-quest cap, and
        // zero bots gained a level in that run.
        //
        // The hand-in logic itself is already correct: RequestQuestTravelTargetAction
        // forces QuestTaker-only fetches once a bot carries five finished quests or
        // is two short of the cap. It just almost never got to execute. Priced above
        // trainer class so it competes with the always-true purposes, and left below
        // Repair/Vendor/AH (6.93+) and the guild entries, which are genuine blockers
        // rather than pastimes. Note this makes the two narrower quest entries
        // above (6.84 focus target, 6.78 needs money) unreachable - same action,
        // stricter trigger, lower relevance. They are left in place rather than
        // deleted so the priced-down alternative is still visible if this entry
        // has to be walked back.
        {"val::has strategy::rpg quest", "request quest travel target", 6.90f}                                // 95%
    };

    for (auto& [trigger, action, relevance] : StringActions)
    {
        triggers.push_back(new TriggerNode(
            trigger,
            NextAction::array(0, new NextAction(action, relevance), NULL)));
    }

    triggers.push_back(new TriggerNode(
        "val::not::travel target active",
        NextAction::array(0, new NextAction("choose travel target", 6.98f), NULL)));

    triggers.push_back(new TriggerNode(
        "val::not::travel target active",
        NextAction::array(0, new NextAction("reset travel target", 6.0f), NULL)));

    triggers.push_back(new TriggerNode(
        "has nearby quest taker",
        NextAction::array(0, new NextAction("reset travel target", 6.99f), NULL)));

    triggers.push_back(new TriggerNode(
        "val::travel target ready",
        NextAction::array(0, new NextAction("check mount state", 1), new NextAction("move to travel target", 1), NULL)));

    triggers.push_back(new TriggerNode(
        "val::travel target traveling",
        NextAction::array(0, new NextAction("check mount state", 1), new NextAction("move to travel target", 1), NULL)));

    triggers.push_back(new TriggerNode(
        "often",
        NextAction::array(0, new NextAction("travel", 1), NULL)));
}

void TravelOnceStrategy::InitNonCombatTriggers(std::list<TriggerNode*>& triggers)
{   
    triggers.push_back(new TriggerNode(
        "val::travel target traveling",
        NextAction::array(0, new NextAction("check mount state", 1), new NextAction("move to travel target", 1), NULL)));
}