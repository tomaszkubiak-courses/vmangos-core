// cmangos/playerbots → Penqle/tortoise-wow compatibility shim.
//
// Provides the cmangos-side names/constants the vendored bot module references
// but Penqle either names differently or doesn't expose. Included by botpch.h
// as the first header in the PCH chain so all bot TUs see it.
//
// What's here:
//   - Type renames / typedef forwards
//   - Define mappings (cmangos constants → Penqle equivalents)
//   - Standard-library headers cmangos uses without explicit include
//
// What's NOT here (handled by per-call-site rewrites because they need
// contextual changes, not name remapping):
//   - DBC-store globals (sMapStore ↔ sMapStorage architecture)
//   - WorldPacket move-only assignment sites
//   - CreatureData::id (single field) vs Penqle's creature_id (array)
//   - PlayerbotAI internal signature mismatches
//   - GuidPosition diamond-inheritance ambiguity

#pragma once

// === Standard library headers the bot module uses without explicit includes ===
// PlayerbotAI.h declares methods taking std::future<...> but doesn't #include
// <future>. Penqle's botpch.h already pulls in many std headers but not this one.
#include <future>
#include <chrono>
#include <random>
#include <cstdio>

// === Type renames ===
// cmangos calls the transport base GenericTransport on WotLK and Transport on Classic.
// VMaNGOS has both as real types - GenericTransport is declared in Maps/Map.h and defined
// in Transports/ - so neither an alias nor a forward declaration belongs here.

// cmangos's CreatureAI base is named UnitAI; Penqle uses CreatureAI. Same shape.
class CreatureAI;
typedef CreatureAI UnitAI;

// cmangos uses GuidSet typedef. Penqle uses ObjectGuidSet.
// Pull ObjectGuid header transitively to ensure the typedef target is visible
// before the alias is used.
#include "ObjectGuid.h"
typedef ObjectGuidSet GuidSet;

// cmangos uses AreaTableEntry; Penqle has AreaEntry (defined in Maps/Map.h).
// They model the same data. Forward-declare and typedef.
struct AreaEntry;
typedef AreaEntry AreaTableEntry;

// cmangos uses AreaTrigger; Penqle has AreaTriggerEntry (DBCStructure.h).
struct AreaTriggerEntry;
typedef AreaTriggerEntry AreaTrigger;

// === Define mappings ===
// cmangos's ItemClass enum has ITEM_CLASS_MISC at value 15. Penqle renamed
// this to ITEM_CLASS_JUNK (also at 15). The bot module's ahbot/Category.h
// uses the cmangos name.
#ifndef ITEM_CLASS_MISC
#define ITEM_CLASS_MISC ITEM_CLASS_JUNK
#endif

// cmangos defines DEFAULT_MAX_LEVEL per-expansion (60 for Classic). The bot
// module's PlayerbotAIConfig.h and PlayerbotLoginMgr.h use this for array
// sizing. Penqle uses MAX_LEVEL/STRONG_MAX_LEVEL but not this exact name.
#ifndef DEFAULT_MAX_LEVEL
#define DEFAULT_MAX_LEVEL 60
#endif

// cmangos's Team enum has TEAM_BOTH_ALLOWED for queries that span both factions.
// Penqle's Team enum has TEAM_NONE=0 (used as "no faction filter" sentinel).
// Map TEAM_BOTH_ALLOWED to TEAM_NONE so default-arg conversions work.
#ifndef TEAM_BOTH_ALLOWED
#define TEAM_BOTH_ALLOWED TEAM_NONE
#endif

// cmangos picks what a distance is measured to with a DistanceCalculation argument; this
// core does the same with SizeFactor. The names map one to one. NOTE: cmangos returns the
// SQUARE of the distance for DIST_CALC_NONE while this core always returns the distance
// itself, so a call site that took a square root of the result had to lose it.
#define DIST_CALC_NONE SizeFactor::None
#define DIST_CALC_BOUNDING_RADIUS SizeFactor::BoundingRadius
#define DIST_CALC_COMBAT_REACH SizeFactor::CombatReach

// cmangos has UNIT_FLAG_CLIENT_CONTROL_LOST. Penqle may use a different name
// or omit it entirely. Define as 0 so the bit-flag operations parse, even if
// they're effectively no-ops at runtime
#ifndef UNIT_FLAG_CLIENT_CONTROL_LOST
#define UNIT_FLAG_CLIENT_CONTROL_LOST 0
#endif

// cmangos has movementFlagsMask as "all movement flags" sentinel. Penqle uses
// MOVEMENTFLAG_MASK_MOVING or specific flag combos. Define as all bits.
#ifndef movementFlagsMask
constexpr uint32 movementFlagsMask = 0xFFFFFFFFu;
#endif

// BarGoLink, the console progress bar, is real here: src/shared/ProgressBar.h. The
// donor's core had none, hence the stub that used to sit in this spot.

// cmangos has InstanceTemplate (sObjectMgr.GetInstanceTemplate). Penqle has
// no equivalent class. Define a minimal stub with the fields the bot reads,
// all zero; bot's getInstanceTemplate() returns nullptr in WorldPosition.h
// so the fields are never read at runtime.
struct InstanceTemplate {
    uint32 levelMin = 0;
    uint32 levelMax = 0;
    uint32 maxPlayers = 0;
    uint32 reset_delay = 0;
    uint32 parent = 0;
};

// === DBC store aliases ===
// cmangos accesses spell DBC via `sSpellTemplate.LookupEntry<SpellEntry>(id)`.
// Penqle uses `sSpellMgr.GetSpellEntry(id)`. The bot's `sSpellTemplate` is used
// in 600+ call sites; rather than rewrite each, provide a header-only wrapper
// object that exposes a templated LookupEntry() forwarding to Penqle's API.
//
// The forward-decls below need ObjectMgr / SpellMgr access. Because this header
// is included EARLY in botpch.h (before SpellMgr.h), we declare the proxy class
// inline-only — its methods get instantiated at the call sites, after Penqle's
// SpellMgr/ObjectMgr are already in scope via later botpch.h includes.

// Note: this shim is included AFTER Penqle's SpellMgr.h / ObjectMgr.h /
// SpellEntry / ItemPrototype headers in botpch.h, so we can call those APIs
// directly in inline bodies.

// Singleton-like wrapper for cmangos's sSpellTemplate. Inline LookupEntry<>()
// forwards to Penqle's sSpellMgr.GetSpellEntry().
struct CmangosSpellTemplateProxy
{
    template<typename T = SpellEntry>
    T const* LookupEntry(uint32 id) const { return sSpellMgr.GetSpellEntry(id); }
    // cmangos's DBCStorage exposes GetMaxEntry. Bot uses it to iterate spells.
    // Penqle's sSpellMgr exposes GetMaxSpellId() — same purpose.
    uint32 GetMaxEntry() const { return sSpellMgr.GetMaxSpellId(); }
};
static CmangosSpellTemplateProxy sSpellTemplate;

