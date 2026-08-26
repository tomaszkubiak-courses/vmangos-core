# Playerbot feature scope: mod-playerbots compared to this fork

Working notes, written 2026-08-25. Not a commitment to build any of it.

## What was compared

- **This fork** — `src/game/PlayerBots/`: 12 files, ~16k lines, compiled directly into the `game`
  library. Upstream VMaNGOS bots, with upstream PRs #2426, #3330, #3336 and #3345 already merged
  in locally.
- **mod-playerbots** — `D:\wow-server\mod-playerbots`, `github.com/mod-playerbots/mod-playerbots`
  at commit `2f7d9f77`. An AzerothCore module, 1362 files, ~242k lines, descended from IKE3's
  mangosbot. Targets WotLK 3.3.5a. It also requires a forked core
  (`mod-playerbots/azerothcore-wotlk`, branch `Playerbot`) because it needs hook types stock
  AzerothCore does not define, so it is not a drop-in module even on its own platform.

The two systems share only their foundation: a `WorldSession` with no socket, a real character
logged in behind it, a manager singleton, and a per-bot AI object. Everything above that differs.

| | This fork | mod-playerbots |
|---|---|---|
| Decision model | hardcoded `switch (class)` — `UpdateInCombatAI_Mage()` etc., `PartyBotAI.cpp:1029` | Engine with Strategy/Trigger/Action/Value objects and a weighted action queue, `src/Bot/Engine/Engine.h` |
| Class AI | 9 vanilla classes, two functions each | per-class directories plus per-dungeon and per-boss action sets |
| Navigation | hardcoded battleground waypoint arrays, `BattleBotWaypoints.cpp` | `TravelMgr`/`TravelNode` graph, ~253k lines, backed by `playerbots_travelnode*` tables |
| Gear and talents | `player_premade_item_template` / `player_premade_spell_template` plus random fill | `PlayerbotFactory`, `RandomItemMgr`, weight scales, BiS tables, enchant tables |
| Configuration | ~9 keys, `mangosd.conf.dist.in:3183` | `playerbots.conf.dist`, 888 keys |
| Database | reuses the world DB | its own `playerbots` DB, roughly 25 tables plus caches |
| Control surface | GM-only chat commands `.partybot` / `.battlebot`, `Chat.cpp:96-132`, all `SEC_ADMINISTRATOR` | player-facing whisper commands, chat filter, account linking, external TCP command server |
| Threading | inline in the world update, throttled by `PlayerBot.UpdateMs` | dedicated `PlayerbotWorldThreadProcessor` with an operation queue |
| Random bots | **no AI at all** — the config comment says so outright | `RandomPlayerbotMgr`: levels, gears, quests, wanders, queues for battlegrounds |

## Ground rules for anything implemented here

- Bot behaviour is not Blizzlike, so each feature needs a config key in `mangosd.conf.dist.in`
  defaulting to off, per `CLAUDE.md`.
- A new `.cpp` must be added to `src/game/CMakeLists.txt`; that list is explicit, not globbed.
- New tables need a migration under `sql/migrations/` and a cmake re-run. The world DB is imported
  from a released dump, so bot-owned data belongs in the characters DB or a new database.
- There is no CI in this fork. Build every `SUPPORTED_CLIENT_BUILD` a change touches by hand.

## What this fork already has, and should not be rebuilt

| Capability | Location |
|---|---|
| Socketless session, bot login, server packets forwarded to the AI | `WorldSession.cpp:135,156,234`; `PlayerBotMgr::AddBot` |
| Bot roster loaded from the `playerbot` table (`char_guid`, `chance`, `ai`) | `PlayerBotMgr.cpp:93` |
| Per-class spell pointer cache, 45 slots | `CombatBotBaseAI.h`, the `m_spells` union |
| Heal target selection, dispel, buffs, crowd control, trinket use, totems | `CombatBotBaseAI.cpp` |
| Gear from premade templates plus random fill for empty slots | `player_premade_item_template`, `EquipRandomGearInEmptySlots()` |
| Talents and spells from a premade spec, or `HandleLearnAllTrainerCommand` | `CombatBotBaseAI.cpp:2563` |
| Threat check driving taunt and pull-off decisions | `PartyBotAI.cpp:300-305` |
| Eat and drink, auto-revive, fleeing, stealth, druid forms | `PartyBotAI.h` |
| Battleground waypoint movement, flag carrying, graveyard jump | `BattleBotAI`, `BattleBotWaypoints.cpp` (WSG, AB, AV) |
| Twenty party bot GM subcommands | `Chat.cpp:96-119` |

