
#include "playerbot/playerbot.h"
#include "FishAction.h"
#include "playerbot/TravelMgr.h"
#include "TellLosAction.h"
#include "EquipAction.h"

using namespace ai;

bool MoveToFishAction::isUseful()
{
    if (qualifier == "travel")
    {
        if (!AI_VALUE(bool, "travel target working"))
            return false;

        TravelTarget* target = AI_VALUE(TravelTarget*, "leader travel target");

        if (target->GetDestination()->GetPurpose() != TravelDestinationPurpose::GatherFishing)
            return false;
    }

    return true;
}

bool MoveToFishAction::Execute(Event& event)
{    
    WorldPosition fishSpot;

    fishSpot = AI_VALUE2(WorldPosition, "custom position", "fish spot");

    // Fishing spots are picked here rather than through the travel target list, so the
    // "the bot keeps dying there" filter has to be applied by hand. Bots drowned reaching
    // these: 308 of the 657 deaths with no killer in a nine hour run were on the way to one.
    if (fishSpot && ai->IsDeadlyTravelPoint(fishSpot))
    {
        RESET_AI_VALUE2(WorldPosition, "custom position", "fish spot");
        fishSpot = WorldPosition();
    }

    if (!fishSpot && qualifier == "travel") //Get travel fish spot if available.
    {
        TravelTarget* target = AI_VALUE(TravelTarget*, "leader travel target");
        fishSpot = *target->GetPosition();

        if (AI_VALUE(TravelTarget*, "travel target") != target) //Do not fish ontop of master.
            fishSpot = *sTravelMgr.GetFishSpot(bot, true);
    }
    
    if (!fishSpot) //Get any fish spot.
    {
        for (uint8 attempt = 0; attempt < 5; ++attempt)
        {
            WorldPosition* candidate = sTravelMgr.GetFishSpot(bot);

            if (!candidate)
                return false;

            if (!ai->IsDeadlyTravelPoint(*candidate))
            {
                fishSpot = *candidate;
                break;
            }
        }

        if (!fishSpot)
            return false;

        TravelPath movePath = sTravelNodeMap.getFullPath(bot, fishSpot, bot);


        if (movePath.empty())
            return false;

        AI_VALUE(LastMovement&, "last movement").setPath(movePath);
    }
    
    SET_AI_VALUE2(WorldPosition, "custom position", "fish spot", fishSpot);
   
    if (fishSpot.distance(bot) < 1.0f)
        return false;

    return MoveTo(fishSpot);
}

bool FishAction::isUseful()
{
    if (qualifier == "travel")
    {
        if (!AI_VALUE(bool, "travel target working"))
            return false;

        TravelTarget* target = AI_VALUE(TravelTarget*, "leader travel target");

        if (target->GetDestination()->GetPurpose() != TravelDestinationPurpose::GatherFishing)
            return false;

        if (!bot->GetGroup() || ai->IsGroupLeader() || target->GetTimeLeft() < 0)
            target->CheckStatus();
    }

    WorldPosition fishSpot = AI_VALUE2(WorldPosition, "custom position", "fish spot");

    if (!fishSpot)
        return false;

    if (!AI_VALUE(bool, "can fish"))
        return false;

    if (fishSpot.distance(bot) > 1.0f)
        return false;

    return true;
}

bool FishAction::Execute(Event& event)
{
    if (qualifier == "travel")
    {
        if (!AI_VALUE(bool, "travel target working"))
            return false;
    }

    if ((!bot->IsStopped()))
    {
        ai->StopMoving();
        SetDuration(100);
        return true;
    }

    WorldPosition fishSpot = AI_VALUE2(WorldPosition, "custom position", "fish spot");

    if (abs(fishSpot.getO() - bot->GetOrientation()) > 0.5)
    {
        bot->SetFacingTo(fishSpot.getO());
        SetDuration(100);
        return true;
    }

    ai->StopMoving();

    std::list<Item*> poles = AI_VALUE2(std::list<Item*>, "inventory items", "fishing pole");

    if (poles.empty())
        return false;

    // The item list is built from a std::set, so its order follows pointer addresses and
    // not inventory slots: front() is not the equipped pole just because one is equipped.
    // Look for the worn one first, and only then for one the bot is actually allowed to
    // put in its main hand. Taking front() on faith and equipping it unconditionally is
    // what used to spin here - a pole that could not be equipped left this action in the
    // same state on every tick, forever.
    Item* pole = nullptr;
    for (Item* candidate : poles)
    {
        if (candidate->IsEquipped() && candidate->GetSlot() == EQUIPMENT_SLOT_MAINHAND)
        {
            pole = candidate;
            break;
        }
    }

    if (!pole)
    {
        for (Item* candidate : poles)
        {
            uint16 dest;
            if (bot->CanEquipItem(NULL_SLOT, dest, candidate, true) == EQUIP_ERR_OK)
            {
                pole = candidate;
                break;
            }
        }

        // Nothing wearable. Drop the spot so the travel system sends the bot somewhere it
        // can do something, rather than leaving it stood in the water retrying.
        if (!pole || !EquipAction::EquipItem(ai, GetMaster(), pole))
        {
            RESET_AI_VALUE2(WorldPosition, "custom position", "fish spot");
            SetDuration(sPlayerbotAIConfig.globalCoolDown);
            return false;
        }
    }

    Event fishCastEvent = Event("fish", "7731 " + chat->formatWorldobject(bot));
    bool didCast = CastCustomSpellAction::Execute(fishCastEvent);

    SetDuration(sPlayerbotAIConfig.globalCoolDown);

    return didCast;
}

bool UseFishingBobberAction::Execute(Event& event)
{
    std::list<GameObject*> objects = TellLosAction::GoGuidListToObjList(ai, AI_VALUE(std::list<ObjectGuid>, "nearest game objects no los"));

    for (auto& obj : objects)
    {
        if (obj->GetEntry() != 35591)
            continue;

        if (obj->GetOwnerGuid() != bot->GetObjectGuid())
            continue;

        if (obj->getLootState() != GO_READY)
        {
            time_t bobberActiveTime = obj->GetRespawnTime() - FISHING_BOBBER_READY_TIME;
            if (bobberActiveTime > time(0))
                SetDuration((bobberActiveTime - time(0)) * IN_MILLISECONDS + 500);
            else
                SetDuration(1000);
            return true;
        }

        WorldPacket packet(CMSG_GAMEOBJ_USE);


        packet << obj->GetObjectGuid();


        bot->GetSession()->BotHandleGameObjectUseOpcode(packet);

        std::ostringstream out; out << "Opening " << chat->formatGameobject(obj);
        ai->TellPlayerNoFacing(ai->GetMaster(), out.str(), PlayerbotSecurityLevel::PLAYERBOT_SECURITY_ALLOW_ALL, false);

        SetDuration(3000);

        if (!urand(0,10))
        {
            RESET_AI_VALUE2(WorldPosition, "custom position", "fish spot");
        }

        return true;
    }

    return false;
}