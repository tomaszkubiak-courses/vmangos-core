
#include "playerbot/playerbot.h"
#include "FishValues.h"

using namespace ai;

bool CanFishValue::Calculate()
{
    if (!bot->GetSkill(SKILL_FISHING, false, false)) //Unable to fish.
        return false;

    std::list<Item*> poles = AI_VALUE2(std::list<Item*>, "inventory items", "fishing pole");

    if (poles.empty()) //No fishing pole.
        return false;

    // Owning a pole is not the same as being able to hold one - a pole below the bot's
    // fishing skill, or one it cannot equip right now, makes every fishing action a no-op.
    // Saying yes anyway is how bots were sent across a continent to stand at water they
    // could never fish.
    for (Item* pole : poles)
    {
        if (pole->IsEquipped() && pole->GetSlot() == EQUIPMENT_SLOT_MAINHAND)
            return true;

        uint16 dest;
        if (bot->CanEquipItem(NULL_SLOT, dest, pole, true) == EQUIP_ERR_OK)
            return true;
    }

    return false; //No pole the bot can wield.
}

bool CanOpenFishingDobberValue::Calculate()
{
    if (!bot->GetCurrentSpell(CURRENT_CHANNELED_SPELL))
        return false;

    std::string spellName = bot->GetCurrentSpell(CURRENT_CHANNELED_SPELL)->m_spellInfo->SpellName[0];
    if (spellName.find("Fishing") != 0)
        return false;

    return true;
}

bool DoneFishingValue::Calculate()
{
    if (!bot->GetSkill(SKILL_FISHING, false, false)) //Unable to fish.
        return false;

    Item* mhItem = bot->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_MAINHAND);

    //Does not have fishing pole equiped.
    if (!mhItem || mhItem->GetProto()->Class != ITEM_CLASS_WEAPON || mhItem->GetProto()->SubClass != ITEM_SUBCLASS_WEAPON_FISHING_POLE)
        return false;

    if (bot->GetCurrentSpell(CURRENT_CHANNELED_SPELL))
    {
        std::string spellName = bot->GetCurrentSpell(CURRENT_CHANNELED_SPELL)->m_spellInfo->SpellName[0];
        if (spellName.find("Fishing") == 0)
            return false;
    }

    // Standing at a fishing spot between two casts is not being finished. This value drives the
    // "put your real gear back on" trigger, so answering yes in the gap made the upgrade sweep
    // pull the pole out of the bot's hand, which the fishing strategy answered by putting it back
    // - a ping-pong that ran for hours. The spot is what says the bot still means to fish; it is
    // cleared once a catch ends the session.
    if (AI_VALUE2(WorldPosition, "custom position", "fish spot"))
        return false;

    return true;
}