## Tier A — prerequisites

| # | Feature | Gap | Effort |
|---|---|---|---|
| A1 | Bot account and character auto-provisioning | Characters must already exist in `playerbot`. `GenBotAccountId()` fakes account ids above `MAX(account.id)+10000` but creates no rows. Needs a name pool table, a character creation path, and a cleanup command. | M |
| A2 | `WorldBotAI`, a third `CombatBotBaseAI` subclass beside `PartyBotAI` and `BattleBotAI` | This is the hook random bots currently lack. All 18 pure virtual class handlers must be implemented. | M for the skeleton |
| A3 | Strategy/Trigger/Action engine | Replaces the `switch (class)` dispatch. Gates per-behaviour toggles and player-set strategies. | XL |
| A4 | Bot updates off the world thread | Only matters beyond a few hundred bots. High risk against map thread-safety. | L |

## Tier B — world and random bot behaviour

This is the real gap: random bots in this fork have no AI whatsoever.

| # | Feature | Notes and dependencies | Effort |
|---|---|---|---|
| B1 | Grinding: select a level-appropriate mob, engage, loot, rest | Uses `GridSearchers` and the existing combat AI. Cheapest large win. | M |
| B2 | Corpse looting, skinning, group loot rolls | `Loot`, `LootMgr` | S–M |
| B3 | Death cycle: release, corpse run, revive | The battle bot graveyard jump is a teleport shortcut; world bots need a real corpse run. | S |
| B4 | Vendors: sell greys, buy food, water, ammo and reagents, repair | `Handlers/NPCHandler.cpp`; `AddAllSpellReagents()` already exists. | M |
| B5 | Trainer visits, replacing the `LearnAllTrainer` shortcut | Makes progression Blizzlike; needs trainer spell filtering. | M |
| B6 | Travel system: node graph, inter-zone routing, taxi use | The module's `TravelMgr`/`TravelNode` is WotLK-specific, so design reuse only. This fork has `PathFinder`/`MoveMap` and taxi data; the graph would be derived from `creature`/`gameobject` spawns and taxi nodes. Blocks B7. | XL |
| B7 | Questing: accept from nearby givers, complete kill/collect/explore objectives, turn in, share | `ObjectMgr::GetCreatureQuestRelationsMapBounds` (`ObjectMgr.h:1436`) and `GetGOQuestRelationsMapBounds` already provide the giver-to-quest map. Objective targeting comes from `quest_template`. Needs B6 for anything outside the current zone. | XL |
| B8 | Level-up maintenance: talents, gear, spells, bags | Partly present (`LearnRandomTalents`, `EquipPremadeGearTemplate`) but fires at spawn, not on level-up. | S–M |
| B9 | Bot chat: say/whisper lines and reactions | The module ships `ai_playerbot_texts` plus a probability table. Needs a new characters-DB table; mostly content once wired. | M |
| B10 | Idle roleplay behaviour: emotes, sitting in inns, visiting NPCs, mounting | Mount handling partly exists in `BattleBotAI::UseMount`. | M |
| B11 | Guilds: create, invite, join, guild chat | `src/game/Guild` is complete. | M |
| B12 | Random bots queueing for battlegrounds unprompted | `BattleBot.AutoJoin` already does this for battle bots; extend to world bots. | S |
| B13 | Mail, sending and receiving | Low value. | S |
| B14 | Auction house participation | Overlaps the existing `AHBot.Enable`; probably skip. | M |
| B15 | Professions: gathering, fishing, crafting | The vanilla skill API is present; large content surface. | L |

## Tier C — player-facing control

| # | Feature | Notes | Effort |
|---|---|---|---|
| C1 | Whisper command interface | Bots here are `SEC_ADMINISTRATOR` only (`Chat.cpp:1222`). The module lets any player whisper their own bots. Needs a command parser and a permission model. Largest usability difference. | L |
| C2 | Bot ownership and account linking | Only `PartyBot.MaxBots` and `PartyBot.SkipChecks` exist today. Required before C1 can open to non-GMs. | M |
| C3 | Per-bot persisted custom strategies | Requires A3. | M |
| C4 | Meeting stone / LFG channel group formation | Vanilla has meeting stones; the module's LFG is the WotLK dungeon finder, so design reuse only. | L |
| C5 | Bots suggesting a dungeon or quest to do | Requires B7. | M |

