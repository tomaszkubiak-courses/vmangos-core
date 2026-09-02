
#include "playerbot/playerbot.h"
#include "EquipAction.h"

#include "playerbot/RandomItemMgr.h"
#include "playerbot/strategy/values/ItemCountValue.h"
#include "playerbot/strategy/values/ItemUsageValue.h"
#include "UnequipAction.h"

using namespace ai;

bool EquipAction::Execute(Event& event)
{
    Player* requester = event.getOwner() ? event.getOwner() : GetMaster();
    std::string text = event.getParam();
    if (text == "?")
    {
        ListItems(requester);
        return true;
    }

    uint8 targetSlot = NULL_SLOT;
    if (text.find("mh ") == 0)
    {
        targetSlot = EQUIPMENT_SLOT_MAINHAND;
        text = text.substr(3);
    }
    else if (text.find("oh ") == 0)
    {
        targetSlot = EQUIPMENT_SLOT_OFFHAND;
        text = text.substr(3);
    }

    ItemIds ids = chat->parseItems(text);
    if (ids.empty())
    {
        //Get items based on text.
        std::list<Item*> found = ai->InventoryParseItems(text, IterateItemsMask::ITERATE_ITEMS_IN_BAGS);

        //Sort items on itemLevel descending.
        found.sort([](Item* i, Item* j) {return i->GetProto()->ItemLevel > j->GetProto()->ItemLevel; });

        std::vector< uint16> dests;
        for (auto& item : found)
        {
            uint32 itemId = item->GetProto()->ItemId;
            if (std::find(ids.begin(), ids.end(), itemId) != ids.end())
            {
                continue;
            }

            uint16 dest;
            InventoryResult msg = bot->CanEquipItem(targetSlot, dest, item, true);

            if (msg != EQUIP_ERR_OK)
            {
                continue;
            }

            if (std::find(dests.begin(), dests.end(), dest) != dests.end())
            {
                continue;
            }

            dests.push_back(dest);
            ids.insert(itemId);
        }
    }

    if (targetSlot != NULL_SLOT)
    {
        EquipItemsToSlot(requester, ids, targetSlot);
    }
    else
    {
        EquipItems(requester, ids);
    }
    return true;
}