// Singleton-like wrapper for cmangos's sItemStorage. Forwards to sObjectMgr.GetItemPrototype().
// Iteration-upper-bound stubs (this proxy + CmangosCreatureStorageProxy,
// CmangosGOStorageProxy, CmangosFactionStoreProxy, CmangosAreaTriggerStoreProxy
// below): cmangos's stores expose GetMaxEntry/GetNumRows; Penqle's don't have
// a tight maximum. The bot module only uses these as upper bounds for
// `for (i=0; i<max; ++i) LookupEntry(i)` scans where LookupEntry returns
// nullptr for unknown ids — so a generous overestimate is safe (a few thousand
// wasted lookups during one-shot init). Bump if a future caller actually
// depends on a tight bound.
struct CmangosItemStorageProxy
{
    template<typename T = ItemPrototype>
    T const* LookupEntry(uint32 id) const { return sObjectMgr.GetItemPrototype(id); }
    uint32 GetMaxEntry() const { return 100000; }
};
static CmangosItemStorageProxy sItemStorage;

// Singleton-like wrapper for cmangos's sMapStore. Penqle uses sMapStorage (SQLStorage).
struct MapEntry;  // defined in Maps/Map.h
struct CmangosMapStoreProxy
{
    template<typename T = MapEntry>
    T const* LookupEntry(uint32 id) const { return sMapStorage.LookupEntry<MapEntry>(id); }
    uint32 GetNumRows() const { return sMapStorage.GetMaxEntry(); }
};
static CmangosMapStoreProxy sMapStore;

// Singleton-like wrapper for cmangos's sFactionTemplateStore.
struct FactionTemplateEntry;  // defined in Database/DBCStructure.h
struct CmangosFactionTemplateStoreProxy
{
    template<typename T = FactionTemplateEntry>
    T const* LookupEntry(uint32 id) const { return sObjectMgr.GetFactionTemplateEntry(id); }
    uint32 GetNumRows() const { return 1500; } // upper bound stub
};
static CmangosFactionTemplateStoreProxy sFactionTemplateStore;

// === Other defines ===
// cmangos has ITEM_FLAG_HAS_LOOT (lootable item). Penqle uses ITEM_FLAG_HAS_LOOT or ITEM_FLAG_OPENABLE.
#ifndef ITEM_FLAG_HAS_LOOT
#define ITEM_FLAG_HAS_LOOT ITEM_FLAG_LOOTABLE
#endif


// === Type renames (cmangos→Penqle struct name diffs) ===
// cmangos's ItemPrototype has _Spell substruct (older naming);
// Penqle uses _ItemSpell (current naming). They're the same shape.
typedef _ItemSpell _Spell;

// cmangos has TEMPSPAWN_* enum values; Penqle has TEMPSUMMON_*. Map.
#ifndef TEMPSPAWN_TIMED_DESPAWN
#define TEMPSPAWN_TIMED_DESPAWN TEMPSUMMON_TIMED_DESPAWN
#endif
#ifndef TEMPSPAWN_TIMED_OR_DEAD_DESPAWN
#define TEMPSPAWN_TIMED_OR_DEAD_DESPAWN TEMPSUMMON_TIMED_OR_DEAD_DESPAWN
#endif
#ifndef TEMPSPAWN_TIMED_OR_CORPSE_DESPAWN
#define TEMPSPAWN_TIMED_OR_CORPSE_DESPAWN TEMPSUMMON_TIMED_OR_CORPSE_DESPAWN
#endif
#ifndef TEMPSPAWN_DEAD_DESPAWN
#define TEMPSPAWN_DEAD_DESPAWN TEMPSUMMON_DEAD_DESPAWN
#endif
#ifndef TEMPSPAWN_CORPSE_DESPAWN
#define TEMPSPAWN_CORPSE_DESPAWN TEMPSUMMON_CORPSE_DESPAWN
#endif
#ifndef TEMPSPAWN_CORPSE_TIMED_DESPAWN
#define TEMPSPAWN_CORPSE_TIMED_DESPAWN TEMPSUMMON_CORPSE_TIMED_DESPAWN
#endif
#ifndef TEMPSPAWN_MANUAL_DESPAWN
#define TEMPSPAWN_MANUAL_DESPAWN TEMPSUMMON_MANUAL_DESPAWN
#endif

// === Spells namespace functions hoisted to global scope ===
// cmangos's bot calls IsPositiveSpell / GetDispellMask without namespace.
// Penqle wraps these in `namespace Spells`. Bring them into global scope
// for the bot's consumption.
using Spells::IsPositiveSpell;
using Spells::GetDispellMask;
using Spells::IsPassiveSpell;
// SpellEntry* overload: bot passes spellInfo directly.
inline bool IsPositiveSpell(SpellEntry const* spellInfo) { return spellInfo && spellInfo->IsPositiveSpell(); }
inline bool IsPositiveSpell(SpellEntry const* spellInfo, WorldObject const* caster, WorldObject const* victim) { return spellInfo && spellInfo->IsPositiveSpell(caster, victim); }

// === TRIGGERED_* spell-cast flags ===
// cmangos's CastSpell takes a TriggerCastFlags bitmask (TRIGGERED_OLD_TRIGGERED, etc.).
// Penqle uses bool triggered. Provide #defines so bot's symbolic constants compile;
// the actual values are arbitrary because Penqle's CastSpell ignores the bitmask
// (it'll pass the int as bool, which defaults to falsy for 0).
// Penqle expects `bool triggered`, not a bitmask. Use `false` for unflagged casts and
// `true` for any "triggered" cast. This is lossy (we can't represent IGNORE_GCD/IGNORE_AURA_SCALING
// distinctly) but matches Penqle's API. NOTE: must be `bool` typed so private template-trap
// overloads (in Object.h) don't catch them.
#ifndef TRIGGERED_NONE
#define TRIGGERED_NONE false
#endif
#ifndef TRIGGERED_OLD_TRIGGERED
#define TRIGGERED_OLD_TRIGGERED true
#endif
#ifndef TRIGGERED_FULL_MASK
#define TRIGGERED_FULL_MASK true
#endif
#ifndef TRIGGERED_IGNORE_GCD
#define TRIGGERED_IGNORE_GCD true
#endif
#ifndef TRIGGERED_IGNORE_AURA_SCALING
#define TRIGGERED_IGNORE_AURA_SCALING true
#endif



// TimePoint is defined in src/shared/Common.h here, as a system_clock time_point at
// millisecond precision rather than the clock's native resolution.
#include <chrono>

// === BG_AV_NODE_STATUS_ defines ===
// The value these have to carry is the second half of an Alterac Valley node event, which this
// core writes as `teamIdx * BG_AV_MAX_STATES + state` (BattleGroundAV::InitNode, and SpawnEvent
// on every capture) - alliance 0, horde 1, neutral 2, assaulted 0, controlled 1. That gives
// 0 alliance assaulted, 1 alliance controlled, 2 horde assaulted, 3 horde controlled,
// 4 neutral assaulted, 5 neutral controlled.
//
// These used to be plain 0, 1, 2, 3 and 4, guessed to make the module's symbols compile. Every
// one of them was wrong, and the whole of BattleGroundTacticsAV.cpp reads node ownership through
// them: asking "is this horde tower horde-occupied" tested for 1, which is what an
// alliance-controlled node reads, so it was false for every horde node in every match. The
// selector opens with "if the horde holds no tower or graveyard, go kill Drek'Thar", so both
// sides marched at the enemy general from the first second, captured nothing, and - since this
// core cannot end an Alterac Valley any other way - the match never finished. One ran for nine
// hours with 80 bots in it.
//
// Derived from the core enums rather than written out, so a change there cannot silently
// desynchronise this again. The macros expand at the use site, which includes BattleGroundAV.h.
#ifndef BG_AV_NODE_STATUS_ALLY_OCCUPIED
#define BG_AV_NODE_STATUS_ALLY_OCCUPIED (BG_AV_TEAM_ALLIANCE * BG_AV_MAX_STATES + POINT_CONTROLLED)
#endif
#ifndef BG_AV_NODE_STATUS_HORDE_OCCUPIED
#define BG_AV_NODE_STATUS_HORDE_OCCUPIED (BG_AV_TEAM_HORDE * BG_AV_MAX_STATES + POINT_CONTROLLED)
#endif