## Tier D — combat quality, no engine required

| # | Feature | Current state | Effort |
|---|---|---|---|
| D1 | Potions, healthstones, bandages in combat | Absent; only `UseTrinketEffects` exists. | S |
| D2 | Racial abilities | Absent. | S |
| D3 | Kiting and range management | Only `RunAwayFromTarget`. | M |
| D4 | Mana conservation behaviour | Absent. | S |
| D5 | Pull strategy: designated puller, ranged pull, line-of-sight pull | Absent; `.partybot pull` is manual. | M |
| D6 | Threat management for DPS bots | Tank-side threat exists at `PartyBotAI.cpp:300`; DPS-side does not. | S |
| D7 | Ready check and automated raid target marking | Manual marks exist (`ccmark`, `focusmark`). | S |
| D8 | Positioning: melee behind the target, ranged spread | Absent. | M |

## Tier E — content, written from scratch

- **E1** Vanilla dungeon tactics. The module's `src/Ai/Dungeon/*` is entirely TBC and WotLK. L per
  instance.
- **E2** Vanilla raid tactics (MC, BWL, AQ, Naxx). The module covers Aq20 and BWL but against WotLK
  spell ids and the AzerothCore API; design reference only. XL.
- **E3** Objective-driven battleground AI beyond waypoints. The module's `BattleGroundTactics.cpp`
  is ~203k lines of WotLK battleground logic. The concepts transfer to WSG, AB and AV; the code
  does not. L.

## Not portable

Death knights, dual specialisation, glyphs, achievements, arena teams, vehicles, emblems, the
WotLK dungeon finder, the `charsections_dbc` and `emotetextsound_dbc` helper tables, and the
AzerothCore hook types the module registers against (`PlayerbotScript`,
`MISCHOOK_ON_DESTRUCT_PLAYER`, `SERVERHOOK_CAN_PACKET_RECEIVE`). This fork has no module hook
system at all; bot code is compiled straight into `game`.

## Order the tiers would have been built in

Written before the tortoise-wow findings below, and kept because it still describes what the
features are worth relative to each other. It is **not** the plan being followed — see "Decision"
at the end.

1. A2 with B1, B2 and B3 — gives random bots an AI for the first time. Self-contained, roughly one
   to two thousand lines, no schema change. Best value for the effort.
2. D1, D2, D4, D6, D7 — small combat wins that benefit party, battle and world bots at once.
3. A1 with B8 and B12 — bots that provision, level and queue themselves.
4. B4, B5, B9, B11 — economy and social presence.
5. C2, then C1 — opening bots to ordinary players.
6. B6, then B7 — travel and questing, the two extra-large items.
7. A3 — only if the strategy engine is wanted for its own sake.

## Effort scale

S is under about 300 lines, M is 300 to 1500, L is 1500 to 5000, XL is above 5000.

# A second donor: tortoise-wow

Examined 2026-08-25, after the comparison above.

`D:\wow-server\tortoise-wow` — `Shyalya/tortoise-wow`, branch `playerbots-integration-gh`, a fork
of `Penqle/tortoise-wow`, which restores Turtle-WoW 1.18.1 (client build 7272). **Turtle's core is
a vmangos derivative**: 85 of roughly 95 `src/game/` entries share names with ours, it has the
`SUPPORTED_CLIENT_BUILD` cache variable and a generated `Progression.h`, the same `Maps/`,
`Objects/`, `Spells/`, `Battlegrounds/` layout, and the same `AuraRemovalMgr`, `GuardMgr`,
`HonorMgr`, `HardcodedEvents` and `Anticheat` subsystems.

What it vendors under `src/modules/PlayerBots/` is **IKE3's cmangos playerbots**, compiled with
`CMANGOS MANGOSBOT_ZERO ENABLE_PLAYERBOTS` — the *vanilla* codepath. 459 `.cpp` files, ~245k
lines, gated behind `-DBUILD_PLAYERBOTS=ON` and the `AiPlayerbot.Enabled` config key.

