#pragma once
#include "MovementActions.h"

namespace ai
{
	class ReviveFromCorpseAction : public MovementAction 
    {
	public:
		ReviveFromCorpseAction(PlayerbotAI* ai) : MovementAction(ai, "revive from corpse") {}
        virtual bool Execute(Event& event) override;
    };

    class FindCorpseAction : public MovementAction
    {
    public:
        FindCorpseAction(PlayerbotAI* ai) : MovementAction(ai, "find corpse"), m_progressCorpse(), m_bestCorpseDist(0.0f), m_lastProgress(0) {}
        virtual bool Execute(Event& event) override;
        virtual bool isUseful() override;

    private:
        // Closing on the corpse is what counts, not being in motion. A bot that is moving but
        // never arriving reported success for as long as it lived, so nothing below it ever ran.
        // Returns false once the distance has stopped improving for CORPSE_RUN_STALL_SECONDS.
        bool IsClosingOnCorpse(Corpse* corpse, float corpseDist);

        ObjectGuid m_progressCorpse;
        float m_bestCorpseDist;
        time_t m_lastProgress;
    };

	class SpiritHealerAction : public MovementAction
    {
	public:
	    SpiritHealerAction(PlayerbotAI* ai, std::string name = "spirit healer") : MovementAction(ai,name) {}
        virtual bool Execute(Event& event) override;
        virtual bool isUseful() override;
    };
}