// === Additional cmangos-only DBC store proxies ===
// sFactionStore (faction.dbc) — distinct from sFactionTemplateStore (factiontemplate.dbc).
struct FactionEntry;  // defined in DBCStructure.h
struct CmangosFactionStoreProxy
{
    template<typename T = FactionEntry>
    T const* LookupEntry(uint32 id) const { return sObjectMgr.GetFactionEntry(id); }
    uint32 GetNumRows() const { return 100; } // stub upper-bound
};
static CmangosFactionStoreProxy sFactionStore;

// sCreatureStorage (creature_template SQL).
struct CmangosCreatureStorageProxy
{
    template<typename T = CreatureInfo>
    T const* LookupEntry(uint32 id) const { return sObjectMgr.GetCreatureTemplate(id); }
    uint32 GetMaxEntry() const { return 100000; }
};
static CmangosCreatureStorageProxy sCreatureStorage;

// === Helpers ===
// strstri overload: bot's PlayerbotAI.cpp forward-declares strstri(std::string, std::string).
// Penqle's playerbot/Helpers.cpp now provides the implementation (added).
// Re-declare here for visibility at all bot TUs.
char* strstri(std::string const& s1, std::string const& s2);

// Overload of strstr taking std::string haystack — bot calls strstr(proto->Name1, "literal")
// where Name1 is std::string. Forward to libc strstr via .c_str().
inline const char* strstr(std::string const& haystack, const char* needle) {
    return std::strstr(haystack.c_str(), needle);
}

// === BattleGroundMgr alias ===
// Done via forwarder in Penqle's BattleGroundMgr.h (BgTemplateId → BGTemplateId).

// === BG_AV_NODE_STATUS_ contested (additional) ===
// "Contested" in the module is what this core calls assaulted: the node has been clicked and is
// counting down to the new owner. See the note on BG_AV_NODE_STATUS_ALLY_OCCUPIED above.
#ifndef BG_AV_NODE_STATUS_ALLY_CONTESTED
#define BG_AV_NODE_STATUS_ALLY_CONTESTED (BG_AV_TEAM_ALLIANCE * BG_AV_MAX_STATES + POINT_ASSAULTED)
#endif
#ifndef BG_AV_NODE_STATUS_HORDE_CONTESTED
#define BG_AV_NODE_STATUS_HORDE_CONTESTED (BG_AV_TEAM_HORDE * BG_AV_MAX_STATES + POINT_ASSAULTED)
#endif

// === TEAM_INDEX_ aliases (cmangos) ===
// Penqle uses BG_TEAM_ALLIANCE/BG_TEAM_HORDE. cmangos uses TEAM_INDEX_ALLIANCE/HORDE/NEUTRAL.
#ifndef TEAM_INDEX_ALLIANCE
#define TEAM_INDEX_ALLIANCE BG_TEAM_ALLIANCE
#endif
#ifndef TEAM_INDEX_HORDE
#define TEAM_INDEX_HORDE BG_TEAM_HORDE
#endif
#ifndef TEAM_INDEX_NEUTRAL
#define TEAM_INDEX_NEUTRAL 2
#endif

// === IsAutocastable (cmangos free function) ===
inline bool IsAutocastable(uint32 /*spellId*/) { return false; }
inline bool IsAutocastable(SpellEntry const* /*spellInfo*/) { return false; }

// === IsSpellAppliesAura / IsSpellHaveEffect / IsAreaAuraEffect (cmangos free functions) ===
inline bool IsSpellAppliesAura(SpellEntry const* spellInfo, uint32 effectMask = 0xFFFFFFFF) {
    return spellInfo && spellInfo->IsSpellAppliesAura(effectMask);
}
inline bool IsSpellHaveEffect(SpellEntry const* spellInfo, uint32 effect) {
    if (!spellInfo) return false;
    for (int i = 0; i < MAX_EFFECT_INDEX; ++i) {
        if (spellInfo->Effect[i] == effect) return true;
    }
    return false;
}
inline bool IsAreaAuraEffect(uint32 effect) {
    return effect == SPELL_EFFECT_APPLY_AREA_AURA_PARTY || effect == SPELL_EFFECT_APPLY_AREA_AURA_FRIEND
        || effect == SPELL_EFFECT_APPLY_AREA_AURA_ENEMY || effect == SPELL_EFFECT_APPLY_AREA_AURA_PET
        || effect == SPELL_EFFECT_APPLY_AREA_AURA_OWNER;
}


// === NAV_AREA_* / NAV_* (cmangos navmesh area types) ===
#ifndef NAV_AREA_WATER
#define NAV_AREA_WATER 7
#endif
#ifndef NAV_AREA_GROUND
#define NAV_AREA_GROUND 4
#endif
#ifndef NAV_AREA_GROUND_STEEP
#define NAV_AREA_GROUND_STEEP 3
#endif
#ifndef NAV_MAGMA_SLIME
#define NAV_MAGMA_SLIME 0x18
#endif
#ifndef NAV_GROUND_STEEP
#define NAV_GROUND_STEEP 0x02
#endif

// === CONDITION_FROM_AREATRIGGER_TELEPORT (cmangos) ===
// The same condition source, spelled CONDITION_FROM_AREATRIGGER here.
#define CONDITION_FROM_AREATRIGGER_TELEPORT CONDITION_FROM_AREATRIGGER

// === MINIMUM_LOOTING_TIME ===
#ifndef MINIMUM_LOOTING_TIME
#define MINIMUM_LOOTING_TIME 1000
#endif

// === FALL_MOTION_TYPE (cmangos motion type) → use a high stub value ===
#ifndef FALL_MOTION_TYPE
#define FALL_MOTION_TYPE 100
#endif

// === AuctionHouseType (cmangos enum) ===
enum AuctionHouseType {
    AUCTION_HOUSE_ALLIANCE = 0,
    AUCTION_HOUSE_HORDE = 1,
    AUCTION_HOUSE_NEUTRAL = 2,
    MAX_AUCTION_HOUSE_TYPE = 3,
};


// === SPELL_RANGE_FLAG_MELEE / RANGED (cmangos defines on SpellRangeEntry::Flags) ===
#ifndef SPELL_RANGE_FLAG_MELEE
#define SPELL_RANGE_FLAG_MELEE 1
#endif
#ifndef SPELL_RANGE_FLAG_RANGED
#define SPELL_RANGE_FLAG_RANGED 2
#endif


// === BG_AV_NODE_STATUS_NEUTRAL_OCCUPIED ===
// Snowfall Graveyard starts neutral, which is a third team index here rather than a flag.
#ifndef BG_AV_NODE_STATUS_NEUTRAL_OCCUPIED
#define BG_AV_NODE_STATUS_NEUTRAL_OCCUPIED (BG_AV_TEAM_NEUTRAL * BG_AV_MAX_STATES + POINT_CONTROLLED)
#endif

