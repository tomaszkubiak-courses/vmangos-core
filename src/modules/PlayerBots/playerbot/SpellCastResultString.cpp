#include "playerbot/playerbot.h"

#include "Spells/SpellDefines.h"

// The cmangos playerbot code asks the core for a human readable reason whenever a
// cast is refused, and prints it through the `cast_spell_command_error` bot text.
// cmangos has this as a free function; vmangos does not, and the port shipped a
// stub returning an empty string, so every bot said "Failed to cast [x]. Reason: "
// with nothing after it.
//
// The strings below are the client-facing messages recorded against each value in
// the SpellCastResult enum in Spells/SpellDefines.h, and the preprocessor guards
// mirror that enum exactly, because which values exist depends on
// SUPPORTED_CLIENT_BUILD. A few entries have no client message - those the client
// never displays, and the generic out-of-bounds one - and fall back to the name of
// the value, which is still more use than an empty string. Some messages carry the
// client's own format specifiers; nothing here runs them through printf, and the
// bot text layer only substitutes its own named placeholders, so they are passed
// through verbatim.
//
// Keep this in step with the enum: a value added there without a case here returns
// the fallback below rather than failing to build.
char const* GetSpellCastResultString(SpellCastResult result)
{
    switch (result)
    {
        case SPELL_FAILED_AFFECTING_COMBAT: return "You are in combat";
        case SPELL_FAILED_ALREADY_AT_FULL_HEALTH: return "You are already at full Health.";
        case SPELL_FAILED_ALREADY_AT_FULL_POWER: return "You are already at full %s.";
        case SPELL_FAILED_ALREADY_BEING_TAMED: return "That creature is already being tamed";
        case SPELL_FAILED_ALREADY_HAVE_CHARM: return "You already control a charmed creature";
        case SPELL_FAILED_ALREADY_HAVE_SUMMON: return "You already control a summoned creature";
        case SPELL_FAILED_ALREADY_OPEN: return "Already open";
        case SPELL_FAILED_AURA_BOUNCED: return "A more powerful spell is already active";
        case SPELL_FAILED_AUTOTRACK_INTERRUPTED: return "SPELL_FAILED_AUTOTRACK_INTERRUPTED";
        case SPELL_FAILED_BAD_IMPLICIT_TARGETS: return "You have no target.";
        case SPELL_FAILED_BAD_TARGETS: return "Invalid target";
        case SPELL_FAILED_CANT_BE_CHARMED: return "Target can't be charmed";
        case SPELL_FAILED_CANT_BE_DISENCHANTED: return "Item cannot be disenchanted";
#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_11_2
        case SPELL_FAILED_CANT_BE_PROSPECTED: return "There are no gems in this";
#endif
        case SPELL_FAILED_CANT_CAST_ON_TAPPED: return "Target is tapped";
        case SPELL_FAILED_CANT_DUEL_WHILE_INVISIBLE: return "You can't start a duel while invisible";
        case SPELL_FAILED_CANT_DUEL_WHILE_STEALTHED: return "You can't start a duel while stealthed";
        case SPELL_FAILED_CANT_STEALTH: return "You are too close to enemies";
        case SPELL_FAILED_CASTER_AURASTATE: return "You can't do that yet";
        case SPELL_FAILED_CASTER_DEAD: return "You are dead";
#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_10_2
        case SPELL_FAILED_CHARMED: return "Can't do that while charmed";
#endif
        case SPELL_FAILED_CHEST_IN_USE: return "That is already being used";
        case SPELL_FAILED_CONFUSED: return "Can't do that while confused";
        case SPELL_FAILED_DONT_REPORT: return "SPELL_FAILED_DONT_REPORT";
        case SPELL_FAILED_EQUIPPED_ITEM: return "Must have the proper item equipped";
        case SPELL_FAILED_EQUIPPED_ITEM_CLASS: return "Must have a %s equipped";
#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_5_1
        case SPELL_FAILED_EQUIPPED_ITEM_CLASS_MAINHAND: return "Must have a %s equipped in the main hand";
#endif
#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_9_4
        case SPELL_FAILED_EQUIPPED_ITEM_CLASS_OFFHAND: return "Must have a %s equipped in the offhand";
#endif
        case SPELL_FAILED_ERROR: return "Internal error";
        case SPELL_FAILED_FIZZLE: return "Fizzled";
        case SPELL_FAILED_FLEEING: return "Can't do that while fleeing";
        case SPELL_FAILED_FOOD_LOWLEVEL: return "That food's level is not high enough for your pet";
        case SPELL_FAILED_HIGHLEVEL: return "Target is too high level";
        case SPELL_FAILED_HUNGER_SATIATED: return "SPELL_FAILED_HUNGER_SATIATED";
        case SPELL_FAILED_IMMUNE: return "Immune";
        case SPELL_FAILED_INTERRUPTED: return "Interrupted";
        case SPELL_FAILED_INTERRUPTED_COMBAT: return "Interrupted";
        case SPELL_FAILED_ITEM_ALREADY_ENCHANTED: return "Item is already enchanted";
        case SPELL_FAILED_ITEM_GONE: return "Item is gone";
        case SPELL_FAILED_ITEM_NOT_FOUND: return "Tried to enchant an item that didn't exist";
        case SPELL_FAILED_ITEM_NOT_READY: return "Item is not ready yet.";
        case SPELL_FAILED_LEVEL_REQUIREMENT: return "You are not high enough level";
        case SPELL_FAILED_LINE_OF_SIGHT: return "Target not in line of sight";
        case SPELL_FAILED_LOWLEVEL: return "Target is too low level";
        case SPELL_FAILED_LOW_CASTLEVEL: return "Skill not high enough";
        case SPELL_FAILED_MAINHAND_EMPTY: return "Your weapon hand is empty";
        case SPELL_FAILED_MOVING: return "Can't do that while moving";
        case SPELL_FAILED_NEED_AMMO: return "Ammo needs to be in the paper doll ammo slot before it can be fired";
        case SPELL_FAILED_NEED_AMMO_POUCH: return "Requires: %s";
        case SPELL_FAILED_NEED_EXOTIC_AMMO: return "Requires exotic ammo: %s";
        case SPELL_FAILED_NOPATH: return "No path available";
        case SPELL_FAILED_NOT_BEHIND: return "You must be behind your target";
        case SPELL_FAILED_NOT_FISHABLE: return "Your cast didn't land in fishable water";
        case SPELL_FAILED_NOT_HERE: return "You can't use that here";
        case SPELL_FAILED_NOT_INFRONT: return "You must be in front of your target";
        case SPELL_FAILED_NOT_IN_CONTROL: return "You are not in control of your actions";
        case SPELL_FAILED_NOT_KNOWN: return "Spell not learned";
        case SPELL_FAILED_NOT_MOUNTED: return "You are mounted";
        case SPELL_FAILED_NOT_ON_TAXI: return "You are in flight";
        case SPELL_FAILED_NOT_ON_TRANSPORT: return "You are on a transport";
        case SPELL_FAILED_NOT_READY: return "Spell is not ready yet.";
        case SPELL_FAILED_NOT_SHAPESHIFT: return "You are in shapeshift form";
        case SPELL_FAILED_NOT_STANDING: return "You must be standing to do that";
        case SPELL_FAILED_NOT_TRADEABLE: return "You can only use this on an object you own";
        case SPELL_FAILED_NOT_TRADING: return "Tried to enchant a trade item, but not trading";
        case SPELL_FAILED_NOT_UNSHEATHED: return "You have to be unsheathed to do that!";
        case SPELL_FAILED_NOT_WHILE_GHOST: return "Can't cast as ghost";
        case SPELL_FAILED_NO_AMMO: return "Out of ammo";
        case SPELL_FAILED_NO_CHARGES_REMAIN: return "No charges remain";
#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_9_4
        case SPELL_FAILED_NO_CHAMPION: return "You haven't selected a champion";
#endif
        case SPELL_FAILED_NO_COMBO_POINTS: return "That ability requires combo points";
        case SPELL_FAILED_NO_DUELING: return "Dueling isn't allowed here";
        case SPELL_FAILED_NO_ENDURANCE: return "Not enough endurance";
        case SPELL_FAILED_NO_FISH: return "There aren't any fish here";
        case SPELL_FAILED_NO_ITEMS_WHILE_SHAPESHIFTED: return "Can't use items while shapeshifted";
        case SPELL_FAILED_NO_MOUNTS_ALLOWED: return "You can't mount here";
        case SPELL_FAILED_NO_PET: return "You do not have a pet";
        case SPELL_FAILED_NO_POWER: return "Dynamic pre-defined messages, no args: Not enough mana, Not enough rage, etc";
#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_9_4
        case SPELL_FAILED_NOTHING_TO_DISPEL: return "Nothing to dispel";
#endif
#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_11_2
        case SPELL_FAILED_NOTHING_TO_STEAL: return "Nothing to steal";
#endif
        case SPELL_FAILED_ONLY_ABOVEWATER: return "Cannot use while swimming";
        case SPELL_FAILED_ONLY_DAYTIME: return "Can only use during the day";
        case SPELL_FAILED_ONLY_INDOORS: return "Can only use indoors";
        case SPELL_FAILED_ONLY_MOUNTED: return "Can only use while mounted";
        case SPELL_FAILED_ONLY_NIGHTTIME: return "Can only use during the night";
        case SPELL_FAILED_ONLY_OUTDOORS: return "Can only use outside";
        case SPELL_FAILED_ONLY_SHAPESHIFT: return "Must be in %s";
        case SPELL_FAILED_ONLY_STEALTHED: return "You must be in stealth mode";
        case SPELL_FAILED_ONLY_UNDERWATER: return "Can only use while swimming";
        case SPELL_FAILED_OUT_OF_RANGE: return "Out of range.";
        case SPELL_FAILED_PACIFIED: return "Can't use that ability while pacified";
        case SPELL_FAILED_POSSESSED: return "You are possessed";
        case SPELL_FAILED_REAGENTS: return "SPELL_FAILED_REAGENTS";
        case SPELL_FAILED_REQUIRES_AREA: return "You need to be in %s";
        case SPELL_FAILED_REQUIRES_SPELL_FOCUS: return "Requires %s";
        case SPELL_FAILED_ROOTED: return "You are unable to move";
        case SPELL_FAILED_SILENCED: return "Can't do that while silenced";
        case SPELL_FAILED_SPELL_IN_PROGRESS: return "Another action is in progress";
        case SPELL_FAILED_SPELL_LEARNED: return "You have already learned the spell";
        case SPELL_FAILED_SPELL_UNAVAILABLE: return "The spell is not available to you";
        case SPELL_FAILED_STUNNED: return "Can't do that while stunned";
        case SPELL_FAILED_TARGETS_DEAD: return "Your target is dead";
        case SPELL_FAILED_TARGET_AFFECTING_COMBAT: return "Target is in combat";
        case SPELL_FAILED_TARGET_AURASTATE: return "You can't do that yet";
        case SPELL_FAILED_TARGET_DUELING: return "Target is currently dueling";
        case SPELL_FAILED_TARGET_ENEMY: return "Target is hostile";
        case SPELL_FAILED_TARGET_ENRAGED: return "Target is too enraged to be charmed";
        case SPELL_FAILED_TARGET_FRIENDLY: return "Target is friendly";
        case SPELL_FAILED_TARGET_IN_COMBAT: return "The target can't be in combat";
        case SPELL_FAILED_TARGET_IS_PLAYER: return "Can't target players";
        case SPELL_FAILED_TARGET_NOT_DEAD: return "Target is alive";
        case SPELL_FAILED_TARGET_NOT_IN_PARTY: return "Target is not in your party";
        case SPELL_FAILED_TARGET_NOT_LOOTED: return "Creature must be looted first";
        case SPELL_FAILED_TARGET_NOT_PLAYER: return "Target is not a player";
        case SPELL_FAILED_TARGET_NO_POCKETS: return "No pockets to pick";
        case SPELL_FAILED_TARGET_NO_WEAPONS: return "Target has no weapons equipped";
        case SPELL_FAILED_TARGET_UNSKINNABLE: return "Creature is not skinnable";
        case SPELL_FAILED_THIRST_SATIATED: return "SPELL_FAILED_THIRST_SATIATED";
        case SPELL_FAILED_TOO_CLOSE: return "Target too close";
        case SPELL_FAILED_TOO_MANY_OF_ITEM: return "You have too many of that item already";
        case SPELL_FAILED_TOTEMS: return "SPELL_FAILED_TOTEMS";
        case SPELL_FAILED_TRAINING_POINTS: return "Not enough training points";
        case SPELL_FAILED_TRY_AGAIN: return "Failed attempt";
        case SPELL_FAILED_UNIT_NOT_BEHIND: return "Target needs to be behind you";
        case SPELL_FAILED_UNIT_NOT_INFRONT: return "Target needs to be in front of you";
        case SPELL_FAILED_WRONG_PET_FOOD: return "Your pet doesn't like that food";
        case SPELL_FAILED_NOT_WHILE_FATIGUED: return "Can't cast while fatigued";
        case SPELL_FAILED_TARGET_NOT_IN_INSTANCE: return "Target must be in this instance";
        case SPELL_FAILED_NOT_WHILE_TRADING: return "Can't cast while trading";
        case SPELL_FAILED_TARGET_NOT_IN_RAID: return "Target is not in your party or raid group";
        case SPELL_FAILED_DISENCHANT_WHILE_LOOTING: return "Cannot disenchant while looting";
#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_11_2
        case SPELL_FAILED_PROSPECT_WHILE_LOOTING: return "Cannot prospect while looting";
        case SPELL_FAILED_PROSPECT_NEED_MORE: return "SPELL_FAILED_PROSPECT_NEED_MORE";
#endif
#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_5_1
        case SPELL_FAILED_TARGET_FREEFORALL: return "Target is currently in free-for-all PvP combat";
        case SPELL_FAILED_NO_EDIBLE_CORPSES: return "There are no nearby corpses to eat";
        case SPELL_FAILED_ONLY_BATTLEGROUNDS: return "Can only use in battlegrounds";
#endif
#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_6_1
        case SPELL_FAILED_TARGET_NOT_GHOST: return "Target is not a ghost";
        case SPELL_FAILED_TOO_MANY_SKILLS: return "Your pet can't learn any more skills";
#endif
#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_7_1
        case SPELL_FAILED_TRANSFORM_UNUSABLE: return "You can't use the new item";
        case SPELL_FAILED_WRONG_WEATHER: return "The weather isn't right for that";
        case SPELL_FAILED_DAMAGE_IMMUNE: return "You can't do that while you are immune";
        case SPELL_FAILED_PREVENTED_BY_MECHANIC: return "Can't do that while %s";
        case SPELL_FAILED_PLAY_TIME: return "Maximum play time exceeded";
#endif
#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_8_4
        case SPELL_FAILED_REPUTATION: return "Your reputation isn't high enough";
#endif
#if SUPPORTED_CLIENT_BUILD > CLIENT_BUILD_1_11_2
        case SPELL_FAILED_MIN_SKILL: return "Your skill is not high enough.  Requires %s (%d).";
#endif
        case SPELL_FAILED_UNKNOWN: return "SPELL_FAILED_UNKNOWN";
        default: break;
    }

    return "unknown reason";
}
