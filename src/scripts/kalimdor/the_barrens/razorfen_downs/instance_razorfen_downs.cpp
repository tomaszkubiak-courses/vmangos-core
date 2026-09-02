/*
 * Copyright (C) 2010 Trinity <http://www.trinitycore.org/>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
 */

#include "scriptPCH.h"
#include "razorfen_downs.h"

#define    MAX_ENCOUNTER  1

struct GongWaveSummon
{
    uint32 uiEntry;
    float fX, fY, fZ, fO;
};

// Retail sniff of the positions the gong summons its waves at (creature_summon_groups,
// summoner 148917). The waves stand where they are spawned - none of them is sent to a
// gathering point.
static GongWaveSummon const s_aGongWave1[] =
{
    { CREATURE_TOMB_FIEND, 2527.02f, 829.979f, 48.0650f, 0.698132f },
    { CREATURE_TOMB_FIEND, 2524.04f, 834.485f, 48.3703f, 0.802851f },
    { CREATURE_TOMB_FIEND, 2544.69f, 912.889f, 46.3991f, 2.129300f },
    { CREATURE_TOMB_FIEND, 2541.49f, 911.176f, 46.2649f, 4.817110f },
    { CREATURE_TOMB_FIEND, 2544.70f, 907.633f, 46.3801f, 1.605700f },
    { CREATURE_TOMB_FIEND, 2541.25f, 907.094f, 46.6420f, 2.024580f },
    { CREATURE_TOMB_FIEND, 2489.91f, 804.795f, 43.2518f, 1.658060f },
    { CREATURE_TOMB_FIEND, 2488.43f, 801.281f, 42.7037f, 4.293510f },
    { CREATURE_TOMB_FIEND, 2485.41f, 804.115f, 43.6851f, 3.054330f },
    { CREATURE_TOMB_FIEND, 2487.34f, 805.911f, 43.0836f, 2.844890f }
};

static GongWaveSummon const s_aGongWave2[] =
{
    { CREATURE_TOMB_REAVER, 2486.83f, 802.874f, 43.1988f, 2.914700f },
    { CREATURE_TOMB_REAVER, 2489.08f, 806.591f, 43.2110f, 3.682650f },
    { CREATURE_TOMB_REAVER, 2543.29f, 911.245f, 46.3279f, 0.680678f },
    { CREATURE_TOMB_REAVER, 2542.82f, 904.936f, 46.8091f, 4.642580f }
};

// Tuten'kash spawns down in the corridor south west of the gong, then walks up to the
// spot he is found at, which is the target of his own on reset move in the sniff.
static GongWaveSummon const s_aGongWave3[] =
{
    { CREATURE_TUTEN_KASH, 2487.94f, 804.222f, 43.1073f, 1.692970f }
};

static float const TUTEN_KASH_POST_X = 2515.71f;
static float const TUTEN_KASH_POST_Y = 854.81f;
static float const TUTEN_KASH_POST_Z = 47.68f;

static uint32 const WAVE_1_SIZE = sizeof(s_aGongWave1) / sizeof(s_aGongWave1[0]);
static uint32 const WAVE_2_SIZE = sizeof(s_aGongWave2) / sizeof(s_aGongWave2[0]);

// The counter is bumped by the gong being rung and by every wave member dying
// (creature_ai_events for 7349 and 7351), so a wave is summoned on the ring that
// follows the last death of the previous one.
enum eGongCounter
{
    GONG_RING_WAVE_1  = 1,
    GONG_READY_WAVE_2 = GONG_RING_WAVE_1 + WAVE_1_SIZE,
    GONG_RING_WAVE_2  = GONG_READY_WAVE_2 + 1,
    GONG_READY_WAVE_3 = GONG_RING_WAVE_2 + WAVE_2_SIZE,
    GONG_RING_WAVE_3  = GONG_READY_WAVE_3 + 1
};

struct instance_razorfen_downs : public ScriptedInstance
{
    instance_razorfen_downs(Map* pMap) : ScriptedInstance(pMap)
    {
        Initialize();
    };

    uint64 uiGongGUID;
    uint64 uiCupFire1GUID;
    uint64 uiCupFire2GUID;

    uint32 m_auiEncounter[MAX_ENCOUNTER];

    uint8 uiGongWaves;

    std::string str_data;
    std::string strInstData;

    void Initialize() override
    {
        uiGongGUID = 0;

        uiCupFire1GUID = 0;

        uiCupFire2GUID = 0;

        uiGongWaves = 0;

        memset(&m_auiEncounter, 0, sizeof(m_auiEncounter));
    }

    void Load(char const* chrIn) override
    {
        if (!chrIn)
        {
            OUT_LOAD_INST_DATA_FAIL;
            return;
        }

        OUT_LOAD_INST_DATA(chrIn);

        std::istringstream loadStream(chrIn);
        loadStream >> m_auiEncounter[0];


        for (uint32 & i : m_auiEncounter)
            if (i == IN_PROGRESS)
                i = NOT_STARTED;

        OUT_LOAD_INST_DATA_COMPLETE;
    }