// === CREATURE_EXTRA_FLAG_INVISIBLE ===
#ifndef CREATURE_EXTRA_FLAG_INVISIBLE
#define CREATURE_EXTRA_FLAG_INVISIBLE 0x00040000
#endif


// === TAXI_MOTION_TYPE (cmangos) → FLIGHT_MOTION_TYPE (Penqle) ===
#ifndef TAXI_MOTION_TYPE
#define TAXI_MOTION_TYPE FLIGHT_MOTION_TYPE
#endif

// === sAreaTriggerStore (cmangos) ===
struct CmangosAreaTriggerStoreProxy
{
    template<typename T = AreaTriggerEntry>
    T const* LookupEntry(uint32 id) const { return sObjectMgr.GetAreaTrigger(id); }
    uint32 GetNumRows() const { return 10000; } // upper bound stub
};
static CmangosAreaTriggerStoreProxy sAreaTriggerStore;

// === LfgRoles / LfgRolePriority ===
// Real enums here, in src/game/LFG/LFGDefines.h, over the same PLAYER_ROLE_* values
// cmangos uses. The donor aliased them onto types its own dungeon-finder work added.


// === Other small defines ===
#ifndef ITEM_FLAG_UNIQUE_EQUIPPABLE
#define ITEM_FLAG_UNIQUE_EQUIPPABLE 0
#endif
#ifndef ROLL_DISENCHANT
#define ROLL_DISENCHANT 4
#endif
#ifndef SPELL_STATE_CHANNELING
#define SPELL_STATE_CHANNELING 3
#endif
#ifndef SKILL_FLAG_CAN_UNLEARN
#define SKILL_FLAG_CAN_UNLEARN 0x10
#endif

// === sScriptDevAIMgr (cmangos's ScriptDevAI) ===
// Gossip goes to the real thing - sScriptMgr::OnGossipHello - so a bot talking to a
// scripted npc runs the same script a player would. What is left here is the handful of
// hooks this core has no counterpart for, chiefly OnNpcSpellClick (spell-click handling is
// a later-expansion feature), which answer false so the caller falls through.
struct CmangosScriptDevAIMgrStub {
    template<typename... Args>
    bool OnGossipHello(Args... /*args*/) { return false; }
};
static CmangosScriptDevAIMgrStub sScriptDevAIMgr;

// === BG_AB GO/banner additional defines (cmangos) ===
#ifndef BG_AB_BANNER_ALLIANCE
#define BG_AB_BANNER_ALLIANCE 0
#endif
#ifndef BG_AB_BANNER_HORDE
#define BG_AB_BANNER_HORDE 1
#endif
#ifndef BG_AB_BANNER_CONTESTED_A
#define BG_AB_BANNER_CONTESTED_A 2
#endif
#ifndef BG_AB_BANNER_CONTESTED_H
#define BG_AB_BANNER_CONTESTED_H 3
#endif

// === BG WSG GO defines (cmangos) — Penqle uses BG_OBJECT_* maybe ===
#ifndef GO_WS_SILVERWING_FLAG
#define GO_WS_SILVERWING_FLAG 179830
#endif
#ifndef GO_WS_WARSONG_FLAG
#define GO_WS_WARSONG_FLAG 179831
#endif
#ifndef GO_WS_SILVERWING_FLAG_DROP
#define GO_WS_SILVERWING_FLAG_DROP 179785
#endif
#ifndef GO_WS_WARSONG_FLAG_DROP
#define GO_WS_WARSONG_FLAG_DROP 179786
#endif

// === BG WSG areatrigger defines (cmangos) ===
#ifndef WS_AT_SILVERWING_ROOM
#define WS_AT_SILVERWING_ROOM 3646
#endif
#ifndef WS_AT_WARSONG_ROOM
#define WS_AT_WARSONG_ROOM 3647
#endif

// === BG_AV node/banner defines (cmangos) ===
// The captain-dead events are ordinary battleground event ids here, not bit flags: 0x10 and 0x20
// are event 16 and event 32, which this core uses for graveyard and tower defender spawns. The
// module tests them to decide whether Balinda and Galvangar are still worth attacking.
#ifndef BG_AV_NODE_CAPTAIN_DEAD_A
#define BG_AV_NODE_CAPTAIN_DEAD_A BG_AV_NodeEventCaptainDead_A
#endif
#ifndef BG_AV_NODE_CAPTAIN_DEAD_H
#define BG_AV_NODE_CAPTAIN_DEAD_H BG_AV_NodeEventCaptainDead_H
#endif
#ifndef BG_AV_GO_BANNER_ALLIANCE
#define BG_AV_GO_BANNER_ALLIANCE 178925
#endif
#ifndef BG_AV_GO_BANNER_ALLIANCE_CONT
#define BG_AV_GO_BANNER_ALLIANCE_CONT 178940
#endif
#ifndef BG_AV_GO_BANNER_HORDE
#define BG_AV_GO_BANNER_HORDE 178943
#endif
#ifndef BG_AV_GO_BANNER_HORDE_CONT
#define BG_AV_GO_BANNER_HORDE_CONT 178944
#endif
#ifndef BG_AV_GO_GY_BANNER_ALLIANCE
#define BG_AV_GO_GY_BANNER_ALLIANCE 180058
#endif
#ifndef BG_AV_GO_GY_BANNER_ALLIANCE_CONT
#define BG_AV_GO_GY_BANNER_ALLIANCE_CONT 180059
#endif
#ifndef BG_AV_GO_GY_BANNER_HORDE
#define BG_AV_GO_GY_BANNER_HORDE 180060
#endif
#ifndef BG_AV_GO_GY_BANNER_HORDE_CONT
#define BG_AV_GO_GY_BANNER_HORDE_CONT 180061
#endif
#ifndef BG_AV_GO_GY_BANNER_SNOWFALL
#define BG_AV_GO_GY_BANNER_SNOWFALL 180062
#endif

// === GetSpellCastResultString (cmangos free function) ===
// Defined in playerbot/SpellCastResultString.cpp - one case per SpellCastResult,
// guarded the same way the enum is.
char const* GetSpellCastResultString(SpellCastResult res);

// === TARGET_FLAG_LOCKED / SPELL_STATE_TARGETING (cmangos) ===
#ifndef SPELL_STATE_TARGETING
#define SPELL_STATE_TARGETING 0
#endif

// === DIST_CALC_COMBAT_REACH_WITH_MELEE / MAX_GOSSIP_TEXT_OPTIONS ===
#define DIST_CALC_COMBAT_REACH_WITH_MELEE SizeFactor::CombatReachWithMelee
#ifndef MAX_GOSSIP_TEXT_OPTIONS
#define MAX_GOSSIP_TEXT_OPTIONS 8
#endif

// === HasPersistentAuraEffect / CAST_FLAG_PERSISTENT_AA / FACTION_GROUP_MASK ===
inline bool HasPersistentAuraEffect(SpellEntry const* /*spellInfo*/) { return false; }
#ifndef CAST_FLAG_PERSISTENT_AA
#define CAST_FLAG_PERSISTENT_AA 0x40
#endif
#ifndef FACTION_GROUP_MASK_ALLIANCE
#define FACTION_GROUP_MASK_ALLIANCE 0x4
#endif
#ifndef FACTION_GROUP_MASK_HORDE
#define FACTION_GROUP_MASK_HORDE 0x2
#endif