So this, not mod-playerbots, is the right donor: IKE3 playerbots already ported onto a
vmangos-lineage vanilla core.

## How tortoise attached it

| Piece | Size | Note |
|---|---|---|
| `cmangos-compat-shim.h` | 1026 lines | cmangos names to Turtle names: typedefs, define mappings, missing standard-library includes. Its header comment lists exactly which mismatches needed per-call-site rewrites instead |
| `cmangos-compat-stubs/` | 5 headers | `ScriptDevAIMgr.h`, `LFGDefines.h`, `LFGQueue.h`, `SpellEffectDefines.h`, `WorldState.h` |
| Core files touched | 14 | `Player.{h,cpp}`, `Unit.cpp`, `World.cpp`, `WorldSession.h`, `CharacterHandler.cpp`, `MovementHandler.cpp`, `Channel.h`, `SharedDefines.h`, `Master.cpp`, two `CMakeLists.txt`, plus two new files |
| `ModuleSlots.h` | 29 lines | a flat `void*` array on `Player`; the module owns the memory and the core never reads it |
| `PlayerbotStubs.cpp` | 41 lines | link stubs for `BUILD_PLAYERBOTS=OFF` |
| `HostHooks.cpp` | 99 lines | bot lifecycle bodies that need both host and module types visible |
| `PlayerbotScripts.cpp` | 265 lines | all remaining core contact, through four hook classes (`WorldScript`, `ServerScript`, `PlayerScript`) and about twelve hooks |

Core contact is that small only because Turtle's core carries an AzerothCore-style hook framework
in `ScriptObjects.h` (817 lines). We do not have one.

Tortoise **removed** vmangos's built-in bots to make room: `World.cpp:2346` records that
`sPlayerBotMgr.Load()` was deleted, `WorldSession.cpp:447` that the `IsChatBot` clause went with
it. The two systems were treated as mutually exclusive.

## The data, which is the main prize

`src/modules/PlayerBots/sql/world/classic/`:

- `ai_playerbot_travel_nodes.sql` — 21 MB, 422,285 lines, the vanilla travel graph
- `ai_playerbot_named_location.sql` — 7.6 MB, 54,102 lines
- `ai_playerbot_zone_level.sql`, `ai_playerbot_weightscales.sql`, `ai_playerbot_enchants.sql`

That is item **B6** above — the extra-large blocker in front of questing — already solved, as
vanilla data.

Configuration: `aiplayerbot.conf.dist.in`, 5052 lines, 3644 `AiPlayerbot.*` keys, with separate
`.tbc` and `.wotlk` variants.

## Drift measurement

Run on 2026-08-25 to decide whether Turtle's core had drifted too far from ours for the
integration to be liftable. There is no shared git history — Turtle's core was uploaded as a
single "Initial commit" on 2025-12-15 — so everything below is content comparison.

### Raw text drift, 435 shared source files

```
our lines:                       252,248
tortoise added:                  105,415
our lines changed or removed:     66,282   (26.3%)
```

Both trees are CRLF, so this is real divergence, not line-ending noise. It is concentrated where
it does not matter: `Protocol/Opcodes_1_12_1.h` is 100% changed because Turtle is build 7272 and
every opcode *value* shifted (the names still match); `WardenAnticheat/WardenWin.cpp` is 92%
changed and the bots never touch it; `Player.cpp` at 24% and `ObjectMgr.cpp` at 39% are mostly
Turtle content additions.

### Functional drift, measured against what the bot module actually calls

