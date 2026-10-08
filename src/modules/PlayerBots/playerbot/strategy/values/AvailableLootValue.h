#pragma once
#include "playerbot/strategy/Value.h"
#include "playerbot/LootObjectStack.h"
#include "playerbot/ServerFacade.h"

namespace ai
{

    class AvailableLootValue : public ManualSetValue<LootObjectStack*>
	{
	public:
        AvailableLootValue(PlayerbotAI* ai, std::string name = "available loot") : ManualSetValue<LootObjectStack*>(ai, NULL, name)
        {
            value = new LootObjectStack(bot);
        }

        virtual ~AvailableLootValue() override
        {
            if (value)
                delete value;
        }
    };

    class LootTargetValue : public ManualSetValue<LootObject>
    {
    public:
        LootTargetValue(PlayerbotAI* ai, std::string name = "loot target") : ManualSetValue<LootObject>(ai, LootObject(), name) {}
    };

    class CanLootValue : public BoolCalculatedValue
    {
    public:
        CanLootValue(PlayerbotAI* ai, std::string name = "can loot") : BoolCalculatedValue(ai, name) {}

        virtual bool Calculate() override
        {
            LootObject loot = AI_VALUE(LootObject, "loot target");

            // Not while a cast is under way: the bot's own gathering or skinning cast is still
            // running when the node is offered again, and a second cast is refused with
            // "Another action is in progress".
            return !loot.IsEmpty() &&
                    !bot->IsNonMeleeSpellCasted(false, true, true) &&
                    loot.IsLootPossible(bot) &&
                    loot.IsInReach(bot);
        }
    };
}