// === BG_AB_BANNER_* / BG_AB_NODE_STATUS_NEUTRAL (cmangos) ===
// Penqle has these in BattleGroundAB.h but with different naming.
#ifndef BG_AB_NODE_STATUS_NEUTRAL
#define BG_AB_NODE_STATUS_NEUTRAL 0
#endif
#ifndef BG_AB_BANNER_STABLE
#define BG_AB_BANNER_STABLE 0
#endif
#ifndef BG_AB_BANNER_BLACKSMITH
#define BG_AB_BANNER_BLACKSMITH 1
#endif
#ifndef BG_AB_BANNER_FARM
#define BG_AB_BANNER_FARM 2
#endif
#ifndef BG_AB_BANNER_LUMBER_MILL
#define BG_AB_BANNER_LUMBER_MILL 3
#endif
#ifndef BG_AB_BANNER_MINE
#define BG_AB_BANNER_MINE 4
#endif

// === SEC_GAMEMASTER alias (cmangos has it; Penqle goes SEC_PLAYER → SEC_ADMINISTRATOR) ===
#ifndef SEC_GAMEMASTER
#define SEC_GAMEMASTER SEC_ADMINISTRATOR
#endif

// === FORCED_MOVEMENT_RUN / ForcedMovement (cmangos) ===
// Penqle uses different movement-flag set; bot only checks symbolic value.
typedef int ForcedMovement;
#ifndef FORCED_MOVEMENT_RUN
#define FORCED_MOVEMENT_RUN 1
#endif
#ifndef FORCED_MOVEMENT_WALK
#define FORCED_MOVEMENT_WALK 0
#endif
#ifndef FORCED_MOVEMENT_FLIGHT
#define FORCED_MOVEMENT_FLIGHT 2
#endif
#ifndef FORCED_MOVEMENT_NONE
#define FORCED_MOVEMENT_NONE 0
#endif

// === SkillLineAbility store proxy ===
// cmangos exposes sSkillLineAbilityStore (DBCStorage<SkillLineAbilityEntry>);
// Penqle exposes sObjectMgr.GetSkillLineAbility(id).
struct SkillLineAbilityEntry;
struct CmangosSkillLineAbilityStoreProxy
{
    template<typename T = SkillLineAbilityEntry>
    T const* LookupEntry(uint32 id) const { return sObjectMgr.GetSkillLineAbility(id); }
    uint32 GetMaxEntry() const { return sObjectMgr.GetMaxSkillLineAbilityId(); }
    uint32 GetNumRows() const { return GetMaxEntry(); }
};
static CmangosSkillLineAbilityStoreProxy sSkillLineAbilityStore;

// === sAreaStore proxy (cmangos uses sAreaStore; Penqle has sAreaStorage) ===
// Same shape; keep both names.
#define sAreaStore sAreaStorage

// === sChatChannelsStore proxy ===
// cmangos bots walk an indexed DBC store to find the chat channels to join. This core
// loads ChatChannels.dbc but does not export the store - DBCStores.h says it has no
// usable index - and offers GetChannelEntryFor(id) instead, so the proxy probes ids.
//
// No string juggling, unlike the donor's version: ChatChannelsEntry here carries
// pattern[8] already, which is exactly the field cmangos reads.
struct CmangosChatChannelsStoreProxy
{
    // Channel ids are a short dense range in 1.12 (General is 1, the highest shipped is
    // well under 50). Probed once; the DBC is read-only after load.
    static std::vector<ChatChannelsEntry const*> const& snapshot()
    {
        static std::vector<ChatChannelsEntry const*> entries = [] {
            std::vector<ChatChannelsEntry const*> v;
            for (uint32 id = 0; id < 64; ++id)
                if (ChatChannelsEntry const* entry = GetChannelEntryFor(id))
                    v.push_back(entry);
            return v;
        }();
        return entries;
    }

    ChatChannelsEntry const* LookupEntry(uint32 index) const
    {
        auto const& entries = snapshot();
        return index < entries.size() ? entries[index] : nullptr;
    }

    uint32 GetNumRows() const { return uint32(snapshot().size()); }
};
static CmangosChatChannelsStoreProxy sChatChannelsStore;

// === sGOStorage (cmangos) → sObjectMgr.GetGameObjectInfo ===
struct CmangosGOStorageProxy
{
    template<typename T = GameObjectInfo>
    T const* LookupEntry(uint32 id) const { return sObjectMgr.GetGameObjectTemplate(id); }
    uint32 GetMaxEntry() const { return 200000; }
};
static CmangosGOStorageProxy sGOStorage;

// === sTaxiNodesStore (cmangos) → sObjectMgr.GetTaxiNodeEntry ===
struct TaxiNodesEntry;
struct CmangosTaxiNodesStoreProxy
{
    template<typename T = TaxiNodesEntry>
    T const* LookupEntry(uint32 id) const { return sObjectMgr.GetTaxiNodeEntry(id); }
    uint32 GetNumRows() const { return sObjectMgr.GetMaxTaxiNodeId(); }
};
static CmangosTaxiNodesStoreProxy sTaxiNodesStore;

// === TransportAnimation stub (cmangos has TransportAnim.dbc; Penqle doesn't) ===
// TransportAnimation, its node type and TransportPathContainer are all real here:
// src/game/Transports/TransportMgr.h. The donor stubbed them because its core kept the
// data elsewhere. Note the container holds TransportAnimationEntry const*, not the
// mutable node pointer cmangos uses.
// Note: Penqle has its own sTransportMgr; we extend TransportMgr inline (see Transports/TransportMgr.h).

// === sLootMgr shim (cmangos global; Penqle has LootStore but no equivalent singleton) ===
// Bot calls sLootMgr.GetLoot(player[, guid]) to fetch the loot the player is currently looking at.
// Penqle stores the Loot object directly on the looted entity (Creature/GameObject/Item/Corpse),
// resolved by the player's current loot guid. This MUST return the real loot: StoreLootAction
// consumes it to actually take items + release. A previous nullptr stub made StoreLoot abort
// before sending CMSG_LOOT_RELEASE, so bots kneeled on an open corpse forever ("crouch loop").
// Mirrors the core resolution in Handlers/LootHandler.cpp (no distance gate: StoreLoot is reacting
// to a server loot response, so the target is already validated).
struct CmangosLootMgrStub
{
    Loot* GetLoot(Player* player, ObjectGuid guid = ObjectGuid()) const
    {
        if (!player || !player->IsInWorld())
            return nullptr;

        if (!guid)
            guid = player->GetLootGuid();
        if (!guid)
            return nullptr;

        switch (guid.GetHigh())
        {
            case HIGHGUID_GAMEOBJECT:
                if (GameObject* go = player->GetMap()->GetGameObject(guid))
                    return &go->loot;
                break;
            case HIGHGUID_CORPSE:
                if (Corpse* bones = player->GetMap()->GetCorpse(guid))
                    return &bones->loot;
                break;
            case HIGHGUID_ITEM:
                if (Item* item = player->GetItemByGuid(guid))
                    return &item->loot;
                break;
            case HIGHGUID_UNIT:
                if (Creature* creature = player->GetMap()->GetCreature(guid))
                    return &creature->loot;
                break;
            default:
                break;
        }

        return nullptr;
    }
};
static CmangosLootMgrStub sLootMgr;