| Surface | Result |
|---|---|
| Core headers included | 94. Three genuinely need porting: `ScriptObjects.h` (817 lines), `ModuleSlots.h` (29), `Handlers/LoginQueryHolder.h` (we have the class inline at `CharacterHandler.cpp:47`). The other thirteen absent ones are arena, vehicle and EY/IC/SA behind `#ifndef MANGOSBOT_ZERO`, or `windows.h`/Eluna |
| Opcode names used | 125, of which **111 present**. The missing fourteen are arena, WotLK LFG, gem sockets and spline-flying |
| Enum constants used | 240, of which **212 present**. Of the 28 missing, about thirteen are TBC/WotLK or Turtle races; about fifteen are renames for the shim (`ITEM_CLASS_MISC` to `ITEM_CLASS_JUNK`, `UNIT_FLAG_UNTARGETABLE`, several `UNIT_STAT_*`) |
| Method signatures compared across `Player.h`, `Unit.h`, `Group.h`, `Object.h`, `Creature.h`, `Item.h`, `SpellMgr.h`, `ObjectMgr.h` | 354 compared, **301 type-identical**. Of the 53 that differ, roughly thirteen are the matcher hitting an unrelated line and roughly twenty are const-qualifier or parameter-name only. Real breaks number about twenty: `CanStoreItem`/`CanBankItem` (we carry an extra `uint8& bagSlot` out-parameter), `AddCooldown` (`SpellEntry const&` against `const*`), `RemoveSpellCooldown` (`uint32` against `SpellEntry const*`), `SendSpellCooldown` (`Milliseconds` against `uint32`), `SaveToDB` (returns `bool` there), `InitTaxiNodes` (takes race and level there) |
| Methods absent from our tree | 60 — `IsInGroup`, `IsEnemy`, `IsFriend`, `IsStunned`, `HasMana`, `GetFaction`, `MeleeAttackStart` and so on. These turned out to be cmangos-compat wrappers Turtle added to its own `Player.h`/`Unit.h`, for example `bool IsEnemy(Unit const* t) const { return t && IsHostileTo(t); }`. One-liners. In our tree they belong in a shim header rather than the core |
| Module references to Turtle-only systems | 8 files: Shop (1), GuildBank (3), LFT (4) |

### The one structural break

The module drives the core by feeding client packets into session handlers — **136 call sites**
across 72 distinct handlers. Of those 72, **58 exist in our tree, and all 58 take vmangos typed
packets**; none takes a raw `WorldPacket`:

```
tortoise: void HandleMovementOpcodes(WorldPacket& recvPacket);
ours:     void HandleMovementOpcodes(WorldPackets::Movement::MovementPacket const& packet);
```

vmangos `development` moved the whole client-packet layer to typed structs; Turtle's core did not.
This is the real cost of sitting on the newer base, and it is bounded because the layer is
uniform — every typed packet reads from a `WorldPacket` (`src/game/Server/Packet.h`):

```cpp
class ClientPacket : public Packet {
public:
    virtual void ReadFromWorldPacket(WorldPacket& recv_data) = 0;
};
```

So the fix is 58 raw-`WorldPacket` overloads on `WorldSession` behind `#ifdef BUILD_PLAYERBOTS`,
two lines each: construct the typed packet, `ReadFromWorldPacket`, forward. Written once, all 136
module call sites then compile unchanged. Turtle already does the same thing at smaller scale —
`WorldSession.h:327` adds `SendPacket(WorldPacket const&)` with the comment "bot module calls
SendPacket(packet) by value."

The outgoing path is fine: we kept `void SendPacket(WorldPacket const* packet)` beside the
`unique_ptr<ServerPacket const>` overload, so the module's 25 `SendPacket` calls work unchanged.
Only `SendMessageToSet` (17 sites) and `BroadcastPacket` (2) need adapting.

### LFG has to be rewritten rather than shimmed

We have `src/game/LFG/`, but it is the vanilla **meeting stone** system —
`HandleMeetingStoneJoinOpcode`, `HandleLFGOpcode`. Turtle has an extended LFG/LFM with auto-join
and auto-fill (`HandleSetLfmOpcode`, `HandleLfmSetAutoFillOpcode`), and its bot-fill feature
(`LFT.BotFill.*`) is built on that. `LfgActions.cpp` and its strategy and triggers must be
retargeted to meeting stones or switched off.

### Conclusion

The drift does not reach into the `Unit` or `Spell` internals the bots depend on: 85% of called
signatures are identical and most of the misses are renames. It reaches into the packet layer,
which is mechanical, and the hook framework, which we would have to add under any plan.

# Decision

**Option A, taken 2026-08-25: port the tortoise-wow playerbots integration onto this fork.**

The alternatives were B, building the tiers above by hand over months, and C, running both bot
systems side by side. C was rejected because both systems create synthetic `WorldSession`s and
hang state off `Player`, and tortoise deliberately deleted the built-in bots rather than
co-exist. B was rejected because the travel-node data alone removes the largest single obstacle
it faced.

## Port plan