void EquipAction::ListItems(Player* requester)
{
    ai->TellPlayer(requester, "=== Equip ===");

    std::map<uint32, int> items;
    std::map<uint32, bool> soulbound;
    for (int i = EQUIPMENT_SLOT_START; i < EQUIPMENT_SLOT_END; ++i)
    {
        if (Item* pItem = bot->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
        {
            if (pItem)
            {
                items[pItem->GetProto()->ItemId] += pItem->GetCount();
            }
        }
    }

    ai->InventoryTellItems(requester, items, soulbound);
}

void EquipAction::EquipItems(Player* requester, ItemIds ids)
{
    for (ItemIds::iterator i = ids.begin(); i != ids.end(); i++)
    {
        FindItemByIdVisitor visitor(*i);
        EquipItem(requester, &visitor);        
    }
}

void EquipAction::EquipItemsToSlot(Player* requester, ItemIds ids, uint8 targetSlot)
{
    for (ItemIds::iterator i = ids.begin(); i != ids.end(); i++)
    {
        FindItemByIdVisitor visitor(*i);
        ai->InventoryIterateItems(&visitor, IterateItemsMask::ITERATE_ITEMS_IN_BAGS);
        std::list<Item*> items = visitor.GetResult();
        if (!items.empty())
        {
            EquipItemToSlot(requester, *items.begin(), targetSlot);
        }
    }
}

void EquipAction::EquipItem(Player* requester, FindItemVisitor* visitor)
{
    ai->InventoryIterateItems(visitor, IterateItemsMask::ITERATE_ITEMS_IN_BAGS);
    std::list<Item*> items = visitor->GetResult();
	if (!items.empty()) 
    {
        EquipItem(ai, requester, *items.begin());
    }
}

//Return the bag slot with smallest bag
uint8 EquipAction::GetSmallestBagSlot(Player* bot)
{
    int8 curBag = 0;
    uint32 curSlots = 0;
    for (uint8 bag = INVENTORY_SLOT_BAG_START; bag < INVENTORY_SLOT_BAG_END; ++bag)
    {
        const Bag* const pBag = (Bag*)bot->GetItemByPos(INVENTORY_SLOT_BAG_0, bag);
        if (pBag)
        {
            if (curBag > 0 && curSlots < pBag->GetBagSize())
            {
                continue;
            }
            
            curBag = bag;
            curSlots = pBag->GetBagSize();
        }
        else
        {
            return bag;
        }
    }

    return curBag;
}

void EquipAction::EquipItemToSlot(Player* requester, Item* item, uint8 targetSlot)
{
    uint8 bagIndex = item->GetBagSlot();
    uint8 slot = item->GetSlot();
    uint32 itemId = item->GetProto()->ItemId;

    uint16 dest;
    InventoryResult msg = bot->CanEquipItem(targetSlot, dest, item, true);
    if (msg != EQUIP_ERR_OK)
    {
        bot->SendEquipError(msg, item, nullptr);
        return;
    }

    uint8 destSlot = dest & 0xFF;
    if (destSlot != targetSlot)
    {
        ai->TellPlayer(requester, "Cannot equip this item to the specified slot.");
        return;
    }

    Item* oldItem = bot->GetItemByPos(INVENTORY_SLOT_BAG_0, targetSlot);
    Item* oldOffhand = nullptr;
    if (destSlot == EQUIPMENT_SLOT_MAINHAND && item->GetProto()->InventoryType == INVTYPE_2HWEAPON)
        oldOffhand = bot->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_OFFHAND);

    uint16 src = ((bagIndex << 8) | slot);
    uint16 dstPos = ((INVENTORY_SLOT_BAG_0 << 8) | targetSlot);

    bot->SwapItem(src, dstPos);

    RESET_AI_VALUE2(ItemUsage, "item usage", ItemQualifier(item).GetQualifier());

    if (oldItem)
        RESET_AI_VALUE2(ItemUsage, "item usage", ItemQualifier(oldItem).GetQualifier());
    if (oldOffhand)
        RESET_AI_VALUE2(ItemUsage, "item usage", ItemQualifier(oldOffhand).GetQualifier());

    sPlayerbotAIConfig.logEvent(ai, "EquipAction", item->GetProto()->Name1, std::to_string(item->GetProto()->ItemId));

    std::map<std::string, std::string> args;
    args["%item"] = chat->formatItem(item);
    ai->TellPlayer(requester, BOT_TEXT2("equip_command", args), PlayerbotSecurityLevel::PLAYERBOT_SECURITY_ALLOW_ALL, false);
}

