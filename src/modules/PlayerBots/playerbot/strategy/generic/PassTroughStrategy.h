#pragma once

namespace ai
{
    class PassTroughStrategy : public Strategy
    {
    public:
        PassTroughStrategy(PlayerbotAI* ai, float relevance = ACTION_PASSTROUGH) : Strategy(ai), relevance(relevance) {}

    protected:
        virtual void InitNonCombatTriggers(std::list<TriggerNode*> &triggers) override
        {
            for (std::list<std::string>::iterator i = supported.begin(); i != supported.end(); i++)
            {
                std::string s = i->c_str();
            }
        }

        virtual void InitCombatTriggers(std::list<TriggerNode*>& triggers) override
        {
            for (std::list<std::string>::iterator i = supported.begin(); i != supported.end(); i++)
            {
                std::string s = i->c_str();
            }
        }

        virtual void InitDeadTriggers(std::list<TriggerNode*>& triggers) override
        {
            for (std::list<std::string>::iterator i = supported.begin(); i != supported.end(); i++)
            {
                std::string s = i->c_str();
            }
        }

    protected:
        std::list<std::string> supported;
        float relevance;
    };
}
