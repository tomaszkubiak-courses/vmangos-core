#pragma once

#include "playerbot/strategy/Action.h"

namespace ai
{
    // From cmangos/playerbots 511efbfd. Tells the master why a purchase from a vendor failed, read
    // from SMSG_BUY_FAILED (vendor guid, item entry, BuyResult).
    class BuyFailedAction : public Action
    {
    public:
        BuyFailedAction(PlayerbotAI* ai) : Action(ai, "buy failed") {}

        virtual bool Execute(Event& event) override
        {
            Player* requester = event.getOwner() ? event.getOwner() : GetMaster();
            if (!requester)
                return false;

            WorldPacket p(event.getPacket());
            if (p.size() < 8 + 4 + 1)
                return false;

            ObjectGuid vendorGuid;
            uint32 itemId;
            uint8 err;
            p.rpos(0);
            p >> vendorGuid >> itemId >> err;

            std::string const msg = GetMessage(err);
            if (msg.empty())
                return false;

            ai->TellError(requester, msg);
            return true;
        }

    private:
        static std::string GetMessage(uint8 err)
        {
            switch (err)
            {
                case BUY_ERR_CANT_FIND_ITEM:       return "Can't find the item.";
                case BUY_ERR_ITEM_ALREADY_SOLD:    return "The item is already sold.";
                case BUY_ERR_NOT_ENOUGHT_MONEY:    return "I don't have enough money.";
                case BUY_ERR_SELLER_DONT_LIKE_YOU: return "The seller doesn't like me.";
                case BUY_ERR_DISTANCE_TOO_FAR:     return "I'm too far away from the seller.";
                case BUY_ERR_ITEM_SOLD_OUT:        return "The item is already sold out.";
                case BUY_ERR_CANT_CARRY_MORE:      return "I can't carry any more of this item.";
                case BUY_ERR_RANK_REQUIRE:         return "I don't have the rank required for this item.";
                case BUY_ERR_REPUTATION_REQUIRE:   return "I don't have enough reputation for this item.";
                default:                           return "";
            }
        }
    };
}