| Step | Work | Size |
|---|---|---|
| 1 | `ModuleSlots.h`, per-`Player` slot storage, and thirteen direct call sites into the module. The calls are unconditional and `PlayerbotStubs.cpp` carries the `BUILD_PLAYERBOTS=OFF` build, which keeps `#ifdef` noise out of the core — same arrangement as the donor. **Done**, `game.lib` and `mangosd.exe` both build | ~250 lines |
| 2 | Handler adapter: 59 raw-`WorldPacket` entry points on `WorldSession` behind `#ifdef BUILD_PLAYERBOTS`. **Done** — `src/game/Server/PlayerbotPacketAdapter.cpp`. They are `BotHandleXOpcode` twins rather than overloads of `HandleXOpcode`, because `Opcodes.cpp` reads each handler's packet class off `decltype(&WorldSession::HandleXOpcode)` and a second overload makes that name ambiguous, which breaks the entire opcode table. Cost of the rename: the module's 136 call sites need `->HandleX(` rewritten to `->BotHandleX(` when it is vendored, which is one substitution | 470 lines, generated |
| 2b | The module's `HandleMasterIncomingPacket` reads raw packet bytes. Our receive path parses a `WorldPacket` into a `ClientPacket` before queueing, so those bytes are gone by the time a handler has run and the `Playerbot_OnPacketHandled` hook fires with the parsed packet instead. The module side has to read the typed packet's fields rather than re-parse a buffer | unknown until the module is in |
| 3 | vmangos compat shim: 60 absent methods as one-line wrappers, ~15 enum renames, ~20 real signature fixes | 600–900 lines |
| 4 | Vendor the module, wire `BUILD_PLAYERBOTS`, add `PlayerbotStubs.cpp` and `HostHooks.cpp` equivalents | ~1 day |
| 5 | Adapt the 19 `SendMessageToSet`/`BroadcastPacket` sites; strip the 8 files referencing Shop, GuildBank and LFT; retarget or disable LFG | — |
| 6 | Import `sql/world/classic/*` and the characters-side tables; add `aiplayerbot.conf` | ~1 day |
| 7 | First boot, then the long tail: premade talent specs regenerated for stock vanilla trees rather than Turtle's reworked ones | open-ended |

The existing `src/game/PlayerBots/` (PartyBot, BattleBot) is expected to be removed or left
disabled, following what tortoise did. That decision can wait until step 4.

## Progress

State as of 2026-08-25, all of it uncommitted except step 1.

### Done

**Step 1 — hooks and module slots.** Committed as `3bc9f2f91` on `feat/playerbots-port`.
`ModuleSlots.h`, `PlayerbotHooks.h`, `PlayerbotStubs.cpp`, per-`Player` slot storage, thirteen
call sites, the `BUILD_PLAYERBOTS` option. `game.lib` and `mangosd.exe` both build with it off,
which is the default.

**Step 2 — packet adapter.** `src/game/Server/PlayerbotPacketAdapter.cpp`, 59 `BotHandleXOpcode`
entry points generated from `WorldSession.h`. Not overloads: `Opcodes.cpp` reads each handler's
packet class off `decltype(&WorldSession::HandleXOpcode)`, and a second overload makes that
ambiguous, which breaks the whole opcode table. The module's 99 call sites were rewritten to the
prefixed names.

**Step 4 — module vendored.** `src/modules/PlayerBots/`, 1021 files, 44 MB, wired into CMake
behind `BUILD_PLAYERBOTS` (off by default). Its build file was rewritten for this tree.

**Boost removed** from the vendored code, since this tree ships none and deliberately wrote its
own replacements (`src/shared/IO/README.md`). `playerbot/BotStringAlgo.h` replaces the five
`boost::algorithm` functions; `std::thread` replaces `boost::thread`; `cpptrace` replaces
`boost::stacktrace`; `IO::Filesystem::GetAllFilesInFolder` replaces
`boost::filesystem::directory_iterator`; a five-line hasher replaces `boost::hash`;
`boost::bimap` was included but never used. `PlayerbotCommandServer` - an external TCP port for
driving bots from outside the game, and the only user of `boost::asio` - was dropped, which
leaves `AiPlayerbot.CommandServerPort` inert.

**The hook glue.** The donor's three AzerothCore script classes became the `Playerbot_*` free
functions at the end of `playerbot/HostHooks.cpp`; `PlayerbotScripts.cpp` is gone.