// === Map::GetHitPosition forwarder (cmangos name) ===
// Penqle uses GetLosHitPosition. The bot module's call sites were patched at
// the source level (TravelMgr.cpp / WorldPosition.h).


// === Free-function helpers (cmangos style) wrapping Penqle SpellEntry methods ===
// cmangos exposes these as free functions; Penqle wraps them in SpellEntry::method.
inline uint32 GetSpellCastTime(SpellEntry const* spellInfo, Spell const* spell = nullptr) {
    return spellInfo ? spellInfo->GetCastTime(nullptr, const_cast<Spell*>(spell)) : 0;
}
// 3-arg form: cmangos signature is GetSpellCastTime(SpellEntry, caster, Spell).
inline uint32 GetSpellCastTime(SpellEntry const* spellInfo, SpellCaster const* caster, Spell const* spell = nullptr) {
    return spellInfo ? spellInfo->GetCastTime(caster, const_cast<Spell*>(spell)) : 0;
}
// IsNextMeleeSwingSpell: cmangos free function checking SPELL_ATTR_ON_NEXT_SWING_1/_2.
inline bool IsNextMeleeSwingSpell(SpellEntry const* spellInfo) {
    // This core names the two attributes SPELL_ATTR_ON_NEXT_SWING_NO_DAMAGE and
    // SPELL_ATTR_ON_NEXT_SWING, and SpellEntry already answers the question.
    return spellInfo && spellInfo->IsNextMeleeSwingSpell();
}
inline uint32 GetSpellRecoveryTime(SpellEntry const* spellInfo) {
    return spellInfo ? spellInfo->GetRecoveryTime() : 0;
}
inline int32 GetSpellDuration(SpellEntry const* spellInfo) {
    return spellInfo ? spellInfo->GetDuration() : 0;
}
inline bool IsChanneledSpell(SpellEntry const* spellInfo) {
    return spellInfo && spellInfo->IsChanneledSpell();
}
inline SpellSchoolMask GetSpellSchoolMask(SpellEntry const* spellInfo) {
    return spellInfo ? SpellSchoolMask(spellInfo->GetSpellSchoolMask()) : SpellSchoolMask(0);
}
inline bool IsNonCombatSpell(SpellEntry const* spellInfo) {
    return spellInfo && spellInfo->IsNonCombatSpell();
}
inline bool IsPositiveEffect(SpellEntry const* spellInfo, SpellEffectIndex eff) {
    return spellInfo && spellInfo->IsPositiveEffect(eff);
}

// === GetAreaEntryByAreaID free function (cmangos) → AreaEntry::GetById (Penqle) ===
inline AreaEntry const* GetAreaEntryByAreaID(uint32 id) { return AreaEntry::GetById(id); }
inline AreaEntry const* GetAreaEntryByMapId(uint32 mapId) {
    auto* mapEntry = sMapStorage.LookupEntry<MapEntry>(mapId);
    return mapEntry ? AreaEntry::GetById(mapEntry->linkedZone) : nullptr;
}

// === MeetingStoneInfo / MeetingStoneSet ===
// The donor added these to its core's LFGMgr.h. This core's LFG is the vanilla meeting
// stone system and has no equivalent, and the bot actions that use them are not wired up
// yet - see the note on LfgActions in doc/PLAYERBOT_PORT_SCOPE.md. Defined here so the
// module compiles; nothing fills a set.
struct MeetingStoneInfo
{
    uint32 areaId = 0;
    uint32 dungeonId = 0;
    std::string name;
};
typedef std::vector<MeetingStoneInfo> MeetingStoneSet;

// === CharSections ===
// The donor's core had no CharSections.dbc loader, so the shim opened the file and
// parsed it by hand. This one loads it at startup (DBCStores.cpp) and publishes both
// sCharSectionsStore and sCharSectionMap, a multimap<uint32, CharSectionsEntry const*>
// keyed the same way. The hand-rolled loader, the duplicate CharSectionType enum and
// the duplicate CharSectionsEntry struct are all gone with it.

// === LFGQueue ===
// Penqle has its own LFGQueue in src/game/LFG/LFGMgr.h with stub methods added.
// World::GetLFGQueue() forwards to sLFGMgr. Bot module uses the existing types.

// === GetSpellStore (cmangos) → sSpellMgr (Penqle) ===
// cmangos exposes a global GetSpellStore() returning the DBC store as a POINTER.
inline CmangosSpellTemplateProxy* GetSpellStore() { return &sSpellTemplate; }

// === WORLD_SESSION_STATE_* ===
// The donor's core tracks a session lifecycle enum on WorldSession; this one does not.
// The single bot call site that read it now asks the question directly - see
// PlayerbotAI::HandleTeleportAck.

// === EmotesTextSoundEntry / FindTextSoundEmoteFor (cmangos) — DBC stubs ===
struct EmotesTextSoundEntry { uint32 SoundId = 0; };
inline EmotesTextSoundEntry const* FindTextSoundEmoteFor(uint32 /*textEmoteId*/, uint32 /*race*/, uint32 /*gender*/) { return nullptr; }

// GetApplicationStartTime is real here: src/shared/Timer.h, on the steady clock.

// === GetTeamIndexByTeamId (cmangos) → BattleGround static method ===
// Provide free-function forwarder. (BattleGround.h has it as a static.)
inline BattleGroundTeamIndex GetTeamIndexByTeamId(Team team) {
    return team == ALLIANCE ? BG_TEAM_ALLIANCE : BG_TEAM_HORDE;
}

// === GetRandomGenerator (cmangos) === stub: cmangos has its own thread-local PRNG;
// Penqle uses urand/frand. Bot module's TravelMgr seeds a default_random_engine via this.
// Returns pointer-style — bot does *GetRandomGenerator() in some sites.
inline std::mt19937* GetRandomGenerator() {
    thread_local std::mt19937 s_rng(static_cast<unsigned>(std::chrono::steady_clock::now().time_since_epoch().count()));
    return &s_rng;
}

// === Loot status flags (cmangos LootMgr.h) ===
// Bot's LootValues.cpp returns bitflags describing loot state. Penqle has no equivalent
// (its Loot just exposes items/gold). Define as bitflags so bot computes a value (which
// is consumed only on the bot side via AI_VALUE comparisons; runtime semantic is harmless).
#ifndef LOOT_STATUS_FAKE_LOOT
enum LootStatusFlags : uint32 {
    LOOT_STATUS_FAKE_LOOT              = 0x01,
    LOOT_STATUS_CONTAIN_GOLD           = 0x02,
    LOOT_STATUS_NOT_FULLY_LOOTED       = 0x04,
    LOOT_STATUS_CONTAIN_FFA            = 0x08,
    LOOT_STATUS_CONTAIN_RELEASED_ITEMS = 0x10,
};
#endif

// === LootMethod sentinel (cmangos has NOT_GROUP_TYPE_LOOT for "no group loot") ===
// Penqle uses NOT_GROUP_TYPE_LOOT or FREE_FOR_ALL — but the enum values may differ.
// Stub as 0xFF so the comparison `lootMethod != NOT_GROUP_TYPE_LOOT` always hits.
#ifndef NOT_GROUP_TYPE_LOOT
constexpr uint32 NOT_GROUP_TYPE_LOOT = 0xFF;
#endif