    void OnObjectCreate(GameObject* pGo) override
    {
        switch (pGo->GetEntry())
        {
            case GO_GONG:
                uiGongGUID = pGo->GetGUID();
                if (m_auiEncounter[0] == DONE)
                    pGo->SetFlag(GAMEOBJECT_FLAGS, GO_FLAG_NO_INTERACT);
                break;
            case GO_IDOL_CUP_FIRE:
                if (uiCupFire1GUID != 0)
                    uiCupFire2GUID = pGo->GetGUID();
                else
                    uiCupFire1GUID = pGo->GetGUID();
                break;
            default:
                break;
        }
    }

    void SetData(uint32 uiType, uint32 uiData) override
    {
        if (uiType == DATA_GONG_WAVES)
        {
            uiGongWaves = uiData;
            GongWaveSummon const* pWave = nullptr;
            uint32 uiWaveSize = 0;

            switch (uiGongWaves)
            {
                case GONG_READY_WAVE_2:
                case GONG_READY_WAVE_3:
                    if (GameObject* pGo = instance->GetGameObject(uiGongGUID))
                        pGo->RemoveFlag(GAMEOBJECT_FLAGS, GO_FLAG_NO_INTERACT);
                    break;
                case GONG_RING_WAVE_1:
                    pWave = s_aGongWave1;
                    uiWaveSize = WAVE_1_SIZE;
                    break;
                case GONG_RING_WAVE_2:
                    pWave = s_aGongWave2;
                    uiWaveSize = WAVE_2_SIZE;
                    break;
                case GONG_RING_WAVE_3:
                    pWave = s_aGongWave3;
                    uiWaveSize = sizeof(s_aGongWave3) / sizeof(s_aGongWave3[0]);
                    break;
                default:
                    break;
            }

            if (pWave)
            {
                if (GameObject* pGo = instance->GetGameObject(uiGongGUID))
                {
                    pGo->SetFlag(GAMEOBJECT_FLAGS, GO_FLAG_NO_INTERACT);

                    for (uint32 i = 0; i < uiWaveSize; ++i)
                    {
                        Creature* pSummon = pGo->SummonCreature(pWave[i].uiEntry, pWave[i].fX, pWave[i].fY, pWave[i].fZ, pWave[i].fO);

                        if (!pSummon)
                            continue;

                        if (pSummon->GetEntry() == CREATURE_TUTEN_KASH)
                        {
                            pSummon->SetWalk(false);
                            pSummon->GetMotionMaster()->MovePoint(0, TUTEN_KASH_POST_X, TUTEN_KASH_POST_Y, TUTEN_KASH_POST_Z, MOVE_PATHFINDING);
                        }
                        else
                        {
                            // The tomb creatures are summoned out of sight of the gong, in two
                            // groups far from each other, and go looking for the party at once.
                            pSummon->SetInCombatWithZone();
                        }
                    }
                }
            }
        }

        if (uiType == BOSS_TUTEN_KASH)
        {
            m_auiEncounter[0] = uiData;

            if (uiData == DONE)
                SaveToDB();
        }

        if (uiType == EXTINGUISH_FIRES)
        {
            if (GameObject* pGoCupFire1 = instance->GetGameObject(uiCupFire1GUID))
                pGoCupFire1->SetLootState(GO_JUST_DEACTIVATED);
            if (GameObject* pGoCupFire2 = instance->GetGameObject(uiCupFire2GUID))
                pGoCupFire2->SetLootState(GO_JUST_DEACTIVATED);
        }

        if (uiData == DONE)
        {
            OUT_SAVE_INST_DATA;

            std::ostringstream saveStream;
            saveStream << m_auiEncounter[0];

            strInstData = saveStream.str();

            SaveToDB();
            OUT_SAVE_INST_DATA_COMPLETE;
        }

    }

    uint32 GetData(uint32 uiType) override
    {
        switch (uiType)
        {
            case DATA_GONG_WAVES:
                return uiGongWaves;
        }

        return 0;
    }

    uint64 GetData64(uint32 uiType) override
    {
        switch (uiType)
        {
            case DATA_GONG:
                return uiGongGUID;
        }

        return 0;
    }
};

InstanceData* GetInstanceData_instance_razorfen_downs(Map* pMap)
{
    return new instance_razorfen_downs(pMap);
}

void AddSC_instance_razorfen_downs()
{
    Script* newscript;

    newscript = new Script;
    newscript->Name = "instance_razorfen_downs";
    newscript->GetInstanceData = &GetInstanceData_instance_razorfen_downs;
    newscript->RegisterSelf();
}