**The module builds at C++17** while the core stays at C++14 - the vendored tree assumes 17
(`std::string_view` in ten files, inline variables). Mixing standard levels per target is
supported within one toolset.

### The donor's shim, adapted

Much of `cmangos-compat-shim.h` turned out to be working around gaps in Turtle's core that this
one does not have:

| The donor stubbed | Reality here |
|---|---|
| A hand-written `CharSections.dbc` parser, ~90 lines of `fopen`/`fread` | `DBCStores.cpp` loads it and publishes `sCharSectionMap` in the same shape |
| `ChatChannelsEntry` rebuilt from a DB table, with `pattern[]` rewired to owned strings | The DBC struct here already carries `pattern[8]`, which is what cmangos reads |
| `BarGoLink` | Real: `src/shared/ProgressBar.h` |
| `TimePoint` | Real: `Common.h`, at millisecond precision |
| `GenericTransport` as an alias for `Transport` | A real base class here |
| `TransportAnimation` and friends | Real: `Transports/TransportMgr.h` |
| `LfgRoles`, `LfgRolePriority` | Real enums: `src/game/LFG/LFGDefines.h` |
| `GetApplicationStartTime` | Real: `src/shared/Timer.h` |

### Core changes the port has needed so far

Beyond step 1 and step 2. Every one of them is a seam the module needs, written so a reader who
has never heard of the module can still tell what the method is for:

| Where | What | Why |
|---|---|---|
| `Handlers/LoginQueryHolder.h` | `LoginQueryHolder` extracted from `CharacterHandler.cpp` | the module logs bots in through `HandlePlayerLogin`, which takes one |
| `Player` | `CalculateTalentsPoints`, `GetQuestSlotQuestId`, `SetQuestSlot`, `SetVisibleItemSlot`, `UpdateSkillsForLevel` moved to public | all side-effect-free or field-level; the module walks the quest log and rerolls item properties the way the client would |
| `Player` | `Say(std::string const&, uint32)`, `Yell(std::string const&, uint32)` overloads | the module builds every line as a `std::string` |
| `Player` | `IsInGroup(Unit const*, bool raid)` | asked of whatever a bot is about to buff or heal, which is a `Unit*` far more often than a `Player*` |
| `Player` | `Whisper(char const*/std::string const&, uint32, ObjectGuid)` | whispers run through `MasterPlayer` here; a bot has no client and whispers a `Player` already in the world |
| `Unit` | `GetTarget()` | the selection (`UNIT_FIELD_TARGET`), which is not the same question as `GetVictim()` |
| `CreatureAI` | `SetReactState` / `GetReactState` / `HasReactState` forwarders | react state lives on `Creature` here; the module drives a bot's pet through its AI |
| `Group` | `GetActiveRoll(lootedTarget, itemSlot)` | the module reads what is being rolled on after its own view of the loot is gone |
| `Loot` | `GetLootingPlayers()` | so a bot does not release loot it never opened |
| `BattleGroundWS` | `GetFlagCarrierGuid(teamIndex)` | the same two guids by index rather than by side |
| `AuctionHouseMgr` | `AuctionSnapshot`, a recursive lock on `AuctionHouseObject` with `GetLock()` / `GetAuctionsBounds_locked()` / `GetAuctionsSnapshot()`, and `AuctionEntry::GetItemCount()` / `GetItemRandomPropertyId()` | ahbot runs on its own thread and cannot hold a pointer into `AuctionsMap` across a tick. Every mutator now takes the lock |
| `DBCStores` | `CharSectionsMap` typedef and `sCharSectionMap` published | the module rolls a random appearance out of it |
| `LFGQueue` | `GetPlayerQueueInfo` / `GetGroupQueueInfo` | the module fills the queue out with bots for what real players are waiting on |
| `ChannelMgr` | `GetChannels()` | the module picks the zone channel a bot should talk in |
| `WorldSession` | `SetPlayerbotSession` / `IsPlayerbotSession`, `ProcessQueuedPacketsNow()`, `SetPlayerLoading` | a driven character has no socket, so `CanProcessPackets()` would drop everything it queues for itself. Without this the queue is a silent no-op at runtime |

### Deliberately not ported