// === SPELL_ATTR_ON_NEXT_SWING aliases ===
// The module writes the cmangos-of-a-different-vintage spelling, SPELL_ATTR_ON_NEXT_SWING_1
// and _2; this core names them SPELL_ATTR_ON_NEXT_SWING (the damaging one, bit 10) and
// SPELL_ATTR_ON_NEXT_SWING_NO_DAMAGE (bit 2).
#define SPELL_ATTR_ON_NEXT_SWING_1 SPELL_ATTR_ON_NEXT_SWING
#define SPELL_ATTR_ON_NEXT_SWING_2 SPELL_ATTR_ON_NEXT_SWING_NO_DAMAGE

// === UNIT_FLAG_UNTARGETABLE / UNIT_FLAG_UNINTERACTIBLE (cmangos names) ===
// Penqle uses UNIT_FLAG_NOT_SELECTABLE for both concepts.
#ifndef UNIT_FLAG_UNTARGETABLE
#define UNIT_FLAG_UNTARGETABLE UNIT_FLAG_NOT_SELECTABLE
#endif
#ifndef UNIT_FLAG_UNINTERACTIBLE
#define UNIT_FLAG_UNINTERACTIBLE UNIT_FLAG_NOT_SELECTABLE
#endif

// === IsAutoRepeatRangedSpell (cmangos free function) ===
// Penqle's SpellEntry has IsAutoRepeatRangedSpell as a method. Wrap as free fn.
inline bool IsAutoRepeatRangedSpell(SpellEntry const* spellInfo) {
    return spellInfo && spellInfo->IsAutoRepeatRangedSpell();
}

// === Consumable item subclasses ===
// Pre-BC item_template only ever uses ITEM_SUBCLASS_CONSUMABLE (0) - the finer split into
// potion/elixir/food/... arrived with TBC - so this core keeps those values commented out
// in ItemPrototype.h. The bot module classifies consumables by them in a dozen places.
// Declared here with their retail values so those checks compile; on vanilla data they
// simply never match, and the bot falls back to the spell-effect based checks next to them.
enum ItemSubclassConsumableCompat
{
    ITEM_SUBCLASS_POTION                = 1,
    ITEM_SUBCLASS_ELIXIR                = 2,
    ITEM_SUBCLASS_FLASK                 = 3,
    ITEM_SUBCLASS_SCROLL                = 4,
    ITEM_SUBCLASS_FOOD                  = 5,
    ITEM_SUBCLASS_ITEM_ENHANCEMENT      = 6,
    ITEM_SUBCLASS_BANDAGE               = 7,
    ITEM_SUBCLASS_CONSUMABLE_OTHER      = 8,
};

// === ITEM_SPELLTRIGGER_ON_NO_DELAY_USE ===
// cmangos has a fifth trigger type for "use, no equip cooldown". This core stops at
// CHANCE_ON_HIT (MAX_ITEM_SPELLTRIGGER == 3), so nothing can carry the value; define it
// past the end of the range so the comparisons compile and never match.
#ifndef ITEM_SPELLTRIGGER_ON_NO_DELAY_USE
#define ITEM_SPELLTRIGGER_ON_NO_DELAY_USE 5
#endif

// === TrainerSpell::learnedSpell ===
// cmangos's TrainerSpell records the spell the trainer's spell teaches. Here the trainer
// spell itself does the teaching, through its SPELL_EFFECT_LEARN_SPELL effects - which is
// how WorldSession::HandleTrainerBuySpellOpcode resolves it. Same resolution, on demand.
inline uint32 GetTrainerLearnedSpell(TrainerSpell const* tSpell)
{
    if (!tSpell)
        return 0;

    SpellEntry const* proto = sSpellMgr.GetSpellEntry(tSpell->spell);
    if (!proto)
        return 0;

    for (int i = 0; i < MAX_EFFECT_INDEX; ++i)
        if (proto->Effect[i] == SPELL_EFFECT_LEARN_SPELL)
            return proto->EffectTriggerSpell[i];

    return 0;
}

// === WorldSession::SendPlaySpellVisual (cmangos) ===
// This core plays a visual by broadcasting it from the unit (Unit::SendPlaySpellVisualKit).
// The bot uses the cmangos form as a private marker - a debug or RTSC highlight only the
// requesting player should see - so send the same packet to that one session.
#include "WorldSession.h"
#include "Server/Packets/Spell.h"
inline void BotSendPlaySpellVisual(WorldSession* session, ObjectGuid guid, uint32 spellVisualId)
{
    if (!session)
        return;

    auto packet = std::make_unique<WorldPackets::Spell::PlaySpellVisual>();
    packet->casterGuid = guid;
    packet->spellVisualId = spellVisualId;
    session->SendPacket(std::move(packet));
}

// === Unit::GetAttackDistance / Player::IsFreeFlying (cmangos) ===
// Aggro radius is a creature notion in this core - Creature::GetAttackDistance - and the bot
// asks it of a Unit it has not classified yet. Anything that is not a creature has no aggro
// radius, so answer zero for it.
inline float BotGetAttackDistance(Unit const* unit, Unit const* target)
{
    Creature const* creature = unit ? unit->ToCreature() : nullptr;
    return creature ? creature->GetAttackDistance(target) : 0.0f;
}

// cmangos's IsFreeFlying means "flying under its own power, not on a taxi". Nothing flies
// that way in vanilla - the flying mounts and their movement flags arrived with TBC - so
// this is constantly false here, and the checks around it fall through to the ground path.
inline bool BotIsFreeFlying(Unit const* /*unit*/) { return false; }

// === Mail (cmangos keeps it on Player; this core keeps it on MasterPlayer) ===
// MasterPlayer is the session-side half of a character - it survives map changes and holds
// the mailbox, the social list and the action bars. A bot logs in through the same path a
// client does (WorldSession::HandlePlayerLogin), so an in-world bot always has one.
#include "Chat/MasterPlayer.h"
inline MasterPlayer* BotMail(Player const* player)
{
    return (player && player->GetSession()) ? player->GetSession()->GetMasterPlayer() : nullptr;
}

// === Player::GetDividerGuid (cmangos) ===
// cmangos parks the guid of whoever pushed a quest on the Player as its "divider". This
// core keeps the same fact - along with the quest it was pushed for - in QuestShareInfo.
inline ObjectGuid BotQuestSharerGuid(Player const* player)
{
    if (!player)
        return ObjectGuid();

    auto const& shareInfo = player->GetQuestShareInfo();
    return shareInfo ? shareInfo->PlayerGuid : ObjectGuid();
}

// === GossipText (cmangos) ===
// cmangos's GossipText carries its lines inline as Options[i].Text_0 / Text_1. Here npc_text
// holds ids into broadcast_text instead, so reading a line is a second lookup. Text_0 is the
// male line and Text_1 the female one; the bot only ever reads what the npc says, so fall
// back to whichever of the two is filled in.
#include "Handlers/NPCHandler.h"
inline std::string BotGossipTextLine(uint32 textId, uint32 optionIndex = 0)
{
    NpcText const* text = sObjectMgr.GetNpcText(textId);
    if (!text || optionIndex >= MAX_GOSSIP_TEXT_OPTIONS)
        return std::string();

    BroadcastText const* broadcast = sObjectMgr.GetBroadcastTextLocale(text->Options[optionIndex].BroadcastTextID);
    if (!broadcast)
        return std::string();

    return !broadcast->maleText[LOCALE_enUS].empty() ? broadcast->maleText[LOCALE_enUS]
                                                     : broadcast->femaleText[LOCALE_enUS];
}