bool EquipAction::EquipItem(PlayerbotAI* ai, Player* requester, Item* item, bool silent)
{
    Player* bot = ai->GetBot();
    AiObjectContext* context = ai->GetAiObjectContext();

    uint8 bagIndex = item->GetBagSlot();
    uint8 slot = item->GetSlot();
    uint32 itemId = item->GetProto()->ItemId;

    uint16 dest;
    InventoryResult result = bot->CanEquipItem(NULL_SLOT, dest, item, !item->IsBag());

    // CanEquipItem's verdict used to be read only to work out which item was being
    // replaced, and the auto-equip packet went out whether or not the equip could
    // succeed. A refused equip leaves the item exactly where it was, so any caller that
    // repeats while the item is not yet worn fires again on the very next tick - and the
    // event log recorded every one of those attempts as a successful EquipAction. Four
    // bots spent a night that way, one of them re-equipping the same fishing pole 55104
    // times over six hours without moving. Containers and quivers are exempt because the
    // branch below deliberately displaces an equipped bag, which CanEquipItem refuses;
    // ammo never goes through an equipment slot at all.
    bool const isBagLike = item->GetProto()->Class == ITEM_CLASS_CONTAINER || item->GetProto()->Class == ITEM_CLASS_QUIVER;
    if (result != EQUIP_ERR_OK && !isBagLike && item->GetProto()->InventoryType != INVTYPE_AMMO)
        return false;

    Item* oldItem = nullptr;
    Item* oldOffhand = nullptr;
    if (result == EQUIP_ERR_OK)
    {
        oldItem = bot->GetItemByPos(dest);

        if (oldItem && oldItem->GetSlot() == EQUIPMENT_SLOT_MAINHAND && item->GetProto()->InventoryType == INVTYPE_2HWEAPON)
            oldOffhand = bot->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_OFFHAND);
    }

    if (item->GetProto()->InventoryType == INVTYPE_AMMO)
    {
        bot->SetAmmo(itemId);
    }
    else
    {
        bool equipedBag = false;
        if (item->GetProto()->Class == ITEM_CLASS_CONTAINER || item->GetProto()->Class == ITEM_CLASS_QUIVER)
        {
            uint8 newBagSlot = GetSmallestBagSlot(bot);

            // GetSmallestBagSlot hands back a free bag slot when there is one, and
            // otherwise the slot holding the smallest equipped bag. Displacing that
            // second kind only works while it is empty: _CanStoreItem_InSpecificSlot
            // refuses to move a non-empty bag (it is guarded as a dupe exploit) and
            // SwapItem reports nothing back, so the code below used to set
            // equipedBag = true for a swap that never happened - and the same
            // decision then fired again on the very next tick. One bot was seen
            // retrying about six times a second for hours, and every attempt logged
            // an anticheat entry. Leave the smaller bag alone until it empties.
            Item* const oldBag = newBagSlot > 0 ? bot->GetItemByPos(INVENTORY_SLOT_BAG_0, newBagSlot) : nullptr;
            const bool oldBagIsFull = oldBag && oldBag->IsBag() && !((Bag*)oldBag)->IsEmpty();

            if (newBagSlot > 0 && !oldBagIsFull)
            {
                uint16 src = ((bagIndex << 8) | slot);

                if (newBagSlot == item->GetBagSlot()) //The new bag is in the slots of the old bag. Move it to the pack first.
                {
                    uint16 dst = ((INVENTORY_SLOT_BAG_0 << 8) | INVENTORY_SLOT_ITEM_START);
                    bot->SwapItem(src, dst);
                    src = dst;
                }

                uint16 dst = ((INVENTORY_SLOT_BAG_0 << 8) | newBagSlot);
                bot->SwapItem(src, dst);
                equipedBag = true;
            }
        }

        if (!equipedBag)
        {
            ObjectGuid const itemGuid = item->GetObjectGuid();

            WorldPacket packet(CMSG_AUTOEQUIP_ITEM, 2);
            packet << bagIndex << slot;
            bot->GetSession()->BotHandleAutoEquipItemOpcode(packet);

            // The opcode handler reports nothing back and a refused auto-equip leaves the item
            // exactly where it was, so CanEquipItem agreeing above is not proof the item is now
            // worn. Callers that repeat while it is not - the upgrade sweep does, once per stack
            // of the same item - fired again on the very next tick, and every attempt was logged
            // as a successful equip. Check the destination slot before claiming anything.
            // dest only holds a slot when CanEquipItem agreed; the bag and quiver cases that
            // reach here in spite of a refusal have no destination to check.
            if (result == EQUIP_ERR_OK)
            {
                Item* const equipped = bot->GetItemByPos(dest);
                if (!equipped || equipped->GetObjectGuid() != itemGuid)
                    return false;
            }
        }
    }

    RESET_AI_VALUE2(ItemUsage, "item usage", ItemQualifier(item).GetQualifier());

    if (oldItem)
        RESET_AI_VALUE2(ItemUsage, "item usage", ItemQualifier(oldItem).GetQualifier());
    if (oldOffhand)
        RESET_AI_VALUE2(ItemUsage, "item usage", ItemQualifier(oldOffhand).GetQualifier());

    sPlayerbotAIConfig.logEvent(ai, "EquipAction", item->GetProto()->Name1, std::to_string(item->GetProto()->ItemId));

    if (!silent)
    {
        std::map<std::string, std::string> args;
        args["%item"] = ChatHelper::formatItem(item);
        ai->TellPlayer(requester, BOT_TEXT2("equip_command", args), PlayerbotSecurityLevel::PLAYERBOT_SECURITY_ALLOW_ALL, false);
    }

    return true;
}