Each of these is a cmangos extension with no counterpart here. The call sites are stubbed with a
comment pointing back at this section rather than left to rot:

- **Navmesh avoid-areas.** `PathFinder::setArea` / `getArea` / `setAreaCost` paint and price
  navmesh polygons in cmangos. This core's `PathInfo` only queries the mesh. `SetAvoidAreaAction`
  and the `avoid add` / `avoid scan` debug commands return false; the RTSC debug line prints the
  position without area flags. Restoring it means a real pathfinder feature, not a shim.
- **`MotionMaster::MoveFall`.** No such generator here; a fall runs on its own movement flags.
- **`MotionMaster::MovePath`.** Replaced by launching a spline directly (`BotMovePath` in the
  shim), which is what this core's own debug movement does.
- **High Elf.** A Turtle-only playable race. Its entries were removed from the bot's race lists
  rather than mapped onto something else.
- **Per-map active zones.** cmangos's `Map` records which zones hold a player. Asking this core's
  map would count bots as players and defeat the purpose, so `RandomPlayerbotMgr` answers it from
  the real players it already tracks (`HasRealPlayerInZone` / `HasRealPlayerOnMap`).
- **Consumable subclasses.** `ITEM_SUBCLASS_POTION`/`FOOD`/... are commented out in
  `ItemPrototype.h` because pre-BC `item_template` only ever uses subclass 0. The shim declares
  them so the bot's classification compiles; on vanilla data those branches never match and the
  spell-effect checks beside them decide instead.
- **`PlayerbotCommandServer`** (dropped with boost::asio, see above) and the perf-mon GM command,
  which the donor's core declared on `ChatHandler`. This tree's command table is
  `ChatHandler::getCommandTable()` and the module does not extend it yet.

### Where it stands

The module compiles. Error count across passes: **1400 -> 902 -> 687 -> 412 -> 254 -> 126 -> 27 -> a
handful**, with `game.lib` building clean after every core change. What is left at the time of
writing is the last few translation units and then the link.

The count was never monotonic, and that is the shape of this work rather than a problem: a file
that used to die on line 50 compiles to line 900 once its first error is gone, so each pass both
clears a family and uncovers the next one behind it.

Families cleared, as a record of what the work looked like: spell casting entry points
(`SpellStart` -> `prepare`, `IsSpellReady`, `AddCooldown`, `RemoveSpellCooldown`,
`CastCustomSpell` base points), quest log and quest sharing, trainer spells (`learnedSpell`
resolved from the spell's `SPELL_EFFECT_LEARN_SPELL` effects), mail (which lives on
`MasterPlayer` here), loot (fields, slot types, release through the handler), auctions
(snapshots, buyout through `BotHandleAuctionPlaceBid`), gossip text (npc_text ids into
`broadcast_text`), chat channels, distances (`SizeFactor` rather than `DistanceCalculation` -
note cmangos returns the *square* for `DIST_CALC_NONE` and this core does not), creature template
fields, area entries and area triggers (the teleport is a separate row here), taxi paths
(`Path<>` is indexable but not iterable), graveyards, config keys, and the logger.

One build-level change was needed: `/bigobj` on this module. The strategy and action contexts
instantiate enough templates in a single translation unit to pass the 65,536-section limit of the
normal object format (C1128).

### Not yet started

- Step 2b, the master-packet path. `Playerbot_OnPacketHandled` is currently an empty body: the
  module's `HandleMasterIncomingPacket` reads raw bytes and this core has only the parsed packet
  by then. Bots will not mirror their owner's actions until it is done.
- LFG. `MeetingStoneInfo` is defined in the shim so the code compiles, but nothing fills a set,
  and `LfgActions.cpp` still calls handlers this core does not have.
- Step 6, the SQL import.
- Step 7, first boot.

## Two fixes worth taking regardless

Both are bugs tortoise found by running about a thousand bots, and both plausibly exist here:

- `BattleGroundQueue` declares a `recursive_mutex` whose five acquisitions were all left commented
  out during the ACE migration. Bots queueing from parallel map threads tear the `std::map` apart.
- `m_antiCheat` is only assigned during a network login, so a socketless session carries a null
  pointer for its whole life, and seven `MovementHandler` sites dereference it unchecked. Our
  existing `.partybot` and `.battlebot` sessions have exactly that shape.