// === Localized names (cmangos ObjectMgr::GetXLocaleStrings) ===
// cmangos fills a caller-provided string; here each locale row is a vector indexed by the
// locale index, and an index that is out of range or empty just means "no translation".
inline std::string BotLocalizedString(std::vector<std::string> const& row, int32 locIdx, std::string const& fallback)
{
    if (locIdx >= 0 && uint32(locIdx) < row.size() && !row[locIdx].empty())
        return row[locIdx];

    return fallback;
}

inline std::string BotLocalizedQuestTitle(uint32 questId, int32 locIdx, std::string const& fallback)
{
    QuestLocale const* locale = sObjectMgr.GetQuestLocale(questId);
    return locale ? BotLocalizedString(locale->Title, locIdx, fallback) : fallback;
}

inline std::string BotLocalizedCreatureName(uint32 entry, int32 locIdx, std::string const& fallback)
{
    CreatureLocale const* locale = sObjectMgr.GetCreatureLocale(entry);
    return locale ? BotLocalizedString(locale->Name, locIdx, fallback) : fallback;
}

inline std::string BotLocalizedItemName(uint32 itemId, int32 locIdx, std::string const& fallback)
{
    ItemLocale const* locale = sObjectMgr.GetItemLocale(itemId);
    return locale ? BotLocalizedString(locale->Name, locIdx, fallback) : fallback;
}

// === Player::CanStoreItem (cmangos) ===
// This core also answers which bag slot the item would land in, through an out parameter
// the bot never reads. Everything else about the call is the same.
inline InventoryResult BotCanStoreItem(Player const* player, uint8 bag, uint8 slot, ItemPosCountVec& dest, Item* pItem, bool swap = false)
{
    if (!player)
        return EQUIP_ERR_ITEM_NOT_FOUND;

    uint8 bagSlot = NULL_SLOT;
    return player->CanStoreItem(bag, slot, dest, pItem, bagSlot, swap);
}

// === countof (cmangos) ===
// Element count of a C array, the cmangos spelling of what this tree writes out by hand.
template<typename T, size_t N>
constexpr size_t countof(T const (&)[N]) { return N; }

// === MotionMaster::MovePath (cmangos) ===
// cmangos walks a unit along a precomputed point list through a path movement generator.
// This core has none; a spline is launched directly instead, the same way its own debug
// movement commands do it (see ChatHandler::HandleVideoTurn).
#include "Movement/spline/MoveSplineInit.h"
inline void BotMovePath(Unit* unit, std::vector<G3D::Vector3> const& path, bool walk = false)
{
    // Two points minimum: MoveSplineInitArgs::Validate rejects a shorter path
    // ('path.size() > 1' failed) and logs an error for it, and a one point path is
    // the unit's own position anyway - there is no movement in it to launch.
    if (!unit || path.size() < 2)
        return;

    Movement::MoveSplineInit init(*unit, "PlayerbotMovePath");
    init.MovebyPath(path);
    init.SetWalk(walk);
    init.Launch();
}

// === GameObject::IsInUse (cmangos) ===
// "Someone is using it right now" is the object's loot state here.
inline bool BotGameObjectInUse(GameObject const* go)
{
    return go && go->getLootState() == GO_ACTIVATED;
}

// === WorldSession::QueuePacket (cmangos) ===
// cmangos queues the raw bytes and parses them when the world thread gets to them. Here the
// queue holds parsed packets, so the parse happens up front. Queuing rather than calling the
// handler still matters: some of these are built on a worker thread, and the handler must run
// on the world thread.
#include "Packet.h"
#include "Server/Packets/Chat.h"
#include "Server/Packets/Spell.h"
template<typename PacketType>
inline void BotQueuePacket(WorldSession* session, WorldPacket packet)
{
    if (!session)
        return;

    auto typed = std::make_unique<PacketType>();
    typed->ReadFromWorldPacket(packet);
    session->QueuePacket(std::move(typed));
}

// === Player::GetItemByEntry (cmangos) ===
// This core can count how many of an item a character holds, but not hand one back, so walk
// the same slots Player::GetItemCount does and return the first match.
inline Item* BotGetItemByEntry(Player const* player, uint32 entry)
{
    if (!player || !entry)
        return nullptr;

    for (int i = EQUIPMENT_SLOT_START; i < INVENTORY_SLOT_ITEM_END; ++i)
        if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
            if (item->GetEntry() == entry)
                return item;

    for (int i = KEYRING_SLOT_START; i < KEYRING_SLOT_END; ++i)
        if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
            if (item->GetEntry() == entry)
                return item;

    for (int i = INVENTORY_SLOT_BAG_START; i < INVENTORY_SLOT_BAG_END; ++i)
        if (Bag* bag = (Bag*)player->GetItemByPos(INVENTORY_SLOT_BAG_0, i))
            if (Item* item = bag->GetItemByEntry(entry))
                return item;

    return nullptr;
}

// === Player::CanBankItem (cmangos) ===
// Same shape as BotCanStoreItem above: this core also reports the bag slot the item would go
// to, through an out parameter the bot does not read.
inline InventoryResult BotCanBankItem(Player const* player, uint8 bag, uint8 slot, ItemPosCountVec& dest, Item const* pItem, bool swap = false)
{
    if (!player)
        return EQUIP_ERR_ITEM_NOT_FOUND;

    uint8 bagSlot = NULL_SLOT;
    return player->CanBankItem(bag, slot, dest, pItem, swap, bagSlot);
}

// A scratch packet for the handlers that read nothing off the wire. The adapters take a
// WorldPacket&, so the empty ones still need something to bind to.
inline WorldPacket& BotEmptyPacket(uint16 opcode)
{
    thread_local WorldPacket packet;
    packet.Initialize(opcode, 0);
    return packet;
}

// === ChannelMgr (cmangos) ===
// Channel lookups here take a PlayerPointer - the session-or-world wrapper this core passes
// around chat code - rather than a Player*. Wrap it at the call site.
#include "Chat/ChannelMgr.h"
inline PlayerPointer BotPlayerPointer(Player* player)
{
    return PlayerPointer(new PlayerWrapper<Player>(*player));
}

// === Player::GetTaxiPathSpline (cmangos) ===
// cmangos hands back the spline a flight is following. Here the flight is a list of taxi
// nodes on PlayerTaxi, so the question the bot actually asks - where is this flight going -
// is answered from the last node of that list.
inline TaxiNodesEntry const* BotTaxiDestinationNode(Player const* player)
{
    if (!player || !player->IsTaxiFlying())
        return nullptr;

    uint32 const destNode = player->GetTaxi().GetTaxiDestination();
    return destNode ? sObjectMgr.GetTaxiNodeEntry(destNode) : nullptr;
}

// === Position distance ===
// cmangos's Position answers distances itself. Here Position is a plain coordinate struct,
// so the two-point distance is computed where it is needed.
inline float BotPositionDistance(Position const& from, Position const& to)
{
    float const dx = from.x - to.x;
    float const dy = from.y - to.y;
    float const dz = from.z - to.z;
    return sqrt(dx * dx + dy * dy + dz * dz);
}