bool EquipUpgradesAction::Execute(Event& event)
{
    if (!sPlayerbotAIConfig.autoEquipUpgradeLoot && !sRandomPlayerbotMgr.IsRandomBot(bot))
        return false;

    if (event.getSource() == "trade status")
    {
        WorldPacket p(event.getPacket());
        p.rpos(0);
        uint32 status;
        p >> status;

        if (status != TRADE_STATUS_TRADE_ACCEPT)
        {
            return false;
        }
    }
    else if (event.getSource() == "item push result")
    {
        bool valid = false;
        WorldPacket& data = event.getPacket();
        if (!data.empty())
        {
            data.rpos(0);

            ObjectGuid guid;
            data >> guid;
            if (guid != bot->GetObjectGuid())
            {
                return false;
            }

            uint32 received, created, isShowChatMessage, slotId, itemId, suffixFactor, count;
            uint32 itemRandomPropertyId;
            //uint32 invCount;
            uint8 bagSlot;

            data >> received;                               // 0=looted, 1=from npc
            data >> created;                                // 0=received, 1=created
            data >> isShowChatMessage;                                      // IsShowChatMessage
            data >> bagSlot;
            // item slot, but when added to stack: 0xFFFFFFFF
            data >> slotId;
            data >> itemId;
            data >> suffixFactor;
            data >> itemRandomPropertyId;
            data >> count;
            // data >> invCount; // [-ZERO] count of items in inventory

            ItemQualifier itemQualifier(itemId, (int32)itemRandomPropertyId);
            const ItemPrototype* itemProto = itemQualifier.GetProto();
            if (itemProto && (itemProto->Class == ItemClass::ITEM_CLASS_WEAPON || 
                              itemProto->Class == ItemClass::ITEM_CLASS_ARMOR ||
                              itemProto->Class == ItemClass::ITEM_CLASS_CONTAINER))
            {
                valid = true;
            }
        }

        if (!valid)
        {
            return false;
        }
    }

    Item* oldMainhand = bot->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_MAINHAND);
    Item* oldOffhand = bot->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_OFFHAND);
        
    if (oldMainhand)
        UnequipAction::UnequipItem(ai, bot, oldMainhand, true);
    if (oldOffhand)
        UnequipAction::UnequipItem(ai, bot, oldOffhand, true);

    context->ClearExpiredValues("item usage", 10); //Clear old item usage.

    std::list<Item*> items;

    FindItemUsageVisitor visitor(bot, ItemUsage::ITEM_USAGE_EQUIP);
    ai->InventoryIterateItems(&visitor, IterateItemsMask::ITERATE_ITEMS_IN_BAGS);
    visitor.SetUsage(ItemUsage::ITEM_USAGE_BAD_EQUIP);
    ai->InventoryIterateItems(&visitor, IterateItemsMask::ITERATE_ITEMS_IN_BAGS);
    items = visitor.GetResult();

    bool didEquip = false;

    items.sort([plr = bot](Item* i, Item* j) {
        bool iMain = i->GetProto()->InventoryType == INVTYPE_WEAPONMAINHAND;
        bool jMain = j->GetProto()->InventoryType == INVTYPE_WEAPONMAINHAND;

        if (iMain != jMain)
            return iMain; // mainhand comes first

        return sRandomItemMgr.ItemStatWeight(plr, i) > sRandomItemMgr.ItemStatWeight(plr, j); });

    for (auto& item : items)
    {
#ifdef MANGOSBOT_TWO
        if (item->GetProto()->Class == ITEM_CLASS_GLYPH)
            continue;
#endif

        // A fishing pole is a tool, not gear. The fishing strategy puts one in the main hand on
        // purpose, and this sweep - which empties the main hand before it starts - then rated the
        // pole as the best thing available for the now empty slot and handed it straight back.
        // The fishing strategy took it as its cue to fish again, and the two traded the same pole
        // in and out at tick rate: three bots did that 55000 times in one night.
        if (item->GetProto()->Class == ITEM_CLASS_WEAPON && item->GetProto()->SubClass == ITEM_SUBCLASS_WEAPON_FISHING_POLE)
            continue;

        // Swapping in another stack of what is already worn changes nothing. Thrown weapons come
        // in stacks of 200 and a bot that had bought 46 of them equipped every single one on each
        // sweep, because each stack is a separate item and each looked like an upgrade for a slot
        // holding, by then, an identical dagger.
        uint16 sameItemDest;
        if (bot->CanEquipItem(NULL_SLOT, sameItemDest, item, true) == EQUIP_ERR_OK)
        {
            Item* const current = bot->GetItemByPos(sameItemDest);
            if (current && current != item && current->GetEntry() == item->GetEntry())
                continue;
        }

        ItemUsage usage = AI_VALUE2(ItemUsage, "item usage", ItemQualifier(item).GetQualifier());
        if (usage == ItemUsage::ITEM_USAGE_EQUIP || usage == ItemUsage::ITEM_USAGE_BAD_EQUIP)
        {
            sLog.outDetail("Bot #%d <%s> auto equips item %d (%s)", bot->GetGUIDLow(), bot->GetName(), item->GetProto()->ItemId, usage == ItemUsage::ITEM_USAGE_EQUIP ? "better than current" : usage == ItemUsage::ITEM_USAGE_BAD_EQUIP ? "wrong item but empty slot" : "");
            ai->TellDebug(ai->GetMaster(), "Equipping: " + chat->formatItem(item) + " - " + ItemUsageValue::ReasonForNeed(usage, item, 1, bot), "debug equip");

            EquipItem(ai, GetMaster(), item, item == oldMainhand || item == oldOffhand);   
            didEquip = true;
        }
    }

    // Check if main-hand has higher top-end damage than off-hand
    if (didEquip && bot->CanDualWield())
    {
        Item* mh = bot->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_MAINHAND);
        Item* oh = bot->GetItemByPos(INVENTORY_SLOT_BAG_0, EQUIPMENT_SLOT_OFFHAND);

        if (mh && oh
            && mh->GetProto()->Class == ITEM_CLASS_WEAPON
            && oh->GetProto()->Class == ITEM_CLASS_WEAPON
            && mh->GetProto()->InventoryType != INVTYPE_2HWEAPON)
        {
            float mhMaxDmg = mh->GetProto()->Damage[0].DamageMax;
            float ohMaxDmg = oh->GetProto()->Damage[0].DamageMax;

            if (ohMaxDmg > mhMaxDmg)
            {
                uint16 srcPos = ((INVENTORY_SLOT_BAG_0 << 8) | EQUIPMENT_SLOT_MAINHAND);
                uint16 dstPos = ((INVENTORY_SLOT_BAG_0 << 8) | EQUIPMENT_SLOT_OFFHAND);
                bot->SwapItem(srcPos, dstPos);

                sLog.outDetail("Bot #%d <%s> swapped MH/OH weapons to put higher top-end damage (%.1f) in main hand",
                    bot->GetGUIDLow(), bot->GetName(), ohMaxDmg);
            }
        }
    }

    return didEquip;
}
